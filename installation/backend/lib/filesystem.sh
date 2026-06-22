#!/usr/bin/env bash
# shellcheck shell=bash
# Format the partitions and lay out the Btrfs subvolumes, then mount everything
# under /mnt. Two functions: ryoku_filesystems (mkfs + subvolume creation) runs
# in the "filesystems" stage, ryoku_mount (mounts + swapfile) in the "mount"
# stage. ESP_DEV and ROOT_DEV come from the disk/luks steps.
#
# Subvolume layout (@ -> /, @log -> /var/log, @pkg -> /var/cache/pacman/pkg are
# always created; @home, @snapshots, @backups follow the RYOKU_SUBVOL_* toggles,
# and @swap is created when RYOKU_SWAP_GIB > 0 so the swapfile stays out of @):
#   @ @home @log @pkg @snapshots @backups @swap

RYOKU_BTRFS_OPTS="compress=zstd,noatime"

ryoku_filesystems() {
  if [[ $RYOKU_DISK_STRATEGY == alongside ]]; then
    log "reusing existing ESP ($ESP_DEV); formatting root ($ROOT_DEV, btrfs)"
  else
    log "formatting ESP ($ESP_DEV, vfat) and root ($ROOT_DEV, btrfs)"
    run mkfs.vfat -F32 -n BOOT "$ESP_DEV"
  fi
  run mkfs.btrfs -f -L ryoku "$ROOT_DEV"

  log "creating subvolumes"
  run mount "$ROOT_DEV" /mnt
  run btrfs subvolume create /mnt/@
  [[ ${RYOKU_SUBVOL_HOME:-1} == 1 ]] && run btrfs subvolume create /mnt/@home
  run btrfs subvolume create /mnt/@log
  run btrfs subvolume create /mnt/@pkg
  [[ ${RYOKU_SUBVOL_SNAPSHOTS:-1} == 1 ]] && run btrfs subvolume create /mnt/@snapshots
  [[ ${RYOKU_SUBVOL_BACKUPS:-0} == 1 ]] && run btrfs subvolume create /mnt/@backups
  # A swapfile cannot live in @ (or any snapshotted subvolume): btrfs refuses to
  # snapshot a subvolume that holds an active swapfile, which breaks snapper on
  # every pacman transaction. Give it its own @swap subvolume.
  (( ${RYOKU_SWAP_GIB:-0} > 0 )) && run btrfs subvolume create /mnt/@swap
  run umount /mnt
}

ryoku_mount() {
  local o=$RYOKU_BTRFS_OPTS
  log "mounting subvolumes under /mnt ($o)"
  run mount -o "$o,subvol=@" "$ROOT_DEV" /mnt

  # Directories must exist on @ before their subvolumes mount over them.
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
  ryoku_swapfile
}

ryoku_swapfile() {
  if (( ${RYOKU_SWAP_GIB:-0} <= 0 )); then
    log "swap: none"
    return 0
  fi
  # @swap is mounted separately so the swapfile never lands inside a snapshotted
  # subvolume (see the subvolume creation above). mkswapfile sets NOCOW and the
  # right permissions; genfstab picks up both the mount and the swap entry later.
  log "swap: ${RYOKU_SWAP_GIB}GiB swapfile in @swap (kept out of snapshots)"
  run mkdir -p /mnt/swap
  run mount -o noatime,subvol=@swap "$ROOT_DEV" /mnt/swap
  run btrfs filesystem mkswapfile --size "${RYOKU_SWAP_GIB}g" /mnt/swap/swapfile
  run swapon /mnt/swap/swapfile
}
