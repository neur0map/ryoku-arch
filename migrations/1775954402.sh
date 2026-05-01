echo "Remove makima key remapping service"

if systemctl is-enabled makima &>/dev/null; then
  sudo systemctl disable --now makima
fi

sudo rm -rf /etc/systemd/system/makima.service.d
sudo rm -f /etc/udev/rules.d/99-uinput.rules
rm -rf "$HOME/.config/makima"

ryoku-pkg-drop makima-bin
