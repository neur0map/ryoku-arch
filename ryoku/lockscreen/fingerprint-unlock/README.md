# Fingerprint Unlock for Ryoku

Touch-to-unlock with `pam_fprintd_grosshack.so` in three places:

1. **Lock screen** (`ryoku-shell lock` / `Super+L`) — sensor scans while the
   password field waits; first success wins, same conversation
2. **Sudo** — touch instead of typing for admin commands (toggle in Settings)
3. **SDDM greeter** — fingerprint at sign-in (toggle in Settings)

Plus a Fingerprint section in Ryoku Settings → Lockscreen for enrollment,
verification, deletion and all of the above.

## Why the lock screen needed this

SDDM unlocks with a fingerprint because `/etc/pam.d/sddm` carries the
grosshack line. The in-session lock used Quickshell's default `login`
service — no fingerprint. This PR ships a self-contained PAM service
(`assets/pam/ryoku-lock`) loaded via `PamContext.configDirectory`, so no
root edit of `/etc/pam.d` is needed for the lock itself.

Two bugs made touch-to-unlock dead on arrival in earlier iterations; both
are fixed here (see [docs/architecture.md](docs/architecture.md)):

- **Arm race**: readiness probes finish before the compositor confirms the
  lock surface, so arming never fired. The shim now arms on
  `onArmWhenReadyChanged`.
- **Stale verifiers**: an aborted conversation orphaned its forked
  `fprintd-verify`, which kept the sensor claim — every later scan silently
  failed until a wasted password cycle re-armed it. Each arm now clears
  strays first.

## Requirements

| Dependency | Why | Check |
|---|---|---|
| `fprintd` | enrollment + verification daemon | `pacman -Q fprintd` |
| `pam_fprintd_grosshack.so` | parallel touch-or-type PAM module | `ls /usr/lib/security/pam_fprintd_grosshack.so` |
| `quickshell` ≥ 0.3 (with `Quickshell.Services.Pam`) | lock surface + PAM conversation | `pacman -Q quickshell` |
| `busctl` (systemd) | reads `num-enroll-stages` for enroll progress | preinstalled on Arch |
| `pkexec` / polkit | root half of the sudo/SDDM toggles | preinstalled on Arch |

A sensor supported by libfprint is required, and at least one finger must be
enrolled before any of the toggles do anything visible.

## What Changed

| File | Change |
|---|---|
| `ryoku/lockscreen/qylock/quickshell-lockscreen/shim/SddmShim.qml` | arm-on-secure fix, stale verifier cleanup, PAM error handling, probe retries |
| `ryoku/lockscreen/qylock/quickshell-lockscreen/assets/pam/ryoku-lock` | new: PAM service for the lock |
| `ryoku/hub/quickshell/pages/LockscreenPage.qml` | Fingerprint section: enroll progress ring, verify plate, sudo/SDDM toggles, two-column card |
| `ryoku/lockscreen/fingerprint-unlock/install.sh` | new: installer/uninstaller |

The clockwork/orbital theme is untouched.

## Settings UI

- **Unlock with fingerprint** — master switch for the lock screen
  (`~/.config/qylock/fingerprint`, read live at each lock)
- **Sudo** / **Sign-in screen** — inject or remove one grosshack line at the
  top of `/etc/pam.d/sudo` / `/etc/pam.d/sddm`. Applied via `pkexec`; every
  change backs the file up to `/etc/pam.d/<svc>.ryoku-fp-bak` and removal
  deletes only the injected line.
- **Prints column** — enrolled fingers with per-finger VERIFY and a two-step
  delete; ENROLL shows real stage progress (`num-enroll-stages` from D-Bus,
  stage passes parsed from fprintd output)

## Install for Testers

```sh
git clone https://github.com/Kavy-Codes/ryoku-arch.git -b fingerprint-unlock-v2
cd ryoku-arch
./ryoku/lockscreen/fingerprint-unlock/install.sh
systemctl --user restart ryoku-shell
```

The installer backs up originals to `~/.ryoku-fingerprint-backups/`. Revert:

```sh
./ryoku/lockscreen/fingerprint-unlock/install.sh --uninstall
systemctl --user restart ryoku-shell
```

## Test Checklist

See [docs/testing.md](docs/testing.md). Short version: enroll → lock → touch
(no button) → unlock; wrong password still works mid-scan; toggles reflect
and revert cleanly; deleting fingers keeps labels in sync.

## Docs

- [docs/architecture.md](docs/architecture.md) — PAM flow, arm lifecycle, race fixes
- [docs/installation.md](docs/installation.md) — install / uninstall / troubleshooting
- [docs/testing.md](docs/testing.md) — full tester checklist
