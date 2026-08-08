# Changelog: lockscreen/

## Unreleased

### Changed
- **`sddm/setup` ships unlock-on-login by default instead of stripping the
  keyring.** The old wiring unconditionally deleted `pam_gnome_keyring` from
  `/etc/pam.d/sddm`, citing a "passwordless Default_keyring" that nothing in the
  repo ever created, so browsers prompted for the keyring on every launch. A
  fresh install now wires `pam_gnome_keyring` (auth + session) so the login
  keyring unlocks with the login password at sign-in -- unless autologin is
  configured, where there is no password to reuse and it ships never-ask (lines
  stripped; the blank default keyring is seeded lazily by the Hub/CLI, never by
  this root installer). Honors `RYOKU_DRYRUN`; `ryoku keyring` changes it later.

### Fixed
- **Suspend now waits for the lock to actually cover the screen.** qylock's
  `lock_shell.qml` touches `$XDG_RUNTIME_DIR/qylock.locked` the moment the
  compositor confirms every output is covered (`WlSessionLock.secure`) and
  removes it on unlock, giving `ryoku-shell lock` a real "locked" signal to
  block on. Before, hypridle's `before_sleep_cmd` returned while Quickshell was
  still loading QML, so logind's sleep inhibitor was released with the desktop
  still in the framebuffer: opening the lid showed your windows for a beat
  before the lock painted.
- **A missing lock theme can no longer lock you out.** `lock.sh` defaulted to
  `nier-automata`, a theme the shipped bundle does not contain, and never
  checked the resolved theme path: with `~/.config/qylock/theme` lost (or an
  uninstalled skin still named there) the theme Loader errored and the session
  locked into a plain black surface that absorbed every keypress with no
  password field. The default is now the shipped `clockwork/orbital` (also in
  `lock_shell.qml` and the QtMultimedia shims), and `lock.sh` verifies
  `Main.qml` exists, falling back to the stock theme before launching.
- `lock.sh` resolves the session type from `$XDG_SESSION_ID` (or the user's
  first logind session) instead of `loginctl | grep $(whoami)`, which matched
  whichever of several sessions happened to sort first (re-login, a second
  seat) and could misread wayland as tty.
- The desktop no longer strands itself on a black lock screen after sleep. The
  ext-session-lock protocol wedges the whole session if the locker crashes while
  locked, which a GPU glitch on resume can trigger: the machine wakes to a black
  screen that eats every keypress and can't be dismissed (reported as "slept and
  won't wake up" and "keybinds don't register on the lock screen"). Hyprland now
  ships with `misc:allow_session_lock_restore` on from boot, so it accepts a
  fresh locker instead of stranding the session and `ryoku-shell lock` can relock
  and take the password. qylock only enabled it after a successful unlock, which
  is too late for the crash that happens before one.

### Added
- Vendored the qylock clockwork theme (orbital and tape variants) and the
  Quickshell lockscreen under `qylock/`, trimmed to only what Ryoku ships.
- Per-skin `preview.gif` for the Lockscreen section in Ryoku Settings: orbital
  reuses qylock's own clockwork preview (its dark-mode segment, to match the
  shipped `themeMode=dark`); tape is rendered from the skin itself. They deploy
  inside the themes dir, and `ryoku-hub lock list` reports their paths.
- `install-qylock`: offline installer for the SDDM greeter and the in-session
  lock. Installs the default skin under the fixed `/usr/share/sddm/themes/ryoku`
  name (the one the Hub overwrites when a skin is chosen) and writes
  `/etc/sddm.conf.d/99-ryoku.conf` (Current=ryoku), installs the Quickshell
  lockscreen to the user's home, links `themes_link`, and sets
  `~/.config/qylock/theme`. Resolves the login user under sudo and pkexec.
  Honors `RYOKU_DRYRUN=1` and `--dry-run`.
- `sddm/setup`: install-time SDDM wiring (enable sddm.service, default to
  graphical.target, strip pam_gnome_keyring from the SDDM PAM stack, ensure a
  Hyprland wayland session exists). Honors `RYOKU_DRYRUN=1` and `--dry-run`.

### Fixed
- In-session lock: skins that gate login and power behind `!isQuickshell`
  (notably `material-you` and `nothing`) left the password field, reboot, and
  shutdown dead under the Quickshell lock, since the shim omitted `sddm.hostName`
  and `isQuickshell` was always true. The shim now reports a real `sddm.hostName`
  (so `isQuickshell` is false), implements `sddm.suspend()`, and exposes SDDM's
  `keyboard` object, so every catalogue skin authenticates and powers off under
  the lock as it does under the SDDM greeter.
