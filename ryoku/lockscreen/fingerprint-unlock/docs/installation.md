# Installation Guide

## Prerequisites

Before installing, verify you have:

1. **fprintd** installed and running:
   ```sh
   systemctl status fprintd
   ```

2. **At least one finger enrolled**:
   ```sh
   fprintd-list $(whoami)
   ```
   Should show `- #0: <finger-name>`. If not, enroll one:
   ```sh
   fprintd-enroll
   ```

3. **pam_fprintd_grosshack.so** available (check if SDDM fingerprint works):
   ```sh
   find / -name "pam_fprintd_grosshack.so" 2>/dev/null
   ```

4. **Quickshell** with `Quickshell.Services.Pam` module.

## Install

### For testers (before merge)

Install from the PR branch on the fork:

```sh
git clone https://github.com/Kavy-Codes/ryoku-arch.git -b fingerprint-unlock
cd ryoku-arch
./ryoku/lockscreen/fingerprint-unlock/install.sh
systemctl --user restart ryoku-shell
```

### After merge (upstream)

```sh
cd ryoku-arch
./ryoku/lockscreen/fingerprint-unlock/install.sh
systemctl --user restart ryoku-shell
```

### What the installer does

1. **Backs up** all existing files to `~/.ryoku-fingerprint-backups/` before overwriting
2. **Copies** the override files to their live locations
3. Backups preserve the original files so you can fully revert

### Options

```sh
./install.sh              # install (backs up existing files first)
./install.sh --dry-run    # show what would happen without changing anything
./install.sh --uninstall  # restore ALL original files from backups
```

### Backup location

All original files are saved to:

```
~/.ryoku-fingerprint-backups/
  .local/share/quickshell-lockscreen/shim/SddmShim.qml
  .local/share/quickshell-lockscreen/lock_shell.qml
  .local/share/quickshell-lockscreen/assets/pam/ryoku-lock
  .local/share/qylock/themes/clockwork/orbital/Main.qml
  .config/quickshell/hub/pages/LockscreenPage.qml
```

These are the exact files that existed before install. If any didn't exist
(e.g. `ryoku-lock` is new), no backup is created for that file.

## Uninstall

```sh
./install.sh --uninstall
systemctl --user restart ryoku-shell
```

This restores **every file** from `~/.ryoku-fingerprint-backups/` to its original
location, completely reverting the install. The backup directory is kept (not
deleted) so you can re-install later if needed.

To fully clean up after uninstalling:

```sh
rm -rf ~/.ryoku-fingerprint-backups
```

## Manual Install (without the script)

If you prefer to install manually:

```sh
# Create backup directory
mkdir -p ~/.ryoku-fingerprint-backups

# Back up existing files
cp ~/.local/share/quickshell-lockscreen/shim/SddmShim.qml ~/.ryoku-fingerprint-backups/
cp ~/.local/share/quickshell-lockscreen/lock_shell.qml ~/.ryoku-fingerprint-backups/
cp ~/.local/share/quickshell-lockscreen/assets/pam/ryoku-lock ~/.ryoku-fingerprint-backups/ 2>/dev/null || true
cp ~/.local/share/qylock/themes/clockwork/orbital/Main.qml ~/.ryoku-fingerprint-backups/
cp ~/.config/quickshell/hub/pages/LockscreenPage.qml ~/.ryoku-fingerprint-backups/

# Copy new files
cp shim/SddmShim.qml ~/.local/share/quickshell-lockscreen/shim/
cp lock_shell.qml ~/.local/share/quickshell-lockscreen/
mkdir -p ~/.local/share/quickshell-lockscreen/assets/pam/
cp assets/pam/ryoku-lock ~/.local/share/quickshell-lockscreen/assets/pam/
cp themes/clockwork/orbital/Main.qml ~/.local/share/qylock/themes/clockwork/orbital/
cp pages/LockscreenPage.qml ~/.config/quickshell/hub/pages/

# Restart
systemctl --user restart ryoku-shell
```

## Verify Installation

```sh
# Check the PAM service exists
ls -la ~/.local/share/quickshell-lockscreen/assets/pam/ryoku-lock

# Check fprintd is working
fprintd-list $(whoami)

# Lock and test
loginctl lock-session
# -> Touch the sensor or type your password
```

## Troubleshooting

### "No fingerprint device found"

```sh
# Check fprintd service
systemctl status fprintd

# List devices
fprintd-list $(whoami)
```

### "Device was already claimed"

Another process is using the fingerprint sensor. Kill any running lock screen:

```sh
pkill -f "quickshell.*lock_shell"
```

### Fingerprint hint doesn't appear

1. Check the toggle is on:
   ```sh
   cat ~/.config/qylock/fingerprint
   # Should print "on" or the file should not exist
   ```

2. Check fingers are enrolled:
   ```sh
   fprintd-list $(whoami)
   # Should show at least one finger
   ```

3. Check the PAM service exists:
   ```sh
   ls ~/.local/share/quickshell-lockscreen/assets/pam/ryoku-lock
   ```

### Lock screen shows QML errors

Restart the shell:

```sh
systemctl --user restart ryoku-shell
```

Check logs:

```sh
journalctl --user -u ryoku-shell --since "5 min ago"
```
