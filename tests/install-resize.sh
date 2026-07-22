#!/usr/bin/env bash
# REAL loop-device integration test for the carve feature (installation/backend/
# lib/resize.sh + the `probe resize` extension in lib/disk.sh): shrink an existing
# partition to free space for an alongside install, the way Ubuntu carves out of
# Windows. For each of ntfs/ext4/btrfs we build a full-disk filesystem with known
# data, carve a chunk out of it, and prove the filesystem still mounts, the data
# checksum is intact, PARTUUID/typeGUID are unchanged, the carved region lands at
# the expected geometry, and the GPT is clean. Then the refusal fixtures: a dirty
# NTFS, a BitLocker signature, and a multi-device btrfs must ALL be refused before
# anything is written.
#
# needs root + loop devices; on EUID!=0 or a missing tool it prints a skip and
# exits 0 (so a non-root CI job stays green). run: sudo bash "$0".
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }
skip() { echo "install-resize: SKIP ($1)"; exit 0; }

[[ $EUID -eq 0 ]] || skip "not root; needs losetup + fs tools (run: sudo bash $0)"
for t in losetup sgdisk sfdisk jq partprobe blkid udevadm truncate sha256sum mkfs.vfat \
         mkfs.ext4 resize2fs e2fsck dumpe2fs mkfs.btrfs btrfs mkntfs ntfsresize; do
  command -v "$t" >/dev/null 2>&1 || skip "missing $t"
done
# part_num lives in common.sh; the fixtures call it at top level.
source "$root/installation/backend/lib/common.sh"

# loop devices must actually work (a locked-down runner can have the tools yet no
# usable loop node). probe once and skip if attaching fails.
probe_img="$(mktemp --suffix=.ryoku-probe.img)"
truncate -s 8M "$probe_img" 2>/dev/null || { rm -f "$probe_img"; skip "cannot create a sparse file"; }
probe_loop="$(losetup -f --show "$probe_img" 2>/dev/null || true)"
[[ -n $probe_loop ]] || { rm -f "$probe_img"; skip "loop devices unavailable"; }
losetup -d "$probe_loop" 2>/dev/null || true
rm -f "$probe_img"

# ALWAYS unmount, detach loops, remove images, even on an assertion failure.
loops=(); imgs=(); mnts=()
cleanup() {
  local x
  if (( ${#mnts[@]} )); then for x in "${mnts[@]}"; do umount "$x" 2>/dev/null || true; rmdir "$x" 2>/dev/null || true; done; fi
  if (( ${#loops[@]} )); then for x in "${loops[@]}"; do losetup -d "$x" 2>/dev/null || true; done; fi
  if (( ${#imgs[@]} )); then for x in "${imgs[@]}"; do rm -f "$x" 2>/dev/null || true; done; fi
}
trap cleanup EXIT

# make_disk <size>: sparse image attached with partition scanning; sets $DISK.
make_disk() {
  local img
  img="$(mktemp --suffix=.resizebackend-test.img)"
  truncate -s "$1" "$img"
  DISK="$(losetup -f --show -P "$img")"
  imgs+=("$img"); loops+=("$DISK")
}

# settle <loop> <last-partnum>: partprobe + wait for the by-index node to appear.
settle() {
  partprobe "$1"; udevadm settle
  local _; for _ in 1 2 3 4 5; do [[ -b ${1}p${2} ]] && break; sleep 0.3; udevadm settle; done
  [[ -b ${1}p${2} ]] || fail "partition nodes never appeared for $1"
}

# edge_sha <dev>: sha256 of the first + last 1 MiB. a shifted/overwritten neighbor
# changes this even if its middle is untouched.
edge_sha() {
  local dev=$1 sz mib
  sz="$(blockdev --getsize64 "$dev")"; mib=$(( sz / 1048576 ))
  { dd if="$dev" bs=1M count=1 2>/dev/null; dd if="$dev" bs=1M skip=$(( mib - 1 )) count=1 2>/dev/null; } | sha256sum | awk '{print $1}'
}

part_uuid() { sgdisk -i "$2" "$1" | sed -n 's/^Partition unique GUID: //p'; }
type_guid() { sgdisk -i "$2" "$1" | sed -n 's/^Partition GUID code: \([0-9A-Fa-f-]*\).*/\1/p'; }

# mount_fs <part> <mp>: NTFS needs the ntfs-3g FUSE helper for a writable mount;
# everything else the kernel mounts directly.
mount_fs() {
  if [[ "$(blkid -o value -s TYPE "$1" 2>/dev/null)" == ntfs ]]; then
    mount -t ntfs-3g "$1" "$2"
  else
    mount "$1" "$2"
  fi
}

# seed_data <part>: mount, write 200 MiB of random data, checksum -> $SEED_SUM.
seed_data() {
  local part=$1 mp; mp="$(mktemp -d)"; mnts+=("$mp")
  mount_fs "$part" "$mp" || fail "seed: could not mount $part"
  dd if=/dev/urandom of="$mp/blob" bs=1M count=200 status=none; sync
  SEED_SUM="$(sha256sum "$mp/blob" | awk '{print $1}')"
  umount "$mp"; rmdir "$mp"; mnts=("${mnts[@]/$mp}")
}

# check_data <part> <want-sum>: remount and prove the blob checksum is unchanged.
check_data() {
  local part=$1 want=$2 mp got; mp="$(mktemp -d)"; mnts+=("$mp")
  mount_fs "$part" "$mp" || fail "check: could not remount $part after carve"
  got="$(sha256sum "$mp/blob" 2>/dev/null | awk '{print $1}')"
  umount "$mp"; rmdir "$mp"; mnts=("${mnts[@]/$mp}")
  [[ $got == "$want" ]] || fail "data checksum changed after carve ($want -> ${got:-gone})"
}

# expected_carved_start <disk> <part> <take_mib>: the sector the freed gap must
# begin at, computed with the SAME arithmetic as ryoku_carve (align end down 1 MiB).
expected_carved_start() {
  local disk=$1 part=$2 take=$3 ss spm pstart psize pend take_s pnew_end
  ss="$(blockdev --getss "$disk")"; spm=$(( 1048576 / ss ))
  read -r pstart psize < <(sfdisk --json "$disk" | jq -r --arg n "$part" '.partitiontable.partitions[] | select(.node==$n) | "\(.start) \(.size)"')
  pend=$(( pstart + psize - 1 )); take_s=$(( take * spm ))
  pnew_end=$(( pend - take_s )); pnew_end=$(( (pnew_end + 1) / spm * spm - 1 ))
  echo $(( pnew_end + 1 ))
}

# run_carve <disk> <part> <take_mib>: run ryoku_carve in a subshell (so a die's
# exit can't kill the test). leaves the log in $out, exit code in $rc, the freed
# region in $region_start/$region_end.
run_carve() {
  rc=0
  out="$(ROOT="$root" DISK="$1" PART="$2" TAKE="$3" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    source "$ROOT/installation/backend/lib/resize.sh"
    export RYOKU_DISK="$DISK" RYOKU_DISK_STRATEGY=alongside RYOKU_SWAP_GIB=0
    export RYOKU_RESIZE_PART="$PART" RYOKU_RESIZE_TAKE_MIB="$TAKE"
    set -euo pipefail
    ryoku_carve
    printf "RESULT_RS=%s\n" "${RYOKU_REGION_START:-}"
    printf "RESULT_RE=%s\n" "${RYOKU_REGION_END:-}"
  ' 2>&1)" || rc=$?
  region_start="$(sed -n 's/^RESULT_RS=//p' <<<"$out" | tail -n1)"
}

# probe_resize <disk>: the machine report the TUI carve view consumes.
probe_resize() { "$root/installation/backend/ryoku-install" probe resize "$1" 2>/dev/null; }

TAKE=26624   # 26 GiB: comfortably above the 22 GiB Ryoku floor (2 boot + 20 root)

# carve_case <name> <mkfs-cmd...> then relies on $DISK/$P2 being set by the caller.
# builds fs on p2, seeds data, carves, and runs the full battery.
carve_battery() {
  local name=$1 disk=$2 p2=$3
  echo "-- carve: $name --"
  seed_data "$p2"
  local pu_b tg_b p1_edge exp_start
  pu_b="$(part_uuid "$disk" 2)"; tg_b="$(type_guid "$disk" 2)"
  p1_edge="$(edge_sha "${disk}p1")"
  exp_start="$(expected_carved_start "$disk" "$p2" "$TAKE")"

  run_carve "$disk" "$p2" "$TAKE"
  [[ $rc -eq 0 ]] || fail "$name: carve failed (rc=$rc): $out"
  settle "$disk" 2

  # carved region at the exact expected geometry, handed to alongside.
  [[ -n $region_start ]] || fail "$name: carve exported no RYOKU_REGION_START: $out"
  [[ $region_start == "$exp_start" ]] || fail "$name: freed region starts at $region_start, want $exp_start"

  # identity preserved.
  [[ "$(part_uuid "$disk" 2)" == "$pu_b" ]] || fail "$name: PARTUUID changed"
  [[ "$(type_guid "$disk" 2)" == "$tg_b" ]] || fail "$name: type GUID changed"
  # neighbour p1 byte-identical.
  [[ "$(edge_sha "${disk}p1")" == "$p1_edge" ]] || fail "$name: neighbour p1 changed (edge checksum)"
  # GPT clean.
  sgdisk -v "$disk" 2>&1 | grep -q 'No problems found' || fail "$name: sgdisk -v not clean after carve"
  # data intact.
  check_data "$p2" "$SEED_SUM"
  echo "   $name: freed region byte-exact at $exp_start, PARTUUID + typeGUID kept, neighbour intact, data checksum intact, GPT clean"
}

# ==========================================================================
# 1. ext4 carve
# ==========================================================================
make_disk 64G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:0        -t 2:8300 -c 2:"Basic data partition" "$disk" >/dev/null
settle "$disk" 2
mkfs.ext4 -q -F -L EXTDATA "${disk}p2"
carve_battery "ext4" "$disk" "${disk}p2"

# probe format assertion on the freshly-carved ext4 disk: the p2 part line and the
# frozen field order the TUI parses.
probe="$(probe_resize "$disk")"
grep -qE "^part ${disk}p2 2 ext4 " <<<"$probe" || fail "probe resize: no ext4 part line for ${disk}p2: $probe"
grep -qE "^part ${disk}p2 2 ext4 [^ ]+ [0-9]+ [0-9-]+ [0-9]+ yes " <<<"$probe" || fail "probe resize: ext4 p2 not reported shrinkable with a numeric min: $probe"
grep -qx "verdict ok" <<<"$probe" || fail "probe resize: verdict not ok: $probe"
echo "   probe resize: ext4 part line + verdict ok match the frozen format"

# ==========================================================================
# 2. ntfs carve
# ==========================================================================
make_disk 64G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:0        -t 2:0700 -c 2:"Basic data partition" "$disk" >/dev/null
settle "$disk" 2
mkntfs -Q -L WINDATA "${disk}p2" >/dev/null 2>&1
carve_battery "ntfs" "$disk" "${disk}p2"

# ==========================================================================
# 3. btrfs carve
# ==========================================================================
make_disk 64G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:0        -t 2:8300 -c 2:"Basic data partition" "$disk" >/dev/null
settle "$disk" 2
mkfs.btrfs -q -L BTRDATA "${disk}p2" >/dev/null 2>&1
carve_battery "btrfs" "$disk" "${disk}p2"

# ==========================================================================
# 3b. verdict generalization: a FULLY ALLOCATED disk (no free region) whose
# partition is shrinkable is still `probe alongside` verdict ok -- the carve path
# is what makes it viable. this is the frozen-contract change that lets the TUI
# offer alongside on a disk with no gaps.
# ==========================================================================
echo "-- verdict: fully-allocated + shrinkable btrfs = alongside ok --"
make_disk 64G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:0        -t 2:8300 -c 2:"Basic data partition" "$disk" >/dev/null
settle "$disk" 2
mkfs.vfat -F 32 -n BOOT "${disk}p1" >/dev/null 2>&1 || fail "verdict: could not format the ESP"
mkfs.btrfs -q -L ryoku "${disk}p2" >/dev/null 2>&1
aprobe="$("$root/installation/backend/ryoku-install" probe alongside "$disk" 2>/dev/null)"
grep -qE '^region ' <<<"$aprobe" && fail "verdict: fixture was expected to be fully allocated (a free region appeared): $aprobe"
grep -qx 'verdict ok' <<<"$aprobe" || fail "verdict: fully-allocated shrinkable disk was not verdict ok: $aprobe"
grep -qE '^esp_kind (ryoku|linux)$' <<<"$aprobe" || fail "verdict: expected esp_kind for the shared ESP: $aprobe"
echo "   verdict ok on a fully-allocated disk via btrfs shrinkability"

# ==========================================================================
# 4. refusal: dirty NTFS (scheduled consistency check) is never carved
# ==========================================================================
echo "-- refusal: dirty NTFS --"
make_disk 64G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 -n 2:0:0 -t 2:0700 -c 2:"Basic data partition" "$disk" >/dev/null
settle "$disk" 2
mkntfs -Q "${disk}p2" >/dev/null 2>&1
# a real resize sets the NTFS scheduled-check flag -> the volume now reads dirty.
ntfsresize --force --force --size 40000000000 "${disk}p2" >/dev/null 2>&1
before="$(sgdisk -i 2 "$disk")"
run_carve "$disk" "${disk}p2" "$TAKE"
[[ $rc -ne 0 ]] || fail "dirty NTFS: carve was NOT refused (rc=$rc): $out"
grep -qiE 'dirty|not shrinkable' <<<"$out" || fail "dirty NTFS: refusal did not name the dirty state: $out"
[[ "$(sgdisk -i 2 "$disk")" == "$before" ]] || fail "dirty NTFS: refused carve still altered the partition"
echo "   dirty NTFS refused, partition untouched"

# ==========================================================================
# 5. refusal: a BitLocker signature is never carved
# ==========================================================================
echo "-- refusal: BitLocker signature --"
make_disk 64G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 -n 2:0:0 -t 2:0700 -c 2:"Basic data partition" "$disk" >/dev/null
settle "$disk" 2
wipefs -a "${disk}p2" >/dev/null 2>&1
# minimal BitLocker (Win7 form) header libblkid recognises: jump + "-FVE-FS-" at
# offset 0, an FVE metadata offset at 176, and the FVE block signature there.
printf '\xeb\x58\x90-FVE-FS-'                 | dd of="${disk}p2" bs=1 conv=notrunc status=none
printf '\x00\x00\x01\x00\x00\x00\x00\x00'     | dd of="${disk}p2" bs=1 seek=176 conv=notrunc status=none
printf -- '-FVE-FS-'                          | dd of="${disk}p2" bs=1 seek=65536 conv=notrunc status=none
udevadm settle
[[ "$(blkid -o value -s TYPE "${disk}p2")" == BitLocker ]] || fail "BitLocker: fixture did not read as TYPE=BitLocker"
before="$(sgdisk -i 2 "$disk")"
run_carve "$disk" "${disk}p2" "$TAKE"
[[ $rc -ne 0 ]] || fail "BitLocker: carve was NOT refused (rc=$rc): $out"
grep -qi 'BitLocker' <<<"$out" || fail "BitLocker: refusal did not name BitLocker: $out"
[[ "$(sgdisk -i 2 "$disk")" == "$before" ]] || fail "BitLocker: refused carve still altered the partition"
echo "   BitLocker refused, partition untouched"

# ==========================================================================
# 6. refusal: multi-device btrfs is never carved
# ==========================================================================
echo "-- refusal: multi-device btrfs --"
make_disk 48G; disk=$DISK
sgdisk -n 1:2048:+100M -t 1:ef00 \
       -n 2:0:+20G     -t 2:8300 -c 2:"Basic data partition" \
       -n 3:0:0        -t 3:8300 -c 3:"Basic data partition" "$disk" >/dev/null
settle "$disk" 3
mkfs.btrfs -q -L BTRRAID "${disk}p2" "${disk}p3" >/dev/null 2>&1
before="$(sgdisk -i 2 "$disk")"
run_carve "$disk" "${disk}p2" "$TAKE"
[[ $rc -ne 0 ]] || fail "multi-dev btrfs: carve was NOT refused (rc=$rc): $out"
grep -qi 'multi-device' <<<"$out" || fail "multi-dev btrfs: refusal did not name the multi-device constraint: $out"
[[ "$(sgdisk -i 2 "$disk")" == "$before" ]] || fail "multi-dev btrfs: refused carve still altered the partition"
echo "   multi-device btrfs refused, partition untouched"

echo "install-resize: all checks passed"
