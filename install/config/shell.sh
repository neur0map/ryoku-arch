#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
SHELL_VENDOR="$RYOKU_PATH/shell"
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

# If the target is a legacy snowarch git checkout, replace it with the vendor.
if [[ -d $SHELL_PATH/.git ]]; then
  rm -rf "$SHELL_PATH"
fi

# Fresh deploy: copy the vendored tree into place.
if [[ ! -d $SHELL_PATH ]]; then
  mkdir -p "$(dirname "$SHELL_PATH")"
  cp -a "$SHELL_VENDOR/." "$SHELL_PATH/"
fi

backup_config_file=""
if [[ -f $USER_CONFIG ]]; then
  backup_config_file=$(mktemp)
  cp "$USER_CONFIG" "$backup_config_file"
fi

(
  cd "$SHELL_PATH"
  ./setup install -y --skip-deps --skip-sysupdate
)

if [[ -n $backup_config_file ]]; then
  restore_user_shell_config "$backup_config_file" "$USER_CONFIG"
  rm -f "$backup_config_file"
fi

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"

ryoku_shell_launcher="$HOME/.local/bin/ryoku-shell"
if [[ -x $ryoku_shell_launcher ]]; then
  "$ryoku_shell_launcher" service enable niri >/dev/null 2>&1 || true
elif ryoku-cmd-present ryoku-shell; then
  ryoku-shell service enable niri >/dev/null 2>&1 || true
fi

ryoku_shell_service="$HOME/.config/systemd/user/ryoku-shell.service"
ryoku_shell_wants_dir="$HOME/.config/systemd/user/niri.service.wants"
if [[ -f $ryoku_shell_service ]]; then
  mkdir -p "$ryoku_shell_wants_dir"
  ln -sf "$ryoku_shell_service" "$ryoku_shell_wants_dir/ryoku-shell.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
systemctl --user daemon-reload >/dev/null 2>&1 || true
