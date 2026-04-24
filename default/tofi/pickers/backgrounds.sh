#!/bin/bash
# Background picker. Replaces the elephant ryokuBackgroundSelector provider.
# Enumerates wallpapers from the active theme's backgrounds/ directory,
# pipes the basenames to tofi, and applies the selection via ryoku-theme-bg-next
# or the direct setter.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/runtime-env.sh"

TOFI_CONFIG="$RYOKU_CONFIG_PATH/current/theme/tofi.conf"
[[ -f $TOFI_CONFIG ]] || TOFI_CONFIG="$RYOKU_PATH/default/tofi/config"

THEME_DIR="$RYOKU_CONFIG_PATH/current/theme"
BG_DIR="$THEME_DIR/backgrounds"

if [[ ! -d $BG_DIR ]]; then
  echo "No backgrounds directory at $BG_DIR" >&2
  exit 1
fi

mapfile -t backgrounds < <(cd "$BG_DIR" && find . -mindepth 1 -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sed 's|^\./||' | sort)

if (( ${#backgrounds[@]} == 0 )); then
  echo "No backgrounds in $BG_DIR" >&2
  exit 1
fi

selection=$(printf '%s\n' "${backgrounds[@]}" | tofi --config "$TOFI_CONFIG" --prompt-text "Background: ")

if [[ -n $selection ]]; then
  setter="$RYOKU_PATH/bin/ryoku-theme-bg-set"
  if [[ -x $setter ]]; then
    exec "$setter" "$BG_DIR/$selection"
  else
    # Fallback: swww set directly if available
    command -v swww >/dev/null && exec swww img "$BG_DIR/$selection"
    echo "No background setter found" >&2
    exit 1
  fi
fi
