#!/bin/bash
# Stage 5: Partition the target disk, create LUKS2 container, format
# btrfs, lay down subvolumes, mount everything at /mnt.

stage_header 5 10 "Partition Disk"

info "Wiping and partitioning $TARGET_DISK."

# 1. Sanity check: the target disk must not be mounted anywhere.
if findmnt --source "$TARGET_DISK" >/dev/null 2>&1 || \
   findmnt --source "${TARGET_DISK}1" >/dev/null 2>&1 || \
   findmnt --source "${TARGET_DISK}2" >/dev/null 2>&1; then
  abort "Refusing to partition: $TARGET_DISK has mounted partitions."
fi

# 2. Wipe existing signatures + partition table.
gum spin --spinner dot --title "Wiping existing partition table..." -- \
  bash -c "wipefs -af '$TARGET_DISK' && sgdisk --zap-all '$TARGET_DISK'"

# 3. Create GPT with two partitions: 1 GiB EFI System, rest LUKS.
gum spin --spinner dot --title "Creating GPT partition table..." -- \
  bash -c "
    sgdisk -o '$TARGET_DISK'
    sgdisk -n 1:0:+1GiB  -t 1:ef00 -c 1:'EFI'         '$TARGET_DISK'
    sgdisk -n 2:0:0      -t 2:8309 -c 2:'cryptryoku'  '$TARGET_DISK'
    partprobe '$TARGET_DISK'
    sleep 1
  "

# Determine partition node names (NVMe vs SATA differ).
if [[ $TARGET_DISK =~ nvme|mmcblk ]]; then
  EFI_PART="${TARGET_DISK}p1"
  ROOT_PART="${TARGET_DISK}p2"
else
  EFI_PART="${TARGET_DISK}1"
  ROOT_PART="${TARGET_DISK}2"
fi
export EFI_PART ROOT_PART

# 4. Format EFI as FAT32.
gum spin --spinner dot --title "Formatting EFI partition..." -- \
  mkfs.fat -F32 -n EFI "$EFI_PART"

# 5. LUKS2 with Argon2id, 1 GiB memory cost.
echo "Setting up LUKS2 (this may take a few seconds)..."
echo -n "$LUKS_PW" | cryptsetup luksFormat \
  --type luks2 --pbkdf argon2id \
  --pbkdf-memory 1048576 --pbkdf-parallel 4 \
  --batch-mode \
  "$ROOT_PART" -

echo -n "$LUKS_PW" | cryptsetup open --type luks2 \
  --batch-mode \
  "$ROOT_PART" cryptroot -

# 6. Capture LUKS UUID for limine cmdline (set later in stage 8).
LUKS_UUID=$(blkid -s UUID -o value "$ROOT_PART")
export LUKS_UUID

# 7. Format btrfs on the unlocked LUKS device.
gum spin --spinner dot --title "Formatting btrfs..." -- \
  mkfs.btrfs -f -L ROOT /dev/mapper/cryptroot

# 8. Create subvolumes.
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@pkg
umount /mnt

# 9. Mount the @ subvol with full mount options, then create mountpoints
# for the rest and mount them.
mount_opts="noatime,compress=zstd:3,space_cache=v2,subvol=@"
if [[ $(lsblk -dn -o ROTA "$TARGET_DISK") == 0 ]]; then
  mount_opts="${mount_opts},ssd,discard=async"
fi

mount -o "$mount_opts" /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{efi,home,.snapshots,var/log,var/cache,var/cache/pacman/pkg}

mount -o "${mount_opts/subvol=@/subvol=@home}" /dev/mapper/cryptroot /mnt/home
mount -o "${mount_opts/subvol=@/subvol=@snapshots}" /dev/mapper/cryptroot /mnt/.snapshots
mount -o "${mount_opts/subvol=@/subvol=@log}" /dev/mapper/cryptroot /mnt/var/log
mount -o "${mount_opts/subvol=@/subvol=@cache}" /dev/mapper/cryptroot /mnt/var/cache
mount -o "${mount_opts/subvol=@/subvol=@pkg}" /dev/mapper/cryptroot /mnt/var/cache/pacman/pkg
mount "$EFI_PART" /mnt/efi

# 10. Set NOCOW on the subvolumes that should not use copy-on-write.
chattr +C /mnt/var/log
chattr +C /mnt/var/cache
chattr +C /mnt/var/cache/pacman/pkg

success "Disk ready at /mnt"
