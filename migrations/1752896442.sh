echo "Replace volume control GUI with a TUI"

if ryoku-cmd-missing wiremix; then
  ryoku-pkg-add wiremix
  ryoku-pkg-drop pavucontrol
  ryoku-refresh-applications
  ryoku-refresh-waybar
fi
