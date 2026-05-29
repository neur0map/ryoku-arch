#!/bin/bash

# Set up SDDM as the graphical login manager. Fresh installs should
# land on the qylock clockwork greeter after the LUKS unlock, not drop
# to a tty and not bypass the greeter via autologin.
#
# RESILIENCE: the qylock greeter theme is cosmetic and needs the network
# (git clone) to install. SDDM itself (the package is in ryoku-base.packages,
# the service + graphical.target are enabled below) must come up even when that
# download fails, or an offline/firewalled install boots to a tty with no login
# screen. So the theme install and its coherence checks are best-effort, while the
# service enablement at the bottom runs unconditionally.

# Best-effort: install the qylock clockwork SDDM greeter theme. A network
# failure here must NOT stop SDDM from being enabled below.
ryoku-install-qylock --theme clockwork \
  || echo "Warning: qylock greeter theme install failed; SDDM will use its default theme." >&2

# Explicitly disable autologin so the SDDM greeter is shown on first boot.
# Users can re-enable it later via ryoku-sddm-autologin. Best-effort.
ryoku-sddm-autologin disable >/dev/null 2>&1 || true

# Prevent password-based SDDM logins from creating an encrypted login
# keyring (which conflicts with the passwordless Default_keyring used
# for auto-unlock).
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm

# The qylock theme is cosmetic; a missing theme must not block enabling SDDM.
[[ -f /usr/share/sddm/themes/orbital/metadata.desktop ]] \
  || echo "Warning: qylock clockwork theme is missing from /usr/share/sddm/themes; SDDM will use its default theme." >&2

hyprland_session_found=false
for session in hyprland.desktop Hyprland.desktop hyprland-uwsm.desktop; do
  if [[ -f /usr/share/wayland-sessions/$session ]]; then
    hyprland_session_found=true
    break
  fi
done

[[ $hyprland_session_found == true ]] \
  || echo "Warning: no Hyprland session file found in /usr/share/wayland-sessions; SDDM will still start." >&2

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable sddm.service

# archinstall leaves default.target = multi-user.target (no DM in its
# config). Without flipping it the system boots to a getty on tty1 and
# SDDM never starts. Manually-installed Arch SDDM users hit the same
# thing via the pacman post-install hook; in our chroot install that
# hook does not fire, so we set it explicitly here.
sudo systemctl set-default graphical.target
