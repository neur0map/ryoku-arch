#!/bin/bash
set -euo pipefail

use_ryoku_helpers() {
  export RYOKU_PATH="/root/ryoku"
  export RYOKU_INSTALL="/root/ryoku/install"
  export RYOKU_INSTALL_LOG_FILE="/var/log/ryoku-install.log"
  if [[ -f /root/ryoku_channel ]]; then
    RYOKU_CHANNEL="$(</root/ryoku_channel)"
    export RYOKU_CHANNEL
  else
    export RYOKU_CHANNEL="main"
  fi
  source /root/ryoku/install/helpers/all.sh
}

run_configurator() {
  set_ryoku_colors
  ./configurator
  RYOKU_USER="$(jq -r '.users[0].username' user_credentials.json)"
  export RYOKU_USER

  # The user picks the update channel in the configurator; honor it for the
  # rest of the install (overriding the ISO build-time default) so it reaches
  # the chroot and gets persisted to the installed system's channel state.
  if [[ -f ryoku_channel.txt ]]; then
    case "$(<ryoku_channel.txt)" in
      unstable-dev) RYOKU_CHANNEL="unstable-dev" ;;
      *) RYOKU_CHANNEL="main" ;;
    esac
    export RYOKU_CHANNEL
  fi

  # The configurator writes install_mode.sh only for an alongside (dual-boot)
  # install; its absence means a normal full-disk install.
  DUAL_BOOT=false
  if [[ -f install_mode.sh ]]; then
    # shellcheck disable=SC1091
    source ./install_mode.sh
  fi
}

install_arch() {
  clear_logo
  gum style --foreground 3 --padding "1 0 0 $PADDING_LEFT" "Installing..."
  echo

  touch /var/log/ryoku-install.log

  start_log_output

  # Set CURRENT_SCRIPT for the trap to display better when nothing is returned for some reason
  # shellcheck disable=SC2034  # read by the error trap in install/helpers/all.sh
  CURRENT_SCRIPT="install_base_system"
  install_base_system > >(sed -u 's/\x1b\[[0-9;]*[a-zA-Z]//g' >>/var/log/ryoku-install.log) 2>&1
  unset CURRENT_SCRIPT
  stop_log_output
}

install_ryoku() {
  local install_status=0

  chroot_bash -lc "sudo pacman -S --noconfirm --needed gum" >/dev/null

  set +e
  chroot_bash -lc "source /home/$RYOKU_USER/.local/share/ryoku/install.sh || bash"
  install_status=$?
  set -e

  # Reboot if requested by installer
  if (( install_status == 42 )) || [[ -f /mnt/var/tmp/ryoku-install-completed ]]; then
    reboot
    return 0
  fi

  (( install_status == 0 )) || return "$install_status"
}

# Set Ryoku color scheme for the terminal: dark background, accent
# orange (#F25623), subdued foreground (#aeab94). Matches the Ryoku
# brand mark and the installed-system theme.
set_ryoku_colors() {
  if [[ $(tty) == "/dev/tty"* ]]; then
    # Map every ANSI color slot the Ryoku installer uses for accents
    # to the brand orange (#F25623). The installer's prompts/branding
    # rendering tends to use yellow (P3) and red (P1) for emphasis;
    # keep both on the brand so the RYOKU mark and headers stay orange.
    echo -en "\e]P0171717" # black (background)
    echo -en "\e]P1F25623" # red -> Ryoku orange
    echo -en "\e]P2F25623" # green -> Ryoku orange
    echo -en "\e]P3F25623" # yellow -> Ryoku orange
    echo -en "\e]P45f6772" # blue (muted gray-blue)
    echo -en "\e]P5F25623" # magenta -> Ryoku orange
    echo -en "\e]P67d8c8a" # cyan (muted)
    echo -en "\e]P7CCD0CF" # white (foreground)
    echo -en "\e]P8333333" # bright black
    echo -en "\e]P9F25623" # bright red -> Ryoku orange
    echo -en "\e]PAF25623" # bright green -> Ryoku orange
    echo -en "\e]PBF25623" # bright yellow -> Ryoku orange
    echo -en "\e]PC8aa0b8" # bright blue
    echo -en "\e]PDF25623" # bright magenta -> Ryoku orange
    echo -en "\e]PE9eb1ae" # bright cyan
    echo -en "\e]PFCCD0CF" # bright white (foreground)

    # Set default foreground and background
    echo -en "\033[0m"
    clear
  fi
}

install_disk() {
  jq -er 'first(.disk_config.device_modifications[]? | select(.wipe == true) | .device)' user_configuration.json
}

cleanup_install_disk() {
  local disk="$1"

  if [[ -z $disk || ! -b $disk ]]; then
    echo "Could not determine install disk for cleanup" >&2
    return 1
  fi

  echo "Cleaning existing holders on install disk: $disk"

  # Ensure that no mounts exist from past install attempts.
  findmnt -R /mnt >/dev/null && umount -R /mnt || true

  # Turn off swap and unmount anything backed by the selected disk, including
  # device-mapper children from previous installs. Active holders can prevent
  # the kernel from re-reading the partition table after archinstall wipes it.
  while IFS= read -r dev; do
    [[ -b $dev ]] || continue

    swapoff "$dev" 2>/dev/null || true

    while IFS= read -r target; do
      [[ -n $target ]] || continue
      umount "$target" 2>/dev/null || true
    done < <(findmnt -rn -S "$dev" -o TARGET 2>/dev/null || true)
  done < <(lsblk -rnpo PATH "$disk")

  # Deactivate any LVM volume groups whose physical volumes live on the
  # selected disk, common when replacing Fedora/RHEL-family installs.
  while IFS= read -r dev type; do
    [[ $type == "disk" || $type == "part" || $type == "crypt" ]] || continue

    while IFS= read -r vg; do
      [[ -n $vg ]] || continue
      vgchange -an "$vg" 2>/dev/null || true
    done < <(pvs --noheadings -o vg_name "$dev" 2>/dev/null | awk '{$1=$1; print}' | sort -u)
  done < <(lsblk -rnpo PATH,TYPE "$disk")

  # Close any LUKS mappings stacked on the selected disk after filesystems and
  # swap have been released.
  while IFS= read -r dev type; do
    [[ $type == "crypt" ]] || continue
    cryptsetup close "$dev" 2>/dev/null || true
  done < <(lsblk -rnpo PATH,TYPE "$disk")

  blockdev --flushbufs "$disk" 2>/dev/null || true
  partprobe "$disk" 2>/dev/null || true
  udevadm settle || true
}

# Dual-boot: carve one new partition out of the largest free region on the
# chosen disk and set up LUKS/Btrfs ourselves, then mount the tree at /mnt so
# archinstall (pre_mounted_config) installs into it without any disk operations.
# Existing partitions and the existing ESP are never modified  -  sgdisk -n 0:0:0
# uses only free space, and we refuse to touch any pre-existing partition.
setup_dual_boot_partitions() {
  local disk="${INSTALL_DISK:-}"
  local esp="${EXISTING_ESP:-}"
  local target="/mnt"

  [[ -b $disk ]] || { echo "Dual-boot: install disk '$disk' not found" >&2; return 1; }
  [[ -b $esp ]] || { echo "Dual-boot: existing ESP '$esp' not found" >&2; return 1; }

  # Defense in depth: the configurator already refuses alongside-install on a
  # BitLocker disk, but re-verify before any destructive operation. A BitLocker
  # volume reports TYPE=BitLocker, or carries "-FVE-FS-" at offset 3.
  local p sig
  while read -r p; do
    [[ -n $p ]] || continue
    if [[ "$(blkid -o value -s TYPE "$p" 2>/dev/null)" == "BitLocker" ]]; then
      echo "Dual-boot: refusing to modify a disk with BitLocker active ($p)" >&2
      return 1
    fi
    sig=$(dd if="$p" bs=1 skip=3 count=8 2>/dev/null | tr -d '\0')
    if [[ "$sig" == "-FVE-FS-" ]]; then
      echo "Dual-boot: refusing to modify a disk with BitLocker active ($p)" >&2
      return 1
    fi
  done < <(lsblk -rpno NAME,TYPE "$disk" 2>/dev/null | awk '$2=="part"{print $1}')

  echo "Dual-boot: creating a Ryoku partition in free space on $disk (existing data untouched)"

  local before after newpart
  before=$(lsblk -rpno NAME "$disk" 2>/dev/null | sort -u)

  # sgdisk picks the largest free block itself (start/end 0:0). Type 8309 = Linux
  # LUKS. No existing partition can be overwritten by this.
  sgdisk -n 0:0:0 -t 0:8309 -c 0:"Ryoku" "$disk" || { echo "Dual-boot: sgdisk failed" >&2; return 1; }

  partprobe "$disk" 2>/dev/null || true
  udevadm settle 2>/dev/null || true
  sleep 1

  after=$(lsblk -rpno NAME "$disk" 2>/dev/null | sort -u)
  newpart=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep -v "^${disk}$" | head -n1)

  # Hard guardrails: the device we operate on must be brand new and must not be
  # the ESP or any partition that already existed.
  [[ -b $newpart ]] || { echo "Dual-boot: could not identify the new partition" >&2; return 1; }
  if [[ "$newpart" == "$esp" ]] || printf '%s\n' "$before" | grep -qxF "$newpart"; then
    echo "Dual-boot: refusing to format '$newpart' (not a freshly created partition)" >&2
    return 1
  fi
  echo "Dual-boot: new Ryoku partition is $newpart"

  local root_dev
  if [[ "${ENCRYPT_INSTALLATION:-true}" == "true" ]]; then
    local pw
    pw=$(jq -r '.encryption_password // empty' user_credentials.json)
    [[ -n $pw ]] || { echo "Dual-boot: encryption requested but no passphrase available" >&2; return 1; }
    printf '%s' "$pw" | cryptsetup luksFormat --type luks2 --batch-mode "$newpart" - || return 1
    printf '%s' "$pw" | cryptsetup open "$newpart" ryoku_root - || return 1
    DUAL_BOOT_LUKS_UUID=$(cryptsetup luksUUID "$newpart")
    root_dev="/dev/mapper/ryoku_root"
  else
    root_dev="$newpart"
  fi

  mkfs.btrfs -f "$root_dev" || return 1

  local tmp
  tmp=$(mktemp -d)
  mount "$root_dev" "$tmp" || return 1
  btrfs subvolume create "$tmp/@" >/dev/null
  btrfs subvolume create "$tmp/@home" >/dev/null
  btrfs subvolume create "$tmp/@log" >/dev/null
  btrfs subvolume create "$tmp/@pkg" >/dev/null
  umount "$tmp"
  rmdir "$tmp"

  # Mount the pre-mounted tree archinstall will install into.
  findmnt -R "$target" >/dev/null 2>&1 && umount -R "$target" || true
  mkdir -p "$target"
  mount -o compress=zstd,subvol=@ "$root_dev" "$target"
  mkdir -p "$target/home" "$target/var/log" "$target/var/cache/pacman/pkg" "$target/boot"
  mount -o compress=zstd,subvol=@home "$root_dev" "$target/home"
  mount -o compress=zstd,subvol=@log "$root_dev" "$target/var/log"
  mount -o compress=zstd,subvol=@pkg "$root_dev" "$target/var/cache/pacman/pkg"

  # Reuse the existing ESP untouched, alongside the other OS's bootloaders.
  mount "$esp" "$target/boot"

}

# Dual-boot post-install: wire LUKS unlock (crypttab + initramfs encrypt hook +
# kernel cmdline) and let Limine discover the co-installed OS. Runs after
# archinstall has populated /mnt. All target-system commands run in the chroot.
configure_dual_boot_post_install() {
  local target="/mnt"

  if [[ "${ENCRYPT_INSTALLATION:-true}" == "true" && -n "${DUAL_BOOT_LUKS_UUID:-}" ]]; then
    printf 'ryoku_root UUID=%s none luks\n' "$DUAL_BOOT_LUKS_UUID" >>"$target/etc/crypttab"

    # Ensure mkinitcpio unlocks LUKS at boot (add the encrypt hook after block).
    if [[ -f $target/etc/mkinitcpio.conf ]]; then
      if ! grep -qE '^HOOKS=.*\bencrypt\b' "$target/etc/mkinitcpio.conf"; then
        sed -i -E 's/^(HOOKS=\([^)]*)\bblock\b/\1block encrypt/' "$target/etc/mkinitcpio.conf"
      fi
      arch-chroot "$target" mkinitcpio -P || true
    fi

    # Point the Limine boot entry at the encrypted root.
    local cmdline="cryptdevice=UUID=${DUAL_BOOT_LUKS_UUID}:ryoku_root root=/dev/mapper/ryoku_root rootflags=subvol=@ rw"
    local limine_conf
    limine_conf=$(find "$target/boot" -maxdepth 3 -name 'limine.conf' 2>/dev/null | head -n1)
    if [[ -n $limine_conf ]]; then
      if grep -qE '^\s*cmdline:' "$limine_conf"; then
        sed -i -E "s|^(\s*cmdline:).*|\1 ${cmdline}|" "$limine_conf"
      else
        printf '    cmdline: %s\n' "$cmdline" >>"$limine_conf"
      fi
    fi
  fi

  # Discover the other OS so it shows up in the Limine menu (best effort).
  arch-chroot "$target" limine-scan 2>/dev/null || true
}

install_base_system() {
  # Initialize and populate the keyring. Ryoku currently relies on the
  # standard Arch repositories in the ISO and does not ship a signed
  # custom repo here.
  pacman-key --init
  pacman-key --populate archlinux

  # Sync the offline database so pacman can find packages
  pacman -Sy --noconfirm

  if [[ ${DUAL_BOOT:-false} == "true" ]]; then
    # Alongside install: partition free space + mount /mnt ourselves. Never wipe.
    setup_dual_boot_partitions
  else
    # Full-disk install: tear down any existing holders before archinstall wipes.
    cleanup_install_disk "$(install_disk)"
  fi

  # Workarounds for archinstall 4.2 regressions under Python 3.14:
  # 1. sync_log_to_install_medium: `self.target / absolute_logfile` drops
  #    self.target because the RHS is absolute, so Path.copy() raises EINVAL
  #    (source == target).
  # 2. _add_limine_bootloader: `Path.copy(efi_dir_path)` raises IsADirectoryError
  #    because 3.14's Path.copy treats target as a literal path, not a directory
  #    (shutil.copy used to auto-append the source filename).
  sed -i \
    -e 's|logfile_target = self\.target / absolute_logfile$|logfile_target = self.target / absolute_logfile.relative_to("/")|' \
    -e 's|(limine_path / file)\.copy(efi_dir_path)|(limine_path / file).copy(efi_dir_path / file)|' \
    -e "s|(limine_path / 'limine-bios.sys')\.copy(boot_limine_path)|(limine_path / 'limine-bios.sys').copy(boot_limine_path / 'limine-bios.sys')|" \
    /usr/lib/python3.14/site-packages/archinstall/lib/installer.py

  # Install using files generated by the ./configurator
  # Skip NTP and WKD sync since we're offline (keyring is pre-populated in ISO)
  archinstall \
    --config user_configuration.json \
    --creds user_credentials.json \
    --silent \
    --skip-ntp \
    --skip-wkd \
    --skip-wifi-check

  if [[ ${DUAL_BOOT:-false} == "true" ]]; then
    # Wire LUKS unlock + Limine co-existence for the alongside install.
    configure_dual_boot_post_install
  fi

  # After archinstall sets up the base system but before our installer runs,
  # we need to ensure the offline pacman.conf is in place
  cp /etc/pacman.conf /mnt/etc/pacman.conf

  # arch-chroot bind-mounts the live ISO's /etc/resolv.conf into the
  # chroot, but in offline-install mode that file may be empty. Write
  # a working first-boot fallback; the install itself must stay on the
  # bundled offline mirror and never require DNS.
  cat > /mnt/etc/resolv.conf <<RESOLV
# written by ryoku-iso during install; install.sh / NetworkManager will
# replace this on first boot with the system-managed config.
nameserver 1.1.1.1
nameserver 8.8.8.8
RESOLV
  chmod 644 /mnt/etc/resolv.conf

  # Mount the offline mirror so it's accessible in the chroot
  mkdir -p /mnt/var/cache/ryoku/mirror/offline
  mount --bind /var/cache/ryoku/mirror/offline /mnt/var/cache/ryoku/mirror/offline

  if [[ -d /var/cache/ryoku/uv ]]; then
    mkdir -p /mnt/var/cache/ryoku/uv
    mount --bind /var/cache/ryoku/uv /mnt/var/cache/ryoku/uv
  fi

  if [[ -d /var/cache/ryoku/nvim ]]; then
    mkdir -p /mnt/var/cache/ryoku/nvim
    mount --bind /var/cache/ryoku/nvim /mnt/var/cache/ryoku/nvim
  fi

  if [[ -d /var/cache/ryoku/appimages ]]; then
    mkdir -p /mnt/var/cache/ryoku/appimages
    mount --bind /var/cache/ryoku/appimages /mnt/var/cache/ryoku/appimages
  fi

  # Optional bundled extras may live under /opt/packages in the live ISO.
  # Bind-mount them into the chroot only when the directory exists.
  if [[ -d /opt/packages ]]; then
    mkdir -p /mnt/opt/packages
    mount --bind /opt/packages /mnt/opt/packages
  fi

  # No need to ask for sudo during the installation (ryoku itself responsible for removing after install)
  # `Defaults !lecture` suppresses the standard "We trust you have received
  # the usual lecture..." banner so the install output stays clean.
  mkdir -p /mnt/etc/sudoers.d
  cat >/mnt/etc/sudoers.d/99-ryoku-installer <<EOF
Defaults lecture=never
root ALL=(ALL:ALL) NOPASSWD: ALL
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
$RYOKU_USER ALL=(ALL:ALL) NOPASSWD: ALL
EOF
  chmod 440 /mnt/etc/sudoers.d/99-ryoku-installer

  # Copy the local ryoku repo to the user's home directory
  mkdir -p /mnt/home/$RYOKU_USER/.local/share/
  cp -r /root/ryoku /mnt/home/$RYOKU_USER/.local/share/

  chown -R 1000:1000 /mnt/home/$RYOKU_USER/.local/

  # Ensure all necessary scripts are executable
  find /mnt/home/$RYOKU_USER/.local/share/ryoku -type f -path "*/bin/*" -exec chmod +x {} \;
  chmod +x /mnt/home/$RYOKU_USER/.local/share/ryoku/boot.sh 2>/dev/null || true
}

chroot_bash() {
  HOME=/home/$RYOKU_USER \
    arch-chroot -u $RYOKU_USER /mnt/ \
    env -i RYOKU_CHROOT_INSTALL=1 \
    RYOKU_USER_NAME="$(<user_full_name.txt)" \
    RYOKU_USER_EMAIL="$(<user_email_address.txt)" \
    RYOKU_CHANNEL="$RYOKU_CHANNEL" \
    USER="$RYOKU_USER" \
    HOME="/home/$RYOKU_USER" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/bin \
    TERM="${TERM:-xterm-256color}" \
    /bin/bash "$@"
}

if [[ $(tty) == "/dev/tty1" ]]; then
  use_ryoku_helpers
  run_configurator
  install_arch
  install_ryoku
fi
