# Set up SDDM as the graphical login manager. Match omarchy 1:1: install
# the SDDM theme via ryoku-refresh-sddm, configure autologin into the
# hyprland-uwsm session, then enable the service. The user lands
# directly on the Ryoku desktop after a single LUKS unlock.

ryoku-refresh-sddm

sudo mkdir -p /etc/sddm.conf.d

# Autologin so the user goes straight to Hyprland after the LUKS unlock.
if [[ ! -f /etc/sddm.conf.d/autologin.conf ]]; then
  cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER
Session=hyprland-uwsm

[Theme]
Current=ryoku
EOF
fi

# Prevent password-based SDDM logins from creating an encrypted login
# keyring (which conflicts with the passwordless Default_keyring used
# for auto-unlock).
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable sddm.service

# archinstall leaves default.target = multi-user.target (no DM in its
# config). Without flipping it the system boots to a getty on tty1 and
# SDDM never starts. Manually-installed Arch SDDM users hit the same
# thing via the pacman post-install hook; in our chroot install that
# hook does not fire, so we set it explicitly here.
sudo systemctl set-default graphical.target
