#!/usr/bin/env bash
# fixture test for ryoku_free_regions (installation/backend/lib/disk.sh): the
# sfdisk-based free-space prober the 'alongside' strategy uses to place its boot
# + root partitions. it parses `sfdisk --json` (sectorsize, firstlba, lastlba,
# partitions), computes the gaps, aligns each region's start UP and end DOWN to
# 1 MiB in the disk's real sector size, and emits one `START END SIZE_MIB` line
# per gap >= 1024 MiB. we pin the exact sector arithmetic (512 and 4096 both) and
# the sub-floor exclusion. sfdisk is mocked with a JSON fixture, so no disk is
# touched; jq + awk run for real.
# the sfdisk mock is single-quoted on purpose: a shell snippet eval'd in a
# subshell that must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }
skip() { echo "install-largest-free: SKIP ($1)"; exit 0; }
command -v jq >/dev/null 2>&1 || skip "missing jq"

# regions <sfdisk-json>: run ryoku_free_regions with sfdisk mocked to emit the
# fixture JSON. the disk arg is ignored by the mock. lines on stdout.
regions() {
  ROOT="$root" FIXTURE="$1" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    sfdisk() { printf "%s\n" "$FIXTURE"; }
    ryoku_free_regions /dev/fake
  '
}

# --- single big region (512-byte sectors): ESP + 10 GiB NTFS, rest free --------
# p2 ends at 534528+20971520-1 = 21506047; the gap 21506048..lastlba aligns down
# to 83884031, size (83884031-21506048+1)/2048 = 30458 MiB. The ~1 MiB lead gap
# (34..2047) is below the 1024 MiB floor and excluded.
single='{"partitiontable":{"label":"gpt","sectorsize":512,"firstlba":34,"lastlba":83886046,"partitions":[
  {"start":2048,"size":532480},
  {"start":534528,"size":20971520}
]}}'
out="$(regions "$single")"
[[ "$out" == "21506048 83884031 30458" ]] || fail "single region wrong: got '$out'"

# --- sub-floor gap excluded, big gap reported (512) ----------------------------
# a 600 MiB gap sits between the ESP and NTFS (below the 1024 MiB floor -> gone);
# only the big trailing gap 22734848..83884031 (29858 MiB) is emitted.
frag='{"partitiontable":{"label":"gpt","sectorsize":512,"firstlba":34,"lastlba":83886046,"partitions":[
  {"start":2048,"size":532480},
  {"start":1763328,"size":20971520}
]}}'
out="$(regions "$frag")"
[[ "$out" == "22734848 83884031 29858" ]] || fail "fragmented region wrong (sub-floor gap must be excluded): got '$out'"

# --- fully allocated: no region at all -----------------------------------------
none='{"partitiontable":{"label":"gpt","sectorsize":512,"firstlba":34,"lastlba":83886046,"partitions":[
  {"start":2048,"size":532480},
  {"start":534528,"size":83351519}
]}}'
out="$(regions "$none")"
[[ -z "$out" ]] || fail "a fully allocated disk must emit no region, got '$out'"

# --- 4096-byte logical sectors: alignment math uses the real sector size -------
# spm = 256. p2 ends at 66816+5242880-1 = 5309695; gap 5309696..lastlba aligns
# down to 15728383, size (15728383-5309696+1)/256 = 40698 MiB.
fourk='{"partitiontable":{"label":"gpt","sectorsize":4096,"firstlba":6,"lastlba":15728634,"partitions":[
  {"start":256,"size":66560},
  {"start":66816,"size":5242880}
]}}'
out="$(regions "$fourk")"
[[ "$out" == "5309696 15728383 40698" ]] || fail "4096-byte sector region wrong: got '$out'"

echo "install-largest-free: all checks passed"
