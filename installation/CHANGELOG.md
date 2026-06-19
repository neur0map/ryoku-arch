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
- The `Ryoku.Blobs` QML plugin (the shell's frame renderer) now rides the install
  path: `iso/build.sh` prebuilds the module into the payload (cmake, ninja, and
  qt6-shadertools on the build host), and `backend/lib/deploy.sh` installs it onto
  the user's Qt QML import path, so the installed desktop renders the frame with
  no build toolchain on the target.

### Changed
- TUI: the intro holds the brand about 5 seconds longer before the wizard.
- TUI network step: recheck connectivity on entry (so a late ethernet lease shows
  as connected), show the real interface, and add an `r` rescan to the Wi-Fi picker.
- TUI: the install-failure screen's support QR now points at `docs.ryoku.dev`.

### Fixed
- The live ISO now autostarts the installer instead of the stock Arch first-boot
  prompt, pacstrap has working mirrors and a populated keyring, and the boot
  console is quiet. See the `iso/` and `backend/` changelogs for detail.
- The installed desktop now ships the packages and NVIDIA KMS config it needs to
  render (Xwayland, the polkit agent, the Qt/GTK runtime), and the first reboot
  targets the installed disk via EFI BootNext. See `system/` and the iso/backend
  changelogs.
- TUI partition step: the swapfile is carved out of the root size and shown in the
  disk bar, so increasing swap now reduces the usable root instead of leaving the
  total unchanged. Root always takes the rest of the disk (the backend uses 100%),
  so the misleading editable root-size slider and the fake free-space line are gone.
- TUI done screen: "Reboot now" and "Power off" now actually run `systemctl
  reboot` / `systemctl poweroff` on Enter; before, every choice just quit the
  installer and the machine stayed in the live session. "Exit to a shell" still
  drops to a prompt.
