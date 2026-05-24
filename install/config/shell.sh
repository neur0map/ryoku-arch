#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
SHELL_VENDOR="$RYOKU_PATH/shell"
SHELL_RUNTIME_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"

restore_user_shell_config() {
  local backup_config_file="$1"
  local config_file="$2"
  local temp_file

  [[ -f $backup_config_file ]] || return 0
  mkdir -p "$(dirname "$config_file")"

  if [[ -f $config_file ]] && ryoku-cmd-present jq; then
    temp_file=$(mktemp)
    jq -s '.[0] * .[1]' "$config_file" "$backup_config_file" >"$temp_file"
    mv "$temp_file" "$config_file"
  else
    cp "$backup_config_file" "$config_file"
  fi
}

if [[ ! -d $SHELL_VENDOR ]]; then
  echo "install/config/shell.sh: missing vendored shell tree at $SHELL_VENDOR" >&2
  exit 1
fi

# If the target is a legacy upstream git checkout, replace it with the vendor.
if [[ -d $SHELL_PATH/.git ]]; then
  rm -rf "$SHELL_PATH"
fi

# Sync the vendored tree into SHELL_PATH on every run so updates land.
# Previous behavior gated this on first-install only ([[ ! -d $SHELL_PATH ]]),
# so subsequent ryoku-updates never propagated new files (added or modified
# in the vendor by `git pull`) into SHELL_PATH or the runtime config dir.
# Result was a silent regression where users kept the prior shell payload
# even after their git checkout had advanced. Sync unconditionally now.
# rsync (preferred) supports --exclude so vendored-but-unwanted files
# (like AGENTS.md) stay out; fall back to cp -a if rsync is unavailable.
mkdir -p "$(dirname "$SHELL_PATH")"
if ryoku-cmd-present rsync; then
  # Drop dev-only artifacts (top-level docs, GitHub metadata, repo docs)
  # so SHELL_PATH stays a focused runtime payload, not a checkout copy.
  # Quickshell ignores these but they pollute the deployed tree.
  rsync -a --delete --delete-excluded \
    --exclude='AGENTS.md' \
    --exclude='README.md' \
    --exclude='CHANGELOG.md' \
    --exclude='CODE_OF_CONDUCT.md' \
    --exclude='CONTRIBUTING.md' \
    --exclude='SECURITY.md' \
    --exclude='ARCHITECTURE.md' \
    --exclude='.gitignore' \
    --exclude='.shellcheckrc' \
    --exclude='.github' \
    --exclude='docs' \
    "$SHELL_VENDOR/." "$SHELL_PATH/"
else
  cp -a "$SHELL_VENDOR/." "$SHELL_PATH/"
fi

backup_config_file=""
if [[ -f $USER_CONFIG ]]; then
  backup_config_file=$(mktemp)
  cp "$USER_CONFIG" "$backup_config_file"
fi

(
  cd "$SHELL_PATH"
  env \
    -u QS_CONFIG_NAME \
    -u QS_CONFIG_PATH \
    -u QS_MANIFEST \
    RYOKU_CORE_UPDATE_CHILD=1 \
    RYOKU_SHELL_RUNTIME_DIR="$SHELL_RUNTIME_DIR" \
    IS_UPDATE=true \
    ./setup install -y -q --skip-deps --skip-setups --skip-sysupdate
)

if [[ -n $backup_config_file ]]; then
  restore_user_shell_config "$backup_config_file" "$USER_CONFIG"
  rm -f "$backup_config_file"
fi

env RYOKU_SHELL_RUNTIME_PATH="$SHELL_RUNTIME_DIR" "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"

ryoku_shell_launcher="$HOME/.local/bin/ryoku-shell"
if [[ -x $ryoku_shell_launcher ]]; then
  env RYOKU_SHELL_RUNTIME_DIR="$SHELL_RUNTIME_DIR" "$ryoku_shell_launcher" service enable >/dev/null 2>&1 || true
elif ryoku-cmd-present ryoku-shell; then
  env RYOKU_SHELL_RUNTIME_DIR="$SHELL_RUNTIME_DIR" ryoku-shell service enable >/dev/null 2>&1 || true
fi

env RYOKU_SHELL_RUNTIME_PATH="$SHELL_RUNTIME_DIR" "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
systemctl --user daemon-reload >/dev/null 2>&1 || true
