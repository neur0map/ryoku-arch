#!/usr/bin/env bash
# fixture test for ryoku_release_disk (installation/backend/lib/disk.sh): the
# pre-wipe teardown that frees a busy target disk so wipefs/sgdisk can't
# fail with "Device or resource busy". runs dry, lsblk is mocked, so what we
# assert is the teardown PLAN (commands, in order). no real device touched.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# run ryoku_release_disk against a mocked block tree, capture the dry-run plan.
release() {
  RYOKU_DRYRUN=1 ROOT="$root" MOCK="$1" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    dmsetup() { return 1; }  # default: no stale mapper present; a case overrides.
    eval "$MOCK"
    ryoku_release_disk /dev/nvme0n1
  '
}

# --- busy disk: mounts (incl. a udisks auto-mount), swap, and a LUKS holder ---
busy='lsblk() {
  case "$*" in
    *MOUNTPOINT*)  printf "/mnt\n/run/media/u/DATA\n\n" ;;
    *NAME,FSTYPE*) printf "/dev/nvme0n1p3 swap\n/dev/nvme0n1p1 vfat\n" ;;
    *NAME,TYPE*)   printf "/dev/nvme0n1 disk\n/dev/nvme0n1p2 part\n/dev/mapper/cr crypt\n" ;;
  esac
}'
out="$(release "$busy")"

grep -qF "umount -R -- '/mnt'" <<<"$out" || fail "did not unmount /mnt"
grep -qF "umount -R -- '/run/media/u/DATA'" <<<"$out" || fail "did not unmount the udisks auto-mount"
grep -qF "swapoff -- '/dev/nvme0n1p3'" <<<"$out" || fail "did not swapoff the swap partition"
grep -qF "swapoff -- '/dev/nvme0n1p1'" <<<"$out" && fail "swapoff hit the non-swap vfat partition"
grep -qF "cryptsetup close -- '/dev/mapper/cr'" <<<"$out" || fail "did not close the LUKS/dm holder"
grep -qF "udevadm settle" <<<"$out" || fail "did not settle udev"

# deepest mount released before its parent (udisks before /mnt).
first_umount="$(grep 'umount -R' <<<"$out" | head -n1)"
[[ $first_umount == *"/run/media/u/DATA"* ]] || fail "unmount order is not deepest-first (got: $first_umount)"

# --- clean disk: no holders -> a quiet no-op (no destructive actions) ---------
out="$(release 'lsblk() { printf "\n"; }')"
grep -qF 'releasing /dev/nvme0n1' <<<"$out" || fail "missing the releasing log line"
grep -qE "umount -R|swapoff --|cryptsetup close --|dmsetup remove|vgchange -an|mdadm --stop" <<<"$out" \
  && fail "acted on a clean disk that has no holders"

# --- orphaned /dev/mapper/root from a failed prior run: freed by NAME ---------
# lsblk ties nothing to the disk (the orphan's backing partition is already
# gone), so only the by-name free reaches it; dmsetup reports the name present.
out="$(release 'dmsetup() { return 0; }
lsblk() { printf "\n"; }')"
grep -qF "freeing stale mapper /dev/mapper/root" <<<"$out" || fail "did not announce freeing the orphaned root mapper"
grep -qF "cryptsetup close -- 'root'" <<<"$out" || fail "did not close the orphaned root mapper by name"
grep -qF "swapoff -a" <<<"$out" || fail "did not swapoff -a to release a swapfile that could pin the mapper"

echo "install-disk-teardown: all checks passed"
