# Changelog: installation/

## Unreleased

### Added
- `tui/`: the installer, a full-screen Go (Bubble Tea) TUI. `main.go` is the UI;
  `system.go` talks to the machine (live keymaps, locales, time zones, disks, and
  Wi-Fi, hardware detection, applying the keymap, hashing the password, and the
  streamed handoff to the backend).
- `backend/`: `ryoku-install` plus `lib/` (preflight, disk, luks, filesystem,
  pacstrap, chroot, deploy, drivers, bootloader). Reads the RYOKU_* answers and
  installs the system end to end. A dry-run mode prints every step.
- `iso/`: an archiso profile that boots straight into the TUI (cage and foot
  autolaunch), with a `build.sh` wrapper.

### Changed
- TUI: the intro holds the brand about 5 seconds longer before the wizard.
- TUI network step: recheck connectivity on entry (so a late ethernet lease shows
  as connected), show the real interface, and add an `r` rescan to the Wi-Fi picker.

### Fixed
- The live ISO now autostarts the installer instead of the stock Arch first-boot
  prompt, pacstrap has working mirrors and a populated keyring, and the boot
  console is quiet. See the `iso/` and `backend/` changelogs for detail.
- The installed desktop now ships the packages and NVIDIA KMS config it needs to
  render (Xwayland, the polkit agent, the Qt/GTK runtime), and the first reboot
  targets the installed disk via EFI BootNext. See `system/` and the iso/backend
  changelogs.
