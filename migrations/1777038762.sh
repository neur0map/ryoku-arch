echo "Force tofi-drun to actually launch selected apps"

MARKER="$HOME/.local/state/ryoku/independence-cutover.tofi-drun-launch.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

# Tofi's compiled-in default is drun-launch=false, which only prints the
# Exec= line to stdout. ryoku-launch-walker does not capture that output,
# so every Super+Space selection was a silent no-op. Patch the live
# config to flip the switch. The template and default copies were
# updated in the repo and will be picked up by fresh installs.
TOFI_CONF="$RYOKU_CONFIG_PATH/current/theme/tofi.conf"

if [[ -f $TOFI_CONF ]] && ! grep -q '^drun-launch' "$TOFI_CONF"; then
  echo "  adding drun-launch = true to $TOFI_CONF"
  printf '\n# Tofi default is drun-launch=false which only prints Exec; force true\n# so Super+Space actually launches the selected app.\ndrun-launch = true\n' >> "$TOFI_CONF"
fi

# Tofi caches its app list at ~/.cache/tofi-drun and does not rescan on
# config changes. Drop it so the next launch re-reads everything.
if [[ -f $HOME/.cache/tofi-drun ]]; then
  echo "  clearing ~/.cache/tofi-drun"
  rm -f "$HOME/.cache/tofi-drun"
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
