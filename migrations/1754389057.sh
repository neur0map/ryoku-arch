echo "Offer to reorganize hyprland.conf as per new defaults"

if [[ ! -f ~/.config/hypr/autostarts.conf ]]; then
  echo -e "\nRyoku now splits default .config/hypr/hyprland.conf into sub-configs."
  echo -e "Resetting to defaults will overwrite your configuration, but save it as .bak.\n"
  if ryoku-tui confirm "Use new default hyprland.conf config?"; then
    ryoku-refresh-hyprland || true
  else
    echo "Left your existing configuration in place!"
  fi
fi
