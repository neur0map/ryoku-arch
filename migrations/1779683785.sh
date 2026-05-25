echo "Use Ryoku in-frame launcher instead of experimental ActivSpot launcher"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

if [[ -f $hypr_conf ]]; then
  sed -i "s|\$menu = sh -lc '\$HOME/.local/bin/activspot-launcher toggle'|\$menu = sh -lc '\$HOME/.local/bin/ryoku-shell launcher'|" "$hypr_conf"
  sed -i "/activspot-launcher.service/d" "$hypr_conf"
fi

for unit in \
  activspot-launcher.service \
  activspot-island.service \
  activspot-main.service \
  activspot-topbar.service \
  activspot-clipboard.service; do
  systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$unit"
done

rm -f /tmp/qs_launcher /tmp/qs_launcher_state "$HOME/.local/bin/activspot-launcher"

if [[ -L ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts ]]; then
  target=$(readlink "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts" || true)
  if [[ $target == "$HOME/.local/share/activspot/scripts" ]]; then
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
  fi
fi
