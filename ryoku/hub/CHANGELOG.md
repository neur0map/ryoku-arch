# Changelog: ryoku/hub/

## Unreleased

### Added
- A **Lockscreen** section: the installed qylock lock skins as a bento grid in the
  Appearance/Extras style, each tile a looping preview (an `AnimatedImage` of the
  real lockscreen) over the warm hairline surface. Ryoku ships the clockwork theme;
  selecting a skin only swaps which one the lock wears (`ryoku-hub lock set`, which
  writes `~/.config/qylock/theme`, the user-level preference `lock.sh` reads) and
  never touches the SDDM greeter or the login flow. **Preview** launches the lock
  live with that skin without changing the selection; **Refresh** re-scans. Backed
  by `ryoku-hub lock list|set`.
- Shell Settings, Island tab: an **Appearance** group to choose the island style
  (Island, Floating, None) plus a **Reveal on hover** toggle that hides the island
  at rest and shows it on a top-centre hover. Writes `islandStyle` / `islandAutohide`
  to `shell.json` live, like the other shell knobs, with the frame left untouched.
- A **Themes** tab in Appearance: full-system "rices" as a bento grid in the
  Extras style. Each theme is a folder under `hyprland/themes/<slug>/` with a look
  (`theme.json`) and real Hyprland Lua (`init.lua`: motion design and decoration
  finish, the actual system change, not just colours). Applying one
  (`ryoku-hub hypr theme <slug>`) folds the look onto the appearance store (so
  Look/Borders reflect it), installs its `init.lua` (loaded before settings.lua,
  so a knob still wins), and reloads. Ships **Ryoku Default** (the shipped look),
  Tokyo Night, Aqua (glass), Catppuccin, Gruvbox, Nord, and Rosé Pine. Colours are
  a **separate toggle**, independent of the theme: they either track the wallpaper
  (wallust) or use the theme's own palette (locked so a wallpaper change keeps it)
  via `ryoku-hub hypr colorsource follow|fixed`. The frame and island stay Ryoku.
- The settings brand mark uses the real Ryoku icon asset instead of a procedural
  gradient square.
- **Ryoku Settings**: the hub is now a full settings app for everything the
  Hyprland (Lua) config drives, plus the shell. New sections, each a live editor:
  **Displays** (detect and arrange monitors on a drag canvas with snapping;
  per-monitor resolution, refresh, scale, rotation, adaptive sync, mirror, and
  enable/disable; Apply live or save hardware-keyed layout profiles, via
  `ryoku-monitor`), **Appearance** (gaps, rounding, borders, opacity, blur,
  shadows, layout, animations, border colours, cursor theme/size), **Input**
  (keyboard layout/variant/options, pointer feel, touchpad, key repeat), an
  editable **Keybinds** Custom tab beside the live legend, and **Window Rules**,
  **Autostart**, and **Environment** list editors.
- The override engine: `ryoku-hub hypr get|defaults|save|preview|restore` keeps a
  single JSON document at `~/.config/ryoku/hypr.json` and generates
  `~/.config/hypr/settings.lua` (only the values that diverge from the shipped
  defaults), which `hyprland.lua` loads after the base modules and before
  `user.lua`. Scalar edits preview at once via `hyprctl eval` (flash-free); Save
  persists and reloads. `cursors` and `layouts` enumerate installed cursor themes
  and X11 keyboard layouts. New `HyprStore` engine and `Dropdown`/`MonitorTile`
  components; new `DisplaysPage`, `AppearancePage`, `InputPage`, `WindowRulesPage`,
  `AutostartPage`, `EnvironmentPage`, `KeybindLegend`, and `KeybindsEditor`.
- Appearance also carries a **Wallpaper** tab (a grid that retheme the desktop by
  routing the pick through `ryoku-shell wallpaper`, so the wallust palette follows
  it) and a **Comfort** tab (backlight via `brightnessctl`, night light via
  `ryoku-cmd-nightlight`), both applied at once.
- An **Animations** section: the live Hyprland animation tree (read via `hyprctl
  animations -j`, never a hardcoded copy) with per-leaf enable/speed/bezier and a
  visual bezier-curve editor (drag the two control points, live preview). Curves
  and per-leaf overrides persist to `settings.lua` (`hl.curve`/`hl.animation`) via
  a new `anim` domain in the override store. New `AnimationsPage`, `BezierEditor`,
  and `AnimRow` components.
- Input gains a touchpad **workspace-swipe** gesture (3 or 4 fingers), emitted as
  `hl.gesture` and previewed live.
- A **Layer Rules** editor: blur/dim/no-animation rules on layer-shell surfaces by
  namespace, emitted as `hl.layer_rule` (new `layerRules` override domain,
  `LayerRulesPage`).
- A **Shell Settings** section: a live editor for the shell's look. **Frame** and
  **Island** tabs expose the knobs with the control each one wants, steppers with
  manual entry for exact pixels (radius, border, sizes, corners, gap), sliders for
  values tuned by eye (opacity, shadow strength, edge/bud melt), and a swatch with
  hex and dark presets for the surface colour, grouped under section headers. Every
  edit is applied to the running shell at once by writing `~/.config/ryoku/shell.json`
  (throttled, atomic), which the shell watches, so the preview is the actual desktop,
  the frame around the window and the island above it, not a mock pane. The action
  bar tracks the dirty state; Save keeps the look, Revert and leaving the section put
  the saved one back, and Reset to defaults restores the shipped values. A
  **Visualizer** tab tunes the desktop audio spectrum beside a live animated
  preview window: style (bars, wave, or dots), position (bottom, top, centre),
  shape (rounded or flat), mirror, on/off, band count, height, bar width, bloom,
  reflection, and the idle wave, writing `~/.config/ryoku/visualizer.json` the same
  live way. New `NumberField`, `SliderRow`, `Slider`, `ColorField`, `ToggleRow`,
  `ChoiceRow`, `SettingSection`, `VizPreview`, and `ShellSettingsPage` components.
- An Updates section wired to the `ryoku` CLI (`ryoku status --json`): a
  typographic status header (installed version, the pending-update count, and a
  live "checked Xm ago") over the real list of pending package updates (each
  `name old -> new`), with an automatic-check schedule in the top right (Off /
  Hourly / Daily / Weekly, persisted to the hub's TOML via an `update_interval`
  key) that re-runs the check on its cadence. "Update now" runs the real
  `ryoku update` in a terminal; the page mirrors its progress from the run-state
  file the CLI publishes (a spinner and a Ryoku wave while it applies), and the
  shell's update island reads the same file. A live count badge rides the nav
  rail. When the system is current there are no rows ("Everything is up to
  date") and the island stays hidden.
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
  keycaps). **Extras** is under construction (its controls will likely use GTK4 +
  libadwaita through the Kirigami addons).
- A global fuzzy finder in the sidebar, focused with `Ctrl + K`. It searches
  content across every section: fuzzy-ranked keybinds (tagged with their
  category) and matching section names you can jump to. The matcher is a small
  subsequence scorer in `quickshell/fuzzy.js`.
- Visual language follows the shell: a deep warm canvas with the brand orange as
  the single deliberate accent, the 力 mark, JetBrains Mono keycaps, and the
  shell's morph motion (a single sliding selection indicator in the rail).

### Changed
- Renamed the product to **Ryoku Settings** (window title, sidebar, the `Super +
  ,` legend, and the float/centre window rule), keeping the internal `ryoku-hub`
  binary, `quickshell/hub` config, and `qs -c hub` invocation. The sidebar is now
  grouped (Displays & look, Input & shortcuts, Session, Desktop) and the hub opens
  on Displays by default.
- `backend/`: the keybind legend parser keeps lambda binds (multi-dispatch
  actions like `Super + A`, which floats and centres) in the legend, taking the
  description from the trailing comment, instead of dropping every bind whose
  action is not a bare `hl.dsp` expression.
- The **Updates** section tracks the git update channel (`main`) instead of pacman
  packages: the status header, the count badge, and the list show the commits the
  checkout is behind `origin/main` (subject + short hash), driven by the `channel`
  field `ryoku status --json` now publishes. "Up to date" shows when current.

### Fixed
- Ryoku Hub: `Super + ,` no longer goes dead after the hub is dismissed with the
  compositor's close (`Super + Q`). The keybind guards against a second instance
  with `flock` held for the life of the `qs -c hub` process; an external close
  only hid the window while the process kept running, pinning the lock so further
  presses silently no-opped. The `FloatingWindow` now quits on its `closed`
  signal, so every dismissal releases the lock.
- Animations: the bezier editor clamps control points to Hyprland's valid range
  (X in [0,1], Y in [-1,2]) and the canvas spans exactly that, so a handle dragged
  off-canvas can no longer write an out-of-range curve that broke `settings.lua`
  on reload (and silently stopped every other override from applying).
- Displays: Mirror and Extend are disabled with a single monitor, and a failed or
  empty detection shows a clear message with a Retry button instead of a permanent
  "Detecting displays" (most often a stale `ryoku-monitor` without the `list`
  subcommand; see the shell deploy fix).
- Appearance: the tab content is top-aligned instead of vertically centred, so the
  shorter tabs (Cursor, Wallpaper, Comfort) no longer open with a large gap.
