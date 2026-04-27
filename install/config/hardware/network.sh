# Ensure iwd service will be started (wifi management).
sudo systemctl enable iwd.service

# Ensure ethernet works on first boot. archinstall's
# copy_iso_network_config(enable_services=True) is supposed to copy the
# live ISO's /etc/systemd/network/*.network files into the install and
# enable systemd-networkd + systemd-resolved, but that path has been
# fragile under Python 3.14 (we already sed-patch installer.py for two
# Path.copy regressions in iso/configs/airootfs/root/.automated_script.sh).
# Don't trust it: enable the services explicitly (idempotent if archinstall
# already enabled them) and drop a default wired DHCP unit so the wired
# NIC comes up regardless of whether archinstall copied the ISO files.
sudo systemctl enable systemd-networkd.service systemd-resolved.service

if [[ ! -f /etc/systemd/network/20-ethernet.network ]]; then
  sudo install -d -m 0755 /etc/systemd/network
  sudo tee /etc/systemd/network/20-ethernet.network >/dev/null <<'EOF'
[Match]
Type=ether
Kind=!*

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
MulticastDNS=yes

[DHCPv4]
RouteMetric=100

[IPv6AcceptRA]
RouteMetric=100
EOF
fi

# Point resolv.conf at the systemd-resolved stub. archinstall does this
# during base install; redo it here so an offline install where the stub
# wasn't symlinked still resolves DNS on first boot.
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Prevent systemd-networkd-wait-online from blocking boot when no cable
# is plugged in or DHCP takes a moment.
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

sudo systemctl is-enabled systemd-networkd.service >/dev/null 2>&1 || {
  echo "Error: systemd-networkd.service did not end up enabled" >&2
  exit 1
}

sudo systemctl is-enabled systemd-resolved.service >/dev/null 2>&1 || {
  echo "Error: systemd-resolved.service did not end up enabled" >&2
  exit 1
}

[[ -L /etc/resolv.conf ]] || {
  echo "Error: /etc/resolv.conf must be a systemd-resolved symlink for first-boot VM DNS" >&2
  exit 1
}
