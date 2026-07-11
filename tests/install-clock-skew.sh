#!/usr/bin/env bash
# fixture test for ryoku_fix_clock_skew (installation/backend/lib/network.sh) and
# its wiring into ryoku_ensure_mirrors: a dead CMOS battery leaves the clock
# years off, TLS then rejects every cert (not yet valid / expired) and pacman
# signatures fail. the helper reads the server's own clock over an UNVERIFIED
# connection (curl -k) and, only when ours is off by more than a day, sets it
# from the Date header so the caller can re-probe. curl is mocked and `date -s`
# is intercepted to a no-op, so no real clock is touched and no network is hit.
# the mocks are single-quoted on purpose: they are shell snippets eval'd in a
# subshell and must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# a curl mock that serves $HDR as the Date header, plus a `date` mock that
# intercepts `date -s` (the clock set) to a printed no-op while letting the real
# date parse/format calls through. shared by the unit and the wiring harness.
mocks='
curl() {
  case "${1:-}" in
    -ksI|-fsSI) : ;;
  esac
  if [[ -n ${HDR+x} ]]; then
    printf "HTTP/1.1 200 OK\r\nServer: test\r\n"
    [[ -n $HDR ]] && printf "Date: %s\r\n" "$HDR"
    printf "\r\n"
  fi
}
date() { if [[ ${1:-} == -s ]]; then echo "CLOCK-SET: $2"; return 0; fi; command date "$@"; }
'

# run_skew <date-header>: call ryoku_fix_clock_skew with curl serving that Date
# header. leaves the log+stderr in $out and the exit code in $rc. rc=0 means it
# judged the skew > 24h and set the clock.
run_skew() {
  rc=0
  out="$(ROOT="$root" HDR="$1" MOCKS="$mocks" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/network.sh"
    eval "$MOCKS"
    set -euo pipefail
    ryoku_fix_clock_skew https://fake.invalid/probe
  ' 2>&1)" || rc=$?
}

# --- clock > 24h off: set it from the Date header, return 0 --------------------
run_skew "Sat, 01 Jan 2000 00:00:00 GMT"
[[ $rc -eq 0 ]] || fail "a clock years off must be judged skewed (rc=$rc): $out"
grep -qF 'clock skew' <<<"$out" || fail "did not announce the clock skew heal"
grep -qF 'CLOCK-SET: Sat, 01 Jan 2000 00:00:00 GMT' <<<"$out" || fail "did not set the clock from the server Date header"

# --- clock within 24h: no clock set, return non-zero --------------------------
run_skew "$(date -u '+%a, %d %b %Y %H:%M:%S GMT')"
[[ $rc -ne 0 ]] || fail "a clock already close must not be adjusted (rc=$rc)"
grep -qF 'CLOCK-SET' <<<"$out" && fail "set the clock when the skew was under a day"
grep -qF 'clock skew' <<<"$out" && fail "announced a heal when the skew was under a day"

# --- unparseable Date header: no-op, return non-zero --------------------------
run_skew "definitely not a date"
[[ $rc -ne 0 ]] || fail "an unparseable Date header must be a no-op (rc=$rc)"
grep -qF 'CLOCK-SET' <<<"$out" && fail "set the clock from an unparseable Date header"

# --- absent Date header: no-op, return non-zero -------------------------------
run_skew ""
[[ $rc -ne 0 ]] || fail "a missing Date header must be a no-op (rc=$rc)"
grep -qF 'CLOCK-SET' <<<"$out" && fail "set the clock with no Date header at all"

# --- wiring: a TLS/reach failure heals the clock, then the mirror re-probe wins -
# ryoku_ensure_mirrors' first reach probe fails; the skew heal sets the clock;
# the second reach probe (the re-probe) succeeds, so the install proceeds.
rc=0
out="$(ROOT="$root" HDR="Sat, 01 Jan 2000 00:00:00 GMT" MOCKS="$mocks" bash -c '
  source "$ROOT/installation/backend/lib/common.sh"
  source "$ROOT/installation/backend/lib/network.sh"
  export RYOKU_MIRROR_PROBE_URLS="https://fake.invalid/core.db"
  export RYOKU_ONLINE=1
  n=0
  curl() {
    case "${1:-}" in
      -fsSI) n=$((n+1)); (( n >= 2 )) && return 0 || return 1 ;;
      -ksI)  printf "HTTP/1.1 200 OK\r\nDate: %s\r\n\r\n" "$HDR" ;;
    esac
  }
  date() { if [[ ${1:-} == -s ]]; then echo "CLOCK-SET: $2"; return 0; fi; command date "$@"; }
  set -euo pipefail
  ryoku_ensure_mirrors
' 2>&1)" || rc=$?
[[ $rc -eq 0 ]] || fail "the mirror re-probe after the clock heal must succeed (rc=$rc): $out"
grep -qF 'clock skew' <<<"$out" || fail "wiring did not heal the clock on the reach failure"
grep -qF 'CLOCK-SET' <<<"$out" || fail "wiring did not set the clock before the re-probe"
grep -qF 'reachable' <<<"$out" || fail "the re-probe after the heal did not report the mirrors reachable"

echo "install-clock-skew: all checks passed"
