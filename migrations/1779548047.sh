echo "Update Hyprland app launcher keybinds"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
old_browser_line="\$browser = sh -lc '\$HOME/.local/bin/helium'"
file_manager_line="\$fileManager = nautilus"
helium_browser_line="\$heliumBrowser = sh -lc '\$HOME/.local/bin/helium'"
yazi_line="\$yaziFileManager = ryoku-launch-tui yazi"
neovim_line="\$neovimEditor = ryoku-launch-tui nvim"
obsidian_line="\$obsidianNotes = obsidian"
file_manager_bind="bind = SUPER, E, exec, \$fileManager"
helium_browser_bind="bind = SUPER, B, exec, \$heliumBrowser"
yazi_bind="bind = SUPER ALT, E, exec, \$yaziFileManager"
neovim_bind="bind = SUPER, N, exec, \$neovimEditor"
obsidian_bind="bind = SUPER, O, exec, \$obsidianNotes"

remove_line_exact() {
  local line="$1"
  local tmp_file

  tmp_file="$(mktemp)"
  grep -Fvx "$line" "$hypr_conf" >"$tmp_file" || true
  cat "$tmp_file" >"$hypr_conf"
  rm -f "$tmp_file"
}

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
  remove_line_exact "$old_browser_line"

  ensure_assignment "fileManager" "$file_manager_line" '^[$]terminal[[:space:]]*='
  ensure_assignment "yaziFileManager" "$yazi_line" '^[$]fileManager[[:space:]]*='
  ensure_assignment "neovimEditor" "$neovim_line" '^[$]yaziFileManager[[:space:]]*='
  ensure_assignment "obsidianNotes" "$obsidian_line" '^[$]neovimEditor[[:space:]]*='
  ensure_assignment "heliumBrowser" "$helium_browser_line" '^[$]lockscreen[[:space:]]*='

  ensure_bind '^bind = SUPER, E,' "$file_manager_bind" '^bind = SUPER, T,'
  ensure_bind '^bind = SUPER ALT, E,' "$yazi_bind" '^bind = SUPER, E,'
  ensure_bind '^bind = SUPER, B,' "$helium_browser_bind" '^bind = SUPER ALT, E,'
  ensure_bind '^bind = SUPER, N,' "$neovim_bind" '^bind = SUPER, B,'
  ensure_bind '^bind = SUPER, O,' "$obsidian_bind" '^bind = SUPER, N,'
fi

if ryoku-cmd-present hyprctl; then
  hyprctl reload >/dev/null 2>&1 || true
fi
