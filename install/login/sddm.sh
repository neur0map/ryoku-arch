# Set up SDDM as the graphical login manager. Fresh installs should
# land on the bundled Ryoku greeter after the LUKS unlock, not drop to a
# tty and not bypass the greeter via autologin.

ryoku-refresh-sddm

# Explicitly disable autologin so the bundled SDDM theme is shown on
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

[[ -f /usr/share/wayland-sessions/niri.desktop ]] || {
  echo "Error: niri session file is missing; graphical login would land incorrectly" >&2
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
