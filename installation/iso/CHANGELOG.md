# Changelog

## Unreleased

### Added
- Add the Ryoku live ISO profile (archiso, releng-based).
  - `profiledef.sh`: iso_name `ryoku`, label `RYOKU_<YYYYMM>`, date-stamped
    version, `install_dir=arch`, BIOS (syslinux) and UEFI (systemd-boot) boot
    modes, x86_64, zstd squashfs, and file permissions for the launchers.
  - `packages.x86_64`: the live environment only. Base system, kernel, archiso
    hooks, both bootloaders, the backend toolchain, NetworkManager + iwd, and
    cage + foot + the JetBrains Mono Nerd Font. No Go: the TUI ships prebuilt.
  - airootfs overlay: root autologin on tty1, a tty1-only login path
    (`.bash_profile` -> `.zlogin`), and `ryoku-installer-session`, which runs the
    TUI in cage + foot with a crash-relaunch loop and exports `RYOKU_REPO` and
    `RYOKU_BACKEND`. NetworkManager is enabled with iwd as its Wi-Fi backend so
    the TUI's `nmcli` calls work. The serial console stays a plain root shell.
  - `build.sh`: stages a throwaway copy of the profile, builds the TUI from
    `../tui`, bakes the TUI, the backend (under `/usr/local/lib/ryoku/backend`
    with a `/usr/local/bin/ryoku-install` wrapper), and the repo payload (at
    `/usr/share/ryoku`, tracked files only via `git archive`) into the staged
    airootfs, then runs `mkarchiso`. The committed profile is never mutated.

### Fixed
- Drop the inline comments from `packages.x86_64`: mkarchiso left their trailing
  whitespace on the package names, so pacstrap reported "target not found".
- Suppress `systemd-firstboot`: ship `/etc/locale.conf`, `hostname`, `localtime`,
  and `vconsole.conf` and mask the service, so the image autostarts the installer
  instead of the stock Arch "Initial Setup" prompt.
- Ship a working `/etc/pacman.d/mirrorlist` (worldwide geo mirror plus global
  backups); the default all-commented list left pacstrap with no servers.
- Initialize the live pacman keyring: ship and enable `pacman-init.service` plus
  the gnupg tmpfs mount (as releng does), so pacstrap can verify packages.
- Force a truecolor TUI and quiet the boot: the session exports
  `COLORTERM=truecolor`, and the kernel cmdline gains `quiet loglevel=3` to hide
  amdgpu link-training console spam before the installer.
- Add `xorg-xwayland` to the live image so cage can start its Xwayland server
  (removes the "cannot create xwayland server" error).
