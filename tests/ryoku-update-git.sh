#!/bin/bash
# End-to-end sandbox test for bin/ryoku-update-git: the git engine that powers
# both normal updates and channel switching. Uses throwaway local repos (a bare
# "remote" + a working clone), an isolated HOME, and stubs for ryoku-update-time
# and hyprctl so it can never touch the real clock, compositor, or system.
# Every updater run is timeout-guarded: a hang fails the test instead of stalling.

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export RYOKU_STATE_PATH="$XDG_STATE_HOME/ryoku"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$RYOKU_STATE_PATH"
unset HYPRLAND_INSTANCE_SIGNATURE RYOKU_UPDATE_BRANCH RYOKU_SHELL_CONFIG_DIR

# Stubs so the engine cannot poke the real system.
STUB="$SANDBOX/stub"
mkdir -p "$STUB"
printf '#!/bin/bash\nexit 0\n' >"$STUB/ryoku-update-time"
printf '#!/bin/bash\nexit 0\n' >"$STUB/hyprctl"
chmod +x "$STUB/ryoku-update-time" "$STUB/hyprctl"
export PATH="$STUB:$PATH"

gw() { timeout 20 git -C "$SANDBOX/work" "$@"; }   # the upstream "source" repo
gc() { timeout 20 git -C "$RYOKU_PATH" "$@"; }     # the installed clone

# Build upstream: main and unstable-dev with distinct history.
timeout 20 git init -q -b main "$SANDBOX/work"
gw config user.email t@example.invalid
gw config user.name tester
printf 'm1\n' >"$SANDBOX/work/file"
gw add -A && gw commit -qm m1
gw branch unstable-dev
gw -c core.hooksPath=/dev/null switch -q unstable-dev
printf 'u1\n' >"$SANDBOX/work/file"
gw commit -qam u1
gw switch -q main
printf 'm2\n' >"$SANDBOX/work/file"
gw commit -qam m2

# Bare "remote" + the installed clone (RYOKU_PATH), checked out on main.
timeout 20 git clone -q --bare "$SANDBOX/work" "$SANDBOX/remote.git"
export RYOKU_PATH="$SANDBOX/repo"
timeout 20 git clone -q "$SANDBOX/remote.git" "$RYOKU_PATH"
gc config user.email t@example.invalid
gc config user.name tester
export RYOKU_UPDATE_REMOTE_URL="file://$SANDBOX/remote.git"

# Advance the remote so there is something to fast-forward to.
gw push -q "$SANDBOX/remote.git" main unstable-dev
printf 'm3\n' >"$SANDBOX/work/file"
gw commit -qam m3
gw push -q "$SANDBOX/remote.git" main
gw switch -q unstable-dev
printf 'u2\n' >"$SANDBOX/work/file"
gw commit -qam u2
gw push -q "$SANDBOX/remote.git" unstable-dev
gw switch -q main

PASS=0
FAIL=0
eq() {
  if [[ "$2" == "$3" ]]; then printf '  ok   %s (%s)\n' "$1" "$2"; ((PASS++))
  else printf '  FAIL %s: expected [%s] got [%s]\n' "$1" "$3" "$2"; ((FAIL++)); fi
}
run_update() { # extra env passed as KEY=VAL ...
  timeout 90 env "$@" bash "$REPO_ROOT/bin/ryoku-update-git" >"$SANDBOX/out.log" 2>&1
  return $?
}

echo "== normal update on main (fast-forward) =="
run_update; rc=$?
eq "exit 0" "$rc" "0"
eq "branch=main" "$(gc rev-parse --abbrev-ref HEAD)" "main"
eq "content=m3 (ff'd)" "$(cat "$RYOKU_PATH/file")" "m3"
eq "state channel=main" "$(cat "$RYOKU_STATE_PATH/channel")" "main"

echo "== idempotent re-run (already up to date, no hang) =="
run_update; rc=$?
eq "exit 0" "$rc" "0"
eq "still m3" "$(cat "$RYOKU_PATH/file")" "m3"

echo "== channel switch to unstable-dev via RYOKU_UPDATE_BRANCH =="
run_update RYOKU_UPDATE_BRANCH=unstable-dev; rc=$?
eq "exit 0" "$rc" "0"
eq "branch=unstable-dev" "$(gc rev-parse --abbrev-ref HEAD)" "unstable-dev"
eq "content=u2" "$(cat "$RYOKU_PATH/file")" "u2"
eq "state channel=unstable-dev" "$(cat "$RYOKU_STATE_PATH/channel")" "unstable-dev"
if command -v jq >/dev/null 2>&1; then
  eq "shell config channel" "$(jq -r '.shellUpdates.channel' "$XDG_CONFIG_HOME/ryoku-shell/config.json" 2>/dev/null)" "unstable-dev"
fi

echo "== channel switch back to main =="
run_update RYOKU_UPDATE_BRANCH=main; rc=$?
eq "exit 0" "$rc" "0"
eq "branch=main" "$(gc rev-parse --abbrev-ref HEAD)" "main"
eq "content=m3" "$(cat "$RYOKU_PATH/file")" "m3"

echo "== untracked local file preserved, then ff brings remote version (no loss, no hang) =="
# remote adds a tracked file; local has a colliding untracked file. The engine
# stashes the untracked content, fast-forwards, and keeps the local copy in the
# stash when it conflicts with the now-tracked file.
gw switch -q main
printf 'remote-version\n' >"$SANDBOX/work/collide"
gw add -A && gw commit -qam add-collide
gw push -q "$SANDBOX/remote.git" main
printf 'local-untracked\n' >"$RYOKU_PATH/collide"
run_update; rc=$?
eq "exit 0" "$rc" "0"
eq "collide now remote-version" "$(cat "$RYOKU_PATH/collide")" "remote-version"
if (( $(gc stash list | wc -l) >= 1 )); then printf '  ok   local content preserved in stash\n'; ((PASS++)); else printf '  FAIL local content not preserved\n'; ((FAIL++)); fi

echo "== ff-only refusal on genuine divergence (clean error, no hang) =="
gc commit --allow-empty -qm "local divergent commit"        # local main gains a unique commit
printf 'm4\n' >"$SANDBOX/work/file"                          # remote main gains a different commit
gw commit -qam m4
gw push -q "$SANDBOX/remote.git" main
run_update; rc=$?
if (( rc != 0 )); then printf '  ok   non-zero exit on divergence (%d)\n' "$rc"; ((PASS++)); else printf '  FAIL expected non-zero on divergence\n'; ((FAIL++)); fi
grep -q "could not fast-forward" "$SANDBOX/out.log" && { printf '  ok   clear ff-only message\n'; ((PASS++)); } || { printf '  FAIL missing ff-only message\n'; ((FAIL++)); }

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
