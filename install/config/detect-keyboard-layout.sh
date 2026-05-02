# Copy over the keyboard layout that's been set in Arch during install to Niri.
conf="/etc/vconsole.conf"
niriconf="$HOME/.config/niri/config.d/10-input-and-cursor.kdl"

[[ -f $niriconf ]] || exit 0

if grep -q '^XKBLAYOUT=' "$conf"; then
  layout=$(grep '^XKBLAYOUT=' "$conf" | cut -d= -f2 | tr -d '"')
  if grep -q '^[[:space:]]*layout ' "$niriconf"; then
    sed -i "s|^[[:space:]]*layout \".*\"|            layout \"$layout\"|" "$niriconf"
  else
    sed -i "/^[[:space:]]*xkb {$/a\\            layout \"$layout\"" "$niriconf"
  fi
fi

if grep -q '^XKBVARIANT=' "$conf"; then
  variant=$(grep '^XKBVARIANT=' "$conf" | cut -d= -f2 | tr -d '"')
  if grep -q '^[[:space:]]*variant ' "$niriconf"; then
    sed -i "s|^[[:space:]]*variant \".*\"|            variant \"$variant\"|" "$niriconf"
  else
    sed -i "/^[[:space:]]*layout /a\\            variant \"$variant\"" "$niriconf"
  fi
fi
