#!/usr/bin/env bash
# REAL loop-device test for the btrfs @swap swapfile the installer builds
# (installation/backend/lib/filesystem.sh ryoku_swapfile). A VM boot once reported
# "Failed to activate swap /swap/swapfile"; this reproduces the installer's exact
# creation at fixture level and proves the swap actually activates -- at install
# time AND on the boot-time remount, where the @swap mount inherits the fs-wide
# compress=zstd from @'s mount (btrfs compression is per-superblock, not per-subvol
# mount). The swapfile survives that because `btrfs filesystem mkswapfile` sets
# NOCOW (+C), which exempts it from compression. Also pins that the resume offset
# the cmdline uses (`map-swapfile -r`) matches the verbose map. Verdict + transcript
# are recorded in .superpowers/sdd/twostage-report.md.
#
# needs root + loop devices; on EUID!=0 or a missing tool it prints a skip and
# exits 0 (so a non-root CI job stays green). run: sudo bash "$0".
set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }
skip() { echo "install-swapfile: SKIP ($1)"; exit 0; }

[[ $EUID -eq 0 ]] || skip "not root; needs losetup/mkfs.btrfs/swapon (run: sudo bash $0)"
for t in losetup mkfs.btrfs btrfs swapon swapoff lsattr truncate findmnt; do
  command -v "$t" >/dev/null 2>&1 || skip "missing $t"
done

# loop devices must actually work (a locked-down runner may have the tools yet no
# usable loop device): probe once and skip if attaching fails.
probe_img="$(mktemp --suffix=.ryoku-swapprobe.img)"
truncate -s 8M "$probe_img" 2>/dev/null || { rm -f "$probe_img"; skip "cannot create a sparse file"; }
probe_loop="$(losetup -f --show "$probe_img" 2>/dev/null || true)"
[[ -n $probe_loop ]] || { rm -f "$probe_img"; skip "loop devices unavailable"; }
losetup -d "$probe_loop" 2>/dev/null || true
rm -f "$probe_img"

# mount options mirror filesystem.sh: RYOKU_BTRFS_OPTS on @ (so @swap inherits
# compress at the superblock level), swap sized like a small install.
BTRFS_OPTS="compress=zstd,noatime"
SWAP_SIZE=256m

LOOP=""; IMG=""; MNT=""
cleanup() {
  [[ -n $MNT ]] && swapoff "$MNT/swap/swapfile" 2>/dev/null || true
  [[ -n $MNT ]] && { umount "$MNT/swap" 2>/dev/null || true; umount "$MNT" 2>/dev/null || true; }
  [[ -n $LOOP ]] && losetup -d "$LOOP" 2>/dev/null || true
  [[ -n $IMG ]] && rm -f "$IMG" 2>/dev/null || true
  [[ -n $MNT ]] && rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

IMG="$(mktemp --suffix=.ryoku-swap.img)"
truncate -s 2G "$IMG"
LOOP="$(losetup -f --show "$IMG")"
mkfs.btrfs -f -L ryoku "$LOOP" >/dev/null 2>&1 || fail "could not mkfs.btrfs the loop device"
MNT="$(mktemp -d)"

# lay out @ + @swap exactly like ryoku_filesystems, then mount like ryoku_mount:
# @ first (sets the superblock's compress=zstd), @swap second (inherits it).
mount "$LOOP" "$MNT"
btrfs subvolume create "$MNT/@" >/dev/null || fail "could not create @"
btrfs subvolume create "$MNT/@swap" >/dev/null || fail "could not create @swap"
umount "$MNT"
mount -o "$BTRFS_OPTS,subvol=@" "$LOOP" "$MNT" || fail "could not mount @"
mkdir -p "$MNT/swap"
mount -o noatime,subvol=@swap "$LOOP" "$MNT/swap" || fail "could not mount @swap"

# ── install phase: create the swapfile the installer's way + activate it ──
btrfs filesystem mkswapfile --size "$SWAP_SIZE" "$MNT/swap/swapfile" >/dev/null \
  || fail "btrfs filesystem mkswapfile failed (the installer's ryoku_swapfile command)"

# Arch btrfs swapfiles MUST be NOCOW (+C); mkswapfile sets it. without it swapon
# fails with EINVAL and the boot logs "Failed to activate swap".
lsattr "$MNT/swap/swapfile" | grep -q 'C' || fail "swapfile is not NOCOW (+C); swapon would fail on btrfs"

swapon "$MNT/swap/swapfile" || fail "install-phase swapon failed on the freshly built swapfile"
swapon --show=NAME --noheadings | grep -qF "$MNT/swap/swapfile" \
  || fail "swapon reported success but the swapfile is not active"
echo "  install phase: mkswapfile set +C, swapon activated $SWAP_SIZE swap [ok]"

# resume offset the cmdline uses (map-swapfile -r) must match the verbose map's
# "Resume offset" field -- the value ryoku_cmdline bakes into resume_offset=.
off_short="$(btrfs inspect-internal map-swapfile -r "$MNT/swap/swapfile")"
off_full="$(btrfs inspect-internal map-swapfile "$MNT/swap/swapfile" | awk '/Resume offset/{print $NF}')"
[[ -n $off_short ]] || fail "map-swapfile -r returned no resume offset (btrfs-progs too old?)"
[[ $off_short == "$off_full" ]] || fail "resume offset mismatch: -r=$off_short verbose=$off_full"
echo "  resume offset: map-swapfile -r ($off_short) matches the verbose map [ok]"

# ── boot phase: tear down, remount @swap as fstab would (compress inherited from
# @'s superblock mount), and re-activate. this is the exact sequence the VM boot
# runs; the swapfile's +C keeps it activatable despite the compressed mount. ──
swapoff "$MNT/swap/swapfile"
umount "$MNT/swap"; umount "$MNT"
mount -o "$BTRFS_OPTS,subvol=@" "$LOOP" "$MNT" || fail "boot-phase: could not remount @"
mount -o "rw,noatime,subvol=@swap" "$LOOP" "$MNT/swap" || fail "boot-phase: could not remount @swap"
findmnt -no OPTIONS "$MNT/swap" | grep -q 'compress=zstd' \
  || fail "boot-phase: @swap did not inherit compress=zstd (the condition that makes the swapfile suspect)"
swapon "$MNT/swap/swapfile" || fail "boot-phase swapon failed (this is the VM 'Failed to activate swap' symptom)"
swapon --show=NAME --noheadings | grep -qF "$MNT/swap/swapfile" \
  || fail "boot-phase: swap not active after remount"
echo "  boot phase: @swap remounted with compress=zstd, +C swapfile still activates [ok]"

echo "install-swapfile: all checks passed"
