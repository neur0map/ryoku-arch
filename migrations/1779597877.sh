echo "Keep game windows opaque under HyprMod transparency"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
game_opacity_comment="# Keep games opaque while preserving HyprMod transparency for normal windows."
game_content_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:content game"
game_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(steam_app_[0-9]+|gamescope)$"
game_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(steam_app_[0-9]+|gamescope)$"

if [[ -f $hypr_conf ]]; then
  tmp_conf=$(mktemp)
  grep -Fxv "$game_opacity_comment" "$hypr_conf" \
    | grep -Fxv "$game_content_rule" \
    | grep -Fxv "$game_class_rule" \
    | grep -Fxv "$game_initial_class_rule" >"$tmp_conf" || true
  mv "$tmp_conf" "$hypr_conf"

  printf '\n%s\n%s\n%s\n%s\n' \
    "$game_opacity_comment" \
    "$game_content_rule" \
    "$game_class_rule" \
    "$game_initial_class_rule" >>"$hypr_conf"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
