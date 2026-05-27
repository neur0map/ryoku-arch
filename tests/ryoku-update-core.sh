#!/bin/bash
# Sandbox test for lib/ryoku-update-core.sh: channel resolution precedence,
# validation, branch mapping, and persistence. Runs in an isolated HOME so it
# never touches the real system. Each git command is timeout-guarded so a
# misbehaving call fails loudly instead of hanging.

set -uo pipefail

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export RYOKU_STATE_PATH="$XDG_STATE_HOME/ryoku"
export RYOKU_CONFIG_PATH="$HOME/.config/ryoku"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$RYOKU_STATE_PATH"

# Fake ryoku repo with main + unstable-dev branches.
export RYOKU_PATH="$SANDBOX/repo"
g() { timeout 20 git -C "$RYOKU_PATH" "$@"; }
timeout 20 git init -q -b main "$RYOKU_PATH"
g config user.email t@example.invalid
g config user.name tester
printf 'v0\n' >"$RYOKU_PATH/version"
g add -A
g commit -qm init
g branch unstable-dev

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/runtime-env.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/ryoku-update-core.sh"

PASS=0
FAIL=0
eq() { # name actual expected
  if [[ "$2" == "$3" ]]; then
    printf '  ok   %s (%s)\n' "$1" "$2"
    ((PASS++))
  else
    printf '  FAIL %s: expected [%s] got [%s]\n' "$1" "$3" "$2"
    ((FAIL++))
  fi
}
true_test() { # name command...
  local name="$1"
  shift
  if "$@"; then
    printf '  ok   %s\n' "$name"
    ((PASS++))
  else
    printf '  FAIL %s (expected success)\n' "$name"
    ((FAIL++))
  fi
}
false_test() { # name command...
  local name="$1"
  shift
  if "$@"; then
    printf '  FAIL %s (expected failure)\n' "$name"
    ((FAIL++))
  else
    printf '  ok   %s\n' "$name"
    ((PASS++))
  fi
}

clear_sources() {
  unset RYOKU_UPDATE_BRANCH
  rm -f "$RYOKU_STATE_PATH/channel"
  rm -f "$XDG_CONFIG_HOME/ryoku-shell/config.json" "$XDG_CONFIG_HOME/illogical-impulse/config.json"
  g switch -q main
}

echo "== validation / mapping =="
true_test "is_valid main" ryoku_channel_is_valid main
true_test "is_valid unstable-dev" ryoku_channel_is_valid unstable-dev
false_test "is_valid garbage" ryoku_channel_is_valid garbage
eq "normalize garbage->main" "$(ryoku_channel_normalize garbage)" "main"
eq "normalize unstable-dev" "$(ryoku_channel_normalize unstable-dev)" "unstable-dev"
eq "branch(unstable-dev)" "$(ryoku_channel_to_branch unstable-dev)" "unstable-dev"
eq "branch(main)" "$(ryoku_channel_to_branch main)" "main"
eq "branch(garbage)->main" "$(ryoku_channel_to_branch garbage)" "main"

echo "== resolution precedence =="
clear_sources
eq "default (clean)" "$(ryoku_resolve_channel)" "main"

clear_sources
g switch -q unstable-dev
eq "from git HEAD" "$(ryoku_resolve_channel)" "unstable-dev"

clear_sources
printf 'unstable-dev\n' >"$RYOKU_STATE_PATH/channel"
eq "from state file" "$(ryoku_resolve_channel)" "unstable-dev"

if command -v jq >/dev/null 2>&1; then
  clear_sources
  printf 'unstable-dev\n' >"$RYOKU_STATE_PATH/channel"
  mkdir -p "$XDG_CONFIG_HOME/ryoku-shell"
  printf '{"shellUpdates":{"channel":"main"}}\n' >"$XDG_CONFIG_HOME/ryoku-shell/config.json"
  eq "config beats state" "$(ryoku_resolve_channel)" "main"
else
  echo "  skip config-precedence (jq missing)"
fi

clear_sources
eq "explicit override" "$(ryoku_resolve_channel unstable-dev)" "unstable-dev"
clear_sources
eq "env override" "$(RYOKU_UPDATE_BRANCH=unstable-dev ryoku_resolve_channel)" "unstable-dev"
clear_sources
eq "invalid override -> main" "$(ryoku_resolve_channel bogus 2>/dev/null)" "main"

echo "== persistence =="
clear_sources
ryoku_persist_channel unstable-dev
eq "state written" "$(cat "$RYOKU_STATE_PATH/channel")" "unstable-dev"
if command -v jq >/dev/null 2>&1; then
  eq "shell config written" "$(jq -r '.shellUpdates.channel' "$(ryoku_shell_config_file)")" "unstable-dev"
fi

echo "== safe.directory self-heal =="
ryoku_git_mark_safe_directory
true_test "RYOKU_PATH marked safe" bash -c 'git config --global --get-all safe.directory | grep -qxF "$RYOKU_PATH"'

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
