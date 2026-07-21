#!/usr/bin/env bash
# REAL loop-device integration test for ryoku_partition_alongside + the sfdisk
# probe (installation/backend/lib/disk.sh): the P0 dual-boot fix. 'alongside'
# shares Windows' single ESP and creates a 2 GiB XBOOTLDR /boot + root in the
# chosen free region, touching NOTHING that exists. we build sparse disks with
# real Windows-shaped GPT tables on loop devices and prove, against the real
# sgdisk/sfdisk/wipefs: the two new partitions carry our partlabels, ryoku-boot
# is XBOOTLDR (not a second ESP) so exactly one EF00 remains, every pre-existing
# partition is byte-identical afterward, leftover ryoku/ryokuboot partitions are
# REFUSED without the RYOKU_RECLAIM_LEFTOVERS ack and reclaimed (not stacked)
# with it, a retry that finds /mnt still mounted releases it and succeeds, and a
# disk with too little free space is refused before anything is written. The D4
# fixtures additionally assert the probe's byte-exact regions and sector-exact
# creation across canonical, trailing-gap, fragmented, and 4Kn layouts.
#
# needs root + loop devices; on EUID!=0 or a missing tool it prints a skip and
# exits 0 (so a non-root CI job stays green). run: sudo bash "$0".
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

skip() { echo "install-partition-alongside: SKIP ($1)"; exit 0; }
[[ $EUID -eq 0 ]] || skip "not root; needs losetup/sgdisk (run: sudo bash $0)"
for t in losetup sgdisk sfdisk jq parted mkfs.vfat mkfs.btrfs blkid partprobe truncate udevadm mountpoint sha256sum; do
  command -v "$t" >/dev/null 2>&1 || skip "missing $t"
done
# part_num lives in common.sh; the D4 fixtures call it at top level.
source "$root/installation/backend/lib/common.sh"

# loop devices must actually work: a container or a locked-down runner can have
# the tools yet no usable loop device. probe once and skip if attaching fails.
probe_img="$(mktemp --suffix=.ryoku-probe.img)"
truncate -s 8M "$probe_img" 2>/dev/null || { rm -f "$probe_img"; skip "cannot create a sparse file"; }
probe_loop="$(losetup -f --show "$probe_img" 2>/dev/null || true)"
[[ -n $probe_loop ]] || { rm -f "$probe_img"; skip "loop devices unavailable"; }
losetup -d "$probe_loop" 2>/dev/null || true
rm -f "$probe_img"

# ALWAYS detach loops + remove images, even on an assertion failure.
loops=(); imgs=(); mnt_ours=0
cleanup() {
  local x
  if (( mnt_ours )); then umount -R /mnt 2>/dev/null || umount -l /mnt 2>/dev/null || true; fi
  if (( ${#loops[@]} )); then for x in "${loops[@]}"; do losetup -d "$x" 2>/dev/null || true; done; fi
  if (( ${#imgs[@]} )); then for x in "${imgs[@]}"; do rm -f "$x" 2>/dev/null || true; done; fi
}
trap cleanup EXIT

# make_disk <size>: create a sparse image, attach it with partition scanning,
# and set $DISK to the loop device. tracked for cleanup.
make_disk() {
  local img bs=${2:-512}
  img="$(mktemp --suffix=.ryoku-test.img)"
  truncate -s "$1" "$img"
  DISK="$(losetup -f --show -P -b "$bs" "$img")"
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

# run_alongside <loop> [ack]: run ryoku_partition_alongside in a subshell (so a
# die's exit can't kill the test), RYOKU_ESP_GIB=1 RYOKU_SWAP_GIB=0. [ack] non-
# empty sets RYOKU_RECLAIM_LEFTOVERS. leaves the log in $out, exit code in $rc,
# resolved devices in $esp / $root_part.
run_alongside() {
  rc=0
  out="$(ROOT="$root" DISK="$1" ACK="${2:-}" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    export RYOKU_DISK="$DISK" RYOKU_ESP_GIB=1 RYOKU_SWAP_GIB=0
    [[ -n $ACK ]] && export RYOKU_RECLAIM_LEFTOVERS=$ACK
    set -euo pipefail
    ryoku_partition_alongside
    printf "RESULT_ESP=%s\n" "${ESP_DEV:-}"
    printf "RESULT_ROOT=%s\n" "${ROOT_PART:-}"
  ' 2>&1)" || rc=$?
  esp="$(sed -n 's/^RESULT_ESP=//p' <<<"$out" | tail -n1)"
  root_part="$(sed -n 's/^RESULT_ROOT=//p' <<<"$out" | tail -n1)"
}

# run_partition <loop> [ack]: run the FULL ryoku_partition dispatcher (which
# first releases a leftover /mnt from a prior attempt) for the alongside
# strategy. same capture as run_alongside.
run_partition() {
  rc=0
  out="$(ROOT="$root" DISK="$1" ACK="${2:-}" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    export RYOKU_DISK="$DISK" RYOKU_ESP_GIB=1 RYOKU_SWAP_GIB=0 RYOKU_DISK_STRATEGY=alongside
    [[ -n $ACK ]] && export RYOKU_RECLAIM_LEFTOVERS=$ACK
    set -euo pipefail
    ryoku_partition
    printf "RESULT_ESP=%s\n" "${ESP_DEV:-}"
    printf "RESULT_ROOT=%s\n" "${ROOT_PART:-}"
  ' 2>&1)" || rc=$?
  esp="$(sed -n 's/^RESULT_ESP=//p' <<<"$out" | tail -n1)"
  root_part="$(sed -n 's/^RESULT_ROOT=//p' <<<"$out" | tail -n1)"
}

part_count() { lsblk -lnpo NAME,TYPE "$1" | awk '$2=="part"' | wc -l; }
snap_parts() { local n; for n in 1 2 3; do echo "== p$n =="; sgdisk -i "$n" "$1"; done; }

XBOOTLDR_GUID=bc13c2ff-59e6-4262-a352-b275fd6f7172

# settle <loop> <last-partnum>: partprobe + wait for the by-index node to appear.
settle() {
  partprobe "$1"; udevadm settle
  local _; for _ in 1 2 3 4 5; do [[ -b ${1}p${2} ]] && break; sleep 0.3; udevadm settle; done
  [[ -b ${1}p${2} ]] || fail "partition nodes never appeared for $1"
}

# fmt_win_esp <part>: format an ESP vfat + seed /EFI/Microsoft so the probe
# detects it as Windows' ESP. mounts briefly, never leaves it mounted.
fmt_win_esp() {
  mkfs.vfat -F 32 -n ESP "$1" >/dev/null 2>&1 || fail "could not format Windows ESP $1"
  local mp; mp="$(mktemp -d)"; mount "$1" "$mp"; mkdir -p "$mp/EFI/Microsoft/Boot"; umount "$mp"; rmdir "$mp"
}

# region_top <loop>: the probe's largest free region as "START END MIB".
region_top() { "$root/installation/backend/ryoku-install" probe alongside "$1" 2>/dev/null | sort -k4,4 -nr | awk '$1=="region" && ++n==1{print $2,$3,$4}'; }

# edge_sha <dev>: sha256 of the first + last 1 MiB of a partition. a shifted or
# overwritten neighbor changes this even if the middle is untouched.
edge_sha() {
  local dev=$1 sz mib
  sz="$(blockdev --getsize64 "$dev")"; mib=$(( sz / 1048576 ))
  { dd if="$dev" bs=1M count=1 2>/dev/null; dd if="$dev" bs=1M skip=$(( mib - 1 )) count=1 2>/dev/null; } | sha256sum | awk '{print $1}'
}

# type_guid <loop> <partnum>: GPT partition type GUID (lowercased).
type_guid() { sgdisk -i "$2" "$1" | sed -n 's/^Partition GUID code: \([0-9A-Fa-f-]*\).*/\1/p' | tr '[:upper:]' '[:lower:]'; }

# ef00_count <loop>: number of EF00 (ESP-type) partitions on the disk.
ef00_count() { sgdisk -p "$1" 2>/dev/null | awk '$6=="EF00"' | wc -l; }

# create_in_region <loop> <start> <end>: run alongside creation at explicit
# region sectors (the RYOKU_REGION_* contract the TUI hands the backend).
create_in_region() {
  rc=0
  out="$(ROOT="$root" DISK="$1" RS="$2" RE="$3" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    export RYOKU_DISK="$DISK" RYOKU_SWAP_GIB=0 RYOKU_REGION_START="$RS" RYOKU_REGION_END="$RE"
    set -euo pipefail
    ryoku_partition_alongside
    printf "RESULT_ESP=%s\n" "${ESP_DEV:-}"
    printf "RESULT_ROOT=%s\n" "${ROOT_PART:-}"
  ' 2>&1)" || rc=$?
  esp="$(sed -n 's/^RESULT_ESP=//p' <<<"$out" | tail -n1)"
  root_part="$(sed -n 's/^RESULT_ROOT=//p' <<<"$out" | tail -n1)"
}

# check_fixture <name> <loop> <expStart> <expEnd> <expMib>: the full D4 battery
# on a built fixture -- byte-exact probe region, sector-exact creation, XBOOTLDR
# type, exactly one EF00, and byte-identical pre-existing partitions.
check_fixture() {
  local name=$1 loop=$2 exp_start=$3 exp_end=$4 exp_mib=$5 p i
  echo "-- fixture: $name --"
  fmt_win_esp "${loop}p1"
  local -a pre=() shas=()
  while IFS= read -r p; do pre+=("$p"); shas+=("$(edge_sha "$p")"); done \
    < <(lsblk -lnpo NAME,TYPE "$loop" | awk '$2=="part"{print $1}')
  local got; got="$(region_top "$loop")"
  [[ "$got" == "$exp_start $exp_end $exp_mib" ]] \
    || fail "$name: probe region '$got', want '$exp_start $exp_end $exp_mib'"
  create_in_region "$loop" "$exp_start" "$exp_end"
  [[ $rc -eq 0 ]] || fail "$name: alongside creation failed (rc=$rc): $out"
  [[ "$(lsblk -dno PARTLABEL "$esp")" == ryokuboot ]] || fail "$name: boot not labeled ryokuboot"
  [[ "$(lsblk -dno PARTLABEL "$root_part")" == ryoku ]] || fail "$name: root not labeled ryoku"
  [[ "$(type_guid "$loop" "$(part_num "$esp")")" == "$XBOOTLDR_GUID" ]] \
    || fail "$name: ryoku-boot type is $(type_guid "$loop" "$(part_num "$esp")"), want XBOOTLDR $XBOOTLDR_GUID"
  [[ "$(ef00_count "$loop")" -eq 1 ]] || fail "$name: expected exactly one EF00, got $(ef00_count "$loop")"
  local bs re
  bs="$(sgdisk -i "$(part_num "$esp")" "$loop" | awk '/First sector/{print $3}')"
  re="$(sgdisk -i "$(part_num "$root_part")" "$loop" | awk '/Last sector/{print $3}')"
  [[ "$bs" == "$exp_start" ]] || fail "$name: boot first sector $bs, want $exp_start"
  [[ "$re" == "$exp_end" ]] || fail "$name: root last sector $re, want $exp_end"
  for i in "${!pre[@]}"; do
    [[ "$(edge_sha "${pre[$i]}")" == "${shas[$i]}" ]] \
      || fail "$name: pre-existing ${pre[$i]} changed (edge checksum)"
  done
  echo "   $name: byte-exact region, sector-exact creation, XBOOTLDR + one EF00, neighbors intact"
}

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
grep -qF 'alongside region' <<<"$out" || fail "free-space math did not accept the region"

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
# 2. leftovers present, NO reclaim ack: refuse, list them, touch nothing
# ==========================================================================
# section 1 left our unmounted ryoku/ryokuboot partitions in place. without
# RYOKU_RECLAIM_LEFTOVERS=1 alongside must NOT delete them (they could be a
# working install); it dies naming them, and the table is unchanged.
before_refuse="$(snap_parts "$disk")"
count_refuse="$(part_count "$disk")"
run_alongside "$disk"                    # no ack
[[ $rc -ne 0 ]] || fail "alongside reclaimed leftovers WITHOUT the RYOKU_RECLAIM_LEFTOVERS ack (rc=$rc): $out"
grep -qF 'RYOKU_RECLAIM_LEFTOVERS' <<<"$out" || fail "refusal did not point at the RYOKU_RECLAIM_LEFTOVERS ack"
grep -qF "$root_part" <<<"$out" || fail "refusal did not list the leftover ryoku root partition"
[[ "$(part_count "$disk")" -eq $count_refuse ]] || fail "refused run still changed the partition count"
[[ "$before_refuse" == "$(snap_parts "$disk")" ]] || fail "refused run altered the partition table"

# ==========================================================================
# 3. leftovers present, reclaim ack set: reclaim + recreate, do not stack
# ==========================================================================
run_alongside "$disk" 1                  # RYOKU_RECLAIM_LEFTOVERS=1
[[ $rc -eq 0 ]] || fail "retry with the reclaim ack failed (rc=$rc): $out"
grep -qF 'reclaiming leftover' <<<"$out" || fail "acked retry did not reclaim the prior ryoku/ryokuboot partitions"
[[ "$(part_count "$disk")" -eq $(( pre_count + 2 )) ]] \
  || fail "acked retry stacked partitions: expected $(( pre_count + 2 )), got $(part_count "$disk")"
[[ "$(lsblk -dno PARTLABEL "$esp")" == ryokuboot ]] || fail "acked retry ESP $esp mislabeled"
[[ "$(lsblk -dno PARTLABEL "$root_part")" == ryoku ]] || fail "acked retry root $root_part mislabeled"
[[ "$parts_before" == "$(snap_parts "$disk")" ]] || fail "acked retry disturbed an existing partition"

# ==========================================================================
# 4. retry with /mnt still mounted from a failed attempt: release + reclaim
# ==========================================================================
# the failure EXIT trap leaves /mnt mounted; the TUI retry re-runs the backend.
# ryoku_partition (the dispatcher) must release /mnt (swapoff + umount -R) BEFORE
# touching the disk, then reclaim the now-unmounted leftover and recreate. mount
# the just-created ryoku root at /mnt to stand in for that leftover.
if mountpoint -q /mnt; then
  echo "install-partition-alongside: NOTE /mnt busy, skipping the mounted-retry case"
else
  mkfs.btrfs -f -q -L ryoku "$root_part" >/dev/null 2>&1 || fail "could not format the root for the mounted-retry case"
  mount "$root_part" /mnt || fail "could not mount the created root at /mnt"
  mnt_ours=1
  run_partition "$disk" 1                # dispatcher, ack set
  [[ $rc -eq 0 ]] || fail "retry with /mnt mounted failed (rc=$rc): $out"
  grep -qF 'releasing /mnt left mounted by a previous install attempt' <<<"$out" \
    || fail "dispatcher did not release the leftover /mnt mount"
  grep -qF 'reclaiming leftover' <<<"$out" || fail "mounted retry did not reclaim the prior partitions"
  mountpoint -q /mnt && fail "the leftover /mnt mount was not released"
  mnt_ours=0
  [[ "$(part_count "$disk")" -eq $(( pre_count + 2 )) ]] \
    || fail "mounted retry stacked partitions: expected $(( pre_count + 2 )), got $(part_count "$disk")"
  [[ "$parts_before" == "$(snap_parts "$disk")" ]] || fail "mounted retry disturbed an existing partition"
fi

# ==========================================================================
# 5. too little free space: refuse before writing anything
# ==========================================================================
# 25 GiB disk, a 6 GiB Basic data partition -> ~19 GiB free, below the 22 GiB
# ('alongside' needs a 20 GiB root + a 2 GiB boot partition).
make_disk 25G; small=$DISK
fake_windows "$small" 6G
small_before="$(snap_parts "$small")"
run_alongside "$small"
[[ $rc -ne 0 ]] || fail "alongside accepted a disk with too little free space (rc=$rc): $out"
grep -qF 'not enough free space' <<<"$out" || fail "did not explain the free-space shortfall"
[[ "$small_before" == "$(snap_parts "$small")" ]] || fail "a rejected too-small disk was still written to"

# ==========================================================================
# D4 fixtures: real Windows-shaped tables, byte-exact regions + sector-exact
# creation. each asserts the full battery via check_fixture. sector numbers are
# deterministic for these fixed layouts (verified against the live probe).
# ==========================================================================

# (a) canonical Ally/OEM: ESP 260M + MSR 16M + NTFS 20G + shrink GAP + Recovery
# 700M + vendor 260M (recovery/vendor pinned at the end so the gap is the shrink
# gap). mirrors /dev/sda's shape on this box.
make_disk 60G; fa="$DISK"
sgdisk -n 1:2048:+260M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:+16M    -t 2:0c01 -c 2:"Microsoft reserved partition" \
       -n 3:0:+20G    -t 3:0700 -c 3:"Basic data partition" \
       -n 4:123731968:+700M -t 4:2700 -c 4:"Windows RE" \
       -n 5:125165568:+260M -t 5:ef02 -c 5:"vendor" "$fa" >/dev/null
settle "$fa" 5
check_fixture "a canonical (ESP+MSR+NTFS+shrink gap+recovery+vendor)" "$fa" 42510336 123731967 39659

# (b) trailing gap after the last partition.
make_disk 50G; fb="$DISK"
sgdisk -n 1:2048:+260M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:+16M    -t 2:0c01 -c 2:"Microsoft reserved partition" \
       -n 3:0:+20G    -t 3:0700 -c 3:"Basic data partition" "$fb" >/dev/null
settle "$fb" 3
check_fixture "b trailing gap after last partition" "$fb" 42510336 104855551 30442

# (c) fragmented: a ~1 MiB lead gap (GPT->p1) and a 600 MiB mid gap, both below
# the 1024 MiB floor and thus EXCLUDED, plus the big trailing gap that IS
# reported. proves the probe reports only usable regions.
make_disk 60G; fc="$DISK"
sgdisk -n 1:2048:+260M -t 1:ef00 -c 1:"EFI system partition" \
       -n 2:0:+16M    -t 2:0c01 -c 2:"Microsoft reserved partition" \
       -n 3:0:+10G    -t 3:0700 -c 3:"Basic data partition" "$fc" >/dev/null
c_p3end="$(sgdisk -i 3 "$fc" | awk '/Last sector/{print $3}')"
sgdisk -n 4:$(( c_p3end + 1 + 600*2048 )):+5G -t 4:0700 -c 4:"Basic data partition" "$fc" >/dev/null
settle "$fc" 4
check_fixture "c fragmented (sub-floor gaps excluded, big gap reported)" "$fc" 33253376 125827071 45202

# (d) 4096-byte logical sector loop: alignment math must use the real sector size.
make_disk 60G 4096; fd="$DISK"
if [[ "$(blockdev --getss "$fd")" != 4096 ]]; then
  echo "   d: SKIP (loop -b 4096 not honored here)"
else
  sgdisk -n 1:256:+260M -t 1:ef00 -c 1:"EFI system partition" \
         -n 2:0:+16M    -t 2:0c01 -c 2:"Microsoft reserved partition" \
         -n 3:0:+20G    -t 3:0700 -c 3:"Basic data partition" "$fd" >/dev/null
  settle "$fd" 3
  check_fixture "d 4096-byte sector loop" "$fd" 5313792 15728383 40682
fi

echo "install-partition-alongside: all checks passed"
