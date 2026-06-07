echo "Persist Bluetooth power state across reboots"

# AutoEnable=false makes bluetoothd respect the last user-set Powered state
# instead of forcing controllers on at every boot. Skip cleanly on machines
# without BlueZ installed.
if [[ -f /etc/bluetooth/main.conf ]]; then
  sudo sed -i 's/^#\?AutoEnable=.*/AutoEnable=false/' /etc/bluetooth/main.conf
fi
