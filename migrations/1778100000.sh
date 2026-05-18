#!/bin/bash
# Migrate from iNiR shell paths to Ryoku-shell paths. Uninstall the source
# shell via its own setup uninstall -y (which knows every tracked path via
# installed_listfile) and then install fresh from the vendored
# shell/ tree.

set -euo pipefail
trap 'echo "Migration failed. Re-run with: bin/ryoku-migrate" >&2' ERR

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

SOURCE_SHELL_NAME="i""nir"
SOURCE_SHELL_PATH="$HOME/.local/share/${SOURCE_SHELL_NAME}"
SOURCE_USER_CONFIG="$HOME/.config/${SOURCE_SHELL_NAME}/config.json"
RYOKU_USER_CONFIG="$HOME/.config/ryoku-shell/config.json"

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

  echo "Restored user shell config from $backup_config_file"
}

# Phase 1: Banner
printf '\n'
printf '\033[1;33mMigrating shell to Ryoku-shell.\033[0m\n'
printf 'Desktop chrome (bar, sidebars, lock UI) will be unavailable for ~1-3 min.\n'
printf 'Existing windows persist (niri keeps running). Do NOT lock the screen.\n'
printf '\n'

# Phase 2: Pre-flight. Skip cleanly on systems with no source shell installed.
if [[ ! -x $SOURCE_SHELL_PATH/setup ]]; then
  echo "Source shell setup script missing at $SOURCE_SHELL_PATH/setup; nothing to migrate."
  exit 0
fi

# Phase 3: Backup user config to a path outside the wipe scope.
ts=$(date +%s)
backup_dir="$RYOKU_STATE_PATH/${SOURCE_SHELL_NAME}-to-ryoku-shell-backup"
backup_config_file=""
mkdir -p "$backup_dir"
if [[ -f $SOURCE_USER_CONFIG ]]; then
  backup_config_file="$backup_dir/config.json.$ts"
  cp "$SOURCE_USER_CONFIG" "$backup_config_file"
  echo "Backed up source shell user config to $backup_config_file"
fi

# Phase 4: Stop source shell services so the unit files can be safely removed.
systemctl --user stop "${SOURCE_SHELL_NAME}.service" "${SOURCE_SHELL_NAME}-super-overview.service" 2>/dev/null || true

# Phase 5: Run the source shell uninstall to remove every tracked file.
"$SOURCE_SHELL_PATH/setup" uninstall -y

# Phase 6: Wipe the source shell tree (uninstall does not remove its own repo).
rm -rf "$SOURCE_SHELL_PATH"

# Phase 7: Run the new shell install pipeline. Deploys to ryoku-shell paths.
"$RYOKU_PATH/install/config/shell.sh"

# Phase 8: Merge the prior shell config back over the freshly generated defaults.
if [[ -n $backup_config_file ]]; then
  restore_user_shell_config "$backup_config_file" "$RYOKU_USER_CONFIG"
fi

# Phase 9: Re-apply the Ryoku overlay after the user config restore.
if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

# Phase 10: Re-link the niri.service.wants symlink to the new unit.
WANTS_DIR="$HOME/.config/systemd/user/niri.service.wants"
SERVICE_UNIT="$HOME/.config/systemd/user/ryoku-shell.service"
mkdir -p "$WANTS_DIR"
ln -sf "$SERVICE_UNIT" "$WANTS_DIR/ryoku-shell.service"

# Remove the old niri-wants symlink if it still exists.
rm -f "$WANTS_DIR/${SOURCE_SHELL_NAME}.service"

# Phase 11: Reload user units and start ryoku-shell.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user start ryoku-shell.service

echo
echo "Migration to Ryoku-shell complete."
if [[ -n $backup_config_file && -f $backup_config_file ]]; then
  echo "Backup of prior shell config: $backup_config_file"
fi
