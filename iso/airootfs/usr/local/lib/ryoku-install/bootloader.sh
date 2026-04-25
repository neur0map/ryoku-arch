#!/bin/bash
# Stage 8: Install limine to the EFI partition and write a basic limine
# config that unlocks LUKS at boot.
#
# The full snapper integration (limine-snapper-sync, limine-mkinitcpio-hook)
# is AUR-only; boot.sh's install pipeline pulls those later via Ryoku's
# AUR helper. Here we only do the minimum to make the system bootable.

stage_header 8 10 "Bootloader"

info "Installing limine to $EFI_PART."

arch-chroot /mnt /bin/bash -e <<CHROOT
mkdir -p /efi/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /efi/EFI/BOOT/

# Write a minimal limine.conf at /boot/limine.conf. limine reads its
# config from /boot/limine.conf by default in the EFI fallback path.
cat > /boot/limine.conf <<LIMINE
TIMEOUT=3
DEFAULT_ENTRY=1
INTERFACE_BRANDING=Ryoku Arch

:Ryoku Arch
    PROTOCOL=linux
    KERNEL_PATH=boot():/vmlinuz-linux
    MODULE_PATH=boot():/initramfs-linux.img
    CMDLINE=cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet

:Ryoku Arch (fallback)
    PROTOCOL=linux
    KERNEL_PATH=boot():/vmlinuz-linux
    MODULE_PATH=boot():/initramfs-linux-fallback.img
    CMDLINE=cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
LIMINE

cp /boot/limine.conf /efi/EFI/BOOT/limine.conf
CHROOT

success "Limine installed."
