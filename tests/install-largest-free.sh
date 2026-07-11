#!/usr/bin/env bash
# fixture test for ryoku_largest_free_mib (installation/backend/lib/disk.sh): the
# free-space sizer the 'alongside' strategy uses to decide whether a dedicated
# Ryoku ESP + root fits without touching Windows. it parses parted's
# machine-readable free listing in whole BYTES, floors to MiB, then subtracts a
# 1 MiB alignment margin. a float-truncating or margin-less parse would either
# reject a disk with room or place a partition that can't start on an aligned
# boundary, so we pin the exact arithmetic. parted is mocked with a fixture, so
# no disk is touched.
# the parted mock is single-quoted on purpose: it is a shell snippet eval'd in a
# subshell and must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# free_mib <parted-fixture>: run ryoku_largest_free_mib with parted mocked to
# emit the fixture. the disk arg is ignored by the mock. result on stdout.
free_mib() {
  ROOT="$root" FIXTURE="$1" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/disk.sh"
    parted() { printf "%s\n" "$FIXTURE"; }
    ryoku_largest_free_mib /dev/fake
  '
}

# --- multiple free rows: picks the largest, floors to MiB, minus 1 margin ------
# a 1 MiB sliver, a 30 GiB main region (32212254720B == 30*1024 MiB), plus two
# trailing NON-free rows (a partition and the disk header) that must be ignored.
# expected: int(32212254720/1048576) - 1 = 30720 - 1 = 30719.
multi='BYT;
/dev/fake:42949672960B:loopback:512:512:gpt:Loopback device:;
1:17408B:1048575B:1031168B:free;
1:1048576B:2097151B:1048576B:free;
2:2097152B:34014052351B:32212254720B:free;
1:34014052352B:34119909375B:105857024B:fat32::boot, esp;
3:34119909376B:42949672959B:8829763584B:ntfs::msftdata;'
out="$(free_mib "$multi")"
[[ $out == 30719 ]] || fail "largest free of a 30 GiB region must floor-minus-margin to 30719 MiB, got '$out'"

# a smaller main region must not be shadowed by the byte count of a non-free row:
# swap the 30 GiB free region for a 2 GiB one (2147483648B) and keep the 8.2 GiB
# ntfs partition. expected int(2147483648/1048576)-1 = 2048-1 = 2047.
smaller='BYT;
/dev/fake:42949672960B:loopback:512:512:gpt:Loopback device:;
2:2097152B:2149580799B:2147483648B:free;
3:2149580800B:42949672959B:40800092160B:ntfs::msftdata;'
out="$(free_mib "$smaller")"
[[ $out == 2047 ]] || fail "must size from the free row, not the larger ntfs partition row, got '$out'"

# --- no free rows at all: nothing fits, size is 0 ------------------------------
none='BYT;
/dev/fake:42949672960B:loopback:512:512:gpt:Loopback device:;
1:1048576B:42949672959B:42948624384B:ntfs::msftdata;'
out="$(free_mib "$none")"
[[ $out == 0 ]] || fail "a disk with no free region must size to 0, got '$out'"

# --- only sub-MiB slivers free: floors to 0 (nothing usable) -------------------
# 786432B (768 KiB) and 524288B (512 KiB): both floor to 0 MiB.
sub='BYT;
/dev/fake:42949672960B:loopback:512:512:gpt:Loopback device:;
1:17408B:803839B:786432B:free;
2:803840B:1328127B:524288B:free;'
out="$(free_mib "$sub")"
[[ $out == 0 ]] || fail "sub-MiB slivers must floor to 0, got '$out'"

echo "install-largest-free: all checks passed"
