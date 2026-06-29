#!/usr/bin/env bash
# fixture test for ryoku_rank_mirrors (installation/backend/lib/mirrors.sh): the
# pre-pacstrap mirror ranking that keeps a user far from the shipped mirrors from
# stalling pacstrap with "Operation too slow. Less than 1 bytes/sec" (which
# aborts the install at "failed to install packages to new root"). reflector,
# curl (geolocation), and timeout are mocked and the mirrorlist is a temp file
# (RYOKU_MIRRORLIST), so we assert the resulting list and the plan, never
# touching the system mirrorlist or the network.
# the mocks and the mirror placeholders ($repo/$arch) are single-quoted on
# purpose: they are shell snippets eval'd in a subshell, or literal mirrorlist
# syntax, and must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# the static list the ISO ships; every case seeds the temp mirrorlist with it.
shipped='# shipped
Server = https://fastly.example/$repo/os/$arch
Server = https://geo.example/$repo/os/$arch'

# run_rank <mock> [env-pre]: seed a temp mirrorlist with $shipped, run
# ryoku_rank_mirrors with the mock applied, leave the log in $out and the
# resulting list in $ranked. timeout is mocked to run its tail in-shell so the
# reflector *function* mock is reachable; curl defaults to reporting country BR.
# the mock (and env-pre) can redefine reflector/curl or set RYOKU_* per case.
run_rank() {
  local mock=$1 env_pre=${2:-} list
  list="$(mktemp)"
  printf '%s\n' "$shipped" >"$list"
  out="$(RYOKU_MIRRORLIST="$list" ROOT="$root" MOCK="$mock" ENVPRE="$env_pre" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/mirrors.sh"
    timeout() { shift; "$@"; }    # drop the duration, run the command in-shell
    curl() { printf "BR\n"; }     # default: geolocation reports country BR
    eval "$ENVPRE"
    eval "$MOCK"
    set -euo pipefail            # mirror the orchestrator: ranking must not abort
    ryoku_rank_mirrors
  ')"
  ranked="$(cat "$list")"
  rm -f "$list"
}

# a reflector that writes two "nearby" mirrors to its --save target (the last
# arg). $repo/$arch stay literal. one variant always succeeds; the other refuses
# a --country query, to force the worldwide fallback path.
writes='reflector() { printf "Server = https://nearby.example/\$repo/os/\$arch\nServer = https://fast.example/\$repo/os/\$arch\n" >"${!#}"; }'
writes_no_country='reflector() { for a in "$@"; do [[ $a == --country ]] && return 1; done; printf "Server = https://nearby.example/\$repo/os/\$arch\nServer = https://fast.example/\$repo/os/\$arch\n" >"${!#}"; }'

# --- country resolved + that country has mirrors: rank within the country -------
run_rank "$writes"
grep -qF 'Server = https://nearby.example/' <<<"$ranked" || fail "ranked mirror missing from the result"
grep -qF '# shipped fallbacks' <<<"$ranked" || fail "shipped fallback header missing"
grep -qF 'Server = https://fastly.example/' <<<"$ranked" || fail "shipped fallback mirror was dropped"
[[ $(grep -n 'nearby.example' <<<"$ranked" | cut -d: -f1) -lt \
   $(grep -n 'fastly.example' <<<"$ranked" | cut -d: -f1) ]] || fail "ranked mirror is not preferred over the fallback"
grep -qF 'within BR' <<<"$out" || fail "did not rank within the resolved country"
grep -qF 'using 2 ranked mirror(s)' <<<"$out" || fail "did not report the ranked mirror count"

# --- country resolved but has no mirrors: fall back to the worldwide ranking ----
run_rank "$writes_no_country"
grep -qF 'Server = https://nearby.example/' <<<"$ranked" || fail "worldwide fallback produced no ranked mirror"
grep -qF 'worldwide' <<<"$out" || fail "did not announce the worldwide fallback"
grep -qF 'BR had none' <<<"$out" || fail "did not note the country had no mirrors"

# --- geolocation fails: skip straight to the worldwide ranking ------------------
run_rank "$writes"$'\ncurl() { return 1; }'
grep -qF 'Server = https://nearby.example/' <<<"$ranked" || fail "worldwide ranking produced no mirror without geolocation"
grep -qF 'worldwide' <<<"$out" || fail "did not rank worldwide without geolocation"
grep -qF 'had none' <<<"$out" && fail "claimed a country had none when geolocation failed"

# --- geolocation returns a non-code (garbage/HTML): ignored, ranks worldwide ----
run_rank "$writes"$'\ncurl() { printf "<html>nope</html>\\n"; }'
grep -qF 'Server = https://nearby.example/' <<<"$ranked" || fail "garbage geolocation broke the worldwide ranking"
grep -qF 'worldwide' <<<"$out" || fail "did not fall back to worldwide on a non-code country"
grep -qF 'had none' <<<"$out" && fail "treated garbage geolocation as a real country"

# --- reflector fails on both paths: shipped list is kept verbatim ---------------
run_rank 'reflector() { return 1; }'
grep -qF 'nearby.example' <<<"$ranked" && fail "kept a ranked mirror after reflector failed"
grep -qF '# shipped fallbacks' <<<"$ranked" && fail "rewrote the list after reflector failed"
grep -qF 'Server = https://fastly.example/' <<<"$ranked" || fail "lost the shipped list after reflector failed"
grep -qF 'keeping the shipped mirrorlist' <<<"$out" || fail "did not announce keeping the shipped list on failure"

# --- offline install: never runs reflector, keeps the shipped list --------------
run_rank "$writes" 'RYOKU_ONLINE=0'
grep -qF 'nearby.example' <<<"$ranked" && fail "ranked mirrors on an offline install"
grep -qF 'offline install' <<<"$out" || fail "did not announce the offline skip"

# --- reflector not installed: keeps the shipped list ----------------------------
run_rank 'command() { [[ $1 == -v && $2 == reflector ]] && return 1; builtin command "$@"; }'
grep -qF 'Server = https://fastly.example/' <<<"$ranked" || fail "lost the shipped list when reflector is absent"
grep -qF 'reflector unavailable' <<<"$out" || fail "did not announce the missing reflector"

# --- dry run: narrates the plan, touches nothing --------------------------------
run_rank "$writes" 'RYOKU_DRYRUN=1'
grep -qF 'nearby.example' <<<"$ranked" && fail "dry run mutated the mirrorlist"
grep -qF 'would rank' <<<"$out" || fail "dry run did not narrate the plan"

echo "install-mirrors: all checks passed"
