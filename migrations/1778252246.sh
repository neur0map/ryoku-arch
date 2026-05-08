echo "Restore Ryoku shell UI defaults and Mod+S toolkit keybind"

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
DEV_SHELL="$RYOKU_PATH/shell"
PAYLOAD_MANIFEST="$DEV_SHELL/sdata/runtime-payload-dirs.txt"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"
niri_binds="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
default_niri_binds="$RYOKU_PATH/config/niri/config.d/70-binds.kdl"
ryoku_shell_launcher="$HOME/.local/bin/ryoku-shell"

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

refresh_shell_runtime_payload() {
  local backup_config_file=""
  local dir

  [[ -d $SHELL_PATH ]] || return 0
  [[ -d $DEV_SHELL ]] || return 0

  echo "Refreshing Ryoku shell runtime payload"
  if [[ -f $PAYLOAD_MANIFEST ]]; then
    while IFS= read -r dir; do
      [[ -n $dir ]] || continue
      [[ -d "$DEV_SHELL/$dir" ]] || continue
      mkdir -p "$SHELL_PATH/$dir"
      rsync -a --exclude='AGENTS.md' "$DEV_SHELL/$dir/" "$SHELL_PATH/$dir/"
    done <"$PAYLOAD_MANIFEST"
  else
    for dir in modules services scripts assets translations defaults dots sdata; do
      [[ -d "$DEV_SHELL/$dir" ]] || continue
      mkdir -p "$SHELL_PATH/$dir"
      rsync -a --exclude='AGENTS.md' "$DEV_SHELL/$dir/" "$SHELL_PATH/$dir/"
    done
  fi

  if [[ -x $SHELL_PATH/setup ]]; then
    if [[ -f $USER_CONFIG ]]; then
      backup_config_file=$(mktemp)
      cp "$USER_CONFIG" "$backup_config_file"
    fi

    ( cd "$SHELL_PATH" && ./setup install -y --skip-deps --skip-sysupdate )

    if [[ -n $backup_config_file ]]; then
      restore_user_shell_config "$backup_config_file" "$USER_CONFIG"
      rm -f "$backup_config_file"
    fi
  fi
}

if [[ ! -x $ryoku_shell_launcher ]]; then
  ryoku_shell_launcher="ryoku-shell"
fi

refresh_shell_runtime_payload

if [[ -f $niri_binds ]]; then
  if ! grep -qE 'Mod\+S[[:space:]]*\{[[:space:]]*spawn .*"toolsMode"[[:space:]]+"toggle"' "$niri_binds"; then
    temp_file=$(mktemp)
    awk -v launcher="$ryoku_shell_launcher" '
      /Mod\+Shift\+S[[:space:]]*\{/ && ! inserted {
        print "    // Toolkit pill (Mod+S)."
        printf "    Mod+S { spawn \"%s\" \"toolsMode\" \"toggle\"; }\n\n", launcher
        inserted = 1
      }
      { print }
      END {
        if (!inserted) {
          print ""
          print "    // Toolkit pill (Mod+S)."
          printf "    Mod+S { spawn \"%s\" \"toolsMode\" \"toggle\"; }\n", launcher
        }
      }
    ' "$niri_binds" >"$temp_file"
    mv "$temp_file" "$niri_binds"
  fi
elif [[ -f $default_niri_binds ]]; then
  mkdir -p "$(dirname "$niri_binds")"
  cp "$default_niri_binds" "$niri_binds"
fi

if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

niri msg action load-config-file >/dev/null 2>&1 || true
systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
