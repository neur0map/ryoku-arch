#!/usr/bin/env bash
# Partition the target disk: a GPT label with an EFI System Partition and a root
# partition that takes the rest. Sets ESP_DEV and ROOT_PART for later steps.
#
# Only the whole-disk strategy is implemented in this pass. 'alongside' (shrink
# an existing partition) is part of the contract but not yet built; we abort
# clearly rather than guess at someone's existing layout.

ryoku_partition() {
  local disk=$RYOKU_DISK
  local esp_end=$(( 1 + RYOKU_ESP_GIB ))   # MiB offset 1 -> end of ESP

  if [[ $RYOKU_DISK_STRATEGY != whole ]]; then
    die "disk strategy '$RYOKU_DISK_STRATEGY' not supported yet (use 'whole')"
  fi

  log "partitioning $disk (whole disk, GPT: ${RYOKU_ESP_GIB}GiB ESP + root)"

  # Wipe any existing partition tables and signatures.
  run sgdisk --zap-all "$disk"
  run wipefs --all "$disk"

  # Fresh GPT: partition 1 = ESP (EF00 == GPT 'esp' flag), partition 2 = root.
  run parted --script "$disk" mklabel gpt
  run parted --script "$disk" mkpart ESP fat32 1MiB "${esp_end}GiB"
  run parted --script "$disk" set 1 esp on
  run parted --script "$disk" mkpart root "${esp_end}GiB" 100%

  # Let the kernel re-read the new table before we touch the partitions.
  run partprobe "$disk"

  ESP_DEV=$(part_dev "$disk" 1)
  ROOT_PART=$(part_dev "$disk" 2)
  log "ESP=$ESP_DEV root partition=$ROOT_PART"
}
