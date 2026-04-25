# Ryoku ISO Installer Design

## Context

Ryoku currently ships a graphical live ISO that boots into Hyprland with a welcome banner. The banner prompts users to run `ryoku-install`, which today is a thin wrapper around `archinstall` plus an `arch-chroot` that runs `boot.sh`. In testing this fails: `boot.sh` inherits Omarchy's preflight guards which require the live system to already have `limine` bootloader and a `btrfs` root filesystem. `archinstall`'s defaults give us GRUB plus ext4, so preflight aborts and the install never reaches Ryoku-layer-on-top.

This spec replaces the `archinstall` wrapper with a custom bash installer modeled on Omarchy's pattern (the part of Omarchy's stack that lives in their PRIVATE ISO build and is therefore not in their public repo). The new installer takes raw partitions, sets up LUKS plus btrfs plus limine plus snapper, then chroots and runs our existing `boot.sh` exactly as Omarchy intends. The result is a production-quality, faithful Ryoku install that matches Omarchy's runtime characteristics (snapshot rollback, encrypted root, limine boot menu) while keeping all install scripts in our public GitHub repo.

## Goals

1. A fresh user boots the Ryoku ISO and reaches a fully working Ryoku desktop after one install pass, no manual recovery required.
2. The new install is encrypted at rest by default (LUKS2 on the root filesystem).
3. Snapshot rollback works out of the box: snapper takes snapshots of `/` and `/home`, limine-snapper-sync exposes them in the boot menu, broken updates are recoverable by booting an older snapshot.
4. Ryoku branding is consistent end to end: the installer uses the same orange + subdued palette as the desktop, in lipgloss-style boxed UI via `gum`.
5. Install scripts continue to live in `neur0map/ryoku-arch` and the ISO's installer pulls our `boot.sh` from there at install time. No private mirror infrastructure required.
6. The installer is split into modules so each phase is independently testable and replaceable.

## Non-goals

- No Calamares-style GUI installer. TUI via gum only.
- No own pacman mirror infrastructure (`mirror.ryoku.sh` etc.). Stock Arch mirrors via `reflector` are sufficient for early-stage usage. Mirror infra can come in a later phase if Ryoku takes off.
- No multi-disk RAID, no LVM, no btrfs RAID profiles. Single-disk install only.
- No swap partition. ZRAM via the Ryoku desktop post-install handles compressed memory swap.
- No archinstall integration. archinstall is on Arch's deprecation curve and our needs (limine, btrfs subvolume layout, LUKS) are tightly coupled to Omarchy's pattern; rolling our own keeps us upstream-independent.
- No automated tests. Manual QEMU testing only at this stage. CI can come later.
- No accessibility features (screen reader, high-contrast mode) in this iteration.

## Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Pre-existing-Arch requirements | Match Omarchy's preflight (limine + btrfs + UEFI + secure-boot-off + not-root + x86_64 + no-Gnome-or-KDE) | Boot.sh already has those guards inherited from Omarchy. The installer's job is to produce a system that satisfies them. |
| Bootloader | limine | Required by boot.sh's preflight guard. Also ships with `limine-snapper-sync` for snapshot booting. |
| Filesystem | btrfs with subvolumes | Required by boot.sh's preflight guard. Also enables snapshot rollback. |
| Disk encryption | LUKS2 always on (option A from brainstorming) | Security-focused distro should not have plaintext disks as default. |
| Implementation language | bash | Consistent with rest of Ryoku (`ryoku-*` commands are bash). |
| TUI library | `gum` (charmbracelet) | lipgloss-quality styling, same vendor as the user's preference, already used elsewhere in Ryoku. |
| archinstall | Not used | Deprecation curve; tight coupling to limine + btrfs + LUKS works better with bespoke partitioning. |
| Install scripts location | GitHub repo `neur0map/ryoku-arch`, fetched via curl-to-shell | Same pattern Omarchy uses for their PUBLIC scripts. No private mirror needed. |

## Architecture overview

The live ISO already boots into Hyprland and runs `ryoku-welcome` in a fullscreen Alacritty (current behavior, no change in this spec). The welcome banner instructs the user to run `ryoku-install`. That command is the ten-stage installer documented below.

```
ryoku-install (entry point, ~50 lines)
  │
  ├─ Stage 1   preflight.sh        UEFI mode, secure boot off, network up, target disks listed
  ├─ Stage 2   prompts.sh         disk selection (gum choose from lsblk)
  ├─ Stage 3   prompts.sh         hostname, username, user password, LUKS passphrase
  ├─ Stage 4   prompts.sh         review screen + type-the-disk-name confirmation
  ├─ Stage 5   partition.sh       GPT, EFI partition, LUKS2, btrfs subvolumes, mount at /mnt
  ├─ Stage 6   bootstrap.sh       pacstrap base + limine + btrfs-progs + cryptsetup + others
  ├─ Stage 7   chroot-setup.sh    timezone, locale, hostname, user, sudoers, fstab, mkinitcpio
  ├─ Stage 8   bootloader.sh      limine to EFI, limine.conf with LUKS cmdline, snapper config
  ├─ Stage 9   firstboot.sh       arch-chroot, sudo -u $USER, curl-to-shell our boot.sh
  └─ Stage 10  reboot.sh          gum confirm, umount /mnt, reboot
```

Each module is independently invocable for debugging. Stage 5 can be tested standalone by running `bash partition.sh /dev/vdb` against a scratch disk.

## File layout in the repo

All installer files ship inside the live ISO's `airootfs`, which means they are part of the live filesystem the user runs from. The build process copies them from the repo into the ISO via `mkarchiso`.

```
iso/airootfs/usr/local/bin/
  ryoku-install                # entry point, sources lib/ modules in order

iso/airootfs/usr/local/lib/ryoku-install/
  preflight.sh                 # stage 1
  prompts.sh                   # stages 2-4
  partition.sh                 # stage 5
  bootstrap.sh                 # stage 6
  chroot-setup.sh              # stage 7
  bootloader.sh                # stage 8
  firstboot.sh                 # script that runs INSIDE the chroot in stage 9
  reboot.sh                    # stage 10

iso/airootfs/usr/local/share/ryoku-install/
  banner.txt                   # the kanji + RYOKU wordmark used as install header
  packages.list                # one-per-line minimum-pacstrap package set
```

The existing `iso/airootfs/usr/local/bin/ryoku-install` (the archinstall wrapper) gets fully replaced. The current `ryoku-welcome` script is unchanged (it still launches in Hyprland on first boot and tells the user to run `ryoku-install`).

## Disk + LUKS + btrfs layout

GPT partition table on the user-selected target disk. Two partitions:

| Partition | Size | Type | Filesystem | Mountpoint | Encrypted |
|---|---|---|---|---|---|
| 1 | 1 GiB | EFI System (`ef00`) | FAT32 | `/efi` | no |
| 2 | rest | LUKS2 container (`8309`) | btrfs (inside LUKS) | see subvolumes | yes |

btrfs subvolumes inside the LUKS container:

| Subvolume | Mountpoint | Mount flags | NOCOW |
|---|---|---|---|
| `@` | `/` | `noatime,compress=zstd:3,ssd,space_cache=v2` | no |
| `@home` | `/home` | same | no |
| `@snapshots` | `/.snapshots` | same | no |
| `@log` | `/var/log` | same | yes (`chattr +C` post-creation) |
| `@cache` | `/var/cache` | same | yes |
| `@pkg` | `/var/cache/pacman/pkg` | same | yes |

Mount-flag rationale: `compress=zstd:3` is a strong compression-vs-CPU tradeoff (level 3 is the btrfs default for good reason). `noatime` removes a per-read write that adds nothing for a desktop. `ssd` and `discard=async` are added if the target reports `rotational=0`. `space_cache=v2` is the modern free-space tracking format. NOCOW on `@log`, `@cache`, `@pkg` because those directories see heavy random rewrites that fragment under btrfs CoW; turning off CoW for them is the standard guidance.

LUKS settings: `luksFormat --type luks2 --pbkdf argon2id --pbkdf-memory 1048576 --pbkdf-parallel 4`. Argon2id with 1 GiB memory cost is the modern default and resists offline brute force on commodity GPUs.

Boot path: limine prompts for the LUKS passphrase before the kernel loads. Single passphrase prompt because EFI is unencrypted and the kernel + initramfs live on the encrypted root via the ENABLE_UKI=no path with limine fetching the kernel directly from `/boot` after unlock.

## Pacstrap minimum package set

15 packages, listed in `iso/airootfs/usr/local/share/ryoku-install/packages.list` for easy editing without touching shell code:

```
base
base-devel
linux
linux-firmware
btrfs-progs
cryptsetup
limine
limine-snapper-sync
limine-mkinitcpio-hook
networkmanager
iwd
sudo
curl
git
intel-ucode
amd-ucode
nano
```

(One file with one package per line, comments allowed via `#`.) These give us a bootable system that can curl boot.sh. boot.sh + install.sh add the remaining ~130 Ryoku base packages.

## Chroot setup (stage 7)

Run from outside the chroot: `genfstab -U /mnt >> /mnt/etc/fstab`.

Run inside `arch-chroot /mnt`:

```bash
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

useradd -m -G wheel,audio,video,input,storage,network -s /bin/bash "$USERNAME"
printf '%s\n%s\n' "$ROOT_PW" "$ROOT_PW" | passwd root
printf '%s\n%s\n' "$USER_PW" "$USER_PW" | passwd "$USERNAME"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel

# mkinitcpio for LUKS + btrfs
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

systemctl enable NetworkManager
```

## Bootloader (stage 8)

```bash
# UEFI install
mkdir -p /efi/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /efi/EFI/BOOT/

LUKS_UUID=$(blkid -s UUID -o value /dev/${disk}2)

cat > /etc/default/limine <<EOF
KERNEL_CMDLINE[default]="cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet splash"
ENABLE_UKI=no
ENABLE_LIMINE_FALLBACK=yes
EOF

limine-update    # generates /boot/limine.conf with kernel entries

# Snapper config
snapper -c root create-config /
snapper -c home create-config /home
systemctl enable limine-snapper-sync.service
systemctl enable snapper-timeline.timer snapper-cleanup.timer
```

## boot.sh handoff (stage 9)

From outside the chroot, run our existing boot.sh inside it as the new user:

```bash
arch-chroot /mnt sudo -u "$USERNAME" bash -c '
  set -eEo pipefail
  cd "$HOME"
  bash <(curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/boot.sh)
'
```

`arch-chroot` mounts the live ISO's `/etc/resolv.conf` over the new system, so the chroot has working DNS for the curl. boot.sh runs as the new user inside the new system. Its preflight guards (limine present, btrfs root, not running as root, secure boot off, no Gnome/KDE) all pass. install.sh runs the full Ryoku layer-on-top: ~130 packages, configs, SDDM, Plymouth, limine-snapper integration, post-install scripts.

## Visual style

All stages follow the same gum-styled header pattern so the user always knows where they are:

```
╔════════════════════════════════════════════════╗
║              Ryoku Installer                   ║
║          Stage 5/10: Partition Disk            ║
╚════════════════════════════════════════════════╝
```

Built with `gum style --border double --foreground 202 --padding "1 2" --margin 1 --align center --width 56`. (`202` is the closest 256-color match to Ryoku orange `#F25623`; gum's `--foreground` accepts truecolor too via `#F25623` syntax for terminals that support it, with 202 as the fallback.)

| UI element | Style |
|---|---|
| Stage header | double border, foreground 202 (orange), centered, padded |
| Info paragraph | foreground 248 (subdued) |
| Choice menu | `gum choose` with cursor in orange |
| Text input | `gum input` with prompt in orange |
| Password input | `gum input --password` with prompt in orange, dots only |
| Warning box | thick border, foreground 196 (bright red), background 232 (near-black) |
| Confirmation | `gum confirm` with prompt in orange |
| Spinner | `gum spin --spinner dot --title "..."` for long-running commands |
| Success message | foreground 35 (green), bold, with `✓` glyph |

The disk-wipe confirmation in stage 4 is the only screen using the warning style, so it stands out visually from every other prompt. It shows `lsblk` output for the target disk so the user sees what is currently there, then requires the user to type the disk name (e.g. `nvme0n1`) to confirm. Three retries before abort.

## Failure modes

| Failure | Stage | Handling |
|---|---|---|
| BIOS-mode firmware (no `/sys/firmware/efi`) | 1 | Abort with help text linking to UEFI instructions |
| Secure Boot enabled (`bootctl status` reports it) | 1 | Abort with help text |
| No network (ping 1.1.1.1 fails) | 1 | Abort with `nmtui` recovery hint |
| No suitable target disks (no rotational=0/1 disks larger than 20 GiB) | 2 | Abort |
| LUKS passphrase shorter than 8 chars | 3 | Re-prompt with warning |
| User typed wrong disk name in stage 4 | 4 | Re-prompt up to 3 times, abort cleanly |
| `cryptsetup luksFormat` fails | 5 | Abort, leave partitions in known-bad state, point at log |
| `pacstrap` fails | 6 | pacman retries on its own; on hard fail, abort with last 50 lines of pacman log |
| `genfstab` produces empty fstab | 7 | Catch via post-genfstab grep, abort |
| `limine-update` fails | 8 | Abort with last 50 lines |
| boot.sh fails inside chroot (Ryoku layer install errors) | 9 | Trap, leave partial install in place, print recovery instructions: "rerun arch-chroot /mnt sudo -u $USERNAME bash -c '<curl boot.sh>'" |
| Power loss mid-install | any | No automatic recovery. Document that the user reboots, opens LUKS via the live ISO, mounts, and re-runs the failed stage |

All errors log to `/tmp/ryoku-install.log` so the user can attach it when reporting issues.

## Testing plan

Iteration loop:

1. `sudo bash iso/build.sh` (~5 min)
2. `qemu-system-x86_64 -enable-kvm -cpu host -m 4G -smp 2 -bios /usr/share/edk2/x64/OVMF.4m.fd -drive file=/tmp/ryoku-test.qcow2,format=qcow2,if=virtio -boot d -cdrom iso/out/ryoku-arch-*.iso -netdev user,id=net0 -device virtio-net,netdev=net0 -display gtk`
   - OVMF is the UEFI firmware. Required because installer mandates UEFI.
3. Walk through all 10 stages, screenshot each.
4. Verify post-reboot: limine prompts for LUKS passphrase, kernel boots, SDDM autologins, Hyprland comes up with full Ryoku branding.
5. Snapshot rollback test: take a manual snapper snapshot, break something (e.g. delete `/usr/bin/Hyprland`), reboot, pick the snapshot in limine menu, verify recovery.

Required host packages added to support testing (one-time):

```
sudo pacman -S --needed edk2-ovmf
```

## Known limitations / Phase 2+

- TUI only. Calamares-style GUI installer is a separate spec.
- Single-disk only (no RAID, no multi-disk pools, no LVM).
- No swap partition (ZRAM via post-install fills the role).
- No accessibility features.
- The live ISO welcome screen is currently a fullscreen Alacritty with the banner; future polish could add a Waybar bar to the live env, a Plymouth boot splash for the ISO, and live preview of the Ryoku desktop without committing to install.
- No live demo of fully-themed Ryoku desktop. The live ISO boots into Hyprland but only shows the welcome screen; a fully-themed live preview is a separate work item.
- Mirror infrastructure (`mirror.ryoku.sh` analogue to Omarchy's `stable-mirror.omarchy.org`) is deferred. Stock Arch mirrors via `reflector` are sufficient until usage justifies the operational burden.

## Snapshot and rollback

Before implementation begins: tag `pre-iso-installer-design` at current dev-clone HEAD and push. Rollback is one command in both trees plus removal of the `iso/airootfs/usr/local/lib/ryoku-install/` directory.

The current `iso/airootfs/usr/local/bin/ryoku-install` (archinstall wrapper) is replaced wholesale; the snapshot tag captures its previous state for rollback.
