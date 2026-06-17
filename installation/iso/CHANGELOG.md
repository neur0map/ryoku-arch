# Changelog

## Unreleased

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
    `/usr/share/ryoku`) into the staged airootfs, then runs `mkarchiso`. The
    committed profile is never mutated.
