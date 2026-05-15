# Mark the ASUS ROG Flow Z13 detachable touchpad as internal so libinput can
# pair it with the keyboard for disable-while-typing.

if ryoku-hw-asus-rog && ryoku-hw-match "GZ302"; then
  sudo tee /etc/udev/rules.d/99-ryoku-asus-z13-touchpad.rules >/dev/null <<'EOF'
ACTION=="add|change", KERNEL=="event*", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1a30", ENV{ID_INPUT_TOUCHPAD}=="1", ENV{ID_INPUT_TOUCHPAD_INTEGRATION}="internal"
EOF
  sudo udevadm control --reload-rules
fi
