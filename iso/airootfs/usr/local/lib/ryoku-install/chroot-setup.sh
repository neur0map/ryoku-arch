#!/bin/bash
# Stage 7: System configuration inside the new install (timezone,
# locale, hostname, user, sudoers, mkinitcpio with sd-encrypt).

stage_header 7 10 "Configure System"

info "Configuring timezone, locale, hostname, user, and initramfs."

# Best-effort timezone detection from current live env (the user can
# override later; this avoids an extra prompt for a default that is
# usually correct).
TZ=$(readlink -f /etc/localtime | sed 's|^/usr/share/zoneinfo/||')
[[ -z $TZ || ! -e "/usr/share/zoneinfo/$TZ" ]] && TZ="UTC"

# Run the configuration in a single chroot session.
arch-chroot /mnt /bin/bash -e <<CHROOT
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo '$HOSTNAME' > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

useradd -m -G wheel,audio,video,input,storage,network -s /bin/bash '$USERNAME'
printf '%s\n%s\n' '$ROOT_PW' '$ROOT_PW' | passwd root
printf '%s\n%s\n' '$USER_PW' '$USER_PW' | passwd '$USERNAME'
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# mkinitcpio with sd-encrypt for LUKS unlock at boot.
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

systemctl enable NetworkManager
CHROOT

success "System configured."
