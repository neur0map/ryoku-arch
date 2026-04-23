echo "Update Waybar for new Ryoku menu"

if ! grep -q "" ~/.config/waybar/config.jsonc; then
  ryoku-refresh-waybar
fi
