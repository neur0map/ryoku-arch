echo "Route Hyprland screenshots through Gradia"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
screenshot_helper='$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot'
screenshot_line="\$screenshot = sh -lc 'exec \"${screenshot_helper}\" screen'"
region_screenshot_line="\$regionScreenshot = sh -lc 'exec \"${screenshot_helper}\" region'"
screenshot_chooser_line="\$screenshotChooser = sh -lc 'exec \"${screenshot_helper}\" choose'"
screenshot_bind="bind = , Print, exec, \$screenshot"
shift_screenshot_bind="bind = SHIFT, Print, exec, \$regionScreenshot"
super_screenshot_bind="bind = SUPER, S, exec, \$screenshotChooser"

ensure_assignment() {
  local variable_name="$1"
  local assignment_line="$2"
  local anchor_pattern="$3"
  local assignment_pattern="^[$]${variable_name}[[:space:]]*="

  if grep -Eq "$assignment_pattern" "$hypr_conf"; then
    sed -i "s|$assignment_pattern.*|$assignment_line|" "$hypr_conf"
  elif grep -Eq "$anchor_pattern" "$hypr_conf"; then
    sed -i "/$anchor_pattern/a $assignment_line" "$hypr_conf"
  else
    printf '%s\n' "$assignment_line" >>"$hypr_conf"
  fi
}

ensure_bind() {
  local bind_pattern="$1"
  local bind_line="$2"
  local anchor_pattern="$3"

  if grep -Eq "$bind_pattern" "$hypr_conf"; then
    sed -i "s|$bind_pattern.*|$bind_line|" "$hypr_conf"
  elif grep -Eq "$anchor_pattern" "$hypr_conf"; then
    sed -i "/$anchor_pattern/a $bind_line" "$hypr_conf"
  else
    printf '%s\n' "$bind_line" >>"$hypr_conf"
  fi
}

if [[ -f $hypr_conf ]]; then
  ensure_assignment "screenshot" "$screenshot_line" '^[$]heliumBrowser[[:space:]]*='
  ensure_assignment "regionScreenshot" "$region_screenshot_line" '^[$]screenshot[[:space:]]*='
  ensure_assignment "screenshotChooser" "$screenshot_chooser_line" '^[$]regionScreenshot[[:space:]]*='

  ensure_bind '^bind = ,[[:space:]]*Print,' "$screenshot_bind" '^bindmd = SUPER, mouse:273,'
  ensure_bind '^bind = SHIFT,[[:space:]]*Print,' "$shift_screenshot_bind" '^bind = ,[[:space:]]*Print,'
  sed -i '/^bind = SUPER SHIFT,[[:space:]]*S,[[:space:]]*exec,[[:space:]]*[$]screenshotChooser[[:space:]]*$/d' "$hypr_conf"
  ensure_bind '^bind = SUPER,[[:space:]]*S,' "$super_screenshot_bind" '^bind = SHIFT,[[:space:]]*Print,'
fi

old_screenshot_apps=()
for package in swappy satty; do
  if ryoku-pkg-present "$package"; then
    old_screenshot_apps+=("$package")
  fi
done

if ryoku-cmd-present ryoku-pkg-remove && ((${#old_screenshot_apps[@]} > 0)); then
  ryoku-pkg-remove "${old_screenshot_apps[@]}" >/dev/null 2>&1 || true
fi

if ryoku-cmd-present hyprctl; then
  hyprctl reload >/dev/null 2>&1 || true
fi
