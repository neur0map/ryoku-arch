echo "Restore Hyprland mouse move and resize bindings"

hypr_conf="$HOME/.config/hypr/hyprland.conf"
move_bind='bindmd = SUPER, mouse:272, Move window, movewindow'
resize_bind='bindmd = SUPER, mouse:273, Resize window, resizewindow'

if [[ -f $hypr_conf ]]; then
  if ! grep -Fxq "$move_bind" "$hypr_conf"; then
    sed -i "/^bind = SUPER, A, togglefloating,/a $move_bind" "$hypr_conf"
  fi

  if ! grep -Fxq "$resize_bind" "$hypr_conf"; then
    sed -i "/^bindmd = SUPER, mouse:272, Move window, movewindow/a $resize_bind" "$hypr_conf"
  fi
fi
