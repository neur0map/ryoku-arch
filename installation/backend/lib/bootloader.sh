#!/usr/bin/env bash
# shellcheck shell=bash
# Install and brand the Limine bootloader, build the initramfs, and enable the
# services the desktop needs. Branding and templates come from system/boot/
# (owned by the boot engineer); this step deploys them and fills in the dynamic
# bits (the root cmdline, the encrypt/nvidia toggles) that are only known here.

ryoku_bootloader() {
  CMDLINE=$(ryoku_cmdline)
  log "kernel cmdline: $CMDLINE quiet splash"

  ryoku_boot_plymouth
  ryoku_boot_default_limine

  if chroot_has limine-mkinitcpio; then
    log "building UKI via limine-mkinitcpio"
    ryoku_boot_limine_conf branding_only
    run arch-chroot /mnt limine-mkinitcpio
    chroot_has limine-update && run arch-chroot /mnt limine-update
  else
    log "building initramfs via mkinitcpio -P"
    ryoku_boot_limine_conf with_entry
    run arch-chroot /mnt mkinitcpio -P
  fi

  ryoku_boot_install_efi
  log "enabling services: sddm, NetworkManager"
  run arch-chroot /mnt systemctl enable sddm.service NetworkManager.service
}

# chroot_has reports whether a command exists inside the target. Under dry-run it
# is false so the flow takes the plain mkinitcpio path (no AUR hook in the base).
chroot_has() {
  [[ -n ${RYOKU_DRYRUN:-} ]] && return 1
  arch-chroot /mnt command -v "$1" >/dev/null 2>&1
}

# ryoku_cmdline builds the root cmdline (without "quiet splash", which default.conf
# appends): UUID root for plain installs, cryptdevice + mapper for LUKS.
ryoku_cmdline() {
  local cmdline
  if [[ ${RYOKU_ENCRYPT:-} == 1 ]]; then
    local luks_uuid
    luks_uuid=$(dev_uuid "$LUKS_PART")
    cmdline="root=/dev/mapper/root rootflags=subvol=@ rw cryptdevice=UUID=${luks_uuid}:root"
  else
    local root_uuid
    root_uuid=$(dev_uuid "$ROOT_DEV")
    cmdline="root=UUID=${root_uuid} rootflags=subvol=@ rw"
  fi
  [[ $RYOKU_PROFILE == amd-nvidia ]] && cmdline+=" nvidia_drm.modeset=1"
  printf '%s' "$cmdline"
}

ryoku_boot_plymouth() {
  log "deploying Plymouth theme 'ryoku'"
  deploy_dir "$RYOKU_REPO/system/boot/plymouth/ryoku" /mnt/usr/share/plymouth/themes/ryoku
  run arch-chroot /mnt plymouth-set-default-theme ryoku
}

# ryoku_boot_default_limine deploys /etc/default/limine and substitutes the
# @@CMDLINE@@ token with the real root cmdline.
ryoku_boot_default_limine() {
  log "deploying /etc/default/limine"
  local src="$RYOKU_REPO/system/boot/limine/default.conf"
  local content
  if [[ -f $src ]]; then
    content=$(<"$src")
  else
    content=$(ryoku_builtin_default_limine)
  fi
  # Substitute only on the KERNEL_CMDLINE directive, leaving any @@CMDLINE@@ that
  # appears in the surrounding comments intact.
  content=$(printf '%s\n' "$content" | sed "/^KERNEL_CMDLINE\[default\]/ s|@@CMDLINE@@|$CMDLINE|")
  run mkdir -p /mnt/etc/default
  write_file /mnt/etc/default/limine <<<"$content"
}

# ryoku_boot_limine_conf writes /boot/limine/limine.conf. The branding header
# comes from the repo (with its trailing placeholder entry stripped) or a built-in
# fallback. With "with_entry" a plain linux-protocol entry is appended for the
# mkinitcpio -P path; "branding_only" leaves entries to the limine hook.
ryoku_boot_limine_conf() {
  local mode=$1
  local src="$RYOKU_REPO/system/boot/limine/limine.conf"
  local branding
  if [[ -f $src ]]; then
    branding=$(sed '/^\/Ryoku Linux/,$d' "$src")
  else
    branding=$(ryoku_builtin_limine_branding)
  fi

  run mkdir -p /mnt/boot/limine
  if [[ $mode == with_entry ]]; then
    write_file /mnt/boot/limine/limine.conf <<EOF
$branding

/Ryoku Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    cmdline: $CMDLINE quiet splash
    module_path: boot():/initramfs-linux.img
EOF
  else
    write_file /mnt/boot/limine/limine.conf <<<"$branding"
  fi
}

# ryoku_boot_install_efi places the Limine EFI binary on the ESP (both the
# limine/ path and the removable EFI/BOOT fallback) and registers a boot entry.
ryoku_boot_install_efi() {
  log "installing Limine EFI binary + boot entry"
  run mkdir -p /mnt/boot/EFI/BOOT /mnt/boot/EFI/limine
  run cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/EFI/limine/limine.efi
  run cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/EFI/BOOT/BOOTX64.EFI
  run arch-chroot /mnt efibootmgr --create --disk "$RYOKU_DISK" --part 1 \
    --label Ryoku --loader '\EFI\limine\limine.efi' --unicode
  # Boot the installed system on the next reboot even if the USB installer is still
  # plugged in (firmware often prefers removable media otherwise).
  if [[ -z "${RYOKU_DRYRUN:-}" ]]; then
    local num
    num=$(efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? Ryoku\b.*/\1/p' | head -1)
    if [[ -n $num ]]; then run efibootmgr --bootnext "$num"; fi
  fi
}

ryoku_builtin_default_limine() {
  cat <<'EOF'
TARGET_OS_NAME="Ryoku"
ESP_PATH="/boot"
ENABLE_UKI=yes
CUSTOM_UKI_NAME="ryoku"
KERNEL_CMDLINE[default]="@@CMDLINE@@"
KERNEL_CMDLINE[default]+=" quiet splash"
EOF
}

ryoku_builtin_limine_branding() {
  cat <<'EOF'
timeout: 3
default_entry: 1
interface_branding: Ryoku Bootloader
interface_branding_color: F25623
interface_help_color: F25623
hash_mismatch_panic: no

term_background: 171717
backdrop: 171717
term_palette: 171717;aeab94;F25623;4D4D4D;88A57D;F56E0F;8A8A8A;bcbfbc
term_palette_bright: 333333;aeab94;F25623;4D4D4D;88A57D;F56E0F;8A8A8A;757d75
term_foreground: CCD0CF
term_foreground_bright: CCD0CF
term_background_bright: 333333
EOF
}
