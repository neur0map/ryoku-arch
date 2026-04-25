# Ryoku ISO Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current archinstall-wrapper `ryoku-install` with a custom 10-stage gum-styled bash installer that lays down LUKS2 + btrfs subvolumes + limine, then chroots and runs our existing `boot.sh` so the rest of the Ryoku layer installs on top.

**Architecture:** Modular bash installer under `iso/airootfs/usr/local/lib/ryoku-install/`. Each stage is one file (preflight, prompts, partition, bootstrap, chroot-setup, bootloader, firstboot, reboot) plus a shared `style.sh` for gum styling helpers. Entry point `iso/airootfs/usr/local/bin/ryoku-install` orchestrates them. Snapper/limine-snapper-sync are AUR-only so they install via boot.sh's existing AUR pipeline, not via pacstrap; stage 8 only sets up base limine.

**Tech Stack:** bash 5, gum (charmbracelet TUI), cryptsetup (LUKS2), btrfs-progs, limine, archiso, pacstrap, arch-chroot, qemu + edk2-ovmf for testing.

**Spec:** [`docs/superpowers/specs/2026-04-24-ryoku-iso-installer-design.md`](../specs/2026-04-24-ryoku-iso-installer-design.md)

---

## Working trees

All edits in dev clone at `/home/omi/prowl/ryoku-arch`. Final task syncs to installed tree at `~/.local/share/ryoku` and pushes to GitHub. Snapshot tag `pre-iso-installer-design` placed before any code changes.

## Files

**Create (in `iso/airootfs/`):**
- `usr/local/bin/ryoku-install` (replaces existing archinstall wrapper)
- `usr/local/lib/ryoku-install/style.sh`
- `usr/local/lib/ryoku-install/preflight.sh`
- `usr/local/lib/ryoku-install/prompts.sh`
- `usr/local/lib/ryoku-install/partition.sh`
- `usr/local/lib/ryoku-install/bootstrap.sh`
- `usr/local/lib/ryoku-install/chroot-setup.sh`
- `usr/local/lib/ryoku-install/bootloader.sh`
- `usr/local/lib/ryoku-install/firstboot.sh`
- `usr/local/lib/ryoku-install/reboot.sh`
- `usr/local/share/ryoku-install/banner.txt`
- `usr/local/share/ryoku-install/packages.list`

**Modify:**
- `iso/releng-ryoku/profiledef.sh` (new file_permissions for the installer files)
- `iso/releng-ryoku/packages.x86_64` (add `gum` to the live env)

**Snapshot tag:**
- `pre-iso-installer-design` at current dev clone HEAD

---

### Task 1: Snapshot tag + add gum to live ISO

**Files:**
- Tag: `pre-iso-installer-design`
- Modify: `iso/releng-ryoku/packages.x86_64`

- [ ] **Step 1.1: Tag and push the snapshot**

```bash
cd /home/omi/prowl/ryoku-arch
git tag pre-iso-installer-design
git push origin pre-iso-installer-design
git log --oneline pre-iso-installer-design -1
```

Expected: tag created and pushed. The log line shows the current HEAD commit.

- [ ] **Step 1.2: Add `gum` to the live ISO package list**

The new installer uses `gum` for all UI. Confirm gum is in the live ISO's package list:

```bash
grep -n '^gum$' iso/releng-ryoku/packages.x86_64 || echo "MISSING"
```

If output is `MISSING`, append `gum`:

```bash
echo 'gum' >> iso/releng-ryoku/packages.x86_64
```

Verify:
```bash
grep -n '^gum$' iso/releng-ryoku/packages.x86_64
```

- [ ] **Step 1.3: Install host-side test deps**

For QEMU UEFI testing in Task 10:

```bash
sudo pacman -S --needed --noconfirm edk2-ovmf
ls /usr/share/edk2/x64/OVMF.4m.fd
```

Expected: package installed; the OVMF firmware file exists.

- [ ] **Step 1.4: Commit**

```bash
git add iso/releng-ryoku/packages.x86_64
git commit -m "iso: add gum to live ISO for installer TUI"
```

---

### Task 2: Static data files (banner + package list)

**Files:**
- Create: `iso/airootfs/usr/local/share/ryoku-install/banner.txt`
- Create: `iso/airootfs/usr/local/share/ryoku-install/packages.list`

- [ ] **Step 2.1: Create the banner file**

Reuse the kanji + RYOKU wordmark from `iso/airootfs/usr/local/bin/ryoku-welcome` (already in the live ISO) so the installer header matches the welcome screen:

```bash
mkdir -p iso/airootfs/usr/local/share/ryoku-install
cat > iso/airootfs/usr/local/share/ryoku-install/banner.txt <<'BANNER'
                   ████████
                   ████████
                   ████████
                   ████████
     ██████████████████████████████████████████
   ██████████████████████████████████████████████
   ██████████████████████████████████████████████
                   ████████              ████████
                   ██████                ██████
                 ████████                ██████
               ████████                  ██████
             ██████████                  ██████
         ██████████                    ████████
       ██████████                      ██████
   ████████████              ████████████████
     ████                      ████████

 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
BANNER
```

- [ ] **Step 2.2: Create the pacstrap package list**

```bash
cat > iso/airootfs/usr/local/share/ryoku-install/packages.list <<'EOF'
# Minimum-viable Arch base for the Ryoku installer.
# After pacstrap, boot.sh + install.sh layer the full Ryoku desktop on top
# (see install/ryoku-base.packages for the rest).

# Core
base
base-devel
linux
linux-firmware
intel-ucode
amd-ucode

# Filesystem + encryption
btrfs-progs
cryptsetup

# Bootloader (only the core; AUR pieces install via boot.sh later)
limine

# Network
networkmanager
iwd

# Tools needed by boot.sh
sudo
curl
git
nano
EOF
```

- [ ] **Step 2.3: Verify**

```bash
ls iso/airootfs/usr/local/share/ryoku-install/
wc -l iso/airootfs/usr/local/share/ryoku-install/packages.list
```

Expected: both files present, packages.list has ~25 lines (including comments and blanks).

- [ ] **Step 2.4: Commit**

```bash
git add iso/airootfs/usr/local/share/ryoku-install/
git commit -m "iso: installer banner + pacstrap package list"
```

---

### Task 3: Style helpers + entry point skeleton

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/style.sh`
- Create: `iso/airootfs/usr/local/bin/ryoku-install` (replace existing)

- [ ] **Step 3.1: Write style.sh**

```bash
mkdir -p iso/airootfs/usr/local/lib/ryoku-install
cat > iso/airootfs/usr/local/lib/ryoku-install/style.sh <<'EOF'
#!/bin/bash
# Shared gum styling helpers for the Ryoku installer.
# Source from each stage; do not invoke directly.

ORANGE_256=202
ORANGE_TRUE='#F25623'
SUBDUED_256=248
GREEN_OK_256=35
RED_ERR_256=196

# Stage header. Usage: stage_header <stage_number> <total> <title>
stage_header() {
  local n="$1" total="$2" title="$3"
  clear
  gum style \
    --border double --foreground "$ORANGE_256" \
    --padding "1 2" --margin 1 --align center --width 56 \
    "Ryoku Installer" "" "Stage ${n}/${total}: ${title}"
  echo
}

# Info paragraph (subdued).
info() {
  gum style --foreground "$SUBDUED_256" "$@"
  echo
}

# Success message.
success() {
  gum style --foreground "$GREEN_OK_256" --bold "$@"
  echo
}

# Warning box (red on near-black).
warning() {
  gum style \
    --border thick --foreground "$RED_ERR_256" --background 232 \
    --padding "1 2" --margin 1 --align center --width 60 \
    "$@"
  echo
}

# Abort with a warning box and exit non-zero.
abort() {
  warning "Pre-flight failed" "" "$@"
  exit 1
}
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/style.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/style.sh && echo "style.sh ok"
```

- [ ] **Step 3.2: Write the entry point**

```bash
cat > iso/airootfs/usr/local/bin/ryoku-install <<'EOF'
#!/bin/bash
#
# Ryoku ISO installer entry point. Orchestrates 10 stages, sourced from
# /usr/local/lib/ryoku-install/. See spec at docs/superpowers/specs/
# 2026-04-24-ryoku-iso-installer-design.md.

set -eEo pipefail

LIB="/usr/local/lib/ryoku-install"
SHARE="/usr/local/share/ryoku-install"
LOG="/tmp/ryoku-install.log"

# Sanity: must be run as root (live ISO auto-logins as ryoku, but the
# installer needs root to partition disks; the wrapper drops to sudo
# automatically if the user is not already root).
if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

# Tee everything to /tmp/ryoku-install.log for post-mortem.
exec > >(tee -a "$LOG") 2>&1
echo "=== ryoku-install started $(date -Iseconds) ==="

source "$LIB/style.sh"

# Run each stage in sequence. Each stage exports the variables it
# discovers / collects (TARGET_DISK, USERNAME, HOSTNAME, etc.) so
# subsequent stages can read them. Failure in any stage exits non-zero
# (set -e); the trap below prints a friendly error and points at the log.
trap 'echo; warning "Installer aborted" "" "See $LOG for details."' ERR

source "$LIB/preflight.sh"      # stage 1
source "$LIB/prompts.sh"        # stages 2-4
source "$LIB/partition.sh"      # stage 5
source "$LIB/bootstrap.sh"      # stage 6
source "$LIB/chroot-setup.sh"   # stage 7
source "$LIB/bootloader.sh"     # stage 8
source "$LIB/firstboot.sh"      # stage 9
source "$LIB/reboot.sh"         # stage 10

echo "=== ryoku-install completed $(date -Iseconds) ==="
EOF
chmod 755 iso/airootfs/usr/local/bin/ryoku-install
bash -n iso/airootfs/usr/local/bin/ryoku-install && echo "ryoku-install ok"
```

- [ ] **Step 3.3: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/style.sh \
        iso/airootfs/usr/local/bin/ryoku-install
git commit -m "iso: installer entry point + gum style helpers"
```

---

### Task 4: Stage 1 (preflight)

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/preflight.sh`

- [ ] **Step 4.1: Write preflight.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/preflight.sh <<'EOF'
#!/bin/bash
# Stage 1: Pre-flight checks. Aborts the install if the live env can't
# host the kind of system Ryoku boot.sh expects.

stage_header 1 10 "Pre-flight"

info "Checking that the live environment can host a Ryoku install."

# UEFI mode required (limine + the spec assume UEFI).
if [[ ! -d /sys/firmware/efi ]]; then
  abort "UEFI mode required." "Reboot in UEFI mode and try again."
fi
info "✓ UEFI mode"

# Secure Boot must be off (limine cannot boot under Secure Boot without
# a signed binary; we do not ship one).
if bootctl status 2>/dev/null | grep -q 'Secure Boot: enabled'; then
  abort "Secure Boot must be disabled." \
        "Disable Secure Boot in your firmware setup, reboot, retry."
fi
info "✓ Secure Boot disabled"

# Network up (boot.sh curls itself from GitHub).
if ! ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
  abort "Network is required." \
        "Use 'nmtui' to connect to Wi-Fi, or check your ethernet cable."
fi
info "✓ Network OK"

# Suitable disks: at least one block device of type 'disk' that is at
# least 20 GiB. Small enough to flag obvious mistakes (a tiny USB) but
# permissive for real laptops.
mapfile -t disks < <(
  lsblk -dn -b -o NAME,SIZE,TYPE \
    | awk '$3=="disk" && $2 >= 20*1024*1024*1024 { print $1 }'
)
if (( ${#disks[@]} == 0 )); then
  abort "No suitable target disks found." \
        "Install requires a disk of at least 20 GiB."
fi
info "✓ ${#disks[@]} candidate disk(s) detected"

success "Pre-flight: OK"

# Export for stage 2 (disk selection).
export RYOKU_CANDIDATE_DISKS="${disks[*]}"
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/preflight.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/preflight.sh && echo "preflight.sh ok"
```

- [ ] **Step 4.2: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/preflight.sh
git commit -m "iso: installer stage 1 preflight (UEFI, secure boot, net, disks)"
```

---

### Task 5: Stages 2-4 (prompts: disk + user info + confirmation)

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/prompts.sh`

- [ ] **Step 5.1: Write prompts.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/prompts.sh <<'EOF'
#!/bin/bash
# Stages 2-4: gum-driven prompts for disk selection, user info,
# and final type-the-disk-name confirmation.

# --- Stage 2: disk selection -------------------------------------------------

stage_header 2 10 "Disk Selection"

info "Pick the disk to install Ryoku to. The selected disk WILL be erased."

# Build a labeled list: name (size, model)
disk_options=()
for d in $RYOKU_CANDIDATE_DISKS; do
  size=$(lsblk -dn -o SIZE "/dev/$d")
  model=$(lsblk -dn -o MODEL "/dev/$d" | sed 's/[[:space:]]*$//')
  disk_options+=("/dev/$d  ($size, ${model:-unknown model})")
done

selection=$(printf '%s\n' "${disk_options[@]}" \
  | gum choose --cursor.foreground 202 --header "Target disk")
TARGET_DISK="${selection%% *}"     # strip the description after the path

if [[ -z $TARGET_DISK ]]; then
  abort "No disk selected."
fi

success "Target: $TARGET_DISK"
export TARGET_DISK

# --- Stage 3: user config ----------------------------------------------------

stage_header 3 10 "User Configuration"

info "Set up your hostname, user, and disk passphrase."

HOSTNAME=$(gum input --prompt.foreground 202 \
  --prompt "Hostname ❯ " --placeholder "ryoku" --value "ryoku")
[[ -z $HOSTNAME ]] && HOSTNAME="ryoku"
export HOSTNAME

USERNAME=$(gum input --prompt.foreground 202 \
  --prompt "Username ❯ " --placeholder "your-name")
if [[ -z $USERNAME ]] || ! [[ $USERNAME =~ ^[a-z][a-z0-9_-]*$ ]]; then
  abort "Username must start with a lowercase letter and contain only" \
        "lowercase letters, digits, '-', or '_'."
fi
export USERNAME

# User password (twice, must match)
prompt_password() {
  local label="$1" min="$2" pw1 pw2
  while :; do
    pw1=$(gum input --password --prompt.foreground 202 \
            --prompt "${label} ❯ ")
    if (( ${#pw1} < min )); then
      info "Too short (minimum ${min} characters). Try again."
      continue
    fi
    pw2=$(gum input --password --prompt.foreground 202 \
            --prompt "${label} (confirm) ❯ ")
    if [[ $pw1 != "$pw2" ]]; then
      info "Passwords did not match. Try again."
      continue
    fi
    printf '%s' "$pw1"
    return
  done
}

USER_PW=$(prompt_password "User password" 8)
export USER_PW

ROOT_PW=$(prompt_password "Root password" 8)
export ROOT_PW

LUKS_PW=$(prompt_password "Disk encryption passphrase" 12)
export LUKS_PW

success "Configuration captured."

# --- Stage 4: review and confirm --------------------------------------------

stage_header 4 10 "Review and Confirm"

# Show what is currently on the target disk
gum style --foreground 248 \
  "Current contents of $TARGET_DISK:" "" \
  "$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$TARGET_DISK")"
echo

# Plan summary
gum style --border rounded --foreground 202 --padding "1 2" --width 60 \
  "Install plan" "" \
  "  Target disk      : $TARGET_DISK" \
  "  Hostname         : $HOSTNAME" \
  "  Username         : $USERNAME" \
  "  Filesystem       : btrfs (subvols: @ @home @snapshots @log @cache @pkg)" \
  "  Encryption       : LUKS2 (Argon2id, 1 GiB memory cost)" \
  "  Bootloader       : limine (UEFI)" \
  "  Snapshots        : enabled (snapper, configured by boot.sh)"
echo

warning "This WILL erase ALL data on $TARGET_DISK." \
        "" \
        "Type the disk name (e.g. $(basename "$TARGET_DISK")) to confirm:"

attempts=0
while (( attempts < 3 )); do
  echo
  typed=$(gum input --prompt.foreground 196 \
            --prompt "confirm ❯ " \
            --placeholder "$(basename "$TARGET_DISK")")
  if [[ $typed == "$(basename "$TARGET_DISK")" ]]; then
    success "Confirmed."
    return 0 2>/dev/null || true
    break
  fi
  attempts=$((attempts + 1))
  info "Mismatch ($attempts/3). The exact disk name is: $(basename "$TARGET_DISK")"
done

if (( attempts >= 3 )); then
  abort "Confirmation failed three times. Aborting."
fi
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/prompts.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/prompts.sh && echo "prompts.sh ok"
```

- [ ] **Step 5.2: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/prompts.sh
git commit -m "iso: installer stages 2-4 (disk select, user config, confirm)"
```

---

### Task 6: Stage 5 (partition + LUKS + btrfs)

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/partition.sh`

- [ ] **Step 6.1: Write partition.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/partition.sh <<'EOF'
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
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/partition.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/partition.sh && echo "partition.sh ok"
```

- [ ] **Step 6.2: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/partition.sh
git commit -m "iso: installer stage 5 (GPT + LUKS2 + btrfs subvolumes)"
```

---

### Task 7: Stage 6 (pacstrap) + Stage 7 (chroot setup)

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/bootstrap.sh`
- Create: `iso/airootfs/usr/local/lib/ryoku-install/chroot-setup.sh`

- [ ] **Step 7.1: Write bootstrap.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/bootstrap.sh <<'EOF'
#!/bin/bash
# Stage 6: pacstrap the minimum Arch base into /mnt.

stage_header 6 10 "Install Base System"

info "Installing the base Arch system to /mnt. This downloads ~350 MiB"
info "of packages and takes a few minutes."

# Read packages.list, ignore comments + blanks.
mapfile -t packages < <(
  grep -vE '^\s*(#|$)' /usr/local/share/ryoku-install/packages.list
)

if (( ${#packages[@]} == 0 )); then
  abort "packages.list is empty or unreadable."
fi

info "Pacstrap will install ${#packages[@]} packages."

# Run pacstrap. -K initializes a fresh keyring inside /mnt; without it,
# pacman in the chroot would have no trusted keys.
pacstrap -K /mnt "${packages[@]}"

# Generate fstab from the current /mnt mount state.
genfstab -U /mnt > /mnt/etc/fstab

# Sanity check: fstab must mention root and /efi.
if ! grep -q 'subvol=@' /mnt/etc/fstab || \
   ! grep -q '/efi' /mnt/etc/fstab; then
  abort "genfstab produced an incomplete /mnt/etc/fstab" \
        "Inspect /mnt/etc/fstab and rerun stage 6."
fi

success "Base system installed; fstab written."
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/bootstrap.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/bootstrap.sh && echo "bootstrap.sh ok"
```

- [ ] **Step 7.2: Write chroot-setup.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/chroot-setup.sh <<'EOF'
#!/bin/bash
# Stage 7: System configuration inside the new install (timezone,
# locale, hostname, user, sudoers, mkinitcpio with sd-encrypt).

stage_header 7 10 "Configure System"

info "Configuring timezone, locale, hostname, user, and initramfs."

# Best-effort timezone detection from current live env (the user can
# override later; this avoids an extra prompt for a default that is
# usually correct).
TZ=$(readlink -f /etc/localtime | sed 's|^/usr/share/zoneinfo/||')
[[ -z $TZ || ! -e "/usr/share/zoneinfo/$TZ" ]] && TZ="UTC"

# Run the configuration in a single chroot session.
arch-chroot /mnt /bin/bash -e <<CHROOT
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo '$HOSTNAME' > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

useradd -m -G wheel,audio,video,input,storage,network -s /bin/bash '$USERNAME'
printf '%s\n%s\n' '$ROOT_PW' '$ROOT_PW' | passwd root
printf '%s\n%s\n' '$USER_PW' '$USER_PW' | passwd '$USERNAME'
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# mkinitcpio with sd-encrypt for LUKS unlock at boot.
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

systemctl enable NetworkManager
CHROOT

success "System configured."
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/chroot-setup.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/chroot-setup.sh && echo "chroot-setup.sh ok"
```

- [ ] **Step 7.3: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/bootstrap.sh \
        iso/airootfs/usr/local/lib/ryoku-install/chroot-setup.sh
git commit -m "iso: installer stages 6-7 (pacstrap + chroot config)"
```

---

### Task 8: Stage 8 (limine bootloader)

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/bootloader.sh`

- [ ] **Step 8.1: Write bootloader.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/bootloader.sh <<'EOF'
#!/bin/bash
# Stage 8: Install limine to the EFI partition and write a basic limine
# config that unlocks LUKS at boot.
#
# The full snapper integration (limine-snapper-sync, limine-mkinitcpio-hook)
# is AUR-only; boot.sh's install pipeline pulls those later via Ryoku's
# AUR helper. Here we only do the minimum to make the system bootable.

stage_header 8 10 "Bootloader"

info "Installing limine to $EFI_PART."

arch-chroot /mnt /bin/bash -e <<CHROOT
mkdir -p /efi/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /efi/EFI/BOOT/

# Write a minimal limine.conf at /boot/limine.conf. limine reads its
# config from /boot/limine.conf by default in the EFI fallback path.
cat > /boot/limine.conf <<LIMINE
TIMEOUT=3
DEFAULT_ENTRY=1
INTERFACE_BRANDING=Ryoku Arch

:Ryoku Arch
    PROTOCOL=linux
    KERNEL_PATH=boot():/vmlinuz-linux
    MODULE_PATH=boot():/initramfs-linux.img
    CMDLINE=cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet

:Ryoku Arch (fallback)
    PROTOCOL=linux
    KERNEL_PATH=boot():/vmlinuz-linux
    MODULE_PATH=boot():/initramfs-linux-fallback.img
    CMDLINE=cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
LIMINE

cp /boot/limine.conf /efi/EFI/BOOT/limine.conf
CHROOT

success "Limine installed."
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/bootloader.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/bootloader.sh && echo "bootloader.sh ok"
```

- [ ] **Step 8.2: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/bootloader.sh
git commit -m "iso: installer stage 8 (limine to EFI, basic limine.conf with LUKS cmdline)"
```

---

### Task 9: Stage 9 (boot.sh handoff) + Stage 10 (reboot)

**Files:**
- Create: `iso/airootfs/usr/local/lib/ryoku-install/firstboot.sh`
- Create: `iso/airootfs/usr/local/lib/ryoku-install/reboot.sh`

- [ ] **Step 9.1: Write firstboot.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/firstboot.sh <<'EOF'
#!/bin/bash
# Stage 9: Inside the new install, fetch and run Ryoku's boot.sh as the
# new user. boot.sh's preflight passes because we set up limine + btrfs
# + (UEFI + non-root). install.sh then installs the full Ryoku layer.

stage_header 9 10 "Install Ryoku Layer"

info "Fetching boot.sh from GitHub and running it inside the new system."
info "This installs ~130 packages (Hyprland, Waybar, alacritty, fastfetch,"
info "themes, etc.) and lays down all Ryoku configs. It can take 10-20 min."

# Run boot.sh as the regular user inside the chroot. arch-chroot bind
# mounts /etc/resolv.conf so DNS works for the curl.
arch-chroot /mnt /bin/bash -e <<CHROOT
sudo -u '$USERNAME' bash -c '
  set -eEo pipefail
  cd "\$HOME"
  bash <(curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/boot.sh)
'
CHROOT

success "Ryoku layer installed."
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/firstboot.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/firstboot.sh && echo "firstboot.sh ok"
```

- [ ] **Step 9.2: Write reboot.sh**

```bash
cat > iso/airootfs/usr/local/lib/ryoku-install/reboot.sh <<'EOF'
#!/bin/bash
# Stage 10: Final stage. Confirm reboot, unmount /mnt cleanly, reboot.

stage_header 10 10 "Reboot"

success "Install complete. Welcome to Ryoku."
echo

info "After reboot, limine will prompt for your disk passphrase, then SDDM"
info "will auto-login to your Ryoku Hyprland desktop."

if gum confirm --prompt.foreground 202 \
     --selected.background 202 --selected.foreground 0 \
     "Reboot now?"; then
  umount -R /mnt
  cryptsetup close cryptroot 2>/dev/null || true
  reboot
else
  info "Reboot when ready: 'umount -R /mnt && reboot'"
fi
EOF
chmod 644 iso/airootfs/usr/local/lib/ryoku-install/reboot.sh
bash -n iso/airootfs/usr/local/lib/ryoku-install/reboot.sh && echo "reboot.sh ok"
```

- [ ] **Step 9.3: Commit**

```bash
git add iso/airootfs/usr/local/lib/ryoku-install/firstboot.sh \
        iso/airootfs/usr/local/lib/ryoku-install/reboot.sh
git commit -m "iso: installer stages 9-10 (boot.sh handoff + reboot)"
```

---

### Task 10: Update profiledef permissions + final build + QEMU end-to-end test

**Files:**
- Modify: `iso/releng-ryoku/profiledef.sh`
- Build artifact: `iso/out/ryoku-arch-*.iso`
- Test artifact: `/tmp/ryoku-test.qcow2`

- [ ] **Step 10.1: Update profiledef.sh file_permissions**

The new installer files need correct ownership/permissions in the ISO. Find the existing `file_permissions=( ... )` block and add entries for the new layout. Open `iso/releng-ryoku/profiledef.sh` and add these inside the `file_permissions=( ... )` array:

```bash
  ["/usr/local/bin/ryoku-install"]="0:0:755"
  ["/usr/local/lib/ryoku-install"]="0:0:755"
  ["/usr/local/lib/ryoku-install/style.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/preflight.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/prompts.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/partition.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/bootstrap.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/chroot-setup.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/bootloader.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/firstboot.sh"]="0:0:644"
  ["/usr/local/lib/ryoku-install/reboot.sh"]="0:0:644"
  ["/usr/local/share/ryoku-install"]="0:0:755"
  ["/usr/local/share/ryoku-install/banner.txt"]="0:0:644"
  ["/usr/local/share/ryoku-install/packages.list"]="0:0:644"
```

(Keep the existing `["/usr/local/bin/ryoku-install"]="0:0:755"` line if present; the new value overrides cleanly.)

Verify:

```bash
grep -c 'ryoku-install' iso/releng-ryoku/profiledef.sh
```

Expected: 14 (one for each entry above plus any pre-existing).

- [ ] **Step 10.2: Build the ISO**

```bash
sudo -n bash -c 'rm -rf /tmp/ryoku-iso-work && rm -f /home/omi/prowl/ryoku-arch/iso/out/*.iso'
sudo -n bash /home/omi/prowl/ryoku-arch/iso/build.sh > /tmp/ryoku-iso-build.log 2>&1
echo "build exit=$?"
ls -lh /home/omi/prowl/ryoku-arch/iso/out/
```

Expected: `iso/out/ryoku-arch-<date>-x86_64.iso` exists, ~2.1 GiB.

If the build fails: `tail -40 /tmp/ryoku-iso-build.log`.

- [ ] **Step 10.3: Boot the ISO in QEMU with UEFI firmware**

```bash
rm -f /tmp/ryoku-test.qcow2
qemu-img create -f qcow2 /tmp/ryoku-test.qcow2 25G

qemu-system-x86_64 \
  -enable-kvm -cpu host -m 4G -smp 2 \
  -bios /usr/share/edk2/x64/OVMF.4m.fd \
  -drive file=/tmp/ryoku-test.qcow2,format=qcow2,if=virtio \
  -boot d -cdrom /home/omi/prowl/ryoku-arch/iso/out/ryoku-arch-*.iso \
  -netdev user,id=net0 -device virtio-net,netdev=net0 \
  -display gtk &

sleep 3
pgrep -a qemu-system-x86 | head
```

Expected: a QEMU window opens, boots the live ISO into Hyprland with the welcome banner. Click into the window and run `ryoku-install`.

- [ ] **Step 10.4: Walk the installer end-to-end (manual)**

Inside the QEMU VM, in the Alacritty terminal:

```bash
ryoku-install
```

Walk all 10 stages:

1. Pre-flight (should report ✓ for all 4 checks)
2. Disk Selection (pick `/dev/vda`)
3. User Configuration (pick a hostname, user, passwords)
4. Review and Confirm (type `vda` to confirm)
5. Partition (watch the gum spinners)
6. Install Base System (a few minutes; pacstrap progress)
7. Configure System (instant)
8. Bootloader (instant)
9. Install Ryoku Layer (10-20 minutes; this is boot.sh + install.sh on top)
10. Reboot (confirm yes)

After the VM reboots, expect: limine prompt for the LUKS passphrase, kernel boots, SDDM auto-logins, Hyprland desktop comes up with full Ryoku branding.

If any stage fails, inspect `/tmp/ryoku-install.log` inside the VM (the live env, before reboot) and report.

- [ ] **Step 10.5: Replace existing ryoku-install (only if profiledef changes broke anything)**

The new `iso/airootfs/usr/local/bin/ryoku-install` already overwrites the old archinstall wrapper because Task 3 wrote to the same path. Confirm:

```bash
head -5 iso/airootfs/usr/local/bin/ryoku-install
```

Expected: the new entry-point header (`# Ryoku ISO installer entry point.`), not the old archinstall wrapper.

- [ ] **Step 10.6: Commit profiledef changes + push**

```bash
git add iso/releng-ryoku/profiledef.sh
git commit -m "iso: profiledef permissions for new ryoku-install modules"
git push origin main
```

Expected: push of all the task commits. Origin/main now has the full installer.

---

## Rollback

```bash
# Reset dev clone to the snapshot tag.
cd /home/omi/prowl/ryoku-arch
git reset --hard pre-iso-installer-design

# Force-push if the new commits had been pushed.
git push --force-with-lease origin main

# Reset installed tree the same way.
git -C ~/.local/share/ryoku fetch origin
git -C ~/.local/share/ryoku reset --hard origin/main
```

The old `archinstall` wrapper at `iso/airootfs/usr/local/bin/ryoku-install` is restored by the snapshot.

---

## Self-review

**Spec coverage:**

| Spec section | Covered by |
|---|---|
| Goals 1-6 | Tasks 3-10 |
| Non-goals (no Calamares, no archinstall, single-disk, no swap) | Honored (no archinstall path, single-disk only, no swap setup) |
| Locked decisions (limine, btrfs, LUKS2, gum, no own mirror) | Tasks 6, 7, 8 |
| Architecture (10-stage layout) | Tasks 4-9 (one stage per task or pair) |
| File layout | Tasks 2, 3 |
| Disk + LUKS + btrfs layout | Task 6 |
| Pacstrap package set | Task 2 (data file) |
| Chroot setup steps | Task 7 |
| Bootloader stage | Task 8 |
| boot.sh handoff stage 9 | Task 9 |
| Visual style (gum) | Task 3 (style helpers) + every stage uses them |
| Failure modes | Each stage `set -eEo pipefail` + abort calls + ERR trap in entry point |
| Testing plan | Task 10 (build + QEMU end-to-end) |
| Snapshot tag | Task 1 |

Snapper integration (limine-snapper-sync, limine-mkinitcpio-hook, snapper config) is deferred to boot.sh's existing AUR pipeline (`install/login/limine-snapper.sh`) because those packages are AUR-only and pacstrap can't pull them directly. End state matches the spec; the responsibility shifts from stage 8 to boot.sh.

**Placeholder scan:** searched for `TBD`, `TODO`, `XXX`, `FIXME`, `implement later`. None present in this plan.

**Type / variable consistency:**

- `TARGET_DISK`, `EFI_PART`, `ROOT_PART`, `LUKS_UUID`, `HOSTNAME`, `USERNAME`, `USER_PW`, `ROOT_PW`, `LUKS_PW`, `RYOKU_CANDIDATE_DISKS`: defined in early stages and consumed in later stages. Verified each is set before first use.
- `stage_header N TOTAL TITLE`, `info`, `success`, `warning`, `abort`: defined in `style.sh`, used uniformly across all stages.
- `arch-chroot /mnt`: uniform mount target.
- `/dev/mapper/cryptroot`: uniform LUKS-open name.
- `cryptdevice=UUID=$LUKS_UUID:cryptroot`: used in mkinitcpio hooks (sd-encrypt) AND the limine cmdline. Consistent.
