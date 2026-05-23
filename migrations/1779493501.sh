echo "Refresh cursor theme defaults for Xwayland applications"

cursor_theme=""
cursor_size=""
cursor_dropin="${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}/toggles/cursor.conf"
gtk_settings="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"

if [[ -f $cursor_dropin ]]; then
  cursor_theme="$(sed -n 's/^XCURSOR_THEME=//p' "$cursor_dropin" | tail -n1)"
  cursor_size="$(sed -n 's/^XCURSOR_SIZE=//p' "$cursor_dropin" | tail -n1)"
fi

if [[ -z $cursor_theme && -f $gtk_settings ]]; then
  cursor_theme="$(sed -n 's/^gtk-cursor-theme-name=//p' "$gtk_settings" | tail -n1)"
fi

if [[ -z $cursor_size && -f $gtk_settings ]]; then
  cursor_size="$(sed -n 's/^gtk-cursor-theme-size=//p' "$gtk_settings" | tail -n1)"
fi

if [[ -z $cursor_theme ]] && ryoku-cmd-present gsettings; then
  cursor_theme="$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || true)"
  cursor_theme="${cursor_theme#\'}"
  cursor_theme="${cursor_theme%\'}"
fi

if [[ -z $cursor_size ]] && ryoku-cmd-present gsettings; then
  cursor_size="$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null || true)"
fi

if [[ -z $cursor_theme ]]; then
  cursor_theme="Bibata-Modern-Classic"
fi

if [[ -z $cursor_size ]]; then
  cursor_size="24"
fi

if [[ -d /usr/share/icons/$cursor_theme/cursors || -d $HOME/.local/share/icons/$cursor_theme/cursors ]]; then
  "$RYOKU_PATH/bin/ryoku-cursor-set" "$cursor_theme" "$cursor_size" || true

  hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

  set_hypr_env() {
    local key="$1"
    local value="$2"
    local anchor="$3"

    if grep -Eq "^env = $key," "$hypr_conf"; then
      sed -i "s|^env = $key,.*|env = $key,$value|" "$hypr_conf"
    elif grep -Eq "^env = $anchor," "$hypr_conf"; then
      sed -i "/^env = $anchor,/i env = $key,$value" "$hypr_conf"
    else
      printf '%s\n' "env = $key,$value" >>"$hypr_conf"
    fi
  }

  if [[ -f $hypr_conf ]]; then
    set_hypr_env XCURSOR_THEME "$cursor_theme" XCURSOR_SIZE
    set_hypr_env XCURSOR_SIZE "$cursor_size" HYPRCURSOR_THEME
    set_hypr_env HYPRCURSOR_THEME "$cursor_theme" HYPRCURSOR_SIZE
    set_hypr_env HYPRCURSOR_SIZE "$cursor_size" QT_QPA_PLATFORM
  fi
else
  echo "  cursor theme '$cursor_theme' is not installed; skipping Xcursor refresh"
fi
