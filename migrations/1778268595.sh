#!/usr/bin/env bash
# Re-assert /etc/openvpn/client perms so RyokuOpenVpn.qml's unprivileged
# discovery can list imported profiles. The openvpn Arch package ships
# the directory at 0750 openvpn:network, which makes the sidebar OpenVPN
# tab silently see an empty profile list even after a successful import
# (the QML side runs `ls /etc/openvpn/client/*.conf` as the user, gets
# permission denied, and the import button appears to do nothing).
#
# Files inside stay 0600 root:root, so cert/key contents remain protected.
# Idempotent: only chmod when the dir exists and the mode is not already 0755.

set -euo pipefail

echo "Open /etc/openvpn/client/ for unprivileged profile listing"

if [[ ! -d /etc/openvpn/client ]]; then
    echo "  /etc/openvpn/client missing, skipping"
    exit 0
fi

current_mode="$(stat -c '%a' /etc/openvpn/client)"
current_owner="$(stat -c '%U:%G' /etc/openvpn/client)"

if [[ "$current_mode" == "755" && "$current_owner" == "root:root" ]]; then
    echo "  already 0755 root:root, skipping"
    exit 0
fi

sudo chmod 0755 /etc/openvpn/client
sudo chown root:root /etc/openvpn/client
echo "  fixed /etc/openvpn/client (was 0$current_mode $current_owner)"
