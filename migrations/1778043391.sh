echo "Restore Ryoku shell appearance defaults"

MARKER="$RYOKU_STATE_PATH/independence-cutover.i""nir-appearance-defaults.done"
DEFAULT_CONFIG="$RYOKU_PATH/shell/defaults/config.json"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ -f $MARKER ]]; then
  exit 0
fi

mark_done() {
  mkdir -p "$RYOKU_STATE_PATH"
  touch "$MARKER"
}

restore_appearance() {
  local config_file="$1"
  local tmp

  [[ -f $config_file ]] || return 0

  tmp=$(mktemp)
  if jq -s '.[0].appearance = .[1].appearance | .[0]' "$config_file" "$DEFAULT_CONFIG" >"$tmp"; then
    mv "$tmp" "$config_file"
  else
    rm -f "$tmp"
    return 1
  fi
}

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping appearance restore"
  mark_done
  exit 0
fi

if [[ ! -f $DEFAULT_CONFIG ]]; then
  echo "  default Ryoku shell config missing: $DEFAULT_CONFIG"
  mark_done
  exit 0
fi

# Defaults are safe to restore unconditionally: they should describe the
# upstream shell defaults plus Ryoku labels/assets, not Ryoku color choices.
restore_appearance "$HOME/.local/share/ryoku-shell/defaults/config.json" || true
restore_appearance "$CONFIG_HOME/quickshell/ryoku-shell/defaults/config.json" || true

# Only touch the user's active shell config when the Ryoku theme system had
# claimed ownership. If the user never had a Ryoku theme marker, leave their
# shell settings alone.
if [[ -f $RYOKU_CONFIG_PATH/current/theme.name ]]; then
  restore_appearance "$CONFIG_HOME/ryoku-shell/config.json" || true
  rm -f "$RYOKU_CONFIG_PATH/current/theme.name"
  echo "  restored Ryoku shell appearance defaults and cleared active Ryoku theme marker"
else
  echo "  no active Ryoku theme marker; keeping user shell appearance"
fi

mark_done
