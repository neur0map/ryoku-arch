#!/bin/bash
# Sandbox test for bin/ryoku-doctor's update-repair path: that it self-heals the
# repo's git safe.directory, always finishes with actionable guidance plus the
# MedEvac escape hatch, and never hangs or aborts. Runs in an isolated HOME with
# a throwaway repo/remote, plain (no-gum) mode, and stubbed hyprctl; the update
# path does not touch systemctl. Every run is timeout-guarded.

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export RYOKU_STATE_PATH="$XDG_STATE_HOME/ryoku"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$RYOKU_STATE_PATH"
export RYOKU_DOCTOR_PLAIN=1 RYOKU_DOCTOR_ASSUME_NO=1
unset HYPRLAND_INSTANCE_SIGNATURE RYOKU_UPDATE_BRANCH

STUB="$SANDBOX/stub"
mkdir -p "$STUB"
printf '#!/bin/bash\nexit 0\n' >"$STUB/hyprctl"
chmod +x "$STUB/hyprctl"
export PATH="$STUB:$PATH"

# Throwaway repo at the same tip as its remote, so the doctor's fast-forward
# offer declines and we reach the log-analysis paths under test.
timeout 20 git init -q -b main "$SANDBOX/work"
git -C "$SANDBOX/work" config user.email t@example.invalid
git -C "$SANDBOX/work" config user.name tester
printf 'v0\n' >"$SANDBOX/work/version"
git -C "$SANDBOX/work" add -A && git -C "$SANDBOX/work" commit -qm init
timeout 20 git clone -q --bare "$SANDBOX/work" "$SANDBOX/remote.git"
export RYOKU_PATH="$SANDBOX/repo"
timeout 20 git clone -q "$SANDBOX/remote.git" "$RYOKU_PATH"
export RYOKU_UPDATE_REMOTE_URL="file://$SANDBOX/remote.git"

LOG="$SANDBOX/update.log"
export RYOKU_UPDATE_LOG="$LOG"

PASS=0
FAIL=0
ok() { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
no() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }
run_doctor() {
  timeout 90 bash "$REPO_ROOT/bin/ryoku-doctor" update >"$SANDBOX/out.log" 2>&1
  RC=$?
}
out_has() { grep -q "$1" "$SANDBOX/out.log" && ok "$2" || no "$2 (missing: $1)"; }

echo "== sudo-stall log: clear guidance, completes, no hang =="
printf '[sudo] password for tester: \nsudo: a terminal is required to read the password\n' >"$LOG"
run_doctor
[[ $RC -ne 124 ]] && ok "did not time out (rc=$RC)" || no "timed out / hung"
out_has "sudo -v" "advises sudo -v"
out_has "ryoku-update -y" "advises retry"

echo "== unrecognized log: graceful dead-end with escape hatch =="
printf 'some totally unrecognized output line\nnothing actionable here\n' >"$LOG"
run_doctor
[[ $RC -ne 124 ]] && ok "did not time out (rc=$RC)" || no "timed out / hung"
out_has "No known auto-fix matched" "reports no match"
out_has "ryoku-call911now" "surfaces MedEvac escape hatch"

echo "== permission self-heal: repo marked git-safe =="
if git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$RYOKU_PATH"; then
  ok "RYOKU_PATH added to git safe.directory"
else
  no "RYOKU_PATH not marked safe"
fi

echo "== channel resolution delegates to the core lib =="
printf 'unstable-dev\n' >"$RYOKU_STATE_PATH/channel"
branch_seen="$(cd "$RYOKU_PATH" && timeout 20 bash -c '
  set -e
  source "'"$REPO_ROOT"'/lib/runtime-env.sh" >/dev/null 2>&1
  source "'"$REPO_ROOT"'/lib/ryoku-update-core.sh"
  RYOKU_PATH="'"$RYOKU_PATH"'" RYOKU_STATE_PATH="'"$RYOKU_STATE_PATH"'" ryoku_resolve_channel
')"
[[ $branch_seen == "unstable-dev" ]] && ok "lib resolves channel from state (unstable-dev)" || no "channel resolution wrong: $branch_seen"

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
