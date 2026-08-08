#!/usr/bin/env bash
# preflight: refuse to start unless we're root, in UEFI mode with Secure Boot
# off, and pointed at a big-enough WHOLE disk. under dry-run the checks just
# narrate and never abort, so the flow can be exercised on a dev box with no
# real target disk.

# min target disk: 32 GiB.
RYOKU_MIN_DISK_BYTES=34359738368

# ryoku_secureboot_enabled: true when firmware Secure Boot is currently ON. the
# SecureBoot efivar payload is a 4-byte attribute prefix + a 1-byte value; the
# last byte is the state (1 = enabled). an absent var reads as not enabled.
# RYOKU_SB_VAR overrides the efivar path (tests only).
ryoku_secureboot_enabled() {
  local var=${RYOKU_SB_VAR:-/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c}
  [[ -e $var ]] || return 1
  local last
  last=$(tail -c1 "$var" 2>/dev/null | od -An -tu1 2>/dev/null | tr -d '[:space:]' || true)
  [[ $last == 1 ]]
}

ryoku_preflight() {
  # dry-run never touches the machine, so narrate and return; we'd just probe
  # hardware that might not be on the dev box.
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "preflight: would require root, UEFI (/sys/firmware/efi) with Secure Boot off (override RYOKU_ALLOW_SECUREBOOT=1), and $RYOKU_DISK a whole disk >= 32 GiB"
    log "preflight: would log the disk's logical sector size (blockdev --getss)"
    log "preflight: would require the repo payload at $RYOKU_REPO and a working DNS resolver before any disk write"
    if [[ ${RYOKU_DISK_STRATEGY:-} == alongside ]]; then
      if [[ -n ${RYOKU_RESIZE_PART:-} ]]; then
        log "preflight: would also require GPT + a shared usable ESP (Windows, Ryoku, or another Linux), the shrink tool for ${RYOKU_RESIZE_PART}'s filesystem, and RYOKU_RESIZE_TAKE_MIB >= $(( (2 + $(ryoku_min_root_gib)) * 1024 )); the freed region is checked after the carve"
      else
        log "preflight: would also require GPT, exactly one usable EF00 ESP with >= 8 MiB free, a free region >= $(( 2 + $(ryoku_min_root_gib) ))GiB, and warn on any BitLocker neighbor"
      fi
    fi
    log "preflight: ok (profile=$RYOKU_PROFILE, strategy=$RYOKU_DISK_STRATEGY, encrypt=${RYOKU_ENCRYPT:-0})"
    return 0
  fi

  # root: partitioning, mkfs, pacstrap, arch-chroot all need it.
  [[ $EUID -eq 0 ]] || die "must run as root"

  # UEFI: boot chain is Limine + an ESP.
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode (/sys/firmware/efi missing)"

  # Secure Boot: Limine ships unsigned, so a machine enforcing Secure Boot
  # refuses to run it. Fail HERE with firmware guidance instead of installing a
  # system that then dies at a security violation on first boot.
  # RYOKU_ALLOW_SECUREBOOT=1 overrides (e.g. the user enrolled their own keys).
  if [[ ${RYOKU_ALLOW_SECUREBOOT:-} != 1 ]] && ryoku_secureboot_enabled; then
    die "Secure Boot is enabled and Limine is unsigned, so the installed system will not boot. Disable Secure Boot in your firmware (UEFI) setup screen, then retry. Set RYOKU_ALLOW_SECUREBOOT=1 only if you have enrolled your own keys."
  fi

  # target disk has to exist and be a block device.
  [[ -b $RYOKU_DISK ]] || die "target $RYOKU_DISK is not a block device"

  # target must be a WHOLE disk, not a partition: repartitioning a partition
  # device is nonsense and 'whole' would wipe its parent's table. lsblk TYPE
  # separates a disk from a part/lvm/crypt node.
  local dtype
  dtype=$(lsblk -dno TYPE "$RYOKU_DISK" 2>/dev/null || true)
  [[ $dtype == disk ]] || die "target $RYOKU_DISK is a '${dtype:-unknown}', not a whole disk. Pass a disk (e.g. /dev/nvme0n1 or /dev/sda), not a partition."

  # target disk has to be >= 32 GiB.
  local size
  size=$(blockdev --getsize64 "$RYOKU_DISK")
  (( size >= RYOKU_MIN_DISK_BYTES )) || \
    die "$RYOKU_DISK is $(( (size + 536870912) / 1073741824 )) GiB; need at least 32 GiB"

  # the pacstrap set and the whole desktop payload live under $RYOKU_REPO; without
  # it pacstrap dies at "missing package list". check HERE, before the disk is
  # wiped, so a missing or mispointed payload aborts with the disk intact instead
  # of after the wipe.
  local base_list="$RYOKU_REPO/system/packages/base.packages"
  [[ -f $base_list ]] || die "repo payload missing: $base_list not found (RYOKU_REPO=$RYOKU_REPO). The installer image is incomplete or RYOKU_REPO is wrong; the disk has not been touched."

  log "preflight: $RYOKU_DISK is $(( size / 1024 / 1024 / 1024 )) GiB, $(blockdev --getss "$RYOKU_DISK")-byte logical sectors"
  if [[ ${RYOKU_DISK_STRATEGY:-} == alongside ]]; then
    if [[ -n ${RYOKU_RESIZE_PART:-} ]]; then ryoku_preflight_resize; else ryoku_preflight_alongside; fi
  fi
  log "preflight: ok (profile=$RYOKU_PROFILE, strategy=$RYOKU_DISK_STRATEGY, encrypt=${RYOKU_ENCRYPT:-0})"
}

# ryoku_require_shared_esp: the gates common to every alongside-family install
# (plain alongside AND carve). A GPT disk with exactly one ESP, and that ESP
# usable to share - Windows', an existing Ryoku's, or another Linux's, judged by
# the same ryoku_esp_scan the probe and the bootloader use - with >= 8 MiB free
# for the Limine loader we land beside the existing one. Sets RYOKU_PF_WESP and
# RYOKU_PF_ESP_KIND. Fail closed: this writes to a user's only disk exactly once.
ryoku_require_shared_esp() {
  local disk=$RYOKU_DISK pttype ef_count espinfo wesp kind tmpd avail_kib=0
  pttype=$(blkid -o value -s PTTYPE "$disk" 2>/dev/null || true)
  [[ $pttype == gpt ]] || die "alongside needs a GPT disk; $disk has '${pttype:-no}' partition table. Use whole-disk, or convert to GPT."

  # exactly one EF00 on the disk: multiple ESPs per disk are firmware-flaky; we
  # share the existing single ESP whoever owns it.
  ef_count=$(sgdisk -p "$disk" 2>/dev/null | awk '$6=="EF00"' | wc -l)
  (( ef_count == 1 )) || die "alongside expects exactly one EFI System Partition on $disk (found $ef_count). Ryoku shares the existing single ESP; refusing a multi-ESP disk."
  espinfo=$(ryoku_esp_scan "$disk") || die "no usable EFI System Partition on $disk. alongside shares the existing ESP; use whole-disk instead."
  read -r wesp kind _ <<<"$espinfo"

  # limine is < 1 MiB, but demand 8 MiB headroom on the shared ESP.
  tmpd=$(mktemp -d)
  if mount -o ro "$wesp" "$tmpd" 2>/dev/null; then
    avail_kib=$(df -k --output=avail "$tmpd" 2>/dev/null | tail -1 | tr -d ' ')
    umount "$tmpd" 2>/dev/null || true
  fi
  rmdir "$tmpd" 2>/dev/null || true
  [[ $avail_kib =~ ^[0-9]+$ ]] || avail_kib=0
  (( avail_kib >= 8192 )) || die "the shared ESP $wesp has ${avail_kib} KiB free; alongside needs >= 8 MiB there for the Limine loader. Free space on the ESP, or use whole-disk."
  RYOKU_PF_WESP=$wesp
  RYOKU_PF_ESP_KIND=$kind
}

# ryoku_bitlocker_warn <disk>: a BitLocker neighbour is not blocking (the user may
# hold the key), but boot may later prompt for the recovery key.
ryoku_bitlocker_warn() {
  if lsblk -rno FSTYPE "$1" 2>/dev/null | grep -qi bitlocker; then
    log "WARNING: a BitLocker-encrypted partition is present on $1. Booting Windows via Ryoku may prompt for the BitLocker recovery key; have it ready. (Recorded, not blocking.)"
  fi
}

# alongside preflight: the shared ESP gates PLUS an existing free region big
# enough for the 2 GiB boot + root floor. fail closed with an actionable message.
ryoku_preflight_alongside() {
  local disk=$RYOKU_DISK need_gib region_mib
  ryoku_require_shared_esp
  need_gib=$(( 2 + $(ryoku_min_root_gib) ))
  region_mib=$(ryoku_free_regions "$disk" | sort -k3,3 -nr | awk 'NR==1{print $3+0}')
  (( region_mib >= need_gib * 1024 )) || die "no unallocated region >= ${need_gib}GiB on $disk (largest is $(( region_mib / 1024 ))GiB). Shrink a partition first, then retry."
  ryoku_bitlocker_warn "$disk"
  log "preflight alongside: GPT ok, shared ESP $RYOKU_PF_WESP ($RYOKU_PF_ESP_KIND, >= 8 MiB free), free region $(( region_mib / 1024 ))GiB >= ${need_gib}GiB"
}

# carve preflight: the shared ESP gates PLUS the shrink tool for the selected
# partition's filesystem and a big-enough take. NO free-region gate here: carve
# CREATES that region, and the alongside partition step re-checks it once the gap
# exists. The deep shrinkability re-verify happens in ryoku_carve.
ryoku_preflight_resize() {
  local disk=$RYOKU_DISK part=$RYOKU_RESIZE_PART take=${RYOKU_RESIZE_TAKE_MIB:-0} fstype tool need_gib
  ryoku_require_shared_esp
  [[ -b $part ]] || die "carve target RYOKU_RESIZE_PART=$part is not a block device."
  local parent; parent=$(lsblk -no PKNAME "$part" 2>/dev/null | head -n1)
  [[ /dev/$parent == "$disk" ]] || die "carve target $part is not a partition of $disk (parent is ${parent:-unknown})."
  fstype=$(blkid -o value -s TYPE "$part" 2>/dev/null || true)
  case $fstype in
    ntfs)           tool=ntfsresize ;;
    ext4|ext3|ext2) tool=resize2fs ;;
    btrfs)          tool=btrfs ;;
    swap)           tool=mkswap ;;
    *)              die "carve does not support filesystem '${fstype:-none}' on $part (only ntfs, ext4, btrfs, swap)." ;;
  esac
  command -v "$tool" >/dev/null 2>&1 || die "carve of $fstype needs '$tool', which is not on the live image (ntfsresize ships in ntfsprogs)."
  need_gib=$(( 2 + $(ryoku_min_root_gib) ))
  { [[ $take =~ ^[0-9]+$ ]] && (( take >= need_gib * 1024 )); } || die "RYOKU_RESIZE_TAKE_MIB='${take}' must free at least ${need_gib} GiB (2 GiB boot + $(ryoku_min_root_gib) GiB root) for Ryoku."
  ryoku_bitlocker_warn "$disk"
  log "preflight carve: GPT ok, shared ESP $RYOKU_PF_WESP ($RYOKU_PF_ESP_KIND), will carve ${take} MiB out of $part ($fstype) with $tool"
}
