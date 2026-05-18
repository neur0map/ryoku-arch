#!/bin/bash
# Wipe Ryoku-touched shell state and re-bootstrap a pristine upstream
# install from the vendored Ryoku shell. See spec at
# local restore design notes.

set -euo pipefail
trap 'echo "Migration failed. Re-run with: bin/ryoku-migrate" >&2' ERR

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="$HOME/.local/share/ryoku-shell"
USER_CONFIG="$HOME/.config/ryoku-shell/config.json"
RYOKU_ICON="$HOME/.local/share/icons/hicolor/scalable/apps/ryoku.svg"
WANTS_DIR="$HOME/.config/systemd/user/niri.service.wants"
SERVICE_UNIT="$HOME/.config/systemd/user/ryoku-shell.service"

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
printf '\033[1;33mWiping Ryoku shell completely and reinstalling fresh upstream.\033[0m\n'
printf 'Desktop chrome (bar, sidebars, lock UI) will be unavailable for ~1-3 min.\n'
printf 'Existing windows persist (niri keeps running). Do NOT lock the screen.\n'
printf '\n'

# Phase 2: Pre-flight. If the shell is already absent, exit cleanly.
if [[ ! -x $SHELL_PATH/setup ]]; then
  echo "Ryoku shell setup script missing at $SHELL_PATH/setup; nothing to wipe."
  exit 0
fi

# Phase 3: Backup user config to a path outside the wipe scope.
ts=$(date +%s)
backup_dir="$RYOKU_STATE_PATH/ryoku-shell-restore-backup"
backup_config_file=""
mkdir -p "$backup_dir"
if [[ -f $USER_CONFIG ]]; then
  backup_config_file="$backup_dir/config.json.$ts"
  cp "$USER_CONFIG" "$backup_config_file"
  echo "Backed up user config to $backup_config_file"
fi

# Phase 4: Stop shell services so the unit files can be safely removed.
systemctl --user stop ryoku-shell.service ryoku-shell-super-overview.service 2>/dev/null || true

# Phase 5: Run the shell's own uninstall to remove every tracked file.
"$SHELL_PATH/setup" uninstall -y

# Phase 6: Wipe the source tree itself (uninstall does not remove its own repo).
rm -rf "$SHELL_PATH"

# Phase 7: Wipe Ryoku-only artifacts that the shell's manifest does not track.
rm -f "$RYOKU_ICON"

# Phase 8: Deploy fresh shell from the vendored tree in this repo.
SHELL_VENDOR="$RYOKU_PATH/shell"
if [[ ! -d $SHELL_VENDOR ]]; then
  echo "migration: missing vendored shell tree at $SHELL_VENDOR" >&2
  exit 1
fi
cp -a "$SHELL_VENDOR/." "$SHELL_PATH/"

# Phase 9: Run the shell's installer with non-interactive flags.
"$SHELL_PATH/setup" install -y --skip-deps --skip-sysupdate

# Phase 10: Merge the prior config back over the freshly generated defaults.
if [[ -n $backup_config_file ]]; then
  restore_user_shell_config "$backup_config_file" "$USER_CONFIG"
fi

# Phase 11: Re-apply the Ryoku overlay after the user config restore.
if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

# Phase 12: Re-create the niri.service.wants symlink so Ryoku shell auto-starts.
mkdir -p "$WANTS_DIR"
ln -sf "$SERVICE_UNIT" "$WANTS_DIR/ryoku-shell.service"

# Phase 13: Reload user units and start Ryoku shell.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user start ryoku-shell.service

echo
echo "Pristine Ryoku shell restore complete."
if [[ -n $backup_config_file && -f $backup_config_file ]]; then
  echo "Backup of prior config: $backup_config_file"
fi
