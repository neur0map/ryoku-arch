echo "Add Super scroll workspace navigation bindings"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
scroll_next_var="\$workspaceScrollNext = sh -lc 'exec \"\$HOME/.local/share/ryoku/bin/ryoku-cmd-hypr-workspace-scroll\" next'"
scroll_prev_var="\$workspaceScrollPrev = sh -lc 'exec \"\$HOME/.local/share/ryoku/bin/ryoku-cmd-hypr-workspace-scroll\" prev'"
scroll_down_bind="bind = SUPER, mouse_down, exec, \$workspaceScrollPrev"
scroll_up_bind="bind = SUPER, mouse_up, exec, \$workspaceScrollNext"

if [[ -f $hypr_conf ]]; then
  ensure_binds_block() {
    if ! grep -q '^[[:space:]]*binds[[:space:]]*{' "$hypr_conf"; then
      printf '\nbinds {\n}\n' >> "$hypr_conf"
    fi
  }

  ensure_binds_option() {
    local key="$1"
    local value="$2"

    if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$hypr_conf"; then
      sed -i "s/^[[:space:]]*${key}[[:space:]]*=.*/  $key = $value/" "$hypr_conf"
    else
      sed -i "/^[[:space:]]*binds[[:space:]]*{/a \\  $key = $value" "$hypr_conf"
    fi
  }

  ensure_binds_block
  ensure_binds_option pass_mouse_when_bound false
  ensure_binds_option scroll_event_delay 0

  sed -i '/^bind = SUPER, mouse_down, workspace, e+1$/d' "$hypr_conf"
  sed -i '/^bind = SUPER, mouse_up, workspace, e-1$/d' "$hypr_conf"

  if ! grep -Fxq "$scroll_next_var" "$hypr_conf"; then
    if grep -q '^[$]toggleFloat = ' "$hypr_conf"; then
      sed -i "/^[$]toggleFloat = /a $scroll_next_var" "$hypr_conf"
    elif grep -q '^bind = SUPER, Page_Down, workspace, e+1' "$hypr_conf"; then
      sed -i "/^bind = SUPER, Page_Down, workspace, e+1/i $scroll_next_var" "$hypr_conf"
    else
      printf '\n%s\n' "$scroll_next_var" >> "$hypr_conf"
    fi
  fi

  if ! grep -Fxq "$scroll_prev_var" "$hypr_conf"; then
    if grep -q '^[$]workspaceScrollNext = ' "$hypr_conf"; then
      sed -i "/^[$]workspaceScrollNext = /a $scroll_prev_var" "$hypr_conf"
    else
      printf '%s\n' "$scroll_prev_var" >> "$hypr_conf"
    fi
  fi

  if ! grep -Fxq "$scroll_down_bind" "$hypr_conf"; then
    if grep -Fxq 'bind = SUPER, Page_Up, workspace, e-1' "$hypr_conf"; then
      sed -i "/^bind = SUPER, Page_Up, workspace, e-1/a $scroll_down_bind" "$hypr_conf"
    else
      printf '\n%s\n' "$scroll_down_bind" >> "$hypr_conf"
    fi
  fi

  if ! grep -Fxq "$scroll_up_bind" "$hypr_conf"; then
    if grep -Fxq "$scroll_down_bind" "$hypr_conf"; then
      sed -i "/^bind = SUPER, mouse_down, exec, [$]workspaceScrollPrev/a $scroll_up_bind" "$hypr_conf"
    else
      printf '%s\n' "$scroll_up_bind" >> "$hypr_conf"
    fi
  fi
fi
