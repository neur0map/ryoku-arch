# installation/iso/

The Ryoku live ISO. It is a standard Arch live image (built with `mkarchiso`,
based on the official `releng` profile) with one job: boot a machine and drop you
straight into the Ryoku installer.

## What it does at boot

1. The kernel and the archiso initramfs bring up the live system from the
   squashfs.
2. `agetty` logs root in automatically on the first console (tty1), with no
   password.
3. The login shell runs `ryoku-installer-session`, which starts a tiny Wayland
   kiosk (`cage`) running a terminal (`foot`) that runs the installer
   (`ryoku-tui`).
4. The TUI collects your answers and hands them to the backend (`ryoku-install`),
   which partitions, formats, installs the base system with `pacstrap`, and sets
   up the bootloader.

The graphical session only ever draws text, so it uses software rendering
(`WLR_RENDERER=pixman`) and works in VMs and on machines without working GPU GL.
The reason for `cage` + `foot` instead of the bare kernel console is color: the
kernel VT has 16 colors and no Nerd Font glyphs, so the TUI would fall back to
plain ASCII. `foot` gives it a truecolor terminal with the JetBrains Mono Nerd
Font, which is what the TUI is designed for.

If the installer crashes, the session relaunches it so the console never drops to
a bare prompt mid-install. A clean quit returns you to a root shell.

The serial console (ttyS0) and any other VT stay a plain root shell, so headless
or recovery use still works: set the `RYOKU_*` answers and run `ryoku-install`
by hand (the payload it reads is at `/usr/share/ryoku`).

## What is baked in

The committed profile holds only the live environment definition. The installer
itself and the repo payload are added by `build.sh` at build time, so binaries
are never committed here.

Live environment packages (`packages.x86_64`): the base system and kernel, the
archiso boot hooks, both bootloaders (syslinux for BIOS, systemd-boot for UEFI),
the backend toolchain (partitioning, filesystems, pacstrap, Limine),
NetworkManager + iwd for Wi-Fi, and `cage` + `foot` + the Nerd Font for the
installer session. There is no Go toolchain on the ISO: the TUI ships prebuilt.

The target system's own packages are not in this list. The backend installs them
with `pacstrap` from `system/packages` at install time.

## On-ISO layout

What `build.sh` places into the image:

```
/usr/local/bin/ryoku-tui                  the prebuilt installer TUI (Go)
/usr/local/bin/ryoku-install              wrapper: execs the backend below
/usr/local/bin/ryoku-installer-session    the cage + foot + ryoku-tui launcher
/usr/local/lib/ryoku/backend/ryoku-install   the real backend script
/usr/local/lib/ryoku/backend/lib/*           the backend's library (sourced)
/usr/share/ryoku/                         the repo payload (RYOKU_REPO)
```

The backend finds its `lib/` by resolving the real path of its own script, so the
real script and its `lib/` must live together. They do, under
`/usr/local/lib/ryoku/backend`. The `/usr/local/bin/ryoku-install` wrapper just
`exec`s the real script, so `realpath` still points at the backend directory and
the library is found. The installer session exports `RYOKU_REPO=/usr/share/ryoku`
and `RYOKU_BACKEND=ryoku-install`, which is how the TUI locates both the payload
and the backend on `PATH`.

## Building it

`build.sh` does everything: it stages a throwaway copy of this profile, builds
the TUI from `../tui`, bakes the TUI, the backend, and the repo into the staged
airootfs, and then runs `mkarchiso`. The committed profile is never modified.

Requirements on the build host: `go` (to compile the TUI), `archiso` (for
`mkarchiso`), and root (mkarchiso needs it).

```
cd installation/iso
./build.sh
```

The ISO lands in `installation/iso/out/`. To stage everything but stop before
`mkarchiso` (useful without root):

```
./build.sh --stage-only
```

If `mkarchiso` is missing, `build.sh` stages the profile and prints the exact
command to finish by hand:

```
sudo mkarchiso -v -w work -o out ./staging/profile
```

Output, work, and staging directories live under `installation/iso/` and are
git-ignored.
