#!/usr/bin/env bash
# Partition the target disk. Two strategies, both setting ESP_DEV and ROOT_PART:
#
#   whole     Wipe the disk and lay a fresh GPT: an EFI System Partition plus a
#             root that takes the rest. Destroys everything on the disk.
#   alongside Keep the existing partitions for dual-booting (e.g. Windows on the
#             same drive): reuse the existing EFI System Partition and create the
#             Ryoku root in the largest free region. Nothing existing is wiped or
#             moved, so the user makes room first by shrinking Windows.

# Largest contiguous free region 'alongside' must find for the Ryoku root: a base
# system closure plus the swapfile, which lives inside root (@swap subvolume).
ryoku_min_root_gib() { echo $(( 15 + ${RYOKU_SWAP_GIB:-0} )); }

ryoku_partition() {
  case $RYOKU_DISK_STRATEGY in
    whole)     ryoku_partition_whole ;;
    alongside) ryoku_partition_alongside ;;
    *) die "disk strategy '$RYOKU_DISK_STRATEGY' not supported (use 'whole' or 'alongside')" ;;
  esac
}

ryoku_partition_whole() {
  local disk=$RYOKU_DISK
  local esp_end=$(( 1 + RYOKU_ESP_GIB ))   # MiB offset 1 -> end of ESP

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
  run_sh 'udevadm settle || true'

  ESP_DEV=$(part_dev "$disk" 1)
  ROOT_PART=$(part_dev "$disk" 2)

  # A fresh GPT can lay these partitions over an older layout, so a stale signature
  # (an old LUKS2 header, a previous btrfs) may still sit at the start of each one.
  # The whole-disk wipefs above does not reach into partition space, so clear the
  # new partitions directly. Otherwise blkid reports the old type (e.g. crypto_LUKS)
  # and the later mount fails with "unknown filesystem type".
  run wipefs --all "$ESP_DEV"
  run wipefs --all "$ROOT_PART"
  log "ESP=$ESP_DEV root partition=$ROOT_PART"
}

ryoku_partition_alongside() {
  local disk=$RYOKU_DISK
  log "partitioning $disk (alongside existing OS: reuse ESP, root in free space, nothing wiped)"

  # Under dry-run the disk may not exist; advertise what we would do and pick
  # plausible device names so the rest of the flow can be exercised.
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: would require GPT, an existing ESP, and >= $(ryoku_min_root_gib)GiB contiguous free"
    local maxnum
    maxnum=$(ryoku_max_partnum "$disk" || true)
    (( maxnum > 0 )) || maxnum=3   # disk absent on a dev box: assume a typical Windows layout (ESP+MSR+C:)
    ESP_DEV=$(part_dev "$disk" 1)
    ROOT_PART=$(part_dev "$disk" "$(( maxnum + 1 ))")
    log "DRYRUN: ESP=$ESP_DEV (reused) new root partition=$ROOT_PART"
    return 0
  fi

  # UEFI dual-boot needs a GPT label; refuse MBR rather than guess at a remap.
  local pttype
  pttype=$(blkid -o value -s PTTYPE "$disk" 2>/dev/null || true)
  [[ $pttype == gpt ]] || die "alongside needs a GPT disk; $disk has '${pttype:-no}' partition table. Use whole-disk, or convert to GPT."

  # Reuse the existing EFI System Partition (where the Windows bootloader lives),
  # so Limine and the Windows boot manager share one ESP.
  ESP_DEV=$(ryoku_find_esp "$disk")
  [[ -n $ESP_DEV ]] || die "alongside found no EFI System Partition on $disk. A UEFI Windows install has one; if this disk has none, use whole-disk."
  log "reusing existing ESP: $ESP_DEV"

  # Need a contiguous free region big enough for the Ryoku root. The user makes
  # room by shrinking Windows first (safest done from Windows Disk Management).
  local free_gib min_gib
  free_gib=$(( $(ryoku_largest_free_mib "$disk") / 1024 ))
  min_gib=$(ryoku_min_root_gib)
  (( free_gib >= min_gib )) || die "not enough free space on $disk: ${free_gib}GiB contiguous free, need >= ${min_gib}GiB. Shrink the Windows partition first, then retry."
  log "largest free region: ${free_gib}GiB (need >= ${min_gib}GiB)"

  # Create the root in the largest free block. sgdisk start/end of 0 default to
  # the start and end of the largest aligned free region, so only free space is
  # used; the existing partitions are never touched.
  local newnum
  newnum=$(( $(ryoku_max_partnum "$disk") + 1 ))
  run sgdisk -n "${newnum}:0:0" -t "${newnum}:8300" -c "${newnum}:ryoku" "$disk"
  run partprobe "$disk"
  run_sh 'udevadm settle || true'

  ROOT_PART=$(part_dev "$disk" "$newnum")
  [[ -b $ROOT_PART ]] || die "alongside created partition $newnum but $ROOT_PART is not a block device"

  # Clear any stale signature in the NEW partition only (never the disk or ESP),
  # so a leftover LUKS/btrfs header at this offset cannot fail the later mount.
  run wipefs --all "$ROOT_PART"
  log "ESP=$ESP_DEV (reused) root partition=$ROOT_PART"
}

# ryoku_find_esp prints the first EFI System Partition device on the disk (GPT
# type GUID c12a7328-f81f-11d2-ba4b-00a0c93ec93b), or nothing.
ryoku_find_esp() {
  local disk=$1 part type
  while read -r part; do
    [[ -n $part ]] || continue
    type=$(lsblk -dno PARTTYPE "$part" 2>/dev/null || true)
    [[ ${type,,} == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] && { printf '%s' "$part"; return 0; }
  done < <(ryoku_partitions "$disk")
  return 1
}

# ryoku_partitions lists the partition device paths on a disk, in table order.
ryoku_partitions() {
  lsblk -lnpo NAME,TYPE "$1" 2>/dev/null | awk '$2=="part"{print $1}'
}

# ryoku_max_partnum prints the highest partition number on the disk (0 if none).
ryoku_max_partnum() {
  sgdisk -p "$1" 2>/dev/null | awk '/^[[:space:]]+[0-9]+[[:space:]]/{n=$1} END{print n+0}'
}

# ryoku_largest_free_mib prints the size (MiB) of the largest contiguous free
# region on the disk, parsed from parted's machine-readable free-space listing.
ryoku_largest_free_mib() {
  parted -ms "$1" unit MiB print free 2>/dev/null \
    | awk -F: '$0 ~ /free;[[:space:]]*$/ { s=$4; sub(/MiB/,"",s); if (s+0>m) m=s+0 } END { printf "%d\n", m+0 }'
}
