#!/usr/bin/env python3
# Real-Windows dual-boot replication under KVM: the permanent regression gate for
# "does our alongside install damage a pre-existing Windows disk?". A user's
# second real-hardware test reported Windows "fully broke" after an alongside
# install (drive undetected by Windows setup afterwards); this harness answers the
# question deterministically on a real Windows layout instead of a synthetic loop
# disk.
#
# It is Python, not bash, because the orchestration is heavy: three separate QEMU
# lifecycles (Windows autounattend install, Ryoku pexpect-driven install, two OVMF
# boot legs), a QEMU monitor for key injection + screendumps, OCR, and a pile of
# qemu-nbd byte-comparisons. install-vm.py already proves the pexpect + OVMF idiom
# in Python, and this reuses its serial contract; bash would fight the monitor and
# JSON diffing at every turn.
#
#   Stage 1  build a CACHED golden Windows 11 image (once) + an integrity manifest
#   Stage 2  qcow2 overlay of the golden; run Ryoku's alongside install from our ISO
#   Stage 3  assert table integrity + filesystem health + both boot legs via nbd/OCR
#
#   install-dualboot-vm.py --iso installation/iso/out/ryoku-*.iso        full run
#   install-dualboot-vm.py --golden-only                                 build cache
#   install-dualboot-vm.py --iso <iso> --skip-golden                     reuse cache
#
# Everything is qcow2/loop and nbd; it NEVER touches a physical disk. Needs root
# for modprobe nbd + qemu-nbd + mounts (re-invokes via sudo where needed). The
# golden image + Windows ISO are cached under cache/ (gitignored); overlays are
# per-run and deleted. See README.md and .superpowers/sdd/dualboot-vm-report.md.
import argparse
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
WIN_ISO = os.path.join(CACHE, "Win11_Enterprise_Eval_x64.iso")
GOLDEN = os.path.join(CACHE, "golden-windows.qcow2")
MANIFEST = os.path.join(CACHE, "golden-manifest.json")

# Windows 11 Enterprise EVALUATION, x64, en-US, build 26100 (24H2). The fwlink is
# Microsoft's stable Evaluation Center entry point; it 302s to a versioned prss
# URL. Evaluation licensing covers exactly this automated-test use. Size is the
# published Content-Length -- a partial/redirected download is caught by it.
WIN_ISO_URL = "https://go.microsoft.com/fwlink/?linkid=2289031"
WIN_ISO_BYTES = 5387960320

OVMF_CODE = next((p for p in (
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd",
    "/usr/share/OVMF/OVMF_CODE_4M.fd",
    "/usr/share/OVMF/OVMF_CODE.fd",
) if os.path.exists(p)), None)
OVMF_VARS = next((p for p in (
    "/usr/share/edk2/x64/OVMF_VARS.4m.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd",
    "/usr/share/OVMF/OVMF_VARS_4M.fd",
    "/usr/share/OVMF/OVMF_VARS.fd",
) if os.path.exists(p)), None)

# GPT partition type GUIDs we reason about (uppercase, as sfdisk --json emits).
GUID_EFI = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
GUID_MSR = "E3C9E316-0B5C-4DB8-817D-F92DF00215AE"
GUID_MSDATA = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"   # Windows C: (NTFS)
GUID_WINRE = "DE94BBA4-06D1-4D40-A16A-BFD50179D6AC"    # Windows Recovery
GUID_XBOOTLDR = "BC13C2FF-59E6-4262-A352-B275FD6F7172"  # Ryoku boot (sgdisk ea00)
GUID_LINUX = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"     # Ryoku root (sgdisk 8300)

MIB = 1024 * 1024


def log(msg):
    print(f"dualboot-vm: {msg}", flush=True)


def die(msg, code=1):
    print(f"dualboot-vm: FATAL: {msg}", file=sys.stderr, flush=True)
    sys.exit(code)


def run(cmd, check=True, capture=False, **kw):
    if capture:
        kw["stdout"] = subprocess.PIPE
        kw["stderr"] = subprocess.STDOUT
    r = subprocess.run(cmd, check=check, text=True, **kw)
    return r.stdout if capture else r


def sudo(cmd, **kw):
    return run(["sudo", *cmd], **kw)


def free_gib(path="/"):
    return shutil.disk_usage(path).free / (1024 ** 3)


def guard_space(need_gib, what):
    have = free_gib()
    log(f"df guard: {have:.1f} GiB free, need >= {need_gib} GiB for {what}")
    if have < need_gib:
        die(f"only {have:.1f} GiB free on /, need >= {need_gib} GiB for {what}; "
            f"free space and retry (golden cache is kept, overlays are deleted).")


# ----------------------------------------------------------------------------- #
# autounattend.xml: wipe disk 0 and lay Windows' real UEFI anatomy (ESP + MSR +
# C: + a trailing WinRE-typed partition), skip OOBE, create a local admin, and at
# first logon shrink C: by 300 GiB before shutting down. Because WinRE sits AFTER
# C:, the shrink leaves ~300 GiB unallocated in the MIDDLE of the disk -- the
# user's exact fragmented case, not the trivial trailing-free one.
#
# No TPM device is attached (bypass keys instead of a swtpm dependency): the
# LabConfig BypassTPMCheck/BypassSecureBootCheck/BypassRAMCheck keys added in the
# windowsPE pass let 24H2 install on a machine with no TPM and Secure Boot off.
# C: is fixed-size (not Extend) so a real recovery partition can live at the end;
# the leftover trailing slack is tiny and never wins "largest free region".
AUTOUNATTEND = r"""<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>0409:00000409</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add"><Order>1</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add"><Order>2</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add"><Order>3</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
      </RunSynchronous>
      <DiskConfiguration>
        <WillShowUI>OnError</WillShowUI>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>300</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>128</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Size>510000</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>4</Order><Type>Primary</Type><Size>900</Size></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Label>System</Label><Format>FAT32</Format></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Label>Windows</Label><Letter>C</Letter><Format>NTFS</Format></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>4</Order><PartitionID>4</PartitionID><Label>Recovery</Label><Format>NTFS</Format><TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
          <InstallToAvailablePartition>false</InstallToAvailablePartition>
          <InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/INDEX</Key><Value>1</Value></MetaData></InstallFrom>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>ryoku</FullName>
        <Organization>Ryoku</Organization>
      </UserData>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <ComputerName>WINGOLD</ComputerName>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <InputLocale>0409:00000409</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
        <NetworkLocation>Home</NetworkLocation>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>ryoku</Name>
            <Group>Administrators</Group>
            <Password><Value>ryoku</Value><PlainText>true</PlainText></Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Enabled>true</Enabled>
        <Username>ryoku</Username>
        <Password><Value>ryoku</Value><PlainText>true</PlainText></Password>
        <LogonCount>1</LogonCount>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>cmd.exe /c "(echo select volume C &amp; echo shrink desired=307200) > C:\shrink.txt &amp; diskpart /s C:\shrink.txt > C:\shrink.log 2>&amp;1 &amp; shutdown /s /t 5"</CommandLine>
          <Description>shrink C by 300 GiB then power off</Description>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"""


# ----------------------------------------------------------------------------- #
# QEMU helpers.
def accel_args():
    if os.path.exists("/dev/kvm"):
        return ["-enable-kvm", "-cpu", "host"]
    return ["-cpu", "max"]


def fresh_vars(work, name="OVMF_VARS.fd"):
    dst = os.path.join(work, name)
    shutil.copy(OVMF_VARS, dst)
    return dst


class Monitor:
    # Thin HMP-over-unix-socket client: enough to send screendump/sendkey and read
    # the echoed banner. QEMU speaks the human monitor here, one command per line.
    def __init__(self, path):
        self.path = path
        self.sock = None

    def connect(self, tries=50):
        for _ in range(tries):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(self.path)
                s.settimeout(2)
                self.sock = s
                time.sleep(0.3)
                self._drain()
                return True
            except OSError:
                time.sleep(0.3)
        return False

    def _drain(self):
        try:
            while True:
                if not self.sock.recv(4096):
                    break
        except OSError:
            pass

    def cmd(self, line):
        self.sock.sendall((line + "\n").encode())
        time.sleep(0.4)
        self._drain()

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None


def key_pusher(monitor_path, key, seconds, interval=1.0):
    # Satisfy the "Press any key to boot from CD" prompt: tap a key for the first
    # few seconds only. We stop after that so later reboots (CD still first in the
    # boot order) time out at the prompt and fall through to the installed HDD --
    # this is what breaks the setup reboot loop without repacking the ISO.
    def worker():
        mon = Monitor(monitor_path)
        if not mon.connect():
            return
        end = time.time() + seconds
        while time.time() < end:
            try:
                mon.cmd(f"sendkey {key}")
            except OSError:
                break
            time.sleep(interval)
        mon.close()
    t = threading.Thread(target=worker, daemon=True)
    t.start()
    return t


# ----------------------------------------------------------------------------- #
# nbd helpers (root). Every disk read/compare goes through qemu-nbd, read-only
# wherever the check allows, so the overlay we assert on is never mutated by the
# assertion itself.
def nbd_modprobe():
    sudo(["modprobe", "nbd", "max_part=16"], check=False)


def nbd_find_free():
    for n in range(16):
        dev = f"/dev/nbd{n}"
        pid = f"/sys/block/nbd{n}/pid"
        if os.path.exists(dev) and not os.path.exists(pid):
            return dev
    die("no free /dev/nbdN device")


def nbd_connect(img, readonly):
    nbd_modprobe()
    dev = nbd_find_free()
    args = ["qemu-nbd", "-c", dev, "--cache=none", "--discard=unmap"]
    if readonly:
        args.append("-r")
    args.append(img)
    sudo(args)
    sudo(["partprobe", dev], check=False)
    for _ in range(20):
        if os.path.exists(dev + "p1"):
            break
        time.sleep(0.5)
    sudo(["udevadm", "settle"], check=False)
    return dev


def nbd_disconnect(dev):
    if not dev:
        return
    subprocess.run(["sync"], check=False)
    sudo(["qemu-nbd", "-d", dev], check=False)
    time.sleep(0.5)


def sfdisk_json(dev):
    out = sudo(["sfdisk", "--json", dev], capture=True)
    return json.loads(out)["partitiontable"]


def part_edge_shas(dev, part_node, size_sectors, sector_bytes):
    # sha256 of the first and last 1 MiB of a partition: cheap fingerprint that
    # flips if the installer wrote anywhere near either boundary. Read via nbd.
    size_mib = (size_sectors * sector_bytes) // MIB
    # dd binary output must not go through text=True; read raw bytes.
    first_b = subprocess.run(["sudo", "dd", f"if={part_node}", "bs=1M", "count=1",
                              "status=none"], stdout=subprocess.PIPE, check=True).stdout
    last_off = max(size_mib - 1, 0)
    last_b = subprocess.run(["sudo", "dd", f"if={part_node}", "bs=1M", "count=1",
                             f"skip={last_off}", "status=none"],
                            stdout=subprocess.PIPE, check=True).stdout
    return hashlib.sha256(first_b).hexdigest(), hashlib.sha256(last_b).hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ----------------------------------------------------------------------------- #
# Stage 1: golden Windows image + integrity manifest.
def download_windows_iso():
    if os.path.exists(WIN_ISO) and os.path.getsize(WIN_ISO) == WIN_ISO_BYTES:
        log(f"Windows ISO cached ({WIN_ISO_BYTES} bytes) -> {WIN_ISO}")
        return
    os.makedirs(CACHE, exist_ok=True)
    guard_space(8, "Windows ISO download")
    log("downloading Windows 11 Enterprise evaluation ISO (~5 GiB, resumable)")
    run(["curl", "-L", "--fail", "--retry", "8", "--retry-delay", "5",
         "-C", "-", "-o", WIN_ISO, WIN_ISO_URL])
    sz = os.path.getsize(WIN_ISO)
    if sz != WIN_ISO_BYTES:
        die(f"Windows ISO size {sz} != expected {WIN_ISO_BYTES}; download corrupt")
    log(f"Windows ISO OK ({sz} bytes)")


def build_answer_iso(work):
    # Windows setup auto-loads \autounattend.xml from the root of any attached
    # removable/optical media; a tiny second CD is the driver-free way to deliver
    # it (no virtio, no USB stack assumptions).
    src = os.path.join(work, "answer")
    os.makedirs(src, exist_ok=True)
    with open(os.path.join(src, "autounattend.xml"), "w") as f:
        f.write(AUTOUNATTEND)
    iso = os.path.join(work, "answer.iso")
    run(["xorriso", "-as", "mkisofs", "-J", "-r", "-V", "UNATTEND",
         "-o", iso, src], capture=True)
    return iso


def install_windows(work):
    guard_space(20, "golden Windows install")
    log("creating 500 GiB sparse golden qcow2 (SATA/AHCI, no drivers needed)")
    run(["qemu-img", "create", "-f", "qcow2", GOLDEN, "500G"], capture=True)
    answer = build_answer_iso(work)
    varsfd = fresh_vars(work)
    mon_path = os.path.join(work, "mon-win.sock")
    cmd = [
        "qemu-system-x86_64", "-machine", "q35", *accel_args(),
        "-m", "6144", "-smp", "4",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={varsfd}",
        "-device", "ich9-ahci,id=ahci",
        "-drive", f"if=none,id=hd,format=qcow2,file={GOLDEN}",
        "-device", "ide-hd,drive=hd,bus=ahci.0,bootindex=2",
        "-drive", f"if=none,id=wincd,media=cdrom,readonly=on,file={WIN_ISO}",
        "-device", "ide-cd,drive=wincd,bus=ahci.1,bootindex=1",
        "-drive", f"if=none,id=anscd,media=cdrom,readonly=on,file={answer}",
        "-device", "ide-cd,drive=anscd,bus=ahci.2",
        "-netdev", "user,id=n0", "-device", "e1000,netdev=n0",
        "-display", "none", "-vga", "std",
        "-monitor", f"unix:{mon_path},server,nowait",
        "-serial", f"file:{os.path.join(work, 'win-serial.log')}",
    ]
    log("booting Windows setup (unattended); this runs 20-50 min under KVM")
    proc = subprocess.Popen(cmd)
    # Tap Enter for the first 25s to clear the initial "press any key" CD prompt.
    key_pusher(mon_path, "ret", 25)
    timeout = 60 * 75
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        die(f"Windows install did not power off within {timeout}s "
            f"(see {os.path.join(work, 'win-serial.log')})")
    if proc.returncode not in (0, None):
        log(f"note: qemu exited rc={proc.returncode} (guest shutdown)")
    log("Windows guest powered off after autounattend shrink")


def record_manifest(work):
    log("recording golden integrity manifest via qemu-nbd (read-only)")
    dev = nbd_connect(GOLDEN, readonly=True)
    try:
        table = sfdisk_json(dev)
        sector = table.get("sectorsize", 512)
        parts = []
        esp_node = None
        for p in table["partitions"]:
            node = p["node"]
            start = p["start"]
            size = p["size"]
            ptype = p["type"].upper()
            first_sha, last_sha = part_edge_shas(dev, node, size, sector)
            entry = {
                "node": node,
                "number": int(re.sub(r".*[^0-9]", "", node)),
                "start": start,
                "size": size,
                "end": start + size - 1,
                "type": ptype,
                "uuid": p.get("uuid", "").upper(),
                "name": p.get("name", ""),
                "first_mib_sha256": first_sha,
                "last_mib_sha256": last_sha,
            }
            parts.append(entry)
            if ptype == GUID_EFI:
                esp_node = node
        if not esp_node:
            die("golden has no EFI system partition; autounattend layout failed")
        esp_info = probe_esp_baseline(esp_node)
        manifest = {
            "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "windows_iso_sha256_bytes": WIN_ISO_BYTES,
            "disk_bytes": table["lastlba"] * sector,
            "sector_size": sector,
            "partitions": parts,
            "windows_esp": esp_info,
        }
        with open(MANIFEST, "w") as f:
            json.dump(manifest, f, indent=2)
        log(f"manifest written: {len(parts)} partitions -> {MANIFEST}")
        summary = ", ".join(f"{e['number']}:{e['type'][:8]}({e['size']//2//1024}MiB)"
                            for e in parts)
        log(f"golden layout: {summary}")
        return manifest
    finally:
        nbd_disconnect(dev)


def fsck_vfat_normalized(node):
    # fsck.vfat -n (read-only) then strip the version banner and the "N files,
    # X/Y clusters" summary (both differ once we add files). What remains is the
    # set of structural notes/errors; comparing overlay-vs-golden on THIS proves
    # the alongside install introduced no NEW filesystem issues -- a stock Windows
    # ESP already returns rc=1 for a benign "no label in boot sector" note.
    r = subprocess.run(["sudo", "fsck.vfat", "-n", node],
                       capture_output=True, text=True)
    keep = []
    for ln in (r.stdout + r.stderr).splitlines():
        s = ln.strip()
        if not s:
            continue
        if s.startswith("fsck.fat"):
            continue
        if re.match(r"^\S+: \d+ files, \d+/\d+ clusters$", s):
            continue
        keep.append(s)
    return r.returncode, "\n".join(keep)


def probe_esp_baseline(esp_node):
    # Baseline the Windows ESP: count files under /EFI/Microsoft and hash
    # bootmgfw.efi, so Stage 3B can prove Ryoku left Windows' boot tree untouched.
    mnt = tempfile.mkdtemp(prefix="esp-base-")
    sudo(["mount", "-o", "ro", esp_node, mnt])
    try:
        ms = os.path.join(mnt, "EFI", "Microsoft")
        count = 0
        bootmgfw_sha = None
        for root, _dirs, files in os.walk(ms):
            for fn in files:
                count += 1
                if fn.lower() == "bootmgfw.efi":
                    fp = os.path.join(root, fn)
                    bootmgfw_sha = subprocess.run(
                        ["sudo", "sha256sum", fp], capture_output=True, text=True,
                        check=True).stdout.split()[0]
        rc, fsck_norm = fsck_vfat_normalized(esp_node)
        return {"node": esp_node, "microsoft_file_count": count,
                "bootmgfw_sha256": bootmgfw_sha,
                "fsck_rc": rc, "fsck_normalized": fsck_norm}
    finally:
        sudo(["umount", mnt], check=False)
        os.rmdir(mnt)


def build_golden(work):
    if os.path.exists(GOLDEN) and os.path.exists(MANIFEST):
        log("golden image + manifest already cached; skipping Stage 1 build")
        with open(MANIFEST) as f:
            return json.load(f)
    os.makedirs(CACHE, exist_ok=True)
    download_windows_iso()
    install_windows(work)
    manifest = record_manifest(work)
    write_cache_readme()
    return manifest


def write_cache_readme():
    with open(os.path.join(CACHE, "README.md"), "w") as f:
        f.write(
            "# installation/tests/cache/ (gitignored)\n\n"
            "Built by `install-dualboot-vm.py`. Never committed.\n\n"
            "- `Win11_Enterprise_Eval_x64.iso` -- Windows 11 Enterprise evaluation "
            "(Microsoft Evaluation Center, build 26100). Evaluation licensing "
            "covers this automated-test use only.\n"
            "- `golden-windows.qcow2` -- a real Windows 11 install with ESP+MSR+C:"
            "+WinRE, C: pre-shrunk 300 GiB (unallocated in the MIDDLE). The pristine "
            "dual-boot baseline; every run overlays it, never mutates it.\n"
            "- `golden-manifest.json` -- the integrity baseline (per-partition "
            "start/end/PARTUUID/typeGUID + first/last-MiB sha256, ESP file count + "
            "bootmgfw.efi sha).\n")


# ----------------------------------------------------------------------------- #
# Stage 2: overlay + Ryoku alongside install (pexpect over serial, install-vm.py
# contract with the two alongside tweaks: AHCI /dev/sda + strategy=alongside).
def make_overlay(work):
    guard_space(20, "Ryoku alongside overlay + install")
    overlay = os.path.join(work, "overlay.qcow2")
    run(["qemu-img", "create", "-f", "qcow2", "-b", os.path.abspath(GOLDEN),
         "-F", "qcow2", overlay], capture=True)
    log(f"overlay created (golden stays pristine) -> {overlay}")
    return overlay


def ryoku_install(work, iso, overlay, user="ryoku"):
    import pexpect
    varsfd = fresh_vars(work, "OVMF_VARS_ryoku.fd")
    serial_log = os.path.join(work, "ryoku-serial.log")
    # AHCI /dev/sda (not virtio /dev/vda) so the disk bus matches the golden and
    # both boot legs: stock Windows keeps a driver-free boot disk, and Ryoku's
    # autodetect initramfs is built against the same controller it will boot on.
    cmd = [
        "qemu-system-x86_64", "-machine", "q35", *accel_args(),
        "-m", "4096", "-smp", "4",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={varsfd}",
        "-device", "ich9-ahci,id=ahci",
        "-drive", f"if=none,id=hd,format=qcow2,file={overlay}",
        "-device", "ide-hd,drive=hd,bus=ahci.0,bootindex=2",
        "-drive", f"file={iso},media=cdrom,readonly=on,if=none,id=cd",
        "-device", "ide-cd,drive=cd,bus=ahci.1,bootindex=1",
        "-netdev", "user,id=n0", "-device", "e1000,netdev=n0",
        "-nographic",
    ]
    pwhash = subprocess.check_output(["openssl", "passwd", "-6", "ryoku"]).decode().strip()
    timeout = 60 * 55
    print(f"dualboot-vm: booting Ryoku ISO for alongside install; log -> {serial_log}")
    child = pexpect.spawn(" ".join(cmd), timeout=timeout, encoding="utf-8",
                          codec_errors="replace")
    child.logfile = open(serial_log, "w")

    def sh(line, t=180):
        child.sendline(line)
        child.expect(r"# ", timeout=t)
        return child.before

    def bail(msg):
        try:
            child.close(force=True)
        except Exception:
            pass
        with open(serial_log) as f:
            tail = f.read()[-4000:]
        die(f"{msg}\n--- ryoku serial tail ---\n{tail}")

    try:
        i = child.expect([r"login:", r"# ", pexpect.TIMEOUT], timeout=420)
        if i == 2:
            bail("Ryoku ISO never reached a serial prompt")
        if i == 0:
            child.sendline("root")
            child.expect(r"# ", timeout=120)
        log_reached = "live shell reached"
        print(f"dualboot-vm: {log_reached}")
        # alongside contract: keep every existing partition, take the largest free
        # region (omit RYOKU_REGION_*), defaults elsewhere. NO RYOKU_WIPE_CONFIRMED.
        env = (f"RYOKU_DISK=/dev/sda RYOKU_DISK_STRATEGY=alongside "
               f"RYOKU_PROFILE=vm RYOKU_HOSTNAME=ryoku-dual RYOKU_USERNAME={user} "
               f"RYOKU_SKIP_AUR=1 RYOKU_REPO=/usr/share/ryoku "
               f"RYOKU_KEYMAP=us RYOKU_XKB_LAYOUT=us "
               f"RYOKU_PASSWORD_HASH='{pwhash}'")
        sh(": > /usr/share/ryoku/system/packages/aur.packages", t=60)
        child.sendline(f"export {env}; ryoku-install; echo BACKEND_EXIT:$?")
        j = child.expect([r"@@RYOKU_DONE", r"BACKEND_EXIT:[1-9]", pexpect.TIMEOUT],
                         timeout=timeout)
        if j != 0:
            bail("ryoku-install did not reach @@RYOKU_DONE (alongside install failed)")
        child.expect(r"BACKEND_EXIT:0", timeout=180)
        child.expect(r"# ", timeout=60)
        print("dualboot-vm: @@RYOKU_DONE, alongside backend exit 0")
        child.sendline("poweroff")
        try:
            child.expect(pexpect.EOF, timeout=180)
        except (pexpect.TIMEOUT, pexpect.EOF):
            pass
    except (pexpect.TIMEOUT, pexpect.EOF):
        bail("timeout/EOF during Ryoku alongside install")
    finally:
        try:
            child.logfile.close()
        except Exception:
            pass


# ----------------------------------------------------------------------------- #
# Stage 3A: table integrity.
def assert_table(overlay, manifest, ev):
    log("Stage 3A: table integrity (qemu-nbd read-only)")
    dev = nbd_connect(overlay, readonly=True)
    diffs = []
    try:
        table = sfdisk_json(dev)
        sector = table.get("sectorsize", 512)
        cur = {p.get("uuid", "").upper(): p for p in table["partitions"]}
        cur_by_type = {}
        for p in table["partitions"]:
            cur_by_type.setdefault(p["type"].upper(), []).append(p)

        # every pre-existing partition byte-identical (start/end/type/uuid + edges)
        pre_uuids = set()
        for base in manifest["partitions"]:
            u = base["uuid"]
            pre_uuids.add(u)
            match = cur.get(u)
            if not match:
                diffs.append(f"pre-existing partition PARTUUID {u} "
                             f"({base['type']}) VANISHED after install")
                continue
            if match["start"] != base["start"]:
                diffs.append(f"{u}: start {base['start']} -> {match['start']}")
            if match["start"] + match["size"] - 1 != base["end"]:
                diffs.append(f"{u}: end {base['end']} -> "
                             f"{match['start'] + match['size'] - 1}")
            if match["type"].upper() != base["type"]:
                diffs.append(f"{u}: typeGUID {base['type']} -> {match['type']}")
            # The Windows ESP is the ONE partition alongside intentionally writes
            # (it shares it: our loader lands in /EFI/ryoku, Windows' /EFI/Microsoft
            # is left alone). So its raw edge bytes legitimately change -- its
            # contents integrity is proven in Stage 3B (Microsoft subtree file count
            # + bootmgfw.efi sha + fsck). Every OTHER pre-existing partition must be
            # byte-identical at both edges: that is where damage would show.
            if base["type"] == GUID_EFI:
                ev.setdefault("stage3A_notes", []).append(
                    f"{u}: shared Windows ESP, edge bytes expected to change "
                    f"(geometry checked here, contents in Stage 3B)")
            else:
                fsha, lsha = part_edge_shas(dev, match["node"], match["size"], sector)
                if fsha != base["first_mib_sha256"]:
                    diffs.append(f"{u}: first-MiB sha {base['first_mib_sha256'][:12]} "
                                 f"-> {fsha[:12]} (bytes changed at partition start)")
                if lsha != base["last_mib_sha256"]:
                    diffs.append(f"{u}: last-MiB sha {base['last_mib_sha256'][:12]} "
                                 f"-> {lsha[:12]} (bytes changed at partition end)")

        # exactly two NEW partitions, and they are our ryokuboot + ryoku
        new = [p for p in table["partitions"] if p.get("uuid", "").upper() not in pre_uuids]
        new_summary = [f"{p['node']}({p['type'][:8]},{p.get('name','')})" for p in new]
        if len(new) != 2:
            diffs.append(f"expected exactly 2 NEW partitions, found {len(new)}: "
                         f"{new_summary}")
        types_new = sorted(p["type"].upper() for p in new)
        if types_new != sorted([GUID_XBOOTLDR, GUID_LINUX]):
            diffs.append(f"new partition types {types_new} != XBOOTLDR+Linux "
                         f"({GUID_XBOOTLDR},{GUID_LINUX})")

        # the new partitions lie strictly inside the FORMER free region (the gap
        # between C: end and the trailing WinRE start).
        cbytes = sorted(manifest["partitions"], key=lambda e: e["start"])
        gap_start = gap_end = None
        for a, b in zip(cbytes, cbytes[1:]):
            if b["start"] - (a["end"] + 1) >= 2 * 1024 * MIB // sector:
                if gap_start is None or (b["start"] - a["end"]) > (gap_end - gap_start):
                    gap_start, gap_end = a["end"] + 1, b["start"] - 1
        if gap_start is None:
            diffs.append("no former free region found between pre-existing partitions")
        else:
            for p in new:
                s, e = p["start"], p["start"] + p["size"] - 1
                if s < gap_start or e > gap_end:
                    diffs.append(f"new {p['node']} sectors {s}-{e} escape the former "
                                 f"free region {gap_start}-{gap_end}")

        # still exactly ONE EF00 on the disk (Windows' ESP; ours is ea00 XBOOTLDR)
        ef = [p for p in table["partitions"] if p["type"].upper() == GUID_EFI]
        if len(ef) != 1:
            diffs.append(f"expected exactly 1 EF00 ESP, found {len(ef)}")

        ev["stage3A_table"] = {
            "pre_existing_checked": len(manifest["partitions"]),
            "new_partitions": new_summary,
            "former_free_region_sectors": [gap_start, gap_end],
            "ef00_count": len(ef),
            "diffs": diffs,
        }
    finally:
        nbd_disconnect(dev)
    ok = not diffs
    log(f"Stage 3A: {'PASS' if ok else 'FAIL'} ({len(diffs)} diffs)")
    for d in diffs:
        log(f"  DIFF: {d}")
    return ok


# ----------------------------------------------------------------------------- #
# Stage 3B: filesystem health.
def assert_filesystems(overlay, manifest, ev):
    log("Stage 3B: filesystem health")
    dev = nbd_connect(overlay, readonly=True)
    findings = {}
    problems = []
    try:
        table = sfdisk_json(dev)
        parts = table["partitions"]
        esp = next((p for p in parts if p["type"].upper() == GUID_EFI), None)
        cvol = next((p for p in parts if p["type"].upper() == GUID_MSDATA), None)
        boot = next((p for p in parts if p["type"].upper() == GUID_XBOOTLDR), None)
        root = next((p for p in parts if p["type"].upper() == GUID_LINUX), None)

        # Windows ESP: fsck.vfat -n must introduce no NEW issues vs the pristine
        # golden. A stock Windows ESP already returns rc=1 for a benign "no label
        # in boot sector" note, so we compare the NORMALIZED output to the baseline
        # rather than trusting rc.
        if esp:
            rc, fsck_norm = fsck_vfat_normalized(esp["node"])
            base = manifest["windows_esp"]
            findings["esp_fsck_rc"] = rc
            findings["esp_fsck_normalized"] = fsck_norm
            findings["esp_fsck_baseline"] = base.get("fsck_normalized", "")
            if fsck_norm != base.get("fsck_normalized", ""):
                problems.append(f"Windows ESP fsck introduced NEW issues vs golden: "
                                f"{fsck_norm!r} (baseline {base.get('fsck_normalized','')!r})")

            mnt = tempfile.mkdtemp(prefix="esp-chk-")
            sudo(["mount", "-o", "ro", esp["node"], mnt])
            try:
                ms = os.path.join(mnt, "EFI", "Microsoft")
                count = 0
                bootmgfw_sha = None
                for rt, _d, fs in os.walk(ms):
                    for fn in fs:
                        count += 1
                        if fn.lower() == "bootmgfw.efi":
                            bootmgfw_sha = subprocess.run(
                                ["sudo", "sha256sum", os.path.join(rt, fn)],
                                capture_output=True, text=True, check=True
                            ).stdout.split()[0]
                base = manifest["windows_esp"]
                findings["ms_file_count"] = count
                findings["ms_file_count_baseline"] = base["microsoft_file_count"]
                findings["bootmgfw_sha256"] = bootmgfw_sha
                findings["bootmgfw_sha256_baseline"] = base["bootmgfw_sha256"]
                if count != base["microsoft_file_count"]:
                    problems.append(f"/EFI/Microsoft file count {count} != baseline "
                                    f"{base['microsoft_file_count']}")
                if bootmgfw_sha != base["bootmgfw_sha256"]:
                    problems.append("bootmgfw.efi sha256 changed (Windows boot binary "
                                    "modified)")
                findings["ryoku_bootx64_present"] = os.path.exists(
                    os.path.join(mnt, "EFI", "ryoku", "BOOTX64.EFI"))
                findings["ryoku_limineconf_present"] = os.path.exists(
                    os.path.join(mnt, "EFI", "ryoku", "limine.conf"))
                if not findings["ryoku_bootx64_present"]:
                    problems.append("our /EFI/ryoku/BOOTX64.EFI missing on the ESP")
                if not findings["ryoku_limineconf_present"]:
                    problems.append("our /EFI/ryoku/limine.conf missing on the ESP")
            finally:
                sudo(["umount", mnt], check=False)
                os.rmdir(mnt)
        else:
            problems.append("no ESP on overlay")

        # ESP backup tar on the new Ryoku root (@/var/backups/ryoku/).
        if root:
            mnt = tempfile.mkdtemp(prefix="root-chk-")
            mounted = False
            for opt in ("subvol=@", "subvolid=5"):
                r = subprocess.run(["sudo", "mount", "-o", f"ro,{opt}",
                                    root["node"], mnt], capture_output=True, text=True)
                if r.returncode == 0:
                    mounted = True
                    break
            if mounted:
                try:
                    bdir = os.path.join(mnt, "var", "backups", "ryoku")
                    tars = []
                    if os.path.isdir(bdir):
                        tars = [f for f in os.listdir(bdir)
                                if f.startswith("windows-esp-") and f.endswith(".tar")]
                    findings["esp_backup_tars"] = tars
                    if not tars:
                        problems.append("ESP backup tar missing on the new root "
                                        "(@/var/backups/ryoku/windows-esp-*.tar)")
                finally:
                    sudo(["umount", mnt], check=False)
                    os.rmdir(mnt)
            else:
                problems.append("could not mount the new Ryoku root read-only")
        else:
            problems.append("no Ryoku root partition on overlay")

        # NTFS C: consistency (no ntfsfix in this ntfs-3g build): probe + a
        # read-only ntfs-3g mount with a spot check that the registry hive dir
        # exists, then unmount. Equivalent health evidence.
        if cvol:
            r = subprocess.run(["sudo", "ntfs-3g.probe", "--readonly", cvol["node"]],
                               capture_output=True, text=True)
            findings["ntfs_probe_rc"] = r.returncode
            if r.returncode != 0:
                problems.append(f"ntfs-3g.probe --readonly rc={r.returncode} "
                                f"(C: not cleanly mountable): {r.stderr.strip()[:200]}")
            mnt = tempfile.mkdtemp(prefix="ntfs-chk-")
            m = subprocess.run(["sudo", "ntfs-3g", "-o", "ro", cvol["node"], mnt],
                               capture_output=True, text=True)
            if m.returncode == 0:
                try:
                    # ntfs-3g mounts are root-only; probe with sudo test, not os.path.
                    cfg = os.path.join(mnt, "Windows", "System32", "config")
                    have_cfg = subprocess.run(["sudo", "test", "-d", cfg]).returncode == 0
                    have_hive = subprocess.run(
                        ["sudo", "test", "-f", os.path.join(cfg, "SYSTEM")]).returncode == 0
                    findings["ntfs_config_dir_present"] = have_cfg
                    findings["ntfs_system_hive_present"] = have_hive
                    if not have_cfg:
                        problems.append("C:\\Windows\\System32\\config missing "
                                        "(NTFS tree damaged)")
                    if not have_hive:
                        problems.append("C:\\Windows\\System32\\config\\SYSTEM hive "
                                        "missing (registry damaged)")
                finally:
                    sudo(["umount", mnt], check=False)
                    os.rmdir(mnt)
            else:
                problems.append(f"ntfs-3g ro mount of C: failed: {m.stderr.strip()[:200]}")
                os.rmdir(mnt)
        else:
            problems.append("no Windows C: (NTFS) partition on overlay")
    finally:
        nbd_disconnect(dev)
    findings["problems"] = problems
    ev["stage3B_filesystems"] = findings
    ok = not problems
    log(f"Stage 3B: {'PASS' if ok else 'FAIL'} ({len(problems)} problems)")
    for p in problems:
        log(f"  PROBLEM: {p}")
    return ok


# ----------------------------------------------------------------------------- #
# Stage 3C: both boot legs under OVMF.
def prep_overlay_bootconf(overlay, work):
    # Prepare ONLY the overlay for the boot legs (the golden stays pristine):
    #  * bump the limine timeout to 30s and give the Ryoku entry a serial console
    #    (drop quiet/splash) so leg 1 is assertable on ttyS0;
    #  * make the ESP's removable fallback \EFI\BOOT\BOOTX64.EFI = limine. On a
    #    real machine firmware boots limine via the "Ryoku" NVRAM entry the backend
    #    registered (\EFI\ryoku\BOOTX64.EFI); our leg VMs start from FRESH OVMF
    #    VARS with no NVRAM, so OVMF falls back to \EFI\BOOT\BOOTX64.EFI -- which
    #    Windows owns (its bootmgr). Pointing that fallback at the SAME limine
    #    binary (same ESP, same limine.conf) reproduces exactly what the NVRAM
    #    entry boots, without editing an offline VARS file.
    dev = nbd_connect(overlay, readonly=False)
    conf_text = None
    try:
        table = sfdisk_json(dev)
        esp = next((p for p in table["partitions"] if p["type"].upper() == GUID_EFI), None)
        if not esp:
            die("boot-leg prep: no ESP on overlay")
        mnt = tempfile.mkdtemp(prefix="esp-boot-")
        sudo(["mount", esp["node"], mnt])
        try:
            src = os.path.join(mnt, "EFI", "ryoku", "limine.conf")
            raw = subprocess.run(["sudo", "cat", src], capture_output=True,
                                 text=True, check=True).stdout
            lines = []
            for ln in raw.splitlines():
                s = ln.strip()
                if s.startswith("timeout:"):
                    lines.append("timeout: 30")
                    continue
                if s.startswith("remember_last_entry:"):
                    # deterministic default across the two legs: entry 1 (Ryoku),
                    # so leg 2's single DOWN always lands on Windows (entry 2).
                    lines.append("remember_last_entry: no")
                    continue
                if s.startswith("default_entry:"):
                    lines.append("default_entry: 1")
                    continue
                if s.startswith("cmdline:") and "vmlinuz" not in s:
                    c = re.sub(r"\bquiet\b|\bsplash\b", "", ln).rstrip()
                    lines.append(c + " console=ttyS0")
                    continue
                lines.append(ln)
            conf_text = "\n".join(lines) + "\n"
            tmp = os.path.join(work, "limine.conf.leg")
            with open(tmp, "w") as f:
                f.write(conf_text)
            for dst in (os.path.join(mnt, "EFI", "ryoku", "limine.conf"),
                        os.path.join(mnt, "EFI", "BOOT", "limine.conf")):
                sudo(["mkdir", "-p", os.path.dirname(dst)])
                sudo(["cp", tmp, dst])
            sudo(["cp", os.path.join(mnt, "EFI", "ryoku", "BOOTX64.EFI"),
                  os.path.join(mnt, "EFI", "BOOT", "BOOTX64.EFI")])
        finally:
            sudo(["umount", mnt], check=False)
            os.rmdir(mnt)
    finally:
        nbd_disconnect(dev)
    return conf_text


def boot_leg_disk_args(overlay, varsfd):
    return [
        "qemu-system-x86_64", "-machine", "q35", *accel_args(),
        "-m", "4096", "-smp", "4",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={varsfd}",
        "-device", "ich9-ahci,id=ahci",
        "-drive", f"if=none,id=hd,format=qcow2,file={overlay}",
        "-device", "ide-hd,drive=hd,bus=ahci.0,bootindex=1",
        "-netdev", "user,id=n0", "-device", "e1000,netdev=n0",
        "-display", "none", "-vga", "std",
    ]


def kill_qemu(proc):
    # Kill AND reap: qcow2 holds an exclusive write lock until the process is
    # fully gone, so the next boot leg would hit "Failed to get write lock" if we
    # only SIGKILL without waiting.
    if proc.poll() is None:
        proc.kill()
    try:
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        pass
    time.sleep(1)


def ocr_png(png):
    # Firmware/loader UI and Windows boot screens are small, low-contrast text on
    # dark backgrounds -- raw tesseract reads almost nothing. Upscale + grayscale +
    # contrast-stretch first (ImageMagick), which makes the limine menu and Windows
    # text legible to OCR.
    if not os.path.exists(png):
        return ""
    prepped = png + ".ocr.png"
    try:
        subprocess.run(["convert", png, "-colorspace", "Gray", "-resize", "300%",
                        "-contrast-stretch", "2%x2%", prepped],
                       capture_output=True, check=True)
        target = prepped
    except (subprocess.CalledProcessError, FileNotFoundError):
        target = png
    r = subprocess.run(["tesseract", target, "stdout", "--psm", "6"],
                       capture_output=True, text=True)
    return (r.stdout or "").strip()


def boot_leg_ryoku(overlay, work, ev):
    # Leg 1: default entry (Ryoku) must boot. console=ttyS0 was added to the
    # overlay, so we assert on serial: kernel + userspace markers, no panic and no
    # limine open-failure. A final screendump is captured for the record.
    log("Stage 3C leg 1: default (Ryoku) boot")
    varsfd = fresh_vars(work, "OVMF_VARS_leg1.fd")
    serial = os.path.join(work, "leg1-serial.log")
    mon_path = os.path.join(work, "mon-leg1.sock")
    cmd = boot_leg_disk_args(overlay, varsfd) + [
        "-serial", f"file:{serial}",
        "-monitor", f"unix:{mon_path},server,nowait",
    ]
    proc = subprocess.Popen(cmd)
    reached = re.compile(r"Reached target|systemd\[1\]|sddm|login:|Ryoku|Welcome to",
                         re.I)
    panic = re.compile(r"Kernel panic|not syncing|Unable to mount root|"
                       r"Cannot open root|Failed to open (image|volume)", re.I)
    deadline = time.time() + 60 * 6
    verdict = "TIMEOUT"
    tail = ""
    try:
        while time.time() < deadline:
            time.sleep(10)
            tail = ""
            if os.path.exists(serial):
                with open(serial, errors="replace") as f:
                    tail = f.read()
            if panic.search(tail):
                verdict = "PANIC"
                break
            if reached.search(tail):
                verdict = "BOOTED"
                break
    finally:
        png = os.path.join(work, "leg1-screen.png")
        mon = Monitor(mon_path)
        if mon.connect(tries=10):
            mon.cmd(f"screendump {png} -f png")
            time.sleep(1)
            mon.close()
        kill_qemu(proc)
    ev["stage3C_leg1_ryoku"] = {
        "verdict": verdict,
        "serial_markers": sorted(set(m.group(0) for m in reached.finditer(tail)))[:8],
        "panic_hit": bool(panic.search(tail)),
        "serial_tail": tail[-1500:],
        "screendump": png,
    }
    ok = verdict == "BOOTED"
    log(f"Stage 3C leg 1: {'PASS' if ok else 'FAIL'} ({verdict})")
    return ok


def boot_leg_windows(overlay, work, ev):
    # Leg 2: select the Windows entry and prove bootmgfw actually LOADS. Pressing
    # DOWN once STOPS limine's auto-boot countdown AND moves the selection from the
    # default (Ryoku, entry 1) to Windows (entry 2), so there is no countdown race;
    # ENTER then chainloads boot():/EFI/Microsoft/Boot/bootmgfw.efi.
    #
    # Discriminating which OS actually came up is done on the SERIAL log, not OCR:
    # Ryoku carries console=ttyS0 (added to the overlay) so it always prints to the
    # serial; Windows never uses ttyS0. So serial-with-Linux-markers == we booted
    # Ryoku (navigation misfired), serial-silent + a non-menu screen == Windows
    # took over. Screendump OCR then tells normal-boot vs recovery vs limine panic.
    log("Stage 3C leg 2: select + boot the Windows entry")
    varsfd = fresh_vars(work, "OVMF_VARS_leg2.fd")
    mon_path = os.path.join(work, "mon-leg2.sock")
    serial = os.path.join(work, "leg2-serial.log")
    cmd = boot_leg_disk_args(overlay, varsfd) + [
        "-serial", f"file:{serial}",
        "-monitor", f"unix:{mon_path},server,nowait",
    ]
    proc = subprocess.Popen(cmd)
    mon = Monitor(mon_path)
    shots = []
    menu_seen = False
    verdict = "INCONCLUSIVE"
    detail = ""
    panic_re = re.compile(r"panic|failed to open image|failed to open volume|"
                          r"failed to load|no such (file|entry)", re.I)
    menu_re = re.compile(r"Ryoku Linux|Windows|Bootloader|Booting automatically", re.I)
    recovery_re = re.compile(r"needs to be repaired|recovery|failed to start|"
                             r"automatic repair|winload|0xc0|inaccessible|"
                             r"boot device|bootmgfw|winre", re.I)
    winalive_re = re.compile(r"getting windows ready|just a moment|please wait|"
                             r"welcome|preparing|sign in|password|other user|"
                             r"ease of access", re.I)
    ryoku_serial_re = re.compile(r"Reached target|systemd\[1\]|Arch Linux|"
                                 r"login:|sddm|ryoku-dual", re.I)

    def read_serial():
        if not os.path.exists(serial):
            return ""
        with open(serial, errors="replace") as f:
            return f.read()

    try:
        if not mon.connect():
            detail = "could not connect to QEMU monitor for leg 2"
            raise RuntimeError(detail)
        # Let OVMF reach the limine menu (it renders by ~4-5s; sample to confirm).
        time.sleep(9)
        pngm = os.path.join(work, "leg2-menu.png")
        mon.cmd(f"screendump {pngm} -f png")
        time.sleep(1)
        tm = ocr_png(pngm)
        shots.append(("menu", pngm, tm))
        menu_seen = bool(menu_re.search(tm))
        # DOWN stops the countdown + selects Windows; confirm, then boot it.
        mon.cmd("sendkey down")
        time.sleep(1)
        pngs = os.path.join(work, "leg2-selected.png")
        mon.cmd(f"screendump {pngs} -f png")
        time.sleep(1)
        shots.append(("selected", pngs, ocr_png(pngs)))
        mon.cmd("sendkey ret")
        # Poll for handoff evidence.
        deadline = time.time() + 60 * 4
        idx = 0
        while time.time() < deadline:
            time.sleep(15)
            png = os.path.join(work, f"leg2-{idx:02d}.png")
            mon.cmd(f"screendump {png} -f png")
            time.sleep(1)
            txt = ocr_png(png)
            sertail = read_serial()
            shots.append((f"t{idx}", png, txt))
            idx += 1
            if panic_re.search(txt):
                verdict = "CHAINLOAD_BROKEN"
                detail = f"limine panic/open-failure after selecting Windows: {txt[:160]!r}"
                break
            if ryoku_serial_re.search(sertail):
                verdict = "NAV_MISFIRE"
                detail = ("navigation misfired: Ryoku booted (serial shows Linux); "
                          "Windows entry was not selected")
                # keep polling briefly in case the screen still tells us more, but
                # this is not a valid Windows-leg result.
                break
            if recovery_re.search(txt):
                verdict = "BOOTMGFW_ALIVE_OS_DAMAGED"
                detail = f"Windows recovery/repair UI (bootmgfw loaded, OS damaged): {txt[:160]!r}"
                break
            if winalive_re.search(txt):
                verdict = "BOOTMGFW_ALIVE"
                detail = f"Windows boot/login UI (bootmgfw loaded): {txt[:160]!r}"
                break
            # menu gone + serial silent (no Linux) + no panic, several polls in ->
            # bootmgfw handed off to a graphical Windows boot (logo/spinner/clock
            # carries little OCR text; Ryoku would have printed to serial).
            if menu_seen and not menu_re.search(txt) and not ryoku_serial_re.search(sertail) \
                    and idx >= 3:
                verdict = "BOOTMGFW_ALIVE"
                detail = ("limine menu handed off; serial silent (not Ryoku), no "
                          "panic -> graphical Windows boot")
                break
    except RuntimeError:
        pass
    finally:
        mon.close()
        kill_qemu(proc)
    ev["stage3C_leg2_windows"] = {
        "verdict": verdict,
        "detail": detail,
        "menu_rendered": menu_seen,
        "serial_tail": read_serial()[-800:],
        "screendumps": [{"tag": t, "png": p, "ocr": (o[:400] if o else "")}
                        for (t, p, o) in shots],
    }
    ok = verdict in ("BOOTMGFW_ALIVE", "BOOTMGFW_ALIVE_OS_DAMAGED")
    log(f"Stage 3C leg 2: {'PASS(chainload)' if ok else 'FAIL'} ({verdict}) {detail}")
    return verdict


# ----------------------------------------------------------------------------- #
def cleanup_overlays(work, keep):
    if keep:
        log(f"keeping work dir (--keep): {work}")
        return
    for fn in os.listdir(work):
        if fn.startswith("overlay") or fn.startswith("OVMF_VARS"):
            try:
                os.remove(os.path.join(work, fn))
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--iso", help="Ryoku ISO under test (required unless --golden-only)")
    ap.add_argument("--work", default=None, help="work dir (default: temp)")
    ap.add_argument("--golden-only", action="store_true",
                    help="build/cache the golden Windows image + manifest, then stop")
    ap.add_argument("--skip-golden", action="store_true",
                    help="require an existing cached golden (fail if absent)")
    ap.add_argument("--keep", action="store_true", help="keep overlays + work dir")
    ap.add_argument("--report", default=None, help="write the evidence JSON here")
    args = ap.parse_args()

    if not OVMF_CODE or not OVMF_VARS:
        die("OVMF firmware not found (pacman -S edk2-ovmf)")
    if not os.path.exists("/dev/kvm"):
        log("WARNING: /dev/kvm absent; TCG will be far too slow for Windows install")

    work = args.work or tempfile.mkdtemp(prefix="ryoku-dualboot-")
    os.makedirs(work, exist_ok=True)
    ev = {"work": work, "started": time.strftime("%Y-%m-%dT%H:%M:%S"),
          "free_gib_start": round(free_gib(), 1)}

    if args.skip_golden:
        if not (os.path.exists(GOLDEN) and os.path.exists(MANIFEST)):
            die("--skip-golden but no cached golden/manifest under cache/")
        with open(MANIFEST) as f:
            manifest = json.load(f)
        log("using cached golden image + manifest")
    else:
        manifest = build_golden(work)

    if args.golden_only:
        log("golden-only: cache built; stopping before Stage 2")
        print(json.dumps({"golden": GOLDEN, "manifest": MANIFEST}, indent=2))
        return

    if not args.iso:
        die("--iso is required for Stage 2/3 (the Ryoku ISO under test)")
    if not os.path.exists(args.iso):
        die(f"Ryoku ISO not found: {args.iso}")
    ev["ryoku_iso"] = os.path.abspath(args.iso)
    ev["ryoku_iso_sha256"] = sha256_file(args.iso)

    overlay = make_overlay(work)
    ryoku_install(work, args.iso, overlay)

    a_ok = b_ok = leg1_ok = False
    leg2 = "INCONCLUSIVE"
    report_path = args.report or os.path.join(work, "evidence.json")
    try:
        a_ok = assert_table(overlay, manifest, ev)
        b_ok = assert_filesystems(overlay, manifest, ev)
        prep_overlay_bootconf(overlay, work)
        leg1_ok = boot_leg_ryoku(overlay, work, ev)
        leg2 = boot_leg_windows(overlay, work, ev)
    finally:
        leg2_ok = leg2 in ("BOOTMGFW_ALIVE", "BOOTMGFW_ALIVE_OS_DAMAGED")
        # VERDICT: does the alongside install DAMAGE the pre-existing Windows?
        # A broken chainload OR a damaged/altered Windows OS both count as damage.
        damaged = (not a_ok) or (not b_ok) or (not leg2_ok) or \
            (leg2 == "BOOTMGFW_ALIVE_OS_DAMAGED")
        ev["free_gib_end"] = round(free_gib(), 1)
        ev["results"] = {
            "table_integrity": a_ok,
            "filesystem_health": b_ok,
            "leg1_ryoku_boots": leg1_ok,
            "leg2_windows_chainload": leg2,
            "windows_damaged": damaged,
        }
        verdict = ("DAMAGES Windows" if damaged else "does NOT damage Windows")
        ev["verdict"] = verdict
        with open(report_path, "w") as f:
            json.dump(ev, f, indent=2)

    log("=" * 68)
    log(f"VERDICT: the alongside install {verdict}")
    log(f"  table integrity:      {'PASS' if a_ok else 'FAIL'}")
    log(f"  filesystem health:    {'PASS' if b_ok else 'FAIL'}")
    log(f"  leg1 Ryoku boots:     {'PASS' if leg1_ok else 'FAIL'}")
    log(f"  leg2 Windows chain:   {leg2}")
    log(f"  evidence JSON:        {report_path}")
    log(f"  df headroom:          {ev['free_gib_end']:.1f} GiB free")
    log("=" * 68)

    cleanup_overlays(work, args.keep)
    sys.exit(0 if not damaged else 3)


if __name__ == "__main__":
    main()
