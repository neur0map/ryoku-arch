#!/usr/bin/env bash
# REAL QEMU+OVMF boot test for the alongside TWO-STAGE limine chain (bootloader.sh).
# The design (VM-proven; evidence at .superpowers/sdd/twostage-report.md) is: a
# STATIC stage-1 hop beside our BOOTX64.EFI on the shared ESP chainloads a
# second-stage limine on our own XBOOTLDR /boot (FAT label RYOKUBOOT), where the
# tool-managed menu lives with correct binary-relative paths. Two failure classes
# hide behind unit tests; both are proven here under real Limine + edk2 OVMF:
#
#   1. GENERATOR (static): ryoku_stage1_hop_text emits a timeout-0 efi_chainload to
#      fslabel(RYOKUBOOT):/ryoku-limine.efi and nothing else; ryoku_alongside_conf_text
#      emits the kernel by fslabel(RYOKUBOOT) and the existing OS by guid(<ESP PARTUUID>)
#      efi_chainload -- never a boot():/EFI cross-volume path (boot() on the XBOOTLDR
#      is NOT the shared ESP).
#   2. TWO-STAGE RYOKU (live): OVMF -> stage-1 hop -> second-stage limine on the
#      XBOOTLDR -> kernel by fslabel(RYOKUBOOT). Limine 12.4.0 will NOT resolve a
#      guid(<GPT-PARTUUID>) KERNEL path to a FAT volume under OVMF (see the matrix in
#      .superpowers/sdd/diskesp-hw-report.md), so kernels stay addressed by FAT label.
#   3. WINDOWS CHAINLOAD (live): the second-stage limine's /Windows entry chainloads
#      guid(<ESP PARTUUID>):/EFI/Microsoft/Boot/bootmgfw.efi -- a genuine cross-volume
#      efi_chainload (XBOOTLDR -> shared ESP). bootmgfw is a stub Limine that boots a
#      marker kernel, so a failure to resolve guid() or open the image would panic
#      instead of ever reaching the kernel.
#
# a Linux kernel with console=ttyS0 is the headless marker: Limine renders to the
# GOP, not serial, but the kernel it hands off to prints to ttyS0 (QEMU -serial).
# the loop device is detached (flushing FAT writes) before every boot. KVM is
# REQUIRED: TCG is too flaky for the Limine handoff here, so a runner with no
# /dev/kvm skips (with a notice under CI) rather than run a flaky boot.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }
# under GitHub Actions a skip also emits a ::notice so the dropped coverage is
# visible in the run summary instead of passing silently green.
skip() {
  [[ -n ${GITHUB_ACTIONS:-} ]] && echo "::notice title=install-chainload-vm skipped::$1"
  echo "install-chainload-vm: SKIP ($1)"
  exit 0
}

[[ $EUID -eq 0 ]] || skip "not root; needs losetup + FAT mount (run: sudo bash $0)"
for t in qemu-system-x86_64 losetup sgdisk mkfs.vfat blkid; do
  command -v "$t" >/dev/null 2>&1 || skip "missing $t"
done
LIMINE=/usr/share/limine/BOOTX64.EFI
[[ -f $LIMINE ]] || skip "limine BOOTX64.EFI not installed"
OVMF_CODE=""; OVMF_VARS=""
for d in /usr/share/edk2/x64 /usr/share/OVMF /usr/share/edk2-ovmf/x64; do
  [[ -f $d/OVMF_CODE.4m.fd ]] && { OVMF_CODE="$d/OVMF_CODE.4m.fd"; OVMF_VARS="$d/OVMF_VARS.4m.fd"; break; }
  [[ -f $d/OVMF_CODE.fd ]] && { OVMF_CODE="$d/OVMF_CODE.fd"; OVMF_VARS="$d/OVMF_VARS.fd"; break; }
done
[[ -n $OVMF_CODE && -f $OVMF_VARS ]] || skip "OVMF firmware not found"
KERNEL=""
for k in /usr/lib/modules/*/vmlinuz; do [[ -f $k ]] && { KERNEL="$k"; break; }; done
[[ -n $KERNEL ]] || skip "no /usr/lib/modules/*/vmlinuz kernel image to boot"
LABEL=RYOKUBOOT
[[ -w /dev/kvm ]] || skip "no KVM (/dev/kvm); TCG is too flaky for the Limine handoff here (see header)"
KVM=(-enable-kvm -cpu host)

work="$(mktemp -d)"
DISK_LOOP=""
cleanup() {
  local mp
  for mp in "$work"/mnt.*; do mountpoint -q "$mp" 2>/dev/null && umount "$mp" 2>/dev/null; done
  [[ -n $DISK_LOOP ]] && losetup -d "$DISK_LOOP" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

img="$work/disk.img"

attach() {
  DISK_LOOP="$(losetup -f --show -P "$img")"
  udevadm settle 2>/dev/null || true
  esp="${DISK_LOOP}p1"; xboot="${DISK_LOOP}p2"
  local _; for _ in 1 2 3 4 5; do [[ -b $xboot ]] && break; sleep 0.3; udevadm settle 2>/dev/null || true; done
}
detach() { sync; losetup -d "$DISK_LOOP" 2>/dev/null || true; DISK_LOOP=""; }

# put <dev> <relpath> <src|->: copy a file onto a mounted FAT partition (creating
# parents). src "-" reads the content from stdin. requires the loop attached.
put() {
  local dev="$1" rel="$2" src="$3" mp
  mp="$(mktemp -d "$work/mnt.XXXX")"
  mount "$dev" "$mp"
  mkdir -p "$mp/$(dirname "$rel")"
  if [[ $src == - ]]; then cat >"$mp/$rel"; else cp "$src" "$mp/$rel"; fi
  sync; umount "$mp"; rmdir "$mp"
}

# set_boot_conf: replace /EFI/BOOT/limine.conf (what the OVMF-booted Limine reads
# first) from stdin, with the loop attached only for the write.
set_boot_conf() { attach; put "$esp" EFI/BOOT/limine.conf -; detach; }

# run_qemu: boot the (detached) image headless, serial -> stdout.
run_qemu() {
  local vars="$work/vars.$RANDOM.fd"
  cp "$OVMF_VARS" "$vars"
  timeout 40 qemu-system-x86_64 -machine q35 -m 2048 "${KVM[@]}" -nographic \
    -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,unit=1,file="$vars" \
    -drive format=raw,file="$img" -serial mon:stdio -no-reboot 2>&1 | tr -d '\000' | strings || true
}

# a kernel that VFS-panics is our "it booted" marker: it prints to ttyS0 only
# after Limine resolved the volume and handed off; Limine's own failure ("Failed
# to open image/volume") would appear INSTEAD, never alongside it.
KERNEL_RAN='Unable to mount root|Kernel panic|Linux version'
LIMINE_FAILED='Failed to open (image|volume)|Failed to load'

# ── build the fixture disk: ESP (ef00, label ESP) + XBOOTLDR (ea00, RYOKUBOOT) ──
truncate -s 220M "$img"
sgdisk -n 1:2048:+80M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:0       -t 2:ea00 -c 2:ryokuboot "$img" >/dev/null
attach
mkfs.vfat -F32 -n ESP "$esp" >/dev/null 2>&1
mkfs.vfat -F32 -n "$LABEL" "$xboot" >/dev/null 2>&1
esp_partuuid="$(blkid -o value -s PARTUUID "$esp")"
detach
[[ -n $esp_partuuid ]] || fail "could not read the shared ESP PARTUUID for the guid() chainload"

# 1. GENERATOR: the real two-stage output (dry-run prints it; no disk needed).
hop="$(RYOKU_REPO=/nonexistent CMDLINE='root=UUID=test rw' ROOT="$root" bash -c '
  source "$ROOT/installation/backend/lib/common.sh"
  source "$ROOT/installation/backend/lib/disk.sh"
  source "$ROOT/installation/backend/lib/bootloader.sh"
  ryoku_stage1_hop_text')"
gen="$(RYOKU_REPO=/nonexistent CMDLINE='root=UUID=test rw' ROOT="$root" PU="$esp_partuuid" bash -c '
  source "$ROOT/installation/backend/lib/common.sh"
  source "$ROOT/installation/backend/lib/disk.sh"
  source "$ROOT/installation/backend/lib/bootloader.sh"
  ryoku_alongside_conf_text windows /EFI/Microsoft/Boot/bootmgfw.efi "$PU"')"
grep -qxF 'timeout: 0' <<<"$hop" || fail "generator: stage-1 hop is not timeout 0"
grep -qF "image_path: fslabel($LABEL):/ryoku-limine.efi" <<<"$hop" || fail "generator: stage-1 hop does not chainload the second-stage limine by fslabel($LABEL)"
grep -qF "kernel_path: fslabel($LABEL):/vmlinuz-linux" <<<"$gen" || fail "generator: stage-2 kernel is not addressed by fslabel($LABEL)"
grep -qF "image_path: guid($esp_partuuid):/EFI/Microsoft/Boot/bootmgfw.efi" <<<"$gen" || fail "generator: stage-2 Windows is not a guid() efi_chainload"
grep -qF 'boot():/EFI' <<<"$gen" && fail "generator: stage-2 conf used a boot():/EFI cross-volume path"
echo "  generator: hop -> fslabel($LABEL) second stage; stage-2 kernel fslabel, Windows guid() [ok]"

# ── stage the binaries for the live boot chain ──
attach
put "$xboot" ryoku-limine.efi "$LIMINE"               # the second-stage limine
put "$xboot" vmlinuz-linux "$KERNEL"                  # the Ryoku kernel (fslabel target)
put "$esp" EFI/BOOT/BOOTX64.EFI "$LIMINE"             # the OVMF-booted stage-1 limine
put "$esp" EFI/Microsoft/Boot/bootmgfw.efi "$LIMINE"  # stub "Windows" (a limine)
put "$esp" vmlinuz-linux "$KERNEL"                    # marker kernel for the stub
# the stub bootmgfw boots the marker kernel from its own (ESP) volume via boot().
put "$esp" EFI/Microsoft/Boot/limine.conf - <<'EOF'
timeout: 0
default_entry: 1

/win-stub
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    cmdline: console=ttyS0 RYOKU_WINCHAIN_OK panic=-1
EOF
detach

# 2. TWO-STAGE RYOKU: OVMF -> hop (ESP) -> second-stage limine (XBOOTLDR) -> kernel.
attach
put "$esp" EFI/BOOT/limine.conf - <<EOF
timeout: 0
default_entry: 1

/Ryoku
    protocol: efi_chainload
    image_path: fslabel($LABEL):/ryoku-limine.efi
EOF
put "$xboot" limine.conf - <<EOF
timeout: 0
default_entry: 1
verbose: yes

/Ryoku Linux
    protocol: linux
    kernel_path: fslabel($LABEL):/vmlinuz-linux
    cmdline: console=ttyS0 RYOKU_FSLABEL_OK panic=-1
EOF
detach
outA="$(run_qemu)"
grep -qiE "$LIMINE_FAILED" <<<"$outA" && fail "two-stage ryoku: Limine could not resolve the chain -- $(grep -iE "$LIMINE_FAILED" <<<"$outA" | head -1)"
grep -qiE "$KERNEL_RAN" <<<"$outA" || fail "two-stage ryoku: the kernel never ran (hop -> second stage -> fslabel($LABEL) did not complete); serial tail: $(tail -c 300 <<<"$outA")"
echo "  two-stage ryoku: hop -> XBOOTLDR limine -> kernel by fslabel($LABEL) [ok]"

# 3. WINDOWS CHAINLOAD: the second-stage limine chainloads the stub bootmgfw by
# guid(<ESP PARTUUID>) -- a genuine XBOOTLDR -> shared-ESP cross-volume efi_chainload.
# the hop at ESP EFI/BOOT/limine.conf from leg 2 stays; only the XBOOTLDR menu changes.
attach
put "$xboot" limine.conf - <<EOF
timeout: 0
default_entry: 1
verbose: yes

/Windows
    protocol: efi_chainload
    image_path: guid($esp_partuuid):/EFI/Microsoft/Boot/bootmgfw.efi
    comment: Windows Boot Manager
EOF
detach
outB="$(run_qemu)"
grep -qiE 'Failed to open image' <<<"$outB" && fail "windows chainload: PANIC 'Failed to open image' -- the guid() cross-volume chainload broke"
grep -qiE "$LIMINE_FAILED" <<<"$outB" && fail "windows chainload: Limine could not resolve guid($esp_partuuid) to the shared ESP -- $(grep -iE "$LIMINE_FAILED" <<<"$outB" | head -1)"
grep -qiE "$KERNEL_RAN" <<<"$outB" || fail "windows chainload: the guid() chainload never handed off to the stub; serial tail: $(tail -c 300 <<<"$outB")"
echo "  windows chainload: guid($esp_partuuid) opened the stub cross-volume, no panic [ok]"

echo "install-chainload-vm: all checks passed"
