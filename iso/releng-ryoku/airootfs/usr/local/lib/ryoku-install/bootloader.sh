#!/bin/bash
# Stage 8: Install limine to the EFI partition and write a basic limine
# config that unlocks LUKS at boot.
#
# The full snapper integration (limine-snapper-sync, limine-mkinitcpio-hook)
# is AUR-only; boot.sh's install pipeline pulls those later via Ryoku's
# AUR helper. Here we only do the minimum to make the system bootable.
#
# limine 7+ uses the new lowercase-key/colon-separated config format
# (limine.conf, not limine.cfg) and the kernel cannot live on the LUKS
# partition (limine cannot read encrypted btrfs), so we copy vmlinuz +
# initramfs onto the ESP and reference them via boot():/.

stage_header 8 10 "Bootloader"

info "Installing limine to $EFI_PART."

arch-chroot /mnt /bin/bash -e <<CHROOT
mkdir -p /efi/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /efi/EFI/BOOT/

# Copy kernel and initramfs onto the ESP so limine can find them.
# limine cannot read encrypted btrfs, so files referenced from limine.conf
# must live on the ESP itself. A pacman hook in chroot-setup keeps these
# in sync on kernel updates.
cp /boot/vmlinuz-linux /efi/
cp /boot/initramfs-linux.img /efi/
[ -f /boot/initramfs-linux-fallback.img ] && cp /boot/initramfs-linux-fallback.img /efi/

# limine reads /EFI/BOOT/limine.conf when booted from the ESP fallback path.
cat > /efi/EFI/BOOT/limine.conf <<LIMINE
timeout: 3
default_entry: 1
interface_branding: Ryoku Arch

/Ryoku Arch
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    module_path: boot():/initramfs-linux.img
    cmdline: cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet

/Ryoku Arch (fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    module_path: boot():/initramfs-linux-fallback.img
    cmdline: cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
LIMINE

cp /efi/EFI/BOOT/limine.conf /boot/limine.conf

# Pacman hook: keep ESP's kernel + initramfs in sync when linux package updates.
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-ryoku-esp-sync.hook <<HOOK
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Operation = Remove
Target = usr/lib/modules/*/vmlinuz
Target = boot/initramfs-linux*.img

[Action]
Description = Syncing kernel + initramfs to ESP for limine
When = PostTransaction
Exec = /bin/sh -c 'cp /boot/vmlinuz-linux /efi/vmlinuz-linux && cp /boot/initramfs-linux.img /efi/initramfs-linux.img && [ -f /boot/initramfs-linux-fallback.img ] && cp /boot/initramfs-linux-fallback.img /efi/initramfs-linux-fallback.img || true'
HOOK
CHROOT

success "Limine installed."
