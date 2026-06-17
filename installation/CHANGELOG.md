# Changelog: installation/

## Unreleased

### Added
- `tui/`: the installer, a full-screen Go (Bubble Tea) TUI. `main.go` is the UI;
  `system.go` talks to the machine (live keymaps, locales, time zones, disks, and
  Wi-Fi, hardware detection, applying the keymap, hashing the password, and the
  streamed handoff to the backend).
- `backend/`: `ryoku-install` plus `lib/` (preflight, disk, luks, filesystem,
  pacstrap, chroot, bootloader, deploy). Reads the RYOKU_* answers and installs
  the system end to end. A dry-run mode prints every step without touching disks.
- `iso/`: an archiso profile that boots straight into the TUI (cage and foot
  autolaunch), with a `build.sh` wrapper.
