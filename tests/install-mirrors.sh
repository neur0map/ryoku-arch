#!/usr/bin/env bash
# fixture test for D3: the bounded four-tier mirror resilience in
# installation/backend/lib/mirrors.sh (reflector -> mirror-status API -> shipped
# list, emergency mirrors always appended, install-time pacman.conf tuned) and
# the --needed retry across tiers in lib/pacstrap.sh. reflector, curl, and
# pacstrap are stubs and the mirrorlist + pacman.conf are temp files, so nothing
# here touches the system config or the network.
# the mocks and the $repo/$arch placeholders are single-quoted on purpose: they
# are shell snippets eval'd in a subshell, or literal mirrorlist syntax, and
# must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

# the static list the ISO ships; every ranking case seeds the temp list with it.
shipped='# shipped
Server = https://shippedA.example/$repo/os/$arch
Server = https://shippedB.example/$repo/os/$arch'

# a realistic mirror-status payload for the tier-2 curl stub: two https mirrors
# fully synced (one low score = better, one high), one http (must be dropped),
# one https but only half-synced (must be dropped).
status_json='{"urls":[
  {"url":"https://t2low.example/archlinux/","protocol":"https","active":true,"completion_pct":1.0,"score":0.9},
  {"url":"https://t2high.example/archlinux/","protocol":"https","active":true,"completion_pct":1.0,"score":3.2},
  {"url":"http://insecure.example/archlinux/","protocol":"http","active":true,"completion_pct":1.0,"score":0.1},
  {"url":"https://stale.example/archlinux/","protocol":"https","active":true,"completion_pct":0.5,"score":0.2}
]}'

# a reflector that writes two mirrors to its --save target (last arg); and one
# that mimics `timeout` killing a hung probe (exit 124).
reflector_ok='reflector() { printf "Server = https://t1a.example/\$repo/os/\$arch\nServer = https://t1b.example/\$repo/os/\$arch\n" >"${!#}"; }'
reflector_timeout='reflector() { return 124; }'

# run_rank <mock> [env-pre]: seed a temp mirrorlist ($shipped) + a stock-ish
# pacman.conf, run ryoku_rank_mirrors with the mock applied. resulting list in
# $ranked, log in $out, tuned pacman.conf in $conf_out. timeout runs its tail
# in-shell so the reflector *function* mock is reachable; curl defaults to a
# succeeding status API.
run_rank() {
  local mock=$1 env_pre=${2:-} list conf
  list="$(mktemp)"; conf="$(mktemp)"
  printf '%s\n' "$shipped" >"$list"
  printf '[options]\n#ParallelDownloads = 5\nArchitecture = auto\n' >"$conf"
  out="$(RYOKU_MIRRORLIST="$list" RYOKU_PACMAN_CONF="$conf" ROOT="$root" \
        MOCK="$mock" ENVPRE="$env_pre" STATUS_JSON="$status_json" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/mirrors.sh"
    timeout() { shift; "$@"; }              # drop the duration, run in-shell
    curl() { printf "%s" "$STATUS_JSON"; }  # default: the status API succeeds
    eval "$ENVPRE"
    eval "$MOCK"
    set -euo pipefail                       # ranking must never abort the install
    ryoku_rank_mirrors
  ')"
  ranked="$(cat "$list")"; conf_out="$(cat "$conf")"
  rm -f "$list" "$conf"
}

# the emergency mirrors (tier 4) must be present in every generated list.
assert_emergency() {
  grep -qF 'geo.mirror.pkgbuild.com' <<<"$1" || fail "$2: geo emergency mirror missing"
  grep -qF 'fastly.mirror.pkgbuild.com' <<<"$1" || fail "$2: fastly emergency mirror missing"
  grep -qF 'mirrors.kernel.org' <<<"$1" || fail "$2: kernel.org emergency mirror missing"
  [[ $(grep -c 'geo.mirror.pkgbuild.com' <<<"$1") -eq 1 ]] || fail "$2: emergency block was stacked twice"
}

# --- tier 1: reflector succeeds, ranks by rate, emergency trails --------------
run_rank "$reflector_ok"
grep -qF 't1a.example' <<<"$ranked" || fail "tier 1 reflector mirror missing from the result"
grep -qF 'tier 1' <<<"$out" || fail "did not announce tier 1"
assert_emergency "$ranked" "tier 1"
[[ $(grep -n 't1a.example' <<<"$ranked" | head -1 | cut -d: -f1) -lt \
   $(grep -n 'geo.mirror.pkgbuild.com' <<<"$ranked" | head -1 | cut -d: -f1) ]] \
   || fail "emergency mirrors are not trailing the ranked mirrors"

# --- pacman.conf tuning: ParallelDownloads uncommented + DisableDownloadTimeout
grep -qE '^ParallelDownloads = 5' <<<"$conf_out" || fail "ParallelDownloads not set to 5"
grep -qF 'DisableDownloadTimeout' <<<"$conf_out" || fail "DisableDownloadTimeout not set"
grep -qE '^[[:space:]]*#[[:space:]]*ParallelDownloads' <<<"$conf_out" && fail "left the commented ParallelDownloads in place"

# --- tier 2: reflector times out -> the mirror-status API is used -------------
run_rank "$reflector_timeout"
grep -qF 't2low.example' <<<"$ranked" || fail "tier 2 status API not used after a reflector timeout"
grep -qF 'tier 2' <<<"$out" || fail "did not announce tier 2"
[[ $(grep -n 't2low.example' <<<"$ranked" | head -1 | cut -d: -f1) -lt \
   $(grep -n 't2high.example' <<<"$ranked" | head -1 | cut -d: -f1) ]] \
   || fail "status API mirrors are not sorted by score"
grep -qF 'insecure.example' <<<"$ranked" && fail "tier 2 kept a non-https mirror"
grep -qF 'stale.example' <<<"$ranked" && fail "tier 2 kept an unsynced mirror"
assert_emergency "$ranked" "tier 2"

# --- tier 3: reflector times out AND the status API fails -> shipped list kept -
run_rank "$reflector_timeout"$'\ncurl() { return 1; }'
grep -qF 'shippedA.example' <<<"$ranked" || fail "tier 3 lost the shipped list"
grep -qF 't2low.example' <<<"$ranked" && fail "tier 3 somehow used the status API"
grep -qF 'tier 3' <<<"$out" || fail "did not announce tier 3"
assert_emergency "$ranked" "tier 3"

# --- offline: never ranks, keeps the shipped list, still appends emergency ----
run_rank "$reflector_ok" 'RYOKU_ONLINE=0'
grep -qF 'shippedA.example' <<<"$ranked" || fail "offline dropped the shipped list"
grep -qF 't1a.example' <<<"$ranked" && fail "offline ran reflector"
grep -qF 'offline install' <<<"$out" || fail "did not announce the offline skip"
assert_emergency "$ranked" "offline"

# --- dry run: narrates the plan, mutates nothing ------------------------------
run_rank "$reflector_ok" 'RYOKU_DRYRUN=1'
grep -qF 'geo.mirror.pkgbuild.com' <<<"$ranked" && fail "dry run mutated the mirrorlist"
grep -qF 'would' <<<"$out" || fail "dry run did not narrate the plan"
grep -qE '^[[:space:]]*#[[:space:]]*ParallelDownloads' <<<"$conf_out" || fail "dry run tuned pacman.conf"

# ============================================================================
# pacstrap retry (installation/backend/lib/pacstrap.sh)
# ============================================================================

# run_pacstrap <pacstrap-stub>: source pacstrap + mirrors + common, neutralize
# the cache-clear rm, let the tier-2 fallback (curl) succeed, and run
# ryoku_pacstrap_install with two fake packages. combined output in $pout, exit
# in $prc, one line per pacstrap invocation in $calls.
run_pacstrap() {
  local stub=$1 d
  d="$(mktemp -d)"
  printf 'Server = https://x/$repo/os/$arch\n' >"$d/mirrorlist"
  cp "$d/mirrorlist" "$d/shipped"
  set +e
  pout="$(CALLS="$d/calls" ROOT="$root" STUB="$stub" STATUS_JSON="$status_json" \
        MLIST="$d/mirrorlist" MSHIP="$d/shipped" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/mirrors.sh"
    source "$ROOT/installation/backend/lib/pacstrap.sh"
    run_sh() { :; }                         # neutralize the /mnt cache-clear
    curl() { printf "%s" "$STATUS_JSON"; }  # tier-2 fallback succeeds
    RYOKU_MIRRORLIST="$MLIST"
    RYOKU_MIRROR_SHIPPED="$MSHIP"
    RYOKU_MIRROR_TIER=1
    RYOKU_MIRROR_TIERS_TRIED="tier 1 (reflector)"
    eval "$STUB"
    set -euo pipefail
    ryoku_pacstrap_install fake-base fake-linux
  ' 2>&1)"
  prc=$?
  set -e
  calls="$(cat "$d/calls" 2>/dev/null || true)"
  rm -rf "$d"
}

# fails the first plain attempt, succeeds once --needed is passed.
stub_once='pacstrap() { echo "$*" >>"$CALLS"; for a in "$@"; do [[ $a == --needed ]] && return 0; done; return 1; }'
# always fails, emitting a pacman-style "failed retrieving file" line to stderr.
stub_fail=$'pacstrap() { echo "$*" >>"$CALLS"; echo "error: failed retrieving file \047core.db\047 from t2low.example : Operation too slow" >&2; return 1; }'

# --- one failure -> exactly one --needed retry, then success ------------------
run_pacstrap "$stub_once"
[[ $prc -eq 0 ]] || fail "pacstrap should have recovered on the --needed retry (rc=$prc)"
[[ $(grep -c . <<<"$calls") -eq 2 ]] || fail "expected exactly two pacstrap invocations, got: [$calls]"
[[ $(grep -c -- '--needed' <<<"$calls") -eq 1 ]] || fail "expected exactly one --needed retry, got: [$calls]"
grep -qF 'next mirror tier' <<<"$pout" || fail "did not announce the tier fallback before the retry"

# --- both attempts fail -> abort with an actionable, tier-listing message -----
run_pacstrap "$stub_fail"
[[ $prc -ne 0 ]] || fail "a double pacstrap failure must abort the install"
[[ $(grep -c -- '--needed' <<<"$calls") -eq 1 ]] || fail "double failure should still retry exactly once with --needed"
grep -qF 'tier 1 (reflector)' <<<"$pout" || fail "final message did not list tier 1"
grep -qF 'tier 2 (mirror-status API)' <<<"$pout" || fail "final message did not list the tier-2 fallback"
grep -qF 'Last mirror error' <<<"$pout" || fail "final message did not extract the failing mirror URL"
grep -qF 't2low.example' <<<"$pout" || fail "final message did not name the failing mirror"

echo "install-mirrors: all checks passed"
