echo "Add HyprMod Super comma launcher"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
# shellcheck disable=SC2016
launcher_line='$hyprlandSettings = hyprmod'
# shellcheck disable=SC2016
bind_line='bind = SUPER, comma, exec, $hyprlandSettings'

if [[ -f $hypr_conf ]]; then
  if ! grep -Fxq "$launcher_line" "$hypr_conf"; then
    if grep -Eq '^[$]systemPanel = ' "$hypr_conf"; then
      sed -i "/^[$]systemPanel = /a $launcher_line" "$hypr_conf"
    else
      printf '%s\n' "$launcher_line" >>"$hypr_conf"
    fi
  fi

  if ! grep -Eq '^bind = SUPER, comma,' "$hypr_conf"; then
    # shellcheck disable=SC2016
    if grep -Fxq 'bind = SUPER, S, exec, $systemPanel' "$hypr_conf"; then
      sed -i "/^bind = SUPER, S, exec, [$]systemPanel$/a $bind_line" "$hypr_conf"
    else
      printf '%s\n' "$bind_line" >>"$hypr_conf"
    fi
  fi
fi
