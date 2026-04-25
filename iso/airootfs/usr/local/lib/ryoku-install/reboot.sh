#!/bin/bash
# Stage 10: Final stage. Confirm reboot, unmount /mnt cleanly, reboot.

stage_header 10 10 "Reboot"

success "Install complete. Welcome to Ryoku."
echo

info "After reboot, limine will prompt for your disk passphrase, then SDDM"
info "will auto-login to your Ryoku Hyprland desktop."

if gum confirm --prompt.foreground 202 \
     --selected.background 202 --selected.foreground 0 \
     "Reboot now?"; then
  umount -R /mnt
  cryptsetup close cryptroot 2>/dev/null || true
  reboot
else
  info "Reboot when ready: 'umount -R /mnt && reboot'"
fi
