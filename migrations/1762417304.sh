echo "Replace bluetooth GUI with TUI"

ryoku-pkg-add bluetui
ryoku-pkg-drop blueberry

if ! grep -q "ryoku-launch-bluetooth" ~/.config/waybar/config.jsonc; then
  sed -i 's/blueberry/ryoku-launch-bluetooth/' ~/.config/waybar/config.jsonc
fi
