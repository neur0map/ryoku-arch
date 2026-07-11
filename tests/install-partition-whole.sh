#!/usr/bin/env bash
# fixture test for ryoku_partition_whole (installation/backend/lib/disk.sh): the
# destructive whole-disk strategy. two things must hold. (1) the wipe guard: a
# disk that already holds partitions is refused unless RYOKU_WIPE_CONFIRMED=1
# (the TUI's typed "ERASE" ack), so a dropped strategy pick can't silently wipe a
# Windows install; a blank disk still goes through without the token. (2) the
# partitioning plan: zap the table, fresh GPT, ESP + root, then wipefs BOTH new
# partitions in order (a stale LUKS/btrfs header at those offsets would fail the
# later mkfs/mount). every destructive binary is mocked to echo its argv, so we
# assert the plan and the guard without root and without touching a disk.
# the mocks are single-quoted on purpose: they are shell snippets eval'd in a
# subshell and must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# every destructive step mocked to echo its argv (so we can assert the plan),
# plus ryoku_disk_populated driven by $POP (0 = populated, 1 = blank). udevadm is
# a no-op and exported so the nested `bash -c` in run_sh inherits it.
mocks='
ryoku_disk_populated()  { return ${POP:-1}; }
ryoku_release_disk()    { echo "release_disk $*"; }
ryoku_wipe_signatures() { echo "wipe_signatures $*"; }
sgdisk()    { echo "sgdisk $*"; }
parted()    { echo "parted $*"; }
wipefs()    { echo "wipefs $*"; }
partprobe() { echo "partprobe $*"; }
udevadm()   { :; }
export -f udevadm
'

# run_whole <populated 0|1> <wipe-confirmed ''|1> [extra-env]: run
# ryoku_partition_whole in REAL mode (the guard is only narrated under dry-run)
# with the mocks applied. leaves the plan in $out and the exit code in $rc.
run_whole() {
  rc=0
  out="$(ROOT="$root" POP="$1" CONF="$2" EXTRA="${3:-}" MOCKS="$mocks" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    export RYOKU_DISK=/dev/sdz RYOKU_ESP_GIB=1
    [[ -n $CONF ]] && export RYOKU_WIPE_CONFIRMED=$CONF
    eval "$EXTRA"
    eval "$MOCKS"
    set -euo pipefail
    ryoku_partition_whole
  ' 2>&1)" || rc=$?
}

lineno() { grep -nF "$1" <<<"$out" | head -n1 | cut -d: -f1; }

# --- populated disk, no ack: refuse, before any destructive command -----------
run_whole 0 '' ''
[[ $rc -ne 0 ]] || fail "wiped a populated disk with no RYOKU_WIPE_CONFIRMED (rc=$rc)"
grep -qF 'refusing to wipe' <<<"$out" || fail "did not explain the wipe refusal"
grep -qF 'sgdisk --zap-all' <<<"$out" && fail "ran the destructive zap despite refusing"
grep -qF 'wipefs' <<<"$out" && fail "ran wipefs despite refusing the wipe"

# --- populated disk WITH the ack: proceeds ------------------------------------
run_whole 0 1 ''
[[ $rc -eq 0 ]] || fail "refused a populated disk even with RYOKU_WIPE_CONFIRMED=1 (rc=$rc): $out"
grep -qF 'sgdisk --zap-all /dev/sdz' <<<"$out" || fail "confirmed wipe did not zap the table"

# --- blank disk, no ack: proceeds without the token (fresh install) -----------
run_whole 1 '' ''
[[ $rc -eq 0 ]] || fail "gated a blank disk on the wipe token (rc=$rc): $out"
grep -qF 'sgdisk --zap-all /dev/sdz' <<<"$out" || fail "blank disk did not get partitioned"

# --- confirmed plan: zap -> GPT -> ESP -> root -> wipefs both, strictly ordered
# assert on the confirmed run's plan above (still in $out from run_whole 1 '').
zap="$(lineno 'sgdisk --zap-all /dev/sdz')"
mklabel="$(lineno 'parted --script /dev/sdz mklabel gpt')"
esp_mkpart="$(lineno 'mkpart ESP fat32 1MiB 2GiB')"
root_mkpart="$(lineno 'mkpart root 2GiB 100%')"
wipe_esp="$(lineno 'wipefs --all /dev/sdz1')"
wipe_root="$(lineno 'wipefs --all /dev/sdz2')"

for step in zap mklabel esp_mkpart root_mkpart wipe_esp wipe_root; do
  [[ -n ${!step} ]] || fail "missing plan step: $step"
done
(( zap < mklabel )) || fail "GPT label written before the table was zapped"
(( mklabel < esp_mkpart )) || fail "ESP partition created before the GPT label"
(( esp_mkpart < root_mkpart )) || fail "root partition created before the ESP"
(( root_mkpart < wipe_esp )) || fail "wipefs ran before the partitions existed"
(( wipe_esp < wipe_root )) || fail "wipefs order is not ESP-then-root"

# wipefs hits exactly the two NEW partitions, never the whole disk.
n_wipe="$(grep -cF 'wipefs --all' <<<"$out")"
[[ $n_wipe -eq 2 ]] || fail "expected 2 partition wipes, got $n_wipe"
grep -qxF 'wipefs --all /dev/sdz' <<<"$out" && fail "wipefs hit the whole disk instead of the partitions"

# --- dry run: the guard is narrated, not enforced -----------------------------
run_whole 0 '' 'RYOKU_DRYRUN=1'
[[ $rc -eq 0 ]] || fail "dry run aborted (rc=$rc): $out"
grep -qF 'would refuse to wipe' <<<"$out" || fail "dry run did not narrate the wipe guard"
grep -qF 'DRYRUN: sgdisk --zap-all' <<<"$out" || fail "dry run did not narrate the zap"

echo "install-partition-whole: all checks passed"
