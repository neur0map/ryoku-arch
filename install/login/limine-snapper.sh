if ! command -v limine &>/dev/null; then
  echo "Error: limine package missing; production ISO boot parity is impossible" >&2
  exit 1
fi

if ! sudo pacman -Q limine-snapper-sync limine-mkinitcpio-hook >/dev/null 2>&1; then
  echo "Error: missing limine-snapper-sync/limine-mkinitcpio-hook; production ISO boot parity is impossible" >&2
  exit 1
fi

if ! command -v limine-update >/dev/null 2>&1; then
  echo "Error: limine-update missing; production ISO boot parity is impossible" >&2
  exit 1
fi

sudo tee /etc/mkinitcpio.conf.d/ryoku_hooks.conf <<EOF >/dev/null
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF
sudo tee /etc/mkinitcpio.conf.d/thunderbolt_module.conf <<EOF >/dev/null
MODULES+=(thunderbolt)
EOF

# Detect boot mode
[[ -d /sys/firmware/efi ]] && EFI=true

# Find config location
if [[ -f /boot/EFI/arch-limine/limine.conf ]]; then
  limine_config="/boot/EFI/arch-limine/limine.conf"
elif [[ -f /boot/EFI/BOOT/limine.conf ]]; then
  limine_config="/boot/EFI/BOOT/limine.conf"
elif [[ -f /boot/EFI/limine/limine.conf ]]; then
  limine_config="/boot/EFI/limine/limine.conf"
elif [[ -f /boot/limine/limine.conf ]]; then
  limine_config="/boot/limine/limine.conf"
elif [[ -f /boot/limine.conf ]]; then
  limine_config="/boot/limine.conf"
else
  echo "Error: Limine config not found" >&2
  exit 1
fi

CMDLINE=$(grep "^[[:space:]]*cmdline:" "$limine_config" | head -1 | sed 's/^[[:space:]]*cmdline:[[:space:]]*//')

sudo cp $RYOKU_PATH/default/limine/default.conf /etc/default/limine
sudo sed -i "s|@@CMDLINE@@|$CMDLINE|g" /etc/default/limine

# Append any drop-in kernel cmdline configs (from hardware fix scripts, etc.)
for dropin in /etc/limine-entry-tool.d/*.conf; do
  [[ -f "$dropin" ]] && cat "$dropin" | sudo tee -a /etc/default/limine >/dev/null
done

# UKI and EFI fallback are EFI only
if [[ -z $EFI ]]; then
  sudo sed -i '/^ENABLE_UKI=/d; /^ENABLE_LIMINE_FALLBACK=/d' /etc/default/limine
fi

# Overwrite /boot/limine.conf with the snapshot-aware template.
if [[ $limine_config != "/boot/limine.conf" ]] && [[ -f $limine_config ]]; then
  sudo rm "$limine_config"
fi
sudo cp $RYOKU_PATH/default/limine/limine.conf /boot/limine.conf

# Match Snapper configs if not installing from the ISO
if [[ -z ${RYOKU_CHROOT_INSTALL:-} ]]; then
  if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
    sudo snapper -c root create-config /
  fi

  if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
    sudo snapper -c home create-config /home
  fi
fi

# Enable quota to allow space-aware algorithms to work
sudo btrfs quota enable /

# Tweak default Snapper configs
sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}
sudo sed -i 's/^SPACE_LIMIT="0.5"/SPACE_LIMIT="0.3"/' /etc/snapper/configs/{root,home}
sudo sed -i 's/^FREE_LIMIT="0.2"/FREE_LIMIT="0.3"/' /etc/snapper/configs/{root,home}

chrootable_systemctl_enable limine-snapper-sync.service
chrootable_systemctl_enable snapper-cleanup.timer

if [[ -n ${RYOKU_CHROOT_INSTALL:-} ]]; then
  sudo systemctl disable snapper-timeline.timer >/dev/null 2>&1 || true
else
  sudo systemctl disable --now snapper-timeline.timer >/dev/null 2>&1 || true
fi

echo "Re-enabling mkinitcpio hooks..."

# Restore the specific mkinitcpio pacman hooks
if [[ -f /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled ]]; then
  sudo mv /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled /usr/share/libalpm/hooks/90-mkinitcpio-install.hook
fi

if [[ -f /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled ]]; then
  sudo mv /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook
fi

echo "mkinitcpio hooks re-enabled"

# Force initramfs rebuild so the plymouth + sd-encrypt hooks written into
# /etc/mkinitcpio.conf.d/ryoku_hooks.conf take effect, then have limine
# rebuild /boot/limine.conf with the snapshot-aware Ryoku entries.
sudo mkinitcpio -P
sudo limine-update

[[ -f /boot/EFI/Linux/ryoku_linux.efi ]] || {
  echo "Error: missing /boot/EFI/Linux/ryoku_linux.efi after limine-update" >&2
  exit 1
}

grep -q '^/+Ryoku' /boot/limine.conf || {
  echo "Error: /boot/limine.conf is missing Ryoku branded entries" >&2
  exit 1
}

if [[ -n $EFI ]] && efibootmgr &>/dev/null; then
  # Remove the archinstall-created Limine entry
  while IFS= read -r bootnum; do
    sudo efibootmgr -b "$bootnum" -B >/dev/null 2>&1
  done < <(efibootmgr | grep -E "^Boot[0-9]{4}\*? Arch Linux Limine" | sed 's/^Boot\([0-9]\{4\}\).*/\1/')
fi
