# Changelog

## Fingerprint unlock for in-session lock

### Added

- **Fingerprint touch-to-unlock** on the in-session lock (`ryoku-shell lock`)
  using `pam_fprintd_grosshack.so` -- the same mechanism the SDDM greeter uses
- **PAM service `ryoku-lock`** shipped in `assets/pam/` -- no root edit of
  `/etc/pam.d` needed, self-contained inline module stack
- **Auto-arm** of fingerprint sensor when the lock surface is secured
- **Sensor hint** in the orbital theme:
  - "SENSOR ACTIVE / TOUCH OR TYPE" text with pulse animation
  - Positioned between user name and password field (eye naturally hits it)
  - Full brightness `mainText` color while scanning (not dim `subColor`)
- **Reveal flourish** on fingerprint unlock (no windup, no second auth)
- **Race condition protection**: `_unlocked` guard prevents `boomSequence` from
  calling `doLogin()` a second time if fingerprint wins mid-windup
- **Fingerprint section in Ryoku Settings** (Lockscreen page):
  - Toggle to enable/disable fingerprint unlock
  - Enroll, verify, and remove fingerprints
  - Live terminal-style output during enrollment/verification
  - Finger naming after enrollment (stored in `fingerprints.json`)
- **Install script** with backup/restore/uninstall support:
  - `--dry-run` to preview changes
  - `--uninstall` to restore from backups
  - Backups stored in `~/.ryoku-fingerprint-backups/`
- **Comprehensive documentation**:
  - Architecture docs explaining PAM flow, grosshack mechanism, data flow
  - Installation guide with prerequisites and troubleshooting
  - Testing checklist covering all scenarios

### Changed

- **`SddmShim.qml`**: PAM config changed from default (`login`) to `ryoku-lock`;
  fingerprint state props exposed to theme; readiness probes for fprintd;
  auto-arm on `armWhenReady`; re-arm timer (700ms) after failed scan
- **`lock_shell.qml`**: arm fingerprint on `WlSessionLock.secure`; reset on
  unlock; `armWhenReady` lifecycle tied to lock surface
- **Orbital theme `Main.qml`**: fingerprint hint moved above password field;
  scanning color changed to full brightness; pulse animation added; reveal
  flourish on sensor win; `_unlocked` race condition guard
- **`LockscreenPage.qml`**: fingerprint card under "Sign-in & Fingerprint"
  collapsible section; terminal-style enroll/verify overlay capturing stderr;
  finger naming flow; JSON-based finger name storage

### Files

| File | Status |
|---|---|
| `ryoku/lockscreen/qylock/quickshell-lockscreen/shim/SddmShim.qml` | Modified |
| `ryoku/lockscreen/qylock/quickshell-lockscreen/lock_shell.qml` | Modified |
| `ryoku/lockscreen/qylock/quickshell-lockscreen/assets/pam/ryoku-lock` | New |
| `ryoku/lockscreen/qylock/themes/clockwork/orbital/Main.qml` | Modified |
| `ryoku/hub/quickshell/pages/LockscreenPage.qml` | Modified |
