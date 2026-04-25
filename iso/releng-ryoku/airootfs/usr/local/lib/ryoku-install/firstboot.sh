#!/bin/bash
# Stage 9: Inside the new install, fetch and run Ryoku's boot.sh as the
# new user. boot.sh's preflight passes because we set up limine + btrfs
# + (UEFI + non-root). install.sh then installs the full Ryoku layer.

stage_header 9 10 "Install Ryoku Layer"

info "Fetching boot.sh from GitHub and running it inside the new system."
info "This installs ~130 packages (Hyprland, Waybar, alacritty, fastfetch,"
info "themes, etc.) and lays down all Ryoku configs. It can take 10-20 min."

# Run boot.sh as the regular user inside the chroot. arch-chroot bind
# mounts /etc/resolv.conf so DNS works for the curl.
#
# chroot-setup.sh dropped /etc/sudoers.d/zz-ryoku-install for the user
# so all the nested sudos inside boot.sh succeed without a password
# prompt. We remove that drop-in after boot.sh exits so the installed
# system reverts to the standard wheel password policy.
arch-chroot /mnt /bin/bash -e <<CHROOT
sudo -u '$USERNAME' bash -c '
  set -eEo pipefail
  cd "\$HOME"
  bash <(curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/boot.sh)
'
rm -f /etc/sudoers.d/zz-ryoku-install
CHROOT

success "Ryoku layer installed."
