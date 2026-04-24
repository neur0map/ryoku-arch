echo "Point Waybar custom/ryoku span at the ryoku font family"

CONFIG_FILE="$HOME/.config/waybar/config.jsonc"

if [[ ! -f $CONFIG_FILE ]]; then
  exit 0
fi

if grep -q "<span font='omarchy'>" "$CONFIG_FILE"; then
  sed -i "s|<span font='omarchy'>|<span font='ryoku'>|g" "$CONFIG_FILE"
  echo "  rewrote omarchy -> ryoku font reference"
  ryoku-restart-waybar >/dev/null 2>&1 || true
fi
