#!/usr/bin/env bash
# shellcheck shell=bash
# Limine: install + brand, build the initramfs, enable the services the
# desktop needs. branding + templates come from system/boot/ (owned by the
# boot engineer); this step deploys them and fills in the dynamic bits
# (root cmdline, encrypt/nvidia toggles) only known here.
#
# layout contract (matches limine-entry-tool, the stack behind
# limine-mkinitcpio-hook and limine-snapper-sync):
#   /boot/limine.conf              THE config. branding globals + entries.
#                                  the tool regenerates entries here and
#                                  limine-snapper-sync adds the Snapshots
#                                  submenu here, preserving our globals.
#   EFI/limine/limine_x64.efi      the booted binary. limine-install (the
#                                  tool's pacman hook) refreshes this exact
#                                  path on every limine upgrade, so the
#                                  firmware never boots a stale bootloader.
#   EFI/BOOT/BOOTX64.EFI           removable-path fallback, same refresh.
# any limine.conf in another search location (/boot/limine/, EFI/limine/,
# ...) shadows the entries file -- Limine stops at the first match -- so
# those candidates are actively removed.

ryoku_bootloader() {
  CMDLINE=$(ryoku_cmdline)
  log "kernel cmdline: $CMDLINE quiet splash"

  ryoku_boot_plymouth
  ryoku_boot_default_limine

  # Intel VMD carry-over MUST land before the initramfs is built (both paths
  # below), or the installed system can't find its own NVMe at boot.
  ryoku_boot_vmd

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

  # any Windows on any drive: chainload it from the menu.
  ryoku_windows_entry

  ryoku_boot_install_efi
  log "enabling services: sddm, NetworkManager, bluetooth, rtkit"
  run arch-chroot /mnt systemctl enable sddm.service NetworkManager.service bluetooth.service rtkit-daemon.service
}

# finalize: runs after the AUR step. when limine-mkinitcpio-hook landed there,
# its pacman hooks already rebuilt the menu in /boot/limine.conf: older
# limine-entry-tool writes a standalone /+Ryoku UKI tree (our flat placeholder
# is then clutter), 1.37+ adopts the placeholder as the tree root and nests
# the "//<kernel>" entries under it (nothing to drop). either way entry 1
# becomes a directory, and a directory can't autoboot, so default_entry moves
# to the newest UKI (entry 2). offline installs (no hook) keep the flat entry
# and default_entry: 1 untouched.
ryoku_bootloader_finalize() {
  local conf=/mnt/boot/limine.conf
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: promote $conf to the tool-managed menu (when the generated tree exists)"
    return 0
  fi
  [[ -f $conf ]] || return 0
  if grep -q '^/+' "$conf"; then
    log "limine-mkinitcpio-hook owns the menu: dropping the flat placeholder entry"
    ryoku_boot_limine_promote "$conf"
  elif grep -Eq '^[[:space:]]*//[^/]' "$conf"; then
    log "limine-mkinitcpio-hook adopted the placeholder as the boot tree: repointing the default"
    ryoku_boot_limine_repoint "$conf"
  else
    return 0
  fi
  # the hook's rewrite re-serialized the file; make sure Windows is still there.
  ryoku_windows_entry
}

# promote CONF: drop the flat "/Ryoku Linux" placeholder (entry line + its
# indented options) and point default_entry at the first UKI inside the
# /+Ryoku tree. pure file surgery, atomic, no chroot -- unit-tested by
# tests/limine-bootloader.sh.
ryoku_boot_limine_promote() {
  local conf=$1 tmp
  tmp=$(mktemp) || return 1
  awk '
    $0 == "/Ryoku Linux" { skip = 1; next }
    skip && /^[[:space:]]+[^[:space:]]/ { next }
    { skip = 0; print }
  ' "$conf" | sed 's/^default_entry: 1$/default_entry: 2/' >"$tmp"
  mv "$tmp" "$conf"
}

# repoint CONF for the adopted layout: limine-entry-tool 1.37+ keeps the flat
# "/Ryoku Linux" placeholder and nests the "//<kernel>" UKIs under it, turning
# it into the menu directory -- but leaves the placeholder's boot stanza
# (protocol/kernel_path/cmdline/module_path) wedged between the title and the
# first sub-entry, where Limine's grammar allows only a `comment`. a directory
# that is also a boot entry cannot autoboot: the timeout resolves nothing and
# the countdown restarts forever. strip that stanza (keep the title, comments,
# and every sub-entry) and move the default off the directory onto its first
# UKI. atomic, idempotent (re-running finds a clean directory + default 2).
ryoku_boot_limine_repoint() {
  local conf=$1 tmp
  tmp=$(mktemp) || return 1
  awk '
    $0 == "/Ryoku Linux" { print; head = 1; n = 0; next }
    head && $0 ~ /^[[:space:]]*\/\// {
      for (i = 0; i < n; i++)
        if (buf[i] !~ /^[[:space:]]+(protocol|kernel_path|module_path|path|cmdline):/ && buf[i] !~ /^[[:space:]]*$/)
          print buf[i]
      head = 0; print; next
    }
    head && $0 ~ /^\/[^\/]/ {
      for (i = 0; i < n; i++) print buf[i]
      head = 0; print; next
    }
    head { buf[n++] = $0; next }
    { print }
    END { if (head) for (i = 0; i < n; i++) print buf[i] }
  ' "$conf" | sed 's/^default_entry: 1$/default_entry: 2/' >"$tmp"
  mv "$tmp" "$conf"
}

# chroot_has: does $1 exist inside the target? dry-run = false, so the flow
# takes the plain mkinitcpio path (no AUR hook in the base).
chroot_has() {
  [[ -n ${RYOKU_DRYRUN:-} ]] && return 1
  arch-chroot /mnt command -v "$1" >/dev/null 2>&1
}

# cmdline (without "quiet splash"; default.conf appends it): UUID root for
# plain installs, cryptdevice + mapper for LUKS, plus the hibernation resume=
# pair when a swapfile exists. NOTE: stdout of this function IS the cmdline
# (captured via $(...)), so every human-facing note goes to stderr.
ryoku_cmdline() {
  local cmdline
  if [[ ${RYOKU_ENCRYPT:-} == 1 ]]; then
    local luks_uuid
    luks_uuid=$(dev_uuid "$LUKS_PART") || die "could not read the LUKS UUID of $LUKS_PART (blkid returned nothing); refusing to write a cryptdevice= cmdline that would not boot."
    cmdline="root=/dev/mapper/root rootflags=subvol=@ rw cryptdevice=UUID=${luks_uuid}:root"
  else
    local root_uuid
    root_uuid=$(dev_uuid "$ROOT_DEV") || die "could not read the root UUID of $ROOT_DEV (blkid returned nothing); refusing to write a root=UUID= cmdline that would not boot."
    cmdline="root=UUID=${root_uuid} rootflags=subvol=@ rw"
  fi
  [[ $RYOKU_PROFILE == amd-nvidia ]] && cmdline+=" nvidia_drm.modeset=1"

  # hibernation: the 'resume' initramfs hook needs the swap-backing device and
  # the swapfile's physical offset within the btrfs. only meaningful with a
  # swapfile (@swap subvol, created in the mount stage before us). the device
  # ref mirrors root=: /dev/mapper/root under LUKS, else UUID= of the root fs.
  # 'map-swapfile -r' (prints just the offset) needs btrfs-progs >= 5.16 -- the
  # same release that added the mkswapfile we build with -- so this normally
  # succeeds; on an older toolchain we skip cleanly (no hibernate, still boots).
  if (( ${RYOKU_SWAP_GIB:-0} > 0 )); then
    local resume_ref off
    if [[ ${RYOKU_ENCRYPT:-} == 1 ]]; then
      resume_ref=/dev/mapper/root
    else
      resume_ref=UUID=${root_uuid}
    fi
    if [[ -n ${RYOKU_DRYRUN:-} ]]; then
      log "dry-run: hibernation resume=$resume_ref resume_offset=<btrfs map-swapfile /mnt/swap/swapfile>" >&2
      cmdline+=" resume=$resume_ref resume_offset=<OFFSET>"
    elif [[ -f /mnt/swap/swapfile ]] && off=$(btrfs inspect-internal map-swapfile -r /mnt/swap/swapfile 2>/dev/null) && [[ -n $off ]]; then
      cmdline+=" resume=$resume_ref resume_offset=$off"
    else
      log "hibernation: no swapfile or btrfs-progs too old for map-swapfile; skipping resume= (system boots, hibernate disabled)" >&2
    fi
  fi
  printf '%s' "$cmdline"
}

# vmd: Intel Volume Management Device (a.k.a. Intel RST "VMD" mode) hides the
# NVMe behind the vmd controller. if the LIVE installer kernel had to load the
# vmd module to see the disk, the INSTALLED initramfs needs it too -- otherwise
# the target can't find its own root at boot (a classic Intel-laptop install
# that boots the ISO fine then drops to an emergency shell). detected on the
# live system (/sys/module/vmd) and written as a MODULES+= drop-in BEFORE the
# initramfs build, so both the limine-mkinitcpio (UKI) and mkinitcpio -P paths
# bake it in. '+=' so it stacks with nvidia.sh's MODULES=() drop-in.
ryoku_boot_vmd() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "dry-run: if the live kernel has VMD loaded (/sys/module/vmd), would write /mnt/etc/mkinitcpio.conf.d/ryoku-vmd.conf with MODULES+=(vmd)"
    return 0
  fi
  [[ -d /sys/module/vmd ]] || return 0
  log "Intel VMD active on the live system: adding 'vmd' to the target initramfs so it finds the NVMe"
  run mkdir -p /mnt/etc/mkinitcpio.conf.d
  write_file /mnt/etc/mkinitcpio.conf.d/ryoku-vmd.conf <<'EOF'
MODULES+=(vmd)
EOF
}

ryoku_boot_plymouth() {
  log "deploying Plymouth theme 'ryoku'"
  deploy_dir "$RYOKU_REPO/system/boot/plymouth/ryoku" /mnt/usr/share/plymouth/themes/ryoku
  run arch-chroot /mnt plymouth-set-default-theme ryoku
}

# default_limine: write /etc/default/limine, swap @@CMDLINE@@ for the real
# root cmdline.
ryoku_boot_default_limine() {
  log "deploying /etc/default/limine"
  local src="$RYOKU_REPO/system/boot/limine/default.conf"
  local content
  if [[ -f $src ]]; then
    content=$(<"$src")
  else
    content=$(ryoku_builtin_default_limine)
  fi
  # substitute only on the KERNEL_CMDLINE directive, so any @@CMDLINE@@
  # sitting in the surrounding comments stays.
  content=$(printf '%s\n' "$content" | sed "/^KERNEL_CMDLINE\[default\]/ s|@@CMDLINE@@|$CMDLINE|")
  run mkdir -p /mnt/etc/default
  write_file /mnt/etc/default/limine <<<"$content"
}

# limine_conf: write /boot/limine.conf (the ESP root -- the one location
# limine-entry-tool manages, so the hook's UKI entries and the snapshot
# submenu land in the file the firmware actually reads). branding header from
# the repo (trailing placeholder entry stripped) or a built-in fallback.
# with_entry appends a plain linux-protocol entry for the mkinitcpio -P path
# and points default_entry at it (the flat menu has no tree directory to
# skip); branding_only keeps default_entry: 2 and leaves entries to the
# limine hook. shadowing candidates are removed either way.
ryoku_boot_limine_conf() {
  local mode=$1
  local src="$RYOKU_REPO/system/boot/limine/limine.conf"
  local branding
  if [[ -f $src ]]; then
    branding=$(sed '/^\/Ryoku Linux/,$d' "$src")
  else
    branding=$(ryoku_builtin_limine_branding)
  fi
  if [[ $mode == with_entry ]]; then
    branding=$(printf '%s\n' "$branding" | sed 's/^default_entry: 2$/default_entry: 1/')
  fi

  ryoku_boot_limine_conflicts
  {
    printf '%s\n' "$branding"
    if [[ $mode == with_entry ]]; then
      cat <<EOF

/Ryoku Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    cmdline: $CMDLINE quiet splash
    module_path: boot():/initramfs-linux.img
EOF
    fi
  } | write_file /mnt/boot/limine.conf
}

# conflicts: remove every limine.conf candidate that would shadow the ESP-root
# config (Limine stops at its first match; limine-install warns about exactly
# this list). matters on re-runs of this installer and on an ESP reused from
# another distro. the empty /boot/limine dir is dropped too.
ryoku_boot_limine_conflicts() {
  run rm -f \
    /mnt/boot/EFI/limine/limine.conf \
    /mnt/boot/EFI/BOOT/limine.conf \
    /mnt/boot/boot/limine/limine.conf \
    /mnt/boot/boot/limine.conf \
    /mnt/boot/limine/limine.conf
  run_sh "rmdir /mnt/boot/limine 2>/dev/null || true"
}

# windows_entry: find an installed Windows on ANY drive (not only the reused
# ESP) and write a uuid()-addressed Limine chainload entry. dual-boot stays
# bootable after Ryoku takes the boot order. boot():/ only reaches Limine's
# own ESP, so a cross-drive Windows has to be referenced by its partition
# GUID; the shared system/boot helper does the scan. runs AFTER the menu is
# generated so the entry isn't regenerated away, and the shipped post.d hook
# re-asserts it on later kernel updates. dry-run skips (probe mounts).
ryoku_windows_entry() {
  local helper="$RYOKU_REPO/system/boot/limine/ryoku-windows-entry"
  local conf=/mnt/boot/limine.conf
  [[ -x $helper && -f $conf ]] || return 0
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "dry-run: skipping Windows boot-entry detection"
    return 0
  fi
  if "$helper" sync "$conf" >/dev/null 2>&1 && grep -q '^/Windows$' "$conf" 2>/dev/null; then
    log "Windows detected: added a chainload entry to the Limine menu"
  fi
}

# install_efi: drop the Limine EFI binary on the ESP and register a boot
# entry. paths match limine-install (limine-entry-tool) exactly --
# EFI/limine/limine_x64.efi + the EFI/BOOT fallback -- so the tool's pacman
# hook keeps refreshing the very binary the firmware boots on every limine
# package upgrade, and its NVRAM dedup (partition uuid + loader path)
# recognizes our entry instead of adding a second one.
ryoku_boot_install_efi() {
  log "installing Limine EFI binary + boot entry"
  run mkdir -p /mnt/boot/EFI/BOOT /mnt/boot/EFI/limine
  run cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/EFI/limine/limine_x64.efi
  # EFI/BOOT/BOOTX64.EFI is the UEFI removable-media fallback loader. writing it
  # is ALWAYS safe now: both strategies install onto OUR OWN ESP (alongside
  # creates a dedicated 'ryokuboot' ESP, never the Windows one), so this can no
  # longer clobber a foreign fallback (the Calamares #2416 hazard). it is also
  # the loader that keeps the box bootable when firmware ignores or drops the
  # NVRAM entry we register below -- see the best-effort handling there.
  run cp /mnt/usr/share/limine/BOOTX64.EFI /mnt/boot/EFI/BOOT/BOOTX64.EFI

  local esp_partnum
  esp_partnum=$(part_num "$ESP_DEV"); : "${esp_partnum:=1}"
  # efibootmgr writes firmware NVRAM, which some machines expose readonly or
  # report full (HP / Insyde-class firmware). that MUST NOT abort the install
  # (set -e): the removable-path EFI/BOOT/BOOTX64.EFI copy above still boots the
  # system. so both --create and --bootnext are best-effort, with a loud warning
  # naming the fallback. loader path stays byte-identical (\EFI\limine\limine_x64.efi)
  # so limine-install's pacman-hook NVRAM dedup (partition uuid + loader path)
  # still recognizes this entry instead of adding a second one on upgrades.
  if ! run arch-chroot /mnt efibootmgr --create --disk "$RYOKU_DISK" --part "$esp_partnum" \
    --label Ryoku --loader '\EFI\limine\limine_x64.efi' --unicode; then
    log "WARNING: efibootmgr could not register the 'Ryoku' NVRAM boot entry (readonly or full firmware NVRAM, e.g. HP/Insyde). The system still boots via the UEFI removable-path fallback EFI/BOOT/BOOTX64.EFI on our ESP; if the firmware does not pick it up automatically, select it once from the firmware boot menu."
    return 0
  fi
  # boot the installed system on the next reboot even if the USB installer
  # is still in (firmware tends to prefer removable media otherwise). also
  # best-effort: a firmware that rejected --create may reject --bootnext too.
  if [[ -z "${RYOKU_DRYRUN:-}" ]]; then
    local num
    num=$(efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? Ryoku\b.*/\1/p' | head -1)
    if [[ -n $num ]]; then
      run efibootmgr --bootnext "$num" || log "WARNING: could not set BootNext; pick 'Ryoku' from the firmware boot menu on the first reboot (or it falls back to EFI/BOOT/BOOTX64.EFI)."
    fi
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
default_entry: 2
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
