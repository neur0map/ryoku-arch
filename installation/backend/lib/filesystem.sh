#!/usr/bin/env bash
# shellcheck shell=bash
# format the partitions, lay out the Btrfs subvolumes, mount it all under
# /mnt. two entrypoints: ryoku_filesystems (mkfs + subvol create) in the
# "filesystems" stage, ryoku_mount (mounts + swapfile) in the "mount" stage.
# ESP_DEV / ROOT_DEV come from disk + luks.
#
# subvolume layout. always: @ -> /, @log -> /var/log, @pkg ->
# /var/cache/pacman/pkg. toggle-gated: @home, @snapshots, @backups
# (RYOKU_SUBVOL_*). @swap iff RYOKU_SWAP_GIB > 0, so the swapfile stays out
# of @:
#   @ @home @log @pkg @snapshots @backups @swap

RYOKU_BTRFS_OPTS="compress=zstd,noatime"

ryoku_filesystems() {
  # both strategies own their ESP now (alongside creates a dedicated Ryoku ESP,
  # never the Windows one), so format it the same way in both.
  log "formatting ESP ($ESP_DEV, vfat) and root ($ROOT_DEV, btrfs)"
  run mkfs.vfat -F32 -n BOOT "$ESP_DEV"
  run mkfs.btrfs -f -L ryoku "$ROOT_DEV"

  log "creating subvolumes"
  run mount "$ROOT_DEV" /mnt
  run btrfs subvolume create /mnt/@
  [[ ${RYOKU_SUBVOL_HOME:-1} == 1 ]] && run btrfs subvolume create /mnt/@home
  run btrfs subvolume create /mnt/@log
  run btrfs subvolume create /mnt/@pkg
  [[ ${RYOKU_SUBVOL_SNAPSHOTS:-1} == 1 ]] && run btrfs subvolume create /mnt/@snapshots
  [[ ${RYOKU_SUBVOL_BACKUPS:-0} == 1 ]] && run btrfs subvolume create /mnt/@backups
  # swapfile can't live in @ (or any snapshotted subvol): btrfs refuses to
  # snapshot one with an active swapfile, which breaks snapper on every
  # pacman transaction. its own @swap subvol.
  (( ${RYOKU_SWAP_GIB:-0} > 0 )) && run btrfs subvolume create /mnt/@swap
  run umount /mnt
}

ryoku_mount() {
  local o=$RYOKU_BTRFS_OPTS
  log "mounting subvolumes under /mnt ($o)"
  run mount -o "$o,subvol=@" "$ROOT_DEV" /mnt

  # dirs must exist on @ before their subvols mount over them.
  run mkdir -p /mnt/var/log /mnt/var/cache/pacman/pkg /mnt/boot
  [[ ${RYOKU_SUBVOL_HOME:-1} == 1 ]] && run mkdir -p /mnt/home
  [[ ${RYOKU_SUBVOL_SNAPSHOTS:-1} == 1 ]] && run mkdir -p /mnt/.snapshots
  [[ ${RYOKU_SUBVOL_BACKUPS:-0} == 1 ]] && run mkdir -p /mnt/.backups

  [[ ${RYOKU_SUBVOL_HOME:-1} == 1 ]] && run mount -o "$o,subvol=@home" "$ROOT_DEV" /mnt/home
  run mount -o "$o,subvol=@log" "$ROOT_DEV" /mnt/var/log
  run mount -o "$o,subvol=@pkg" "$ROOT_DEV" /mnt/var/cache/pacman/pkg
  [[ ${RYOKU_SUBVOL_SNAPSHOTS:-1} == 1 ]] && run mount -o "$o,subvol=@snapshots" "$ROOT_DEV" /mnt/.snapshots
  [[ ${RYOKU_SUBVOL_BACKUPS:-0} == 1 ]] && run mount -o "$o,subvol=@backups" "$ROOT_DEV" /mnt/.backups

  run mount "$ESP_DEV" /mnt/boot

  # ESP capacity guard, HERE (right after the ESP mounts) and NOT deep in the
  # bootloader step: the Limine binaries, the kernel, and both initramfs images
  # have to fit on /mnt/boot, but pacstrap + mkinitcpio fill /boot long before
  # the bootloader runs, so a too-small ESP used to fail cryptically mid-install.
  # with the new partitioning this NEVER fires (whole-disk and alongside each
  # give us our OWN >= 1 GiB ESP); it only catches a hand-built/reused ESP that
  # is too small, BEFORE anything is written to it. dry-run narrates (no fs yet).
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "dry-run: would require >= 64 MiB free on the ESP (/mnt/boot)"
  else
    local esp_avail_kib
    esp_avail_kib=$(df -k --output=avail /mnt/boot 2>/dev/null | tail -1 | tr -d ' ')
    [[ $esp_avail_kib =~ ^[0-9]+$ ]] || esp_avail_kib=0
    (( esp_avail_kib >= 65536 )) || die "ESP /mnt/boot has ${esp_avail_kib} KiB free; need >= 64 MiB for the bootloader + kernel + initramfs. Use a larger ESP (RYOKU_ESP_GIB)."
  fi

  ryoku_swapfile
}

ryoku_swapfile() {
  if (( ${RYOKU_SWAP_GIB:-0} <= 0 )); then
    log "swap: none"
    return 0
  fi
  # @swap is mounted separately so the swapfile never lands inside a
  # snapshotted subvol (see above). mkswapfile sets NOCOW + the right perms;
  # genfstab picks up both the mount and the swap entry later.
  log "swap: ${RYOKU_SWAP_GIB}GiB swapfile in @swap (kept out of snapshots)"
  run mkdir -p /mnt/swap
  run mount -o noatime,subvol=@swap "$ROOT_DEV" /mnt/swap
  run btrfs filesystem mkswapfile --size "${RYOKU_SWAP_GIB}g" /mnt/swap/swapfile
  run swapon /mnt/swap/swapfile
}
