echo "Update Waybar for new Omarchy menu"

if ! grep -q "" ~/.config/waybar/config.jsonc; then
  ryoku-refresh-waybar
fi
