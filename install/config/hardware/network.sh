# Configure NetworkManager as the system network daemon. The Ryoku shell
# (services/Network.qml, sidebarRight wifi UI, sidebar VPN, SecPulse, etc.)
# queries `nmcli` exclusively, so NM has to be the active provider for
# the bar to render the correct icon and for the wifi/vpn UIs to work.
#
# History note: a prior version of this script enabled systemd-networkd
# + systemd-resolved instead, with a hand-written 20-ethernet.network
# fallback. That worked for raw connectivity but left the shell unable
# to detect the active interface (icon stuck on "wifi searching" even
# on wired installs, sidebar wifi picker empty). Rolled back to NM here.
# If archinstall's copy_iso_network_config is ever fragile again on
# Python 3.x, fix that path - do not swap the system network manager.

# iwd remains the wifi backend NetworkManager talks to (configured via
# /etc/NetworkManager/conf.d/wifi_backend.conf shipped in default/).
sudo systemctl enable iwd.service

sudo systemctl enable NetworkManager.service

# Keep these out of the way so they cannot race NM for the same
# interfaces or block boot waiting for an interface NM is about to
# claim.
sudo systemctl disable systemd-networkd.service             2>/dev/null || true
sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl mask    systemd-networkd-wait-online.service
sudo systemctl disable NetworkManager-wait-online.service   2>/dev/null || true
sudo systemctl mask    NetworkManager-wait-online.service

# resolved is fine to keep - NM defaults to handing DNS off to it via
# the systemd-resolved plugin when it's running. Don't enable it
# explicitly though; let NM decide based on /etc/NetworkManager/NetworkManager.conf.
sudo systemctl is-enabled NetworkManager.service >/dev/null 2>&1 || {
  echo "Error: NetworkManager.service did not end up enabled" >&2
  exit 1
}

# Drop any stale wired DHCP unit a previous install (or the live ISO's
# /etc/systemd/network) may have copied in - NM owns the wired link
# now and these would just sit around confusing future debugging.
if [[ -f /etc/systemd/network/20-ethernet.network ]]; then
  sudo rm -f /etc/systemd/network/20-ethernet.network
fi

# /etc/resolv.conf is bind-mounted from the live ISO during arch-chroot
# so we can't reliably swap it in here. The static resolv.conf written by
# .automated_script.sh on /mnt (1.1.1.1 + 8.8.8.8) is what ends up on the
# installed disk and is enough for first-boot DNS until NM takes over.
