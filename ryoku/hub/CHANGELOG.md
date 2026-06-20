# Changelog: ryoku/hub/

## Unreleased

### Added
- An Updates section: a typographic status header (the version bump current ->
  latest, commits behind, branch, last-checked) with an automatic-check schedule
  in the top right (Off / Hourly / Daily / Weekly, persisted to the hub's TOML via
  a new `update_interval` key) over a git-style commit timeline tagged by area.
  Update now runs the update in place with a live, colour-coded log console and a
  Ryoku wave progress line; on success a Refresh shell button reloads the shell so
  changes apply (`ryoku-shell reload`), on failure the log exports to
  `~/ryoku-update-<stamp>.log`. The run publishes its state to a runtime file so
  the shell's update island mirrors it (a wave while running, a refresh affordance
  on success). A live count badge rides the nav rail. The commit data and the run
  are mock (in `Singletons/Updates.qml`); Refresh shell and Export logs are real,
  and the scheduled check waits on a `ryoku-hub updates` backend.
- Ryoku Hub: the desktop's central control center, a native Qt6/QML app
  (Quickshell, not a webview) with Kirigami-style sidebar navigation. Opened with
  `Super + ,`; it floats and centres on top of the current windows via a Hyprland
  window rule.
- `backend/` `ryoku-hub`, a Go data plane the QML shells out to: `ryoku-hub
  keybinds` parses the live Hyprland binds (`~/.config/hypr/modules/binds.lua`,
  the single source of truth) into categorised JSON, prettifying key tokens and
  deriving descriptions from each bind's comment or dispatcher; `ryoku-hub config
  get|set` persists hub state as TOML at `~/.config/ryoku/hub.toml` (atomic
  write), starting with the last open section.
- `quickshell/` the UI: a `FloatingWindow` with a navigation rail and a content
  area. The **Keybinds** section is functional, rendering the full shortcut
  legend as a flat list (ember section headers with a hairline rule, mechanical
  keycaps). **Extras** and **Shell Settings** are under construction (their
  controls will likely use GTK4 + libadwaita through the Kirigami addons).
- A global fuzzy finder in the sidebar, focused with `Ctrl + K`. It searches
  content across every section: fuzzy-ranked keybinds (tagged with their
  category) and matching section names you can jump to. The matcher is a small
  subsequence scorer in `quickshell/fuzzy.js`.
- Visual language follows the shell: a deep warm canvas with the brand orange as
  the single deliberate accent, the 力 mark, JetBrains Mono keycaps, and the
  shell's morph motion (a single sliding selection indicator in the rail).

### Fixed
- Ryoku Hub: `Super + ,` no longer goes dead after the hub is dismissed with the
  compositor's close (`Super + Q`). The keybind guards against a second instance
  with `flock` held for the life of the `qs -c hub` process; an external close
  only hid the window while the process kept running, pinning the lock so further
  presses silently no-opped. The `FloatingWindow` now quits on its `closed`
  signal, so every dismissal releases the lock.
