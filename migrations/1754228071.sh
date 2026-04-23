echo "Add auto-update icon to waybar when update available"

if ! grep -q "custom/update" ~/.config/waybar/config.jsonc; then
  ryoku-refresh-waybar
fi
