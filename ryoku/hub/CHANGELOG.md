# Changelog: ryoku/hub/

## Unreleased

### Added
- A **Dictation** page (System): switch on voice typing and pick the Voxtype
  speech-to-text engine, from local Whisper (Fast or Accurate) to the OpenAI
  API (with a key field). Models download and remove in the Hub with one click,
  no terminal; it writes Voxtype's config and drives its user service, while the
  shell keeps Super+` and the mic wave.

### Changed
- Shell -> Bar now places the bar on any frame edge (Top / Bottom / Left /
  Right) and picks its skin (Noctalia / Caelestia, both carried one-to-one
  from the credited shells), next to the thickness and
  content toggles; the **Status glyphs** toggle covers the bar's
  network/battery/inbox cluster. The bar defaults flipped on to match the
  shell's new default face (the reset baseline follows), and the island's
  dead Width/Height knobs gave way to a note: the island sizes itself. A
  **Reserve space below the island** toggle closes the top gap when off
  (windows rise to the frame, the island floats over them).

### Fixed
- **Live preview and touchpad toggles work again.** Every appearance/input
  preview (and any saved tap-to-click divergence) generated
  `["tap-to-click"]`, a key the Hyprland Lua config rejects; because the
  whole `hl.config({...})` call is one statement, the error killed the entire
  block, so no slider previewed and a saved tap-to-click off silently
  disabled every other override in `settings.lua` on the next login. The
  generator now emits the hl API's `tap_to_click`.
- **Window rule actions No blur / No border / No shadow now apply.** They
  generated `noblur`/`noborder`/`noshadow`, all unknown to `hl.window_rule`,
  and one bad rule stopped `settings.lua` at that line (everything after it,
  binds, env, autostart, silently dropped). They map to the real fields now
  (`no_blur`, `border_size = 0`, `no_shadow`), verified against the live
  runtime.
- **Layer rule "Dim around" now applies** (`dim_around` is a bool in the hl
  API; the old `dim_around = 0.4` errored out the file). The layer "No
  shadow" action is gone from the page and a stored legacy rule is dropped at
  generation: layer surfaces lost that effect in Hyprland's rule rewrite, and
  emitting it would break the whole generated file.
- **The cursor picked in Appearance now reaches the apps you launch.** The
  override only ran `hyprctl setcursor` (compositor + XWayland); spawned apps
  kept reading the base `XCURSOR_*` env from `env.lua`. A diverged cursor now
  also exports `XCURSOR_THEME/SIZE` and `HYPRCURSOR_THEME/SIZE` from
  `settings.lua` (a later `hl.env` wins over the base), and `env.lua` gained
  the missing `HYPRCURSOR_THEME`. Revert/leaving a page also re-asserts the
  saved cursor, so an unsaved cursor preview no longer sticks until logout.
- **Reset to defaults on Input resets the workspace-swipe settings too** (the
  swipe toggle and finger count were skipped before; the reset now walks the
  full input domain).
- The Animations tree no longer lists Hyprland's internal leaves
  (`__internal_fadeCTM`).
- Desktop Widgets: the page now watches `widgets.json` and folds external
  edits into unedited fields, so dragging a widget on the desktop while the
  page is open no longer gets clobbered by the next Save (same treatment for
  `visualizer.json` on the Shell page, which the deck's quick toggle writes).
- "Ryoku Default" on the Themes page is the shipped baseline again: its look
  had drifted to an older rice (rounding 16, gaps 8/26, border 3), so applying
  it pinned non-default values; its look is now empty and folds to the exact
  `decoration.lua` defaults, and `HyprStore`'s initial draft matches them too.
- Connections > Bluetooth no longer shows a dead switch when the service is
  gone. With no org.bluez on the bus (bluez missing or bluetoothd stopped),
  `Bluetooth.defaultAdapter` is null and the old page still rendered "Bluetooth
  is off." with a live-looking toggle that silently did nothing -- exactly what
  a bluez-less install showed. The adapter toggle now hides without an adapter,
  the placeholder says the service isn't running, and a **Start service** pill
  revives it (`pkexec systemctl enable --now bluetooth.service`, the polkit
  prompt via hyprpolkitagent) with a transient failure line. An rfkill-blocked
  radio (airplane mode, a laptop radio key) is surfaced as "Bluetooth is
  blocked." and the toggle unblocks first (`rfkill unblock bluetooth`,
  seat-writable via systemd uaccess), powering the adapter when the unblock
  lands, instead of asking BlueZ for a Powered=true it refuses.
- GPU page no longer offers to "fix" a disabled IOMMU it cannot fix. On an
  Intel host with IOMMU off, the capability engine used to show a warn ("Ryoku
  can add intel_iommu=on") and a `needs-setup` verdict with an Enable button,
  but the enable path never touched the kernel cmdline, and the one function
  that would (`addCmdlineTokens`) edited the `cmdline:` line that
  `limine-mkinitcpio-hook` regenerates on every kernel update, so any such
  edit silently reverted. Modern kernels already default `intel_iommu=on` when
  VT-d is present, so empty IOMMU groups mean VT-d is off in firmware, which
  only the BIOS/UEFI can change. IOMMU-off is now an honest hard fail for
  every vendor ("Enable IOMMU / VT-d / AMD-Vi in firmware."), matching the AMD
  path. Removed the unreachable `addCmdlineTokens`/`iommuFixable`/`pkgInRepo`
  dead code and their tests; `hwcaps_test.go` asserts the corrected verdict.

### Added
- **Appearance / Look grew the rest of the decoration surface**, all live
  previewed: corner softness (`rounding_power`), dim-inactive with strength,
  blur X-ray, vibrancy and noise, shadow sharpness (`render_power`), the new
  glow (enabled, range, colour), drag-to-resize at edges (`resize_on_border`),
  floating-window snapping (`general:snap`), and the scrolling tiling layout
  next to dwindle/master.
- **Input covers the pointer and touchpad properly**: left-handed buttons,
  mouse natural scroll and scroll speed, middle-click paste
  (`misc:middle_click_paste`), numlock at login, touchpad tap-and-drag,
  click-by-finger-count, middle-click emulation and scroll speed, and the
  workspace swipe gained direction, create-new, and distance tuning
  (`gestures:*`).
- **Cursor comfort**: hide the cursor after an idle timeout or while typing
  (`cursor:inactive_timeout`, `cursor:hide_on_key_press`).
- **Animations rows gained a style picker** for the families that support one
  (windows pop-in/slide/gnomed, workspace slide/fade variants, layer styles);
  a base style like `popin 78%` shows as-is until you pick another.
- **Window rules: the full useful action set.** New actions: maximize, square
  corners, never dim, no animations, force opaque, blur X-ray, never take
  focus, hold focus (dialogs), keep aspect ratio, pseudo-tile, block
  idle/sleep (always/focus/fullscreen), and ignore app request
  (maximize/fullscreen/activate/activatefocus), the last two with inline
  choice values. Layer rules gained blur X-ray and show-above-lockscreen.
- Comfort tab surfaces a failure from `brightnessctl` or the night-light
  helper instead of pretending the slider applied.
- Themes now declare their decoration nuances (`roundingPower`,
  `blurVibrancy`, `blurNoise`) in `theme.json`'s look instead of raw Lua in
  `init.lua`, so the Appearance sliders reflect the live values after a theme
  applies; `init.lua` is motion-only. An already-applied theme's stale
  `theme.lua` self-heals on the next hub open (`hypr get`): its nuance values
  fold into still-default store fields (the live look does not move) and the
  copy is rewritten from the migrated, motion-only `init.lua`, so the sliders
  stop snapping back on Save.
- **Credits** section (pinned in the nav under a heart): a showcase "thank you"
  screen, Profile's twin in build and mood. kansha (感謝) meets the Three Graces
  of Greek myth: the marble trio dissolves off the right the way Lady Justice
  anchors the Profile (dissolve baked into the asset's alpha, so it melts into
  the canvas with no seam). The projects Ryoku stands on read as editorial type
  lines (name, then role · author in mono, hairline rules, no boxes), each
  opening its home with a click where one is known; a separate band credits the
  alpha and beta testers who keep finding the bugs. `CreditsPage.qml`, a `heart`
  glyph in `Icon.qml`, wired into `Hub.qml`; art (`art/three-graces.png`)
  generated with fal.ai and alpha-ramped locally.
- Every section whose GUI maps to a real config file gains a `CONFIG` chip next to
  its title (in the shared `PageHeader`): it opens that file in `nvim` (side by
  side, in a kitty window). The Hyprland sections (Input, Appearance, Animations,
  Keybinds, Window/Layer Rules, Autostart, Environment) open their base module
  beside `user.lua`, the file edits persist in (the Hub regenerates `settings.lua`
  from its JSON, so base-module and `settings.lua` edits do not survive, but
  `user.lua` loads last and always wins); Displays opens `monitors.lua` beside
  `monitors_user.lua`; GPU opens `gpu.lua`; Shell and Widgets open their `~/.config/ryoku/*.json`. The
  chip is hidden for sections with no editable file (Profile, Connections, Updates,
  Store, Add-ons, Lockscreen).
- The **Store**: the plugin Discover catalogue and the Extras bundles are unified
  into one section with a Plugins / Bundles switch. The separate Plugins and Extras
  nav entries are gone, and installed-plugin management moved to the Add-ons
  section, so the Store only browses and installs.
- An **Add-ons** section: installed plugins as a bento grid, each card opening that
  plugin's own settings - rendered from its `metadata.settings` schema by
  `PluginSettingsForm` (dropdown / toggle / slider / text controls grouped under
  mono headers), plus its enable toggle, host, and a remove action. Changes persist
  to `plugins.json` through `ryoku-plugins-place`, so the desktop retunes live; a
  plugin ships no settings QML, only the schema.
- Updates: `ryoku update` can pause on a question (enabling the snapshot helpers)
  and the Updates page renders it inline, in the `UpdateStatus` idiom: an ember
  rule, a headline and detail, and dossier-stamp Install / Skip actions (no
  centred pill modal). The tap writes the choice to the run-state back-channel the
  update is waiting on.
- Plugins: a plugin's settings now follow its lifecycle. `ryoku-hub extras` seeds
  a plugin's manifest presets into `plugins.json` (`<id>.settings`) on install and
  forgets the whole entry on uninstall, so a widget's settings appear with it and
  disappear when it is removed (through `ryoku-plugins-place seed` / `forget`).
- A **Desktop Widgets** section: a live editor for the clock and weather widgets
  on the wallpaper (`WidgetsPage`, with Clock and Weather tabs). Each tab pairs a
  live preview that mirrors the running design (`ClockPreview`/`WeatherPreview`,
  driven by the real wallust palette via a new hub `Wallust` singleton) with full
  controls: face/design, 12/24h and seconds, the date design, the C/F unit and
  today/week scope, the accent source, size, background (none/card/glass) and
  radius, placement (a snap zone or a free X/Y) with a desktop lock, and opacity. Edits write
  `~/.config/ryoku/widgets.json` throttled and atomically (the widgets host
  watches it, so the desktop retunes live), with Save/Revert/Reset and a
  leave-without-save restore, matching Shell Settings. Adds a `widgets` nav icon.
- A **Connections** section: Wi-Fi, Bluetooth, and Hotspot, each a subtab
  (`ConnectionsPage` + `WifiTab`/`BluetoothTab`/`HotspotTab`), ported from the shell's
  Link surfaces into the hub palette. Wi-Fi lists live networks (Quickshell Networking)
  with connect/disconnect, an inline password for secured unknowns (`nmcli --ask`, the
  secret fed via stdin), and rescan; Bluetooth toggles the adapter, scans, and
  connects/pairs (`bluetoothctl`); Hotspot toggles and edits the SSID/password for the
  `RyokuHotspot` AP (`nmcli`). The nav rail now scrolls when its sections overflow,
  keeping the 力 footer pinned.
- A **Profile** section: a showcase screen built for sharable rice screenshots. The
  shell pill's SYSTEM specimen card, reproduced as a hub-palette twin (`ProfileCard`,
  fed by a hub `SysInfo` reading the shared `ryoku-sysinfo`), sits on the left as the
  hero; a dossier (`ProfileStats`) sits on the right with a live clock, a vitals
  strip (load, CPU temp, processes, battery, displays), runtime spec lines
  (compositor, architecture, swap), a package wave with explicit/AUR/total counts,
  the look (cursor, fonts), and the wallust palette as a spectrum. Extended values
  come from a new `ryoku-profile-stats` helper; no addresses are shown, so the shot
  is safe to post. Drawn entirely in the card's carbon vocabulary (mono labels,
  hairline type-lines, tabular figures) over an ambient, vignetted backdrop.
- A **Lockscreen** section: the full qylock theme catalogue as a bento grid in the
  Appearance/Extras style, fetched live from the upstream repo (`ryoku-hub lock
  catalog`) so new and fixed skins appear without a Ryoku release. Each tile loops
  a preview of the real lockscreen (a local gif for the two vendored clockwork
  skins, the upstream `Assets` gif streamed for the rest, loaded only near the
  viewport). Selecting a skin makes it both the in-session lock (`ryoku-hub lock
  set`, writing `~/.config/qylock/theme`, the preference `lock.sh` reads) and the
  SDDM greeter (`ryoku-hub lock apply-greeter`, reinstalled under the fixed
  `/usr/share/sddm/themes/ryoku`); the greeter half lives on a system path, so it
  escalates with pkexec, leaving only the login/auth flow untouched. Skins not yet
  installed download first (`ryoku-hub lock install`, with the size shown up front).
  **Preview** launches an installed skin live without changing the selection;
  **Refresh** re-syncs; offline falls back to the installed skins.
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
- Colour sourcing is one master, not three toggles. "Colours follow wallpaper"
  in Appearance -> Themes is the single switch; the Borders "Follow wallpaper
  palette" and Shell "Match wallpaper" toggles are gone, and window borders and
  shell chrome now follow that one master (read from `theme.json`
  `followWallpaper`). The Borders tab shows its fixed-colour fields only when the
  master is off. The backend no longer runs `wallust` directly: `applyTheme`,
  `setFollowWallpaper`, and `applyScheme("follow")` write their intent and call
  `ryoku-shell wallpaper repaint`, so a theme apply or a toggle derives the same
  palette as a normal wallpaper change (honouring the ryowalls per-image tune).
- Single-select controls read as one family. The active choice in `ChoiceRow`
  (Input, Displays, GPU, Shell, Widgets, Appearance) and the pick-one pills for
  plugin placement and host now wear the same dark raised pill (`keyTop` +
  hairline, bright label) as the `Segmented` tab bar and the nav rail, instead of
  a solid ember block. The brand orange stays an accent, never a fill.
- **GPU section is graphics-only.** It chooses which GPU Ryoku renders on (Hybrid
  / Performance / Passthrough) and sets up the optional GPU-passthrough stack
  (binds the discrete GPU to vfio so a VM can own it), with the readiness dossier
  behind a disclosure instead of filling the page. The specimen card is a sibling
  of the Profile card (carbon, holographic wash, cursor foil, parallax tilt, the
  Ryoku wave): a VRAM badge, the render GPU as the hero, and both GPUs in a dossier
  box with a DISPLAY/FREE marker. Running virtual machines moved to the **ryovm**
  app: the Machine tab, the windowed-VM launcher, and the `ryoku-hub vm`
  subcommand (with `qemu.go`/`vmrun.go`/`vmxml.go`/`vmsnapshot.go`) are removed;
  the hub no longer launches or manages VMs.
- Add-ons: a plugin's `image` setting opens the system file chooser (via the
  desktop portal) on click, instead of a raw text field.
- Store: the catalogue refresh moved to a single control to the left of the
  Plugins / Bundles switch, refreshing whichever catalogue is shown; the embedded
  pages no longer show their own refresh inside the store.
- Add-ons: the per-plugin settings detail drops the showcase backdrop (the warm
  glow read muddy behind a form); the bento grid keeps it.
- Plugins store: the Install / Installed / Remove actions match the update consent
  prompt - outlined ember "stamp" buttons (a thin ember border + mono uppercase
  label, no fill) for the live action and hairline ghost stamps for the rest,
  replacing the generic bright full-pill.
- The sidebar brand is a centred masthead: the wide-tracked **RYOKU ARCH**
  wordmark and a "system and shell settings" subtitle sit over a dimmed 力
  backdrop (a soft warm glow and a faint grid, echoing the Profile portrait
  window). The old flat logo image is gone (`brand-icon.png` deleted) and the
  expand/collapse-all control moves beside the search so the masthead owns its row.
- The Profile showcase frame (soft glow, faint grid, vignette, corner ticks) is
  extracted to a shared `ShowcaseBackdrop` and now sits behind the **Store** and
  **Add-ons** pages too, so the three screens read as one family; the Add-ons
  bento cards gain a lifted drop shadow.
- `HubButton` (the Save/Revert/Reset bar on every settings page) and every primary
  action across the hub (Store Install, the update consent Install) are outlined
  ember stamps in the Profile dossier idiom: a small-radius carbon chip with a mono
  uppercase label and ember as a thin accent (border + label), never a fill.
- The sidebar is rebuilt as three bands: **Profile** pinned at the top on its own
  (no more single-item "You" drawer), the functional groups scrolling in the
  middle, and **Updates** pinned at the foot so its pending-update badge stays in
  view. The middle groups are **System** (Displays, Input, Keybinds, Connections),
  **Desktop** (the visual sections), **Add-ons** (Plugins, Extras), and
  **Advanced** (Window/Layer Rules, Autostart, Environment) at the bottom. Each
  group is a drawer that animates open and closed; only the group holding the
  current section starts open, and an expand/collapse-all control in the header
  reveals or tucks the rest. Group headers adopt the Profile dossier idiom (a
  brand accent dot, a larger mono label, hairline rules between bands and groups),
  and nav rows gain a hover highlight that previews the selection.
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
- **The login screen keeps the lock skin you pick.** Choosing a lockscreen skin
  applies it as the SDDM greeter too, but a skin pulled from the catalogue
  downloads into a 0700 user-owned dir (`os.MkdirTemp`), and the `cp -a` into
  `/usr/share/sddm/themes/ryoku` preserved that owner and mode. The greeter runs
  as the unprivileged `sddm` user, which then could not read the theme, so SDDM
  silently fell back to its embedded theme on every boot (it bit only users who
  had switched skins). `installGreeter` now normalizes the installed greeter to
  root-owned and world-readable, so the picked skin survives a reboot. Covered by
  `lock_test.go`; `ryoku doctor` heals boxes already broken this way.
- **Input: "Follow mouse" now takes effect.** The Hub's input default was out of
  sync with the shipped Hyprland config (`input.lua` ships `follow_mouse = 2`, the
  backend and the QML store both assumed `1`), so the diff-based generator wrote no
  override when "Normal" was picked and the base config's click-to-focus stayed in
  force. Aligned the default to `2`, so choosing "Normal" now writes
  `follow_mouse = 1` and the window under the cursor becomes active on hover.
- **Enable passthrough now installs the AUR stack.** Looking Glass and the kvmfr
  module are AUR-only, but the privileged `gpu apply enable` ran under pkexec and
  only `pacman`-installed the official core, so it printed a `yay -S` hint and left
  kvmfr absent: passthrough never turned on, even after a relogin. Enable now
  builds the AUR pieces as the invoking user (the Hub launches it in a floating
  terminal), then escalates for the system setup, and the plan reports honest
  state instead of claiming an install it never performed.
- Plugins: installing a plugin now fetches every file it declares, not just its
  entry points. `ensurePlugin` also pulls a `files` manifest array (helper QML and
  assets), so a multi-file plugin (one whose view imports a sibling component, or
  ships a sample image) installs complete instead of rendering nothing.
- Plugins / Extras: a catalogue refresh now reflects a just-pushed change at
  once. `ryoku-hub extras` fetches bypass the GitHub raw CDN cache (a unique
  query param plus a `no-cache` header), which had served a stale `registry.json`
  for minutes, so a newly published addon stayed invisible until the CDN expired.
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
