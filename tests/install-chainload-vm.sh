#!/usr/bin/env bash
# REAL QEMU+OVMF boot test for the alongside boot chain (bootloader.sh). Two
# failures hide behind unit tests: the P0 dual-boot panic ("efi: Failed to open
# image", a uuid() chainload to Limine's OWN boot volume) and the fact that
# Limine 12.4.0 will NOT resolve guid(<GPT-PARTUUID>) to a FAT volume under OVMF
# (see the matrix in .superpowers/sdd/diskesp-hw-report.md) -- so the real
# limine.conf addresses kernels by FAT label. This boots the REAL generated conf
# under real Limine + edk2 OVMF and proves BOTH menu legs:
#
#   1. GENERATOR (static): ryoku_boot_alongside_conf emits the Windows entry as
#      boot(): (protocol efi, same-volume) and the kernel as fslabel(RYOKUBOOT).
#   2. RYOKU (live): Limine loads a kernel by fslabel(RYOKUBOOT) off the XBOOTLDR
#      /boot -- a DIFFERENT volume than the loader. Success = the kernel runs (it
#      VFS-panics with no root, which is past volume resolution + handoff).
#   3. WINDOWS CHAINLOAD (live): the /Windows entry chainloads boot():/EFI/
#      Microsoft/Boot/bootmgfw.efi. bootmgfw is a stub Limine that boots a marker
#      kernel, so if boot(): OPENED the image the kernel runs; the bug would panic
#      with "Failed to open image" and never reach it.
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

# ── build the fixture disk: ESP (ef00) + XBOOTLDR (ea00, FAT label RYOKUBOOT) ──
truncate -s 220M "$img"
sgdisk -n 1:2048:+80M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:0       -t 2:ea00 -c 2:ryokuboot "$img" >/dev/null
attach
mkfs.vfat -F32 -n ESP "$esp" >/dev/null 2>&1
mkfs.vfat -F32 -n "$LABEL" "$xboot" >/dev/null 2>&1

# 1. GENERATOR: the real ryoku_boot_alongside_conf output (dry-run prints it).
gen="$(
  RYOKU_DRYRUN=1 RYOKU_REPO=/nonexistent CMDLINE="root=UUID=test rw" ESP_DEV="$xboot" bash -c '
    source "'"$root"'/installation/backend/lib/common.sh"
    source "'"$root"'/installation/backend/lib/disk.sh"
    source "'"$root"'/installation/backend/lib/bootloader.sh"
    ryoku_boot_alongside_conf
  '
)"
grep -qF 'path: boot():/EFI/Microsoft/Boot/bootmgfw.efi' <<<"$gen" \
  || fail "generator: Windows entry is not the same-volume boot(): form"
grep -qF 'protocol: efi_chainload' <<<"$gen" \
  && fail "generator: Windows entry uses efi_chainload (uuid cross-volume) -- would panic"
grep -qF "kernel_path: fslabel($LABEL):/vmlinuz-linux" <<<"$gen" \
  || fail "generator: kernel is not addressed by fslabel($LABEL)"
echo "  generator: Windows -> boot():, kernel -> fslabel($LABEL) [ok]"

# stage the kernel on both volumes + the stub "Windows" bootmgfw + fallback loader.
put "$xboot" vmlinuz-linux "$KERNEL"
put "$esp" vmlinuz-linux "$KERNEL"
put "$esp" EFI/Microsoft/Boot/bootmgfw.efi "$LIMINE"
put "$esp" EFI/BOOT/BOOTX64.EFI "$LIMINE"
put "$esp" EFI/Microsoft/Boot/limine.conf - <<'EOF'
timeout: 0
default_entry: 1

/win-stub
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    cmdline: console=ttyS0 RYOKU_WINCHAIN_OK panic=-1
EOF
detach

# 2. RYOKU: Limine loads the kernel by fslabel(RYOKUBOOT) off the XBOOTLDR.
set_boot_conf <<EOF
timeout: 0
default_entry: 1
verbose: yes

/Ryoku Linux
    protocol: linux
    kernel_path: fslabel($LABEL):/vmlinuz-linux
    cmdline: console=ttyS0 RYOKU_FSLABEL_OK panic=-1
EOF
outA="$(run_qemu)"
grep -qiE "$LIMINE_FAILED" <<<"$outA" && fail "ryoku entry: Limine could not open the kernel by fslabel() -- $(grep -iE "$LIMINE_FAILED" <<<"$outA" | head -1)"
grep -qiE "$KERNEL_RAN" <<<"$outA" || fail "ryoku entry: the kernel never ran (fslabel($LABEL) did not resolve); serial tail: $(tail -c 300 <<<"$outA")"
echo "  ryoku entry: kernel booted from fslabel($LABEL) [ok]"

# 3. WINDOWS CHAINLOAD: the real boot(): /Windows entry opens the stub bootmgfw.
set_boot_conf <<'EOF'
timeout: 0
default_entry: 1
verbose: yes

/Windows
    comment: Boot into Windows
    protocol: efi
    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
EOF
outB="$(run_qemu)"
grep -qiE 'Failed to open image' <<<"$outB" && fail "windows chainload: PANIC 'Failed to open image' -- the bug is back"
grep -qiE "$LIMINE_FAILED" <<<"$outB" && fail "windows chainload: Limine could not open the stub -- $(grep -iE "$LIMINE_FAILED" <<<"$outB" | head -1)"
grep -qiE "$KERNEL_RAN" <<<"$outB" || fail "windows chainload: boot():/ never handed off to the stub; serial tail: $(tail -c 300 <<<"$outB")"
echo "  windows chainload: boot():/ opened the stub, no panic [ok]"

echo "install-chainload-vm: all checks passed"
