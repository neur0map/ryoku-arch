#!/usr/bin/env bash
# shellcheck shell=bash
# Wire up Btrfs snapshots in the installed system: a snapper "root" config for /,
# automatic pre/post snapshots around pacman transactions (snap-pac, from the base
# set), the snapper cleanup timer, and limine-snapper-sync so snapshots show up as
# Limine boot entries. Runs after the AUR step (limine-snapper-sync is an AUR
# package) so every piece is present; everything routes through the dry-run
# wrappers and is gated on the @snapshots subvolume actually existing.

ryoku_snapshots() {
  if [[ ${RYOKU_SUBVOL_SNAPSHOTS:-1} != 1 ]]; then
    log "snapshots: @snapshots subvolume disabled, skipping snapper setup"
    return 0
  fi
  log "configuring snapper (root), snap-pac, and limine-snapper-sync"
  ryoku_snap_config
  ryoku_snap_services
}

# ryoku_snap_config writes the snapper "root" config directly. snapper's own
# `create-config` talks to the snapperd D-Bus daemon, which is not running inside
# the chroot, so we lay the file down ourselves. The @snapshots subvolume already
# mounts at /.snapshots (filesystem.sh), so snapper only needs the config, the
# registration in /etc/conf.d/snapper, and the right ownership/mode on /.snapshots.
# Retention keeps ~10 numbered snapshots (the snap-pac / `ryoku update` pairs) and
# disables timeline snapshots, which a desktop does not need.
ryoku_snap_config() {
  run mkdir -p /mnt/etc/snapper/configs
  write_file /mnt/etc/snapper/configs/root <<'EOF'
# Ryoku snapper config for the root filesystem. Written by the installer instead
# of `snapper create-config` (which needs the snapperd D-Bus daemon, absent in the
# chroot). Keys not listed here fall back to snapper's built-in defaults.
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="no"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOF

  # Register "root" so the snapper systemd timers and snap-pac act on it.
  write_file /mnt/etc/conf.d/snapper <<'EOF'
## Path: System/Snapper
## Type: string
## Default: ""
# Snapper configs the systemd units and pacman hooks operate on.
SNAPPER_CONFIGS="root"
EOF

  # snapper expects /.snapshots owned by root with mode 750.
  run chmod 750 /mnt/.snapshots
  run chown root:root /mnt/.snapshots
}

# ryoku_snap_services enables the snapper cleanup timer (prunes per the retention
# limits above) and limine-snapper-sync (publishes snapshots as Limine boot
# entries). limine-snapper-sync ships in the AUR set, so it may be missing on an
# offline install; enabling it is best-effort.
ryoku_snap_services() {
  log "enabling snapper-cleanup.timer"
  run arch-chroot /mnt systemctl enable snapper-cleanup.timer

  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: arch-chroot /mnt systemctl enable limine-snapper-sync.service"
    return 0
  fi
  if [[ -f /mnt/usr/lib/systemd/system/limine-snapper-sync.service ]]; then
    log "enabling limine-snapper-sync.service"
    arch-chroot /mnt systemctl enable limine-snapper-sync.service \
      || log "snapshots: warning, could not enable limine-snapper-sync.service"
  else
    log "snapshots: limine-snapper-sync not installed (offline AUR?); boot-entry sync not enabled"
  fi
}
