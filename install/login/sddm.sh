#!/bin/bash

# Set up SDDM as the graphical login manager. Fresh installs should
# land on the qylock clockwork greeter after the LUKS unlock, not drop
# to a tty and not bypass the greeter via autologin.

ryoku-refresh-sddm
ryoku-install-qylock --theme clockwork

# Explicitly disable autologin so the qylock SDDM theme is shown on
# first boot. Users can re-enable it later via ryoku-sddm-autologin.
ryoku-sddm-autologin disable >/dev/null

# Prevent password-based SDDM logins from creating an encrypted login
# keyring (which conflicts with the passwordless Default_keyring used
# for auto-unlock).
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

[[ -f /usr/share/sddm/themes/ii-pixel/metadata.desktop ]] || {
  echo "Error: bundled ii-pixel theme is missing from /usr/share/sddm/themes" >&2
  exit 1
}

[[ -f /usr/share/sddm/themes/orbital/metadata.desktop ]] || {
  echo "Error: qylock clockwork theme is missing from /usr/share/sddm/themes" >&2
  exit 1
}

hyprland_session_found=false
for session in hyprland.desktop Hyprland.desktop hyprland-uwsm.desktop; do
  if [[ -f /usr/share/wayland-sessions/$session ]]; then
    hyprland_session_found=true
    break
  fi
done

[[ $hyprland_session_found == true ]] || {
  echo "Error: Hyprland session file is missing; graphical login would land incorrectly" >&2
  exit 1
}

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable sddm.service

# archinstall leaves default.target = multi-user.target (no DM in its
# config). Without flipping it the system boots to a getty on tty1 and
# SDDM never starts. Manually-installed Arch SDDM users hit the same
# thing via the pacman post-install hook; in our chroot install that
# hook does not fire, so we set it explicitly here.
sudo systemctl set-default graphical.target
