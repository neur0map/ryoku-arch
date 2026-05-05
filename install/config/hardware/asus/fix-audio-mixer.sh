# Fix audio volume on Asus ROG laptops by using a soft mixer.

if ryoku-hw-asus-rog; then
  mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
  cp $RYOKU_PATH/default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf ~/.config/wireplumber/wireplumber.conf.d/
  rm -rf ~/.local/state/wireplumber/default-routes

  # Initialize the hardware Master control before WirePlumber routes through the soft mixer.
  card=$(aplay -l 2>/dev/null | grep -i "ALC285" | head -1 | sed 's/card \([0-9]*\).*/\1/')
  if [[ -n $card ]]; then
    amixer -c "$card" set Master 100% unmute 2>/dev/null
  fi
fi
