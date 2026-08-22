# Installation

## Prerequisites

```sh
pacman -Q fprintd quickshell          # both required
ls /usr/lib/security/pam_fprintd_grosshack.so   # required for touch-or-type
fprintd-list "$USER"                  # sensor found + >= 1 finger enrolled
```

No fingers enrolled yet? Run `fprintd-enroll` once, or use
Settings → Lockscreen → Fingerprint → ENROLL FINGERPRINT after installing.

## Install

```sh
git clone https://github.com/Kavy-Codes/ryoku-arch.git -b fingerprint-unlock-v2
cd ryoku-arch/ryoku/lockscreen/fingerprint-unlock
./install.sh
systemctl --user restart ryoku-shell
```

Files placed:

| Source | Destination |
|---|---|
| `shim/SddmShim.qml` | `~/.local/share/quickshell-lockscreen/shim/` |
| `lock_shell.qml` | `~/.local/share/quickshell-lockscreen/` |
| `assets/pam/ryoku-lock` | `~/.local/share/quickshell-lockscreen/assets/pam/` |
| `pages/LockscreenPage.qml` | `~/.config/quickshell/hub/pages/` |

Existing files are backed up to `~/.ryoku-fingerprint-backups/`.

Dry run first: `./install.sh --dry-run`

## Uninstall / Revert

```sh
./install.sh --uninstall      # restores from ~/.ryoku-fingerprint-backups/
systemctl --user restart ryoku-shell
```

### Removing sudo / SDDM access

Settings → Lockscreen → Fingerprint → toggle off **Sudo** / **Sign-in
screen**. This deletes only the injected grosshack line; each edit also left
a full copy at `/etc/pam.d/<svc>.ryoku-fp-bak`.

## Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| hint never shows at lock | `fprintd-list $USER` shows a finger? toggle file says `on`? | enroll a finger; Settings toggle ON |
| "touch sensor" but touch does nothing (old builds) | — | this PR fixes it; reinstall and retest |
| unlock works only after typing a wrong password | stale `fprintd-verify` holding the claim (old builds) | fixed here by pre-arm cleanup |
| toggles error with "cancelled?" | polkit prompt dismissed | retry, accept the prompt |
| no enroll progress ring, only spinner | `num-enroll-stages` probe failed | harmless; ring fills on completion regardless |
