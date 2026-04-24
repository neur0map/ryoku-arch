#!/bin/bash
# Theme picker.
# Enumerates themes from both $RYOKU_PATH/themes (shipped library) and
# $RYOKU_CONFIG_PATH/themes (user customizations), pipes the unique set
# to tofi, and hands the selection to ryoku-theme-set. ryoku-theme-set
# itself resolves a theme name from either location with user overrides
# applied last.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/runtime-env.sh"

TOFI_CONFIG="$RYOKU_CONFIG_PATH/current/theme/tofi.conf"
[[ -f $TOFI_CONFIG ]] || TOFI_CONFIG="$RYOKU_PATH/default/tofi/config"

SHIPPED_DIR="$RYOKU_PATH/themes"
USER_DIR="$RYOKU_CONFIG_PATH/themes"

collect() {
  local dir="$1"
  [[ -d $dir ]] || return 0
  (cd "$dir" && find . -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | sed 's|^\./||')
}

mapfile -t themes < <({ collect "$SHIPPED_DIR"; collect "$USER_DIR"; } | sort -u)

if (( ${#themes[@]} == 0 )); then
  notify-send -u critical "Theme picker" "No themes found in $SHIPPED_DIR or $USER_DIR"
  exit 1
fi

selection=$(printf '%s\n' "${themes[@]}" | tofi --config "$TOFI_CONFIG" --prompt-text "Theme: ")

if [[ -n $selection ]]; then
  exec ryoku-theme-set "$selection"
fi
