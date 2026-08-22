# Changelog

## v2 — final

### Fixed
- **Touch-to-unlock never fired on a fresh lock**: readiness probes finished
  before `WlSessionLock.secure`, so `armWhenReady` landed too late and no PAM
  conversation ever started. The shim arms on `onArmWhenReadyChanged`.
- **Fingerprint only worked after a wrong password**: aborted conversations
  orphaned their forked `fprintd-verify`; the orphan kept the sensor claim so
  the next scan silently failed. Every arm now clears stale verifiers first.
- Dead PAM conversations (`onError`) no longer leave the hint claiming the
  sensor is listening.
- `pam.start()` failures surface with config/dir/user context instead of
  failing silently; finger probe retries while fprintd wakes up.

### Added
- **Sudo toggle**: grosshack line injected into `/etc/pam.d/sudo` (pkexec,
  backup-first, removal deletes only that line).
- **Sign-in screen toggle**: same for `/etc/pam.d/sddm`.
- Enroll progress: real stage counts (`num-enroll-stages` via D-Bus, passes
  parsed live from stdout+stderr), retry guidance in plain language.
- Verify result plate with match/no-match and auto-close on success.
- Two-step destructive confirms (per-finger delete, REMOVE ALL).
- `install.sh` committed (referenced but missing from earlier iterations).

### Changed
- Settings card runs full width again (symmetric with the gallery) and splits
  into two columns: controls left, enrolled prints right.
- Enroll/verify modal switched from a raw terminal window to the hub's paper
  style; fprintd output demoted to a two-line log strip.
- Collapse chevron moved beside the title; only the header toggles the sheet.

### Untouched
- clockwork/orbital theme files.

## v1

- Initial fingerprint unlock wiring: `ryoku-lock` PAM service, SddmShim
  fingerprint state + auto-arm, sensor hint in the orbital theme,
  Fingerprint section in hub settings.
