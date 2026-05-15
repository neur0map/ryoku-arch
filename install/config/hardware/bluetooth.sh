# Turn on bluetooth by default
chrootable_systemctl_enable bluetooth.service

wireplumber_config_dir="$HOME/.config/wireplumber/wireplumber.conf.d"
mkdir -p "$wireplumber_config_dir"
cp "$RYOKU_PATH/default/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf" \
  "$wireplumber_config_dir/bluetooth-a2dp-autoconnect.conf"
