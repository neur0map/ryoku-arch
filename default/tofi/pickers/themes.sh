#!/bin/bash
# Theme picker. Replaces the elephant ryokuthemes provider.
# Enumerates themes under ~/.config/ryoku/themes/, pipes them to tofi,
# and hands the selection to ryoku-theme-set.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/runtime-env.sh"

THEMES_DIR="$RYOKU_CONFIG_PATH/themes"

if [[ ! -d $THEMES_DIR ]]; then
  echo "No themes directory at $THEMES_DIR" >&2
  exit 1
fi

mapfile -t themes < <(cd "$THEMES_DIR" && find . -mindepth 1 -maxdepth 1 -type d -o -type l | sed 's|^\./||' | sort)

if (( ${#themes[@]} == 0 )); then
  echo "No themes installed under $THEMES_DIR" >&2
  exit 1
fi

selection=$(printf '%s\n' "${themes[@]}" | tofi --config "$RYOKU_PATH/default/tofi/config" --prompt-text "Theme: ")

if [[ -n $selection ]]; then
  exec ryoku-theme-set "$selection"
fi
