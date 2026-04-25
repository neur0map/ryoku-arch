# Ryoku Arch ISO

Live ISO for installing Ryoku to a real disk. Boots into an Arch live
environment, prints a Ryoku-orange welcome banner, and exposes a single
helper command `ryoku-install` that wraps `archinstall` plus Ryoku's
`boot.sh`.

## Layout

- `releng-ryoku/` : archiso profile, derived from upstream `releng`.
  - `profiledef.sh` : Ryoku ISO metadata (label, name, version).
  - `airootfs/etc/motd` : Ryoku-orange welcome banner shown on login.
  - `airootfs/usr/local/bin/ryoku-install` : installer wrapper.
  - All other files inherited verbatim from upstream `releng`. Re-sync
    if a future archiso release ships meaningful changes.

## Building

Requires `archiso` and root (mkarchiso writes to a work directory and
calls `pacstrap`).

```bash
sudo bash iso/build.sh
```

That wraps:

```bash
sudo mkarchiso -v -w /tmp/ryoku-iso-work -o iso/out iso/releng-ryoku
```

The output `.iso` lands in `iso/out/`. Build takes ~10 to 30 minutes
depending on hardware and pacman mirror speed. Output is ~1.5 to 2 GB.

The `iso/out/` directory is git-ignored (see `.gitignore`).

## Testing in QEMU

After a successful build:

```bash
qemu-system-x86_64 \
  -enable-kvm -cpu host -m 4G -smp 2 \
  -boot d -cdrom iso/out/ryoku-arch-*.iso \
  -drive file=ryoku-test.qcow2,format=qcow2,if=virtio \
  -netdev user,id=net0 -device virtio-net,netdev=net0 \
  -display gtk
```

(Create the test disk first: `qemu-img create -f qcow2 ryoku-test.qcow2 25G`.)

Inside the VM:

1. Auto-login as root.
2. Read the MOTD.
3. Run `ryoku-install`.
4. Walk through `archinstall` (pick disk, timezone, locale, hostname,
   create regular user, skip the install-profile step).
5. After archinstall completes, the wrapper chroots into `/mnt` and runs
   `boot.sh` as the regular user. This is where Ryoku itself installs.
6. When that finishes, type `reboot` to drop the ISO and boot into the
   newly installed Ryoku desktop.

## What the ISO does NOT do (yet)

- No Calamares-style graphical partitioning. `archinstall` is text mode.
- No live preview of the Ryoku desktop from the ISO. The live env is
  bare Arch; Ryoku only appears after install.
- No Ryoku boot splash or branded grub theme. Boot menu is upstream.

These are tracked as polish work for a future iteration.
