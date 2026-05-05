#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_contains "config/hypr/hyprlock.conf" \
  'path = ~/.config/ryoku/current/background' \
  "hyprlock must read the synced current lockscreen background"

assert_not_contains "config/hypr/hyprlock.conf" \
  'source = ~/.config/ryoku/current/theme/hyprlock.conf' \
  "hyprlock must not source the removed generated theme file"

assert_contains "config/hypr/hyprlock.conf" \
  '^\$font_color = rgb\(' \
  "hyprlock must define fallback font colors inline"

assert_contains "config/hypr/hyprlock.conf" \
  '^\$outer_color = rgba\(' \
  "hyprlock must define fallback input outline colors inline"

assert_contains "shell/scripts/colors/switchwall.sh" \
  'RYOKU_CONFIG_PATH="\$\{RYOKU_CONFIG_PATH:-\$XDG_CONFIG_HOME/ryoku\}"' \
  "switchwall.sh must know the Ryoku current config path"

assert_contains "shell/scripts/colors/switchwall.sh" \
  "sync_ryoku_current_background\\(\\)" \
  "switchwall.sh must define a lockscreen background sync helper"

assert_contains "shell/scripts/colors/switchwall.sh" \
  "sync_lock_background_for_wallpaper\\(\\)" \
  "switchwall.sh must define a media-aware lockscreen sync helper"

assert_contains "shell/scripts/colors/switchwall.sh" \
  'ln -nsf "\$lock_background" "\$RYOKU_CONFIG_PATH/current/background"' \
  "switchwall.sh must update ~/.config/ryoku/current/background"

assert_contains "shell/scripts/colors/switchwall.sh" \
  'sync_lock_background_for_wallpaper "\$imgpath"' \
  "static-accent theme changes must still sync the selected wallpaper to the lockscreen"

assert_contains "shell/scripts/colors/switchwall.sh" \
  'sync_ryoku_current_background "\$thumbnail"' \
  "video wallpapers must sync the generated thumbnail for lockscreen use"

assert_contains "shell/scripts/colors/switchwall.sh" \
  'sync_ryoku_current_background "\$color_source"' \
  "image and gif wallpapers must sync the static lockscreen source"

assert_contains "bin/ryoku-wallpaper-apply" \
  'thumbnail="\$poster"' \
  "video wallpaper apply must use the poster as its thumbnail when generated"

assert_contains "bin/ryoku-wallpaper-apply" \
  'set_shell_wallpaper_config "\$path" "\$thumbnail"' \
  "video wallpaper apply must persist video path and poster thumbnail"

if awk '
  /^apply_video\(\)/ { in_apply = 1 }
  in_apply && /^}/ { in_apply = 0 }
  in_apply && /ryoku-theme-bg-set/ && /\$path/ { found = 1 }
  END { exit found ? 0 : 1 }
' "bin/ryoku-wallpaper-apply"; then
  fail "video wallpaper apply must not point the lockscreen symlink at the video file"
fi

echo "PASS: tests/wallpaper-lockscreen-sync.sh"
