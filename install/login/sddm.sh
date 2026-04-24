# Set up SDDM as the graphical login manager. The theme catalog comes
# from qylock (Darkkal44/qylock), a curated SDDM + Quickshell theme
# bundle. Attended installs hand off to qylock's interactive picker so
# the user selects their theme. Unattended installs skip the picker; the
# user can run ryoku-install-qylock post-boot.

sudo mkdir -p /etc/sddm.conf.d
if [[ ! -f /etc/sddm.conf.d/autologin.conf ]]; then
  cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER
Session=hyprland-uwsm
EOF
fi

# Prevent password-based SDDM logins from creating an encrypted login keyring
# (which conflicts with the passwordless Default_keyring used for auto-unlock).
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# Install the qylock theme bundle. The installer is interactive when run
# attended; when run from a pipeline (no tty) it is skipped and the user
# runs ryoku-install-qylock later.
if [[ -t 0 ]] && ryoku-pkg-aur-accessible; then
  ryoku-install-qylock || echo "qylock install skipped; run ryoku-install-qylock manually."
fi

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable sddm.service
