# Fingerprint Unlock for Ryoku Lock Screen

Touch-to-unlock on the in-session lock (`ryoku-shell lock` / `Super+L`) using
the same `pam_fprintd_grosshack.so` mechanism the SDDM greeter already uses.
Plus a Fingerprint section in Ryoku Settings for enrollment and management.

## TL;DR

SDDM sign-in already unlocks with a fingerprint because `/etc/pam.d/sddm`
carries the grosshack pair. The in-session lock did **not** -- its PAM
conversation used the quickshell default service `login`, which has no
fingerprint line. This change wires the in-session lock onto the **same
grosshack mechanism** via a self-contained PAM service shipped with the lock.

## What Changed

### Files

| File (repo path) | Destination | What it does |
|---|---|---|
| `ryoku/lockscreen/qylock/quickshell-lockscreen/shim/SddmShim.qml` | `~/.local/share/quickshell-lockscreen/shim/` | PAM config, auto-arm, fingerprint state, readiness probes |
| `ryoku/lockscreen/qylock/quickshell-lockscreen/lock_shell.qml` | `~/.local/share/quickshell-lockscreen/` | Arm on `secure`, reset on unlock |
| `ryoku/lockscreen/qylock/quickshell-lockscreen/assets/pam/ryoku-lock` | `~/.local/share/quickshell-lockscreen/assets/pam/` | PAM service (grosshack pair) |
| `ryoku/lockscreen/qylock/themes/clockwork/orbital/Main.qml` | `~/.local/share/qylock/themes/clockwork/orbital/` | Sensor hint + fingerprint reveal |
| `ryoku/hub/quickshell/pages/LockscreenPage.qml` | `~/.config/quickshell/hub/pages/` | Fingerprint card + enroll/verify modal |

### New Files

- `assets/pam/ryoku-lock` -- PAM service file (does not exist in upstream)
- All other files are modifications of existing Ryoku files

## How It Works

See [`docs/architecture.md`](docs/architecture.md) for the full technical
breakdown. In brief:

1. `loginctl lock-session` or `Super+L` triggers `ryoku-shell lock`
2. `lock.sh` launches `quickshell -p lock_shell.qml`
3. `WlSessionLock` secures the screen, `onSecureChanged` sets `armWhenReady = true`
4. `SddmShim` probes `fprintd-list` and reads `~/.config/qylock/fingerprint`
5. If enabled and fingers enrolled, `armFingerprint()` starts a PAM conversation
6. `pam_fprintd_grosshack.so` forks fprintd-verify -- sensor is live
7. Theme shows "SENSOR ACTIVE / TOUCH OR TYPE" with a pulse animation
8. Touch the sensor: PAM succeeds, `loginctl unlock-session`
9. Type a password: `pam_unix` succeeds via the same conversation

## Install

See [`docs/installation.md`](docs/installation.md).

### For testers (before merge)

Install from the PR branch on the fork:

```sh
git clone https://github.com/Kavy-Codes/ryoku-arch.git -b fingerprint-unlock
cd ryoku-arch
./ryoku/lockscreen/fingerprint-unlock/install.sh
systemctl --user restart ryoku-shell
```

The installer **backs up** all original files to `~/.ryoku-fingerprint-backups/`
before overwriting them. You can fully revert at any time:

```sh
./ryoku/lockscreen/fingerprint-unlock/install.sh --uninstall
systemctl --user restart ryoku-shell
```

Remove the test clone when done:

```sh
rm -rf ryoku-arch
```

### After merge (upstream)

```sh
cd ryoku-arch
./ryoku/lockscreen/fingerprint-unlock/install.sh
systemctl --user restart ryoku-shell
```

## Testing

See [`docs/testing.md`](docs/testing.md) for the full checklist.

Quick version:

1. Enroll a finger: Settings -> Lockscreen -> Fingerprint -> ENROLL FINGERPRINT
2. Lock: `loginctl lock-session` or `Super+L`
3. Touch sensor: hint appears, touch unlocks (reveal plays)
4. Type password: still works mid-scan
5. Toggle off: no sensor hint, password only
6. SDDM: sign-in screen unchanged

## Dependencies

- `fprintd` with at least one enrolled finger (`fprintd-enroll`)
- `pam_fprintd_grosshack.so` (already present if SDDM fingerprint works)
- Quickshell with `Quickshell.Services.Pam` module
- No new packages required

## Notes

- The hint is in-session only; the SDDM greeter's copy of the theme is untouched
- Auto-arm waits at the `pam_unix` prompt (no response -> no faillock entry)
- Re-arm after fail is on a 700ms timer
- `fingerprintUnlock` is a heuristic (scanning && !typed); it only drives the
  reveal animation, never gates the unlock itself
- Enrollment/verify captures stderr from fprintd (where the output goes) and
  displays it in a styled terminal overlay
- Race condition protection: `_unlocked` guard prevents double PAM auth if
  fingerprint wins during windup animation
