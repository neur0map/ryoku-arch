#!/usr/bin/env bash
# Preflight checks: refuse to start unless we are root, booted in UEFI mode, and
# pointed at a disk big enough to hold a usable system. Under dry-run the checks
# report what they would verify and never abort, so the flow can be exercised on
# a developer machine without a real target disk.

# Minimum target disk size: 32 GiB.
RYOKU_MIN_DISK_BYTES=34359738368

ryoku_preflight() {
  # Under dry-run we never touch the machine, so report the checks and return
  # instead of probing hardware that may not exist on the developer's box.
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "preflight: would require root, UEFI (/sys/firmware/efi), and $RYOKU_DISK >= 32 GiB"
    log "preflight: ok (profile=$RYOKU_PROFILE, strategy=$RYOKU_DISK_STRATEGY, encrypt=${RYOKU_ENCRYPT:-0})"
    return 0
  fi

  # Must run as root: partitioning, mkfs, pacstrap and arch-chroot all need it.
  [[ $EUID -eq 0 ]] || die "must run as root"

  # Must be UEFI: the boot chain is Limine + an EFI System Partition.
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (/sys/firmware/efi missing)"

  # Target disk must exist and be a block device.
  [[ -b $RYOKU_DISK ]] || die "target $RYOKU_DISK is not a block device"

  # Target disk must be at least 32 GiB.
  local size
  size=$(blockdev --getsize64 "$RYOKU_DISK")
  (( size >= RYOKU_MIN_DISK_BYTES )) || \
    die "$RYOKU_DISK is $(( size / 1024 / 1024 / 1024 )) GiB; need at least 32 GiB"

  log "preflight: $RYOKU_DISK is $(( size / 1024 / 1024 / 1024 )) GiB"
  log "preflight: ok (profile=$RYOKU_PROFILE, strategy=$RYOKU_DISK_STRATEGY, encrypt=${RYOKU_ENCRYPT:-0})"
}
