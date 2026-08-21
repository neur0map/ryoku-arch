# Testing Checklist

## Prerequisites

- [ ] `fprintd` is installed and running (`systemctl status fprintd`)
- [ ] At least one finger is enrolled (`fprintd-list $(whoami)` shows entries)
- [ ] `pam_fprintd_grosshack.so` is available
- [ ] Quickshell is installed with `Quickshell.Services.Pam`

## Installation

- [ ] Run `./install.sh --dry-run` and verify the output
- [ ] Run `./install.sh` and verify files are copied
- [ ] Verify backups exist in `~/.ryoku-fingerprint-backups/`
- [ ] Run `systemctl --user restart ryoku-shell` without errors

## Settings Page

- [ ] Open Ryoku Settings -> Lockscreen
- [ ] Expand "Sign-in & Fingerprint" section
- [ ] Fingerprint card shows device name and enrolled finger count
- [ ] Toggle "Unlock with fingerprint" Off -> On
- [ ] Toggle writes `~/.config/qylock/fingerprint` correctly
- [ ] ENROLL FINGERPRINT button opens the terminal modal
- [ ] Terminal modal shows live fprintd output
- [ ] Enrollment completes successfully
- [ ] Naming prompt appears after enrollment
- [ ] VERIFY button works for each enrolled finger
- [ ] DELETE button removes a finger
- [ ] REMOVE ALL removes all fingers (with confirm)

## Lock Screen - Fingerprint

- [ ] Lock: `loginctl lock-session` or `Super+L`
- [ ] Sensor hint appears ("SENSOR ACTIVE / TOUCH OR TYPE")
- [ ] Hint has a pulse animation while scanning
- [ ] Touch the sensor: unlocks immediately (reveal plays)
- [ ] No password prompt appears on touch unlock

## Lock Screen - Password

- [ ] Lock again
- [ ] Type password and press Enter
- [ ] Password still works while sensor is scanning
- [ ] "ACCESS DENIED" appears on wrong password

## Lock Screen - Toggle Off

- [ ] Settings -> Lockscreen -> Fingerprint -> Toggle Off
- [ ] Lock the screen
- [ ] No sensor hint appears
- [ ] Password-only unlock works

## Race Condition

- [ ] Lock the screen
- [ ] Start typing a password (but don't press Enter yet)
- [ ] Touch the sensor while typing
- [ ] Only one unlock happens (no double auth)
- [ ] No QML errors in journal

## SDDM Greeter

- [ ] Log out completely
- [ ] SDDM greeter appears (unchanged)
- [ ] Fingerprint still works at the greeter (if it did before)
- [ ] Greeter does NOT show the sensor hint (in-session only)

## Uninstall

- [ ] Run `./install.sh --uninstall`
- [ ] Verify original files are restored from backups
- [ ] Run `systemctl --user restart ryoku-shell`
- [ ] Lock screen works without fingerprint (password only)
- [ ] Settings -> Lockscreen no longer shows fingerprint card

## Edge Cases

- [ ] Lock while no finger is enrolled -> no sensor hint
- [ ] Lock while fprintd is stopped -> no sensor hint
- [ ] Enroll a new finger while lock is active -> re-arm works
- [ ] Delete all fingers while lock is active -> hint disappears
- [ ] Multiple rapid lock/unlock cycles -> no stale state
- [ ] Reboot after install -> everything still works

## Logs

Check for QML errors:

```sh
journalctl --user -u ryoku-shell --since "5 min ago" | grep -i "error\|qml"
```

Check fprintd:

```sh
journalctl -u fprintd --since "5 min ago"
```

Check PAM:

```sh
journalctl --since "5 min ago" | grep -i "pam\|fprint"
```
