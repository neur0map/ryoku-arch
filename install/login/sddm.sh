# Set up SDDM as the graphical login manager and install the qylock
# theme bundle (Darkkal44/qylock). Autologin is intentionally NOT
# enabled by default - the point of shipping a themed lockscreen is
# to actually see it at boot. Users who want autologin back can run
# 'ryoku-sddm-autologin enable'.

sudo mkdir -p /etc/sddm.conf.d

# Prevent password-based SDDM logins from creating an encrypted login
# keyring (which conflicts with the passwordless Default_keyring used
# for auto-unlock).
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# Install qylock themes non-interactively on a fresh install; the user
# can re-run ryoku-install-qylock to pick a different theme later.
if ryoku-pkg-aur-accessible; then
  ryoku-install-qylock --default || echo "qylock install skipped; run ryoku-install-qylock manually."
fi

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable sddm.service

# archinstall leaves default.target = multi-user.target (no DM in its
# config). Without flipping it the system boots to a getty on tty1 and
# SDDM never starts. Manually-installed Arch SDDM users hit the same
# thing via the pacman post-install hook; in our chroot install that
# hook does not fire, so we set it explicitly here.
sudo systemctl set-default graphical.target
