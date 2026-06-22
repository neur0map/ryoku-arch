# ryoku/hub/

Ryoku Settings: the desktop's central GUI control center. A native Qt6/QML app
(Quickshell, not a webview) with a grouped, Kirigami-style sidebar and a global
fuzzy search, opened with `Super + ,`. It floats and centres on top of the
current windows. The product name is **Ryoku Settings**; the internal binary,
config directory, and `qs -c hub` invocation keep the original `hub` name.

It is where you edit anything the Hyprland (Lua) config drives, plus the Ryoku
shell, in one place: monitors, appearance, input, keybinds, window rules,
autostart, environment, the shell's look, the lock screen, and the update channel.

## Layout

- `backend/` One Go program, `ryoku-hub`, the data plane. The QML front end shells
  out to it the same way the rest of the desktop talks to `ryoku-shell`:
  - `ryoku-hub keybinds` parses the live Hyprland binds
    (`~/.config/hypr/modules/binds.lua`) into categorised, display-ready JSON.
  - `ryoku-hub hypr get|defaults|save|preview|restore` reads and writes the
    system-settings override document and generates the Lua the live config loads
    (see "The override model" below). `cursors` and `layouts` enumerate installed
    cursor themes and X11 keyboard layouts for the pickers.
  - `ryoku-hub config get|set <key> [value]` persists hub UI state as TOML at
    `~/.config/ryoku/hub.toml` (last open section, update-check cadence).
  - `ryoku-hub lock catalog|list|set|install <slug>` drives the lock-skin picker:
    `catalog` lists the full qylock theme set live from upstream (each skin's
    preview gif, install size, and installed/active state), `list` is the
    installed-only offline fallback, `set` writes `~/.config/qylock/theme`, and
    `install` downloads a theme into `~/.local/share/qylock/themes` then activates
    it. None of it touches the greeter or the auth flow.
- `quickshell/` The UI, hand-written Quickshell (QML), deployed to
  `~/.config/quickshell/hub` and launched with `qs -c hub`:
  - `shell.qml` the `FloatingWindow`; `Hub.qml` the app (rail + content + the data
    fetch and section persistence).
  - `NavRail` the sidebar: brand header, the global `SearchField`, the grouped
    section list with one sliding selection indicator, and a footer mark.
  - `HyprStore` the shared engine behind every Lua-editing page: it loads the full
    override document from the backend, holds an editable draft, previews scalar
    edits live (flash-free, via `hyprctl eval`), and persists on Save.
  - Page components, one per file: `DisplaysPage` (+ `MonitorTile`),
    `AppearancePage`, `LockscreenPage` (+ `LockscreenTile`), `InputPage`, `KeybindsPage` (+ `KeybindLegend`,
    `KeybindsEditor`), `WindowRulesPage`, `AutostartPage`, `EnvironmentPage`,
    `ShellSettingsPage`, `UpdatesPage`, and the reusable controls
    (`SettingSection`, `NumberField`, `SliderRow`, `Slider`, `ColorField`,
    `ToggleRow`, `ChoiceRow`, `Segmented`, `Dropdown`, `HubButton`, `Icon`).

## Sections

- **Displays** detect every connected monitor and arrange them on a drag canvas
  (edges snap), with per-monitor resolution, refresh, scale, rotation, adaptive
  sync, mirroring, and enable/disable. Apply to the live session, or save a named
  profile keyed to the connected displays' hardware identity so it returns
  automatically when you plug them in again. Backed by `ryoku-monitor`.
- **Appearance** window gaps, rounding, border thickness, active/inactive opacity,
  blur, shadows, tiling layout, animations, border colours (follow the wallpaper
  palette or fix them), and the cursor theme and size. A **Wallpaper** tab retheme
  the desktop (the wallust palette follows the pick, via `ryoku-shell wallpaper`),
  and a **Comfort** tab controls backlight and the night light.
- **Lockscreen** the full qylock theme catalogue as a bento grid, fetched live from
  upstream so new and fixed skins appear without a Ryoku release. Each tile previews
  the real lockscreen (a local gif for the two vendored clockwork skins, the upstream
  Assets gif for the rest). Selecting an installed skin swaps which one the in-session
  lock wears (writes `~/.config/qylock/theme`, read by `lock.sh`); selecting one not
  installed downloads it first (size shown up front) then activates it, never touching
  the SDDM greeter or the login flow. **Preview** shows an installed skin live;
  **Refresh** re-syncs. Backed by `ryoku-hub lock`.
- **Animations** the live Hyprland animation tree (read via `hyprctl animations`)
  with per-leaf enable, speed, and bezier, plus a visual bezier-curve editor that
  previews as you drag. Curves and overrides persist to `settings.lua` on Save.
- **Input** keyboard layout/variant/options, pointer sensitivity, follow-mouse,
  acceleration, touchpad behaviour (including a workspace-swipe gesture), and key repeat.
- **Keybinds** the full shortcut legend, read live from `binds.lua` so it never
  drifts, plus a Custom editor for your own shortcuts layered on top.
- **Window Rules** float, size, pin, place, or restyle windows by class or title.
- **Layer Rules** blur, dim, or disable animations on layer-shell surfaces (bars,
  launchers, notification daemons) matched by namespace.
- **Autostart** commands run at login, after the base Ryoku autostart.
- **Environment** environment variables for the Hyprland session.
- **Shell** the live editor for the screen frame, the top island (its style: the
  classic fused island, a floating pill, or none, each with an optional
  reveal-on-hover), and the desktop visualiser (writes `~/.config/ryoku/shell.json`
  and `visualizer.json`).
- **Updates** the commits the checkout is behind on its channel, with an
  auto-check cadence.

## The override model

The Lua-editing sections never touch the shipped Hyprland modules (those are
re-laid by `ryoku materialize` on update). Instead:

- The editable source of truth is one JSON document at
  `~/.config/ryoku/hypr.json`, owned by `ryoku-hub`.
- From it, `ryoku-hub` generates `~/.config/hypr/settings.lua`, written only with
  the values that diverge from the shipped defaults, so an untouched setting falls
  through to the base module. `hyprland.lua` `require`s it after the base modules
  and before `user.lua`, so the GUI's tweaks override the defaults while a
  hand-written `user.lua` still wins.
- Editing a scalar (appearance/input/cursor) previews at once through
  `hyprctl eval` (no reload, no flash). Save persists the JSON, regenerates
  `settings.lua`, and reloads to lock in list changes (rules, binds, env,
  autostart) that an eval cannot undo. Revert and leaving a page restore the saved
  state.

Monitors are the exception: they are owned by `ryoku-monitor`, which writes
`monitors.lua` and stores profiles under `~/.config/ryoku/monitors/`. Displays
edits stage in the canvas and only touch the live screens on Apply.

## Search

A global fuzzy finder lives in the sidebar (focus it with `Ctrl + K`). Typing
searches content across every section: it ranks matching keybinds (each tagged
with its category) and lists matching section names you can jump to. The matcher
is a small subsequence scorer in `quickshell/fuzzy.js`.

## Deploy

`ryoku/shell/deploy.sh` builds `ryoku-hub` onto `PATH` and copies the quickshell
config to `~/.config/quickshell/hub`. The installer installs the prebuilt binary
and the config; `installation/iso/build.sh` prebuilds the binary into the image
payload. The `Super + ,` keybind and the float/centre window rule live in
`ryoku/hyprland/modules/binds.lua` and `window_rules.lua`.
