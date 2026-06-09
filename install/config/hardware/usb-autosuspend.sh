# Disable USB autosuspend to prevent peripheral disconnection issues
if ryoku_boot_config_enabled; then
  if [[ ! -f /etc/modprobe.d/disable-usb-autosuspend.conf ]]; then
    echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
  fi
fi

