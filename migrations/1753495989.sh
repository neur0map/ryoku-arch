echo "Allow updating of timezone by right-clicking on the clock (or running ryoku-cmd-tzupdate)"

if ryoku-cmd-missing tzupdate; then
  bash "$OMARCHY_PATH/install/config/timezones.sh"
  ryoku-refresh-waybar
fi
