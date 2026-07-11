#!/usr/bin/env bash
# REAL loop-device integration test for ryoku_partition_alongside
# (installation/backend/lib/disk.sh): the P0 dual-boot fix. 'alongside' must
# create a DEDICATED Ryoku ESP + root in the largest free region and NEVER touch
# the existing OS -- the old code reused the Windows ESP (too small for our
# kernel/initramfs, and writing our loader clobbered Windows' boot). we build a
# sparse disk with a fake Windows layout on a loop device and prove, against the
# real sgdisk/parted/wipefs, that: the two new partitions carry our partlabels,
# every pre-existing partition is byte-identical afterward, the Windows ESP's
# vfat filesystem survives untouched, a failed-run retry reclaims our leftovers
# instead of stacking, and a disk with too little free space is refused before
# anything is written.
#
# needs root + loop devices; on EUID!=0 or a missing tool it prints a skip and
# exits 0 (so a non-root CI job stays green). run: sudo bash "$0".
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

skip() { echo "install-partition-alongside: SKIP ($1)"; exit 0; }
[[ $EUID -eq 0 ]] || skip "not root; needs losetup/sgdisk (run: sudo bash $0)"
for t in losetup sgdisk parted mkfs.vfat blkid partprobe truncate udevadm; do
  command -v "$t" >/dev/null 2>&1 || skip "missing $t"
done

# loop devices must actually work: a container or a locked-down runner can have
# the tools yet no usable loop device. probe once and skip if attaching fails.
probe_img="$(mktemp --suffix=.ryoku-probe.img)"
truncate -s 8M "$probe_img" 2>/dev/null || { rm -f "$probe_img"; skip "cannot create a sparse file"; }
probe_loop="$(losetup -f --show "$probe_img" 2>/dev/null || true)"
[[ -n $probe_loop ]] || { rm -f "$probe_img"; skip "loop devices unavailable"; }
losetup -d "$probe_loop" 2>/dev/null || true
rm -f "$probe_img"

# ALWAYS detach loops + remove images, even on an assertion failure.
loops=(); imgs=()
cleanup() {
  local x
  if (( ${#loops[@]} )); then for x in "${loops[@]}"; do losetup -d "$x" 2>/dev/null || true; done; fi
  if (( ${#imgs[@]} )); then for x in "${imgs[@]}"; do rm -f "$x" 2>/dev/null || true; done; fi
}
trap cleanup EXIT

# make_disk <size>: create a sparse image, attach it with partition scanning,
# and set $DISK to the loop device. tracked for cleanup.
make_disk() {
  local img
  img="$(mktemp --suffix=.ryoku-test.img)"
  truncate -s "$1" "$img"
  DISK="$(losetup -f --show -P "$img")"
  imgs+=("$img"); loops+=("$DISK")
}

# fake_windows <loop> <basic-data-size>: an EF00 ESP (100MiB), an MSR (16MiB),
# and a Basic data partition of the given size, leaving the rest free -- the
# common single-disk Windows GPT layout.
fake_windows() {
  sgdisk -n 1:0:+100M -t 1:ef00 -c 1:"EFI system partition" \
         -n 2:0:+16M  -t 2:0c01 -c 2:"Microsoft reserved partition" \
         -n 3:0:+"$2" -t 3:0700 -c 3:"Basic data partition" "$1" >/dev/null
  partprobe "$1"; udevadm settle
  local _
  for _ in 1 2 3 4 5; do [[ -b ${1}p3 ]] && break; sleep 0.3; udevadm settle; done
  [[ -b ${1}p3 ]] || fail "loop partition nodes never appeared for $1"
}

# run_alongside <loop>: run ryoku_partition_alongside in a subshell (so a die's
# exit can't kill the test), RYOKU_ESP_GIB=1 RYOKU_SWAP_GIB=0. leaves the log in
# $out, exit code in $rc, and the resolved devices in $esp / $root_part.
run_alongside() {
  rc=0
  out="$(ROOT="$root" DISK="$1" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    export RYOKU_DISK="$DISK" RYOKU_ESP_GIB=1 RYOKU_SWAP_GIB=0
    set -euo pipefail
    ryoku_partition_alongside
    printf "RESULT_ESP=%s\n" "${ESP_DEV:-}"
    printf "RESULT_ROOT=%s\n" "${ROOT_PART:-}"
  ' 2>&1)" || rc=$?
  esp="$(sed -n 's/^RESULT_ESP=//p' <<<"$out" | tail -n1)"
  root_part="$(sed -n 's/^RESULT_ROOT=//p' <<<"$out" | tail -n1)"
}

part_count() { lsblk -lnpo NAME,TYPE "$1" | awk '$2=="part"' | wc -l; }
snap_parts() { local n; for n in 1 2 3; do echo "== p$n =="; sgdisk -i "$n" "$1"; done; }

# ==========================================================================
# 1. dedicated ESP + root in free space, nothing existing touched
# ==========================================================================
make_disk 40G; disk=$DISK
fake_windows "$disk" 12G
mkfs.vfat -F 32 "${disk}p1" >/dev/null 2>&1 || fail "could not pre-format the Windows ESP"
vfat_uuid_before="$(blkid -s UUID -o value "${disk}p1")"
[[ -n $vfat_uuid_before ]] || fail "the pre-written Windows ESP has no fs UUID to track"
parts_before="$(snap_parts "$disk")"
pre_count="$(part_count "$disk")"

run_alongside "$disk"
[[ $rc -eq 0 ]] || fail "alongside rejected a disk with ample free space (rc=$rc): $out"
grep -qF 'largest free region' <<<"$out" || fail "free-space math did not accept the region"

# the two new partitions carry OUR partlabels.
[[ -n $esp && -n $root_part ]] || fail "alongside did not set ESP_DEV/ROOT_PART: $out"
[[ "$(lsblk -dno PARTLABEL "$esp")" == ryokuboot ]] || fail "new ESP $esp is not labeled ryokuboot"
[[ "$(lsblk -dno PARTLABEL "$root_part")" == ryoku ]] || fail "new root $root_part is not labeled ryoku"
[[ $esp != "$root_part" ]] || fail "ESP and root resolved to the same device"

# every pre-existing partition is byte-identical (type GUID, unique GUID,
# first/last sector, name all unchanged).
[[ "$parts_before" == "$(snap_parts "$disk")" ]] || fail "an existing partition (p1-p3) changed after alongside"

# the Windows ESP was never wipefs'd/formatted: its vfat UUID survives.
vfat_uuid_after="$(blkid -s UUID -o value "${disk}p1")"
[[ "$vfat_uuid_after" == "$vfat_uuid_before" ]] \
  || fail "the Windows ESP filesystem changed (uuid $vfat_uuid_before -> ${vfat_uuid_after:-gone})"

# exactly two partitions were added.
[[ "$(part_count "$disk")" -eq $(( pre_count + 2 )) ]] \
  || fail "expected $(( pre_count + 2 )) partitions, got $(part_count "$disk")"

# ==========================================================================
# 2. failed-run retry: reclaim our unmounted leftovers, do not stack
# ==========================================================================
run_alongside "$disk"
[[ $rc -eq 0 ]] || fail "retry over our own leftovers failed (rc=$rc): $out"
grep -qF 'reclaiming leftover' <<<"$out" || fail "retry did not reclaim the prior ryoku/ryokuboot partitions"
[[ "$(part_count "$disk")" -eq $(( pre_count + 2 )) ]] \
  || fail "retry stacked partitions: expected $(( pre_count + 2 )), got $(part_count "$disk")"
[[ "$(lsblk -dno PARTLABEL "$esp")" == ryokuboot ]] || fail "retry ESP $esp mislabeled"
[[ "$(lsblk -dno PARTLABEL "$root_part")" == ryoku ]] || fail "retry root $root_part mislabeled"
# the Windows layout is STILL intact after the reclaim+recreate cycle.
[[ "$parts_before" == "$(snap_parts "$disk")" ]] || fail "retry disturbed an existing partition"

# ==========================================================================
# 3. too little free space: refuse before writing anything
# ==========================================================================
# 25 GiB disk, a 6 GiB Basic data partition -> ~18 GiB free, below the 21 GiB
# ('alongside' needs 20 GiB root + 1 GiB ESP).
make_disk 25G; small=$DISK
fake_windows "$small" 6G
small_before="$(snap_parts "$small")"
run_alongside "$small"
[[ $rc -ne 0 ]] || fail "alongside accepted a disk with too little free space (rc=$rc): $out"
grep -qF 'not enough free space' <<<"$out" || fail "did not explain the free-space shortfall"
[[ "$small_before" == "$(snap_parts "$small")" ]] || fail "a rejected too-small disk was still written to"

echo "install-partition-alongside: all checks passed"
