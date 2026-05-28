#!/bin/bash
# Sandbox test for bin/ryoku-update's argument routing: that -sc validates the
# channel, that a switch runs the same pipeline with RYOKU_UPDATE_BRANCH set and
# the pacman channel refreshed, that a normal update does neither, and that a
# switch without -y is gated by a confirmation. Every system-touching command is
# stubbed, the re-exec wrappers are skipped, and runs are timeout-guarded.

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export RYOKU_STATE_PATH="$XDG_STATE_HOME/ryoku"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$RYOKU_STATE_PATH"

# RYOKU_PATH with no bin/ryoku-update so continue_with_refreshed_updater takes
# the in-process run_post_git_update path instead of re-exec.
export RYOKU_PATH="$SANDBOX/repo"
mkdir -p "$RYOKU_PATH"

# Skip the sudo gate, idle-inhibit re-exec, PTY re-exec, and battery guard.
export RYOKU_UPDATE_LOGGED=1 RYOKU_UPDATE_INHIBITED=1 RYOKU_UPDATE_POWER_CHECKED=1

LOG="$SANDBOX/calls.log"
STUB="$SANDBOX/stub"
mkdir -p "$STUB"
mkstub() { printf '#!/bin/bash\n%s\n' "$2" >"$STUB/$1"; chmod +x "$STUB/$1"; }
mkstub ryoku-update-git    'echo "git:${RYOKU_UPDATE_BRANCH:-none}" >>"'"$LOG"'"; exit 0'
mkstub ryoku-update-perform 'echo "perform" >>"'"$LOG"'"; exit 0'
mkstub ryoku-snapshot       'exit 0'
mkstub ryoku-refresh-pacman 'echo "pacman:$1" >>"'"$LOG"'"; exit 0'
mkstub ryoku-update-confirm 'exit ${RYOKU_TEST_CONFIRM_RC:-0}'
mkstub ryoku-update-time    'exit 0'
# ryoku-tui replaces gum: confirm exits non-zero to simulate "decline", zero to
# simulate "accept". Other subcommands (style, etc.) are no-ops.
mkstub ryoku-tui            'case "$1" in confirm) exit ${RYOKU_TEST_TUI_CONFIRM_RC:-0};; *) exit 0;; esac'
export PATH="$STUB:$PATH"

run() { # args...  -> sets RC, resets log
  : >"$LOG"
  timeout 60 bash "$REPO_ROOT/bin/ryoku-update" "$@" >"$SANDBOX/out.log" 2>&1
  RC=$?
}

PASS=0
FAIL=0
ok() { printf '  ok   %s\n' "$1"; PASS=$((PASS + 1)); }
no() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }
eq() { if [[ "$2" == "$3" ]]; then ok "$1 ($2)"; else printf '  FAIL %s: expected [%s] got [%s]\n' "$1" "$3" "$2"; FAIL=$((FAIL + 1)); fi; }
has() { if grep -qx "$2" "$LOG"; then ok "$1"; else no "$1 (missing: $2)"; fi; }
hasnt() { if grep -qx "$2" "$LOG"; then no "$1 (unexpected: $2)"; else ok "$1"; fi; }

echo "== validation =="
run -sc bogus
eq "invalid channel exit 1" "$RC" "1"
grep -q "unknown channel" "$SANDBOX/out.log" && ok "invalid channel message" || no "invalid channel message"
run -sc
eq "missing channel value exit 1" "$RC" "1"
grep -q "requires a channel" "$SANDBOX/out.log" && ok "missing-value message" || no "missing-value message"

echo "== channel switch (-sc unstable-dev -y) =="
run -sc unstable-dev -y
eq "exit 0" "$RC" "0"
has "refresh-pacman called for channel" "pacman:unstable-dev"
has "git ran with RYOKU_UPDATE_BRANCH=unstable-dev" "git:unstable-dev"
has "perform ran" "perform"

echo "== normal update (-y, no switch) =="
run -y
eq "exit 0" "$RC" "0"
has "git ran without a forced branch" "git:none"
has "perform ran" "perform"
hasnt "no pacman channel refresh on normal update" "pacman:unstable-dev"

echo "== switch without -y is gated (decline -> cancelled, no git) =="
RYOKU_TEST_TUI_CONFIRM_RC=1 run -sc unstable-dev    # ryoku-tui confirm declines
eq "exit 0 (clean cancel)" "$RC" "0"
grep -q "cancelled" "$SANDBOX/out.log" && ok "prints cancelled" || no "prints cancelled"
hasnt "git did not run on declined switch" "git:unstable-dev"

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
