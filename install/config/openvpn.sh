# Install polkit rule for password-less openvpn-client@* control,
# ensure /etc/openvpn/client/ exists, and add this user to the
# systemd-journal group so the SecPulse OpenVPN tab's log tail can
# read system-unit journals without sudo.

if ! ryoku-cmd-present openvpn; then
  echo "openvpn not installed; skipping openvpn.sh"
  exit 0
fi

sudo install -m 644 -o root -g root \
  "$RYOKU_PATH/default/polkit/49-ryoku-openvpn.rules" \
  /etc/polkit-1/rules.d/49-ryoku-openvpn.rules

sudo install -d -m 755 -o root -g root /etc/openvpn/client
# install -d only sets the mode on creation, and the openvpn package
# ships /etc/openvpn/client/ at 0750 openvpn:network. Re-assert 0755
# so RyokuOpenVpn.qml's unprivileged discovery can list profiles.
# Files inside stay 0600 root:root, so cert/key contents are untouched.
sudo chmod 0755 /etc/openvpn/client
sudo chown root:root /etc/openvpn/client

if ! id -nG "$USER" | tr ' ' '\n' | grep -qx systemd-journal; then
  sudo usermod -aG systemd-journal "$USER"
fi
