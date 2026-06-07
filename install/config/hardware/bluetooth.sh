# Turn on bluetooth by default
chrootable_systemctl_enable bluetooth.service

# Persist the last power state across reboots. BlueZ defaults to
# AutoEnable=true, which forces controllers on at boot regardless of the
# last user-set state; AutoEnable=false makes bluetoothd respect it.
sudo sed -i 's/^#\?AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf

wireplumber_config_dir="$HOME/.config/wireplumber/wireplumber.conf.d"
mkdir -p "$wireplumber_config_dir"
cp "$RYOKU_PATH/default/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf" \
  "$wireplumber_config_dir/bluetooth-a2dp-autoconnect.conf"
