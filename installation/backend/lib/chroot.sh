#!/usr/bin/env bash
# shellcheck shell=bash
# Configure the freshly installed system: locale, console keymap, timezone,
# hostname, the primary user, sudo, the initramfs HOOKS, and (when encrypting)
# crypttab. Files that live under /mnt are written directly; anything that must
# run in the target environment goes through arch-chroot.

ryoku_configure() {
  ryoku_cfg_locale
  ryoku_cfg_keymap
  ryoku_cfg_timezone
  ryoku_cfg_hostname
  ryoku_cfg_user
  ryoku_cfg_sudo
  ryoku_cfg_initramfs
  ryoku_cfg_crypttab
}

ryoku_cfg_locale() {
  log "locale: $RYOKU_LOCALE"
  run sed -i "s|^#\(${RYOKU_LOCALE} \)|\1|" /mnt/etc/locale.gen
  write_file /mnt/etc/locale.conf <<EOF
LANG=$RYOKU_LOCALE
EOF
  run arch-chroot /mnt locale-gen
}

ryoku_cfg_keymap() {
  log "console keymap: $RYOKU_KEYMAP"
  write_file /mnt/etc/vconsole.conf <<EOF
KEYMAP=$RYOKU_KEYMAP
EOF
}

ryoku_cfg_timezone() {
  local tz=$RYOKU_TIMEZONE
  if [[ $tz == auto ]]; then
    if [[ -n ${RYOKU_DRYRUN:-} ]]; then
      printf 'DRYRUN: curl -fsSL https://ipinfo.io/timezone\n'
      tz='<auto-timezone>'
    else
      tz=$(curl -fsSL https://ipinfo.io/timezone) || die "could not resolve timezone via ipinfo.io"
      [[ -n $tz ]] || die "ipinfo.io returned an empty timezone"
    fi
  fi
  log "timezone: $tz"
  run ln -sf "/usr/share/zoneinfo/$tz" /mnt/etc/localtime
  run arch-chroot /mnt hwclock --systohc
}

ryoku_cfg_hostname() {
  log "hostname: $RYOKU_HOSTNAME"
  write_file /mnt/etc/hostname <<EOF
$RYOKU_HOSTNAME
EOF
  write_file /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $RYOKU_HOSTNAME.localdomain $RYOKU_HOSTNAME
EOF
}

ryoku_cfg_user() {
  log "user: $RYOKU_USERNAME (wheel, shell /usr/bin/fish)"
  run arch-chroot /mnt useradd -m -G wheel -s /usr/bin/fish "$RYOKU_USERNAME"
  # Set the same password on the user and root so both sudo (wheel) and su work
  # with the password chosen at install. Hashes go in on stdin (chpasswd -e reads
  # name:hash) and are never logged.
  printf '%s:%s\n' "$RYOKU_USERNAME" "$RYOKU_PASSWORD_HASH" | run_secret \
    "arch-chroot /mnt chpasswd -e (user:hash via stdin)" \
    arch-chroot /mnt chpasswd -e
  printf 'root:%s\n' "$RYOKU_PASSWORD_HASH" | run_secret \
    "arch-chroot /mnt chpasswd -e (root:hash via stdin)" \
    arch-chroot /mnt chpasswd -e
}

ryoku_cfg_sudo() {
  log "sudo: wheel group"
  write_file /mnt/etc/sudoers.d/10-wheel <<'EOF'
%wheel ALL=(ALL:ALL) ALL
EOF
  run chmod 0440 /mnt/etc/sudoers.d/10-wheel
}

ryoku_cfg_initramfs() {
  log "mkinitcpio HOOKS drop-in (/etc/mkinitcpio.conf.d/ryoku.conf)"
  local src="$RYOKU_REPO/system/boot/mkinitcpio/ryoku.conf"
  local content
  if [[ -f $src ]]; then
    content=$(<"$src")
  else
    content='HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck)'
  fi
  # The 'encrypt' hook is only needed for LUKS roots; drop it on the HOOKS line
  # only (so it never touches the word "encrypted" in the comments above).
  [[ ${RYOKU_ENCRYPT:-} != 1 ]] && content=$(printf '%s\n' "$content" | sed -E '/^HOOKS=/ s/ encrypt\b//')

  run mkdir -p /mnt/etc/mkinitcpio.conf.d
  write_file /mnt/etc/mkinitcpio.conf.d/ryoku.conf <<<"$content"

  # NVIDIA needs early KMS so the dGPU comes up before the display manager.
  if [[ $RYOKU_PROFILE == amd-nvidia ]]; then
    log "mkinitcpio MODULES drop-in for NVIDIA early KMS"
    write_file /mnt/etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
  fi
}

ryoku_cfg_crypttab() {
  [[ ${RYOKU_ENCRYPT:-} == 1 ]] || return 0
  local luks_uuid
  luks_uuid=$(dev_uuid "$LUKS_PART")
  log "crypttab: root -> UUID=$luks_uuid"
  write_file /mnt/etc/crypttab <<EOF
root UUID=$luks_uuid none luks
EOF
}
