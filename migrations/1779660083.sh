echo "Keep web apps and games fully opaque under HyprMod transparency"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
old_opacity_comment="# Keep games opaque while preserving HyprMod transparency for normal windows."
old_webapp_opacity_comment="# Keep web apps and games opaque while preserving HyprMod transparency for normal windows."
opacity_comment="# Keep web apps and games fully opaque while preserving HyprMod transparency for normal windows."
webapp_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
webapp_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
helium_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(helium)$"
helium_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(helium)$"
game_content_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:content game"
game_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:class ^(steam_app_[0-9]+|gamescope)$"
game_initial_class_rule="windowrule = opacity 1.0 override 1.0 override 1.0 override, match:initial_class ^(steam_app_[0-9]+|gamescope)$"
webapp_class_opaque_rule="windowrule = opaque true, match:class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
webapp_initial_class_opaque_rule="windowrule = opaque true, match:initial_class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
helium_class_opaque_rule="windowrule = opaque true, match:class ^(helium)$"
helium_initial_class_opaque_rule="windowrule = opaque true, match:initial_class ^(helium)$"
game_content_opaque_rule="windowrule = opaque true, match:content game"
game_class_opaque_rule="windowrule = opaque true, match:class ^(steam_app_[0-9]+|gamescope)$"
game_initial_class_opaque_rule="windowrule = opaque true, match:initial_class ^(steam_app_[0-9]+|gamescope)$"
webapp_class_force_rgbx_rule="windowrule = force_rgbx true, match:class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
webapp_initial_class_force_rgbx_rule="windowrule = force_rgbx true, match:initial_class ^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$"
helium_class_force_rgbx_rule="windowrule = force_rgbx true, match:class ^(helium)$"
helium_initial_class_force_rgbx_rule="windowrule = force_rgbx true, match:initial_class ^(helium)$"
game_content_force_rgbx_rule="windowrule = force_rgbx true, match:content game"
game_class_force_rgbx_rule="windowrule = force_rgbx true, match:class ^(steam_app_[0-9]+|gamescope)$"
game_initial_class_force_rgbx_rule="windowrule = force_rgbx true, match:initial_class ^(steam_app_[0-9]+|gamescope)$"

if [[ -f $hypr_conf ]]; then
  tmp_conf=$(mktemp)
  cp "$hypr_conf" "$tmp_conf"

  for rule in \
    "$old_opacity_comment" \
    "$old_webapp_opacity_comment" \
    "$opacity_comment" \
    "$webapp_class_rule" \
    "$webapp_initial_class_rule" \
    "$helium_class_rule" \
    "$helium_initial_class_rule" \
    "$game_content_rule" \
    "$game_class_rule" \
    "$game_initial_class_rule" \
    "$webapp_class_opaque_rule" \
    "$webapp_initial_class_opaque_rule" \
    "$helium_class_opaque_rule" \
    "$helium_initial_class_opaque_rule" \
    "$game_content_opaque_rule" \
    "$game_class_opaque_rule" \
    "$game_initial_class_opaque_rule" \
    "$webapp_class_force_rgbx_rule" \
    "$webapp_initial_class_force_rgbx_rule" \
    "$helium_class_force_rgbx_rule" \
    "$helium_initial_class_force_rgbx_rule" \
    "$game_content_force_rgbx_rule" \
    "$game_class_force_rgbx_rule" \
    "$game_initial_class_force_rgbx_rule"; do
    next_conf=$(mktemp)
    grep -Fxv "$rule" "$tmp_conf" >"$next_conf" || true
    mv "$next_conf" "$tmp_conf"
  done

  mv "$tmp_conf" "$hypr_conf"

  printf '\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$opacity_comment" \
    "$webapp_class_rule" \
    "$webapp_initial_class_rule" \
    "$helium_class_rule" \
    "$helium_initial_class_rule" \
    "$game_content_rule" \
    "$game_class_rule" \
    "$game_initial_class_rule" \
    "$webapp_class_opaque_rule" \
    "$webapp_initial_class_opaque_rule" \
    "$helium_class_opaque_rule" \
    "$helium_initial_class_opaque_rule" \
    "$game_content_opaque_rule" \
    "$game_class_opaque_rule" \
    "$game_initial_class_opaque_rule" \
    "$webapp_class_force_rgbx_rule" \
    "$webapp_initial_class_force_rgbx_rule" \
    "$helium_class_force_rgbx_rule" \
    "$helium_initial_class_force_rgbx_rule" \
    "$game_content_force_rgbx_rule" \
    "$game_class_force_rgbx_rule" \
    "$game_initial_class_force_rgbx_rule" >>"$hypr_conf"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
