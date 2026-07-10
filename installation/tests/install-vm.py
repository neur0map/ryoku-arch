#!/usr/bin/env python3
# Boot a Ryoku ISO in QEMU, run the installer unattended against a virtual disk,
# and verify the result, so a broken install or a missing package is caught
# before a user hits it. Drives the live root shell over the serial console
# (pexpect); the backend is env-driven and prints @@RYOKU_DONE on success.
#
#   install-vm.py --iso ryoku.iso            full install + verify
#   install-vm.py --iso ryoku.iso --boot-only   just reach the live shell (sanity)
#
# Exits 0 when the install completes and the installed tree checks out, non-zero
# otherwise, printing the serial log tail. Uses KVM when /dev/kvm is present,
# else TCG (slow). See docs/updates.md.
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

import pexpect

OVMF_CODE = next((p for p in (
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd",
    "/usr/share/OVMF/OVMF_CODE_4M.fd",
    "/usr/share/OVMF/OVMF_CODE.fd",
    "/usr/share/OVMF/OVMF_CODE.4m.fd",
    "/usr/share/OVMF/x64/OVMF_CODE.fd",
) if os.path.exists(p)), None)
OVMF_VARS = next((p for p in (
    "/usr/share/edk2/x64/OVMF_VARS.4m.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd",
    "/usr/share/OVMF/OVMF_VARS_4M.fd",
    "/usr/share/OVMF/OVMF_VARS.fd",
    "/usr/share/OVMF/OVMF_VARS.4m.fd",
    "/usr/share/OVMF/x64/OVMF_VARS.fd",
) if os.path.exists(p)), None)

# the installed tree a real user must end up with: the package, the materialized
# config (including the files that used to reach no one), the bootloader, and the
# enabled greeter. checked by mounting the target root read-only after install.
INSTALLED_CHECKS = [
    ("d", "usr/share/ryoku/config"),
    ("f", "home/{user}/.config/quickshell/pill/shell.qml"),
    ("f", "home/{user}/.config/hypr/hyprland.lua"),
    ("f", "home/{user}/.config/pip/pip.conf"),
    ("f", "home/{user}/.config/mimeapps.list"),
    ("f", "usr/share/applications/ryoku-nvim.desktop"),
    ("d", "boot/EFI"),
]


def qemu_cmd(work, iso, with_iso):
    vars_copy = os.path.join(work, "OVMF_VARS.fd")
    if not os.path.exists(vars_copy):
        shutil.copy(OVMF_VARS, vars_copy)
    accel = ["-enable-kvm", "-cpu", "host"] if os.path.exists("/dev/kvm") else ["-cpu", "max"]
    cmd = [
        "qemu-system-x86_64", "-machine", "q35", *accel, "-m", "4096", "-smp", "4",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={vars_copy}",
        "-drive", f"file={os.path.join(work, 'target.qcow2')},if=virtio,format=qcow2",
        "-netdev", "user,id=n0", "-device", "virtio-net-pci,netdev=n0",
        "-nographic",
    ]
    if with_iso:
        cmd += ["-drive", f"file={iso},media=cdrom,readonly=on", "-boot", "d"]
    return cmd


def fail(child, msg):
    print(f"\ninstall-vm: {msg}", file=sys.stderr)
    try:
        child.close(force=True)
    except Exception:
        pass
    sys.exit(1)


def login(child):
    # archiso serial: an autologin root shell, or a login prompt (any hostname).
    i = child.expect([r"login:", r"# ", pexpect.TIMEOUT], timeout=300)
    if i == 0:
        child.sendline("root")
        if child.expect([r"Password:", r"# "], timeout=60) == 0:
            child.sendline("")
            child.expect(r"# ", timeout=60)
    elif i == 2:
        fail(child, "the live ISO never reached a serial prompt (see log)")


def sh(child, line, timeout=120):
    child.sendline(line)
    child.expect(r"# ", timeout=timeout)
    return child.before


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iso", required=True)
    ap.add_argument("--work", default=None)
    ap.add_argument("--user", default="test")
    ap.add_argument("--profile", default="vm")
    ap.add_argument("--timeout", type=int, default=2400, help="install timeout (s)")
    ap.add_argument("--dry", action="store_true",
                    help="RYOKU_DRYRUN install-flow smoke (no real disk writes)")
    ap.add_argument("--boot-only", action="store_true", help="reach the live shell then stop")
    args = ap.parse_args()

    if not OVMF_CODE or not OVMF_VARS:
        print("install-vm: OVMF firmware not found (pacman -S edk2-ovmf)", file=sys.stderr)
        sys.exit(2)

    work = args.work or tempfile.mkdtemp(prefix="ryoku-vm-")
    os.makedirs(work, exist_ok=True)
    log = os.path.join(work, "serial.log")
    subprocess.run(["qemu-img", "create", "-f", "qcow2",
                    os.path.join(work, "target.qcow2"), "40G"], check=True,
                   stdout=subprocess.DEVNULL)
    pwhash = subprocess.check_output(["openssl", "passwd", "-6", "test"]).decode().strip()

    print(f"install-vm: booting {args.iso} (KVM={'yes' if os.path.exists('/dev/kvm') else 'no, TCG'}); log -> {log}")
    child = pexpect.spawn(" ".join(qemu_cmd(work, args.iso, with_iso=True)),
                          timeout=args.timeout, encoding="utf-8", codec_errors="replace")
    child.logfile = open(log, "w")
    try:
        login(child)
        print("install-vm: live shell reached")
        if args.boot_only:
            sh(child, "echo READY:$(uname -r)")
            child.sendline("poweroff")
            child.expect(pexpect.EOF, timeout=120)
            print("install-vm: boot-only sanity OK")
            return

        env = (f"RYOKU_DISK=/dev/vda RYOKU_PROFILE={args.profile} "
               f"RYOKU_HOSTNAME=ryoku-test RYOKU_USERNAME={args.user} "
               f"RYOKU_DISK_STRATEGY=whole RYOKU_WIPE_CONFIRMED=1 RYOKU_SKIP_AUR=1 "
               f"RYOKU_REPO=/usr/share/ryoku RYOKU_PASSWORD_HASH='{pwhash}'")
        if args.dry:
            env += " RYOKU_DRYRUN=1"
        # skip the optional AUR builds (they compile from source for minutes and
        # are best-effort): RYOKU_SKIP_AUR covers a current ISO, emptying the set
        # also covers an older backend that predates the flag.
        sh(child, ": > /usr/share/ryoku/system/packages/aur.packages")
        child.sendline(f"export {env}; ryoku-install; echo BACKEND_EXIT:$?")
        i = child.expect([r"@@RYOKU_DONE", r"BACKEND_EXIT:[1-9]", pexpect.TIMEOUT],
                         timeout=args.timeout)
        if i != 0:
            fail(child, "the installer did not reach @@RYOKU_DONE (see log)")
        child.expect(r"BACKEND_EXIT:0", timeout=120)
        child.expect(r"# ", timeout=60)
        print("install-vm: @@RYOKU_DONE, backend exit 0")
        if args.dry:
            child.sendline("poweroff")
            child.expect(pexpect.EOF, timeout=120)
            print("install-vm: dry-run install flow OK")
            return

        # independent check: mount the installed tree (@ root, @home, ESP) and
        # assert it, so "the backend said done" is backed by real files on disk.
        sh(child, "umount -R /mnt 2>/dev/null; mkdir -p /mnt2")
        sh(child, "mount -o subvol=@ /dev/vda2 /mnt2")
        sh(child, "mount -o subvol=@home /dev/vda2 /mnt2/home 2>/dev/null || true")
        sh(child, "mount /dev/vda1 /mnt2/boot 2>/dev/null || true")
        missing = []
        for kind, rel in INSTALLED_CHECKS:
            path = "/mnt2/" + rel.format(user=args.user)
            if "R0E" not in sh(child, f"test -{kind} {path}; echo R$?E"):
                missing.append(f"{kind}:{path}")
        if "enabled" not in sh(child, "systemctl --root=/mnt2 is-enabled sddm 2>&1"):
            missing.append("sddm not enabled (no greeter on boot)")
        sh(child, "umount -R /mnt2 2>/dev/null || true")
        child.sendline("poweroff")
        child.expect(pexpect.EOF, timeout=120)
        if missing:
            print("install-vm: installed tree is missing:", file=sys.stderr)
            for m in missing:
                print(f"  {m}", file=sys.stderr)
            sys.exit(1)
        print("install-vm: installed tree verified")
    except (pexpect.TIMEOUT, pexpect.EOF) as e:
        with open(log) as f:
            tail = f.read()[-4000:]
        print(f"\ninstall-vm: {type(e).__name__}\n--- serial tail ---\n{tail}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
