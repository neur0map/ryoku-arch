# ryoku/hub/

Ryoku Hub: the desktop's central GUI control center. A native Qt6/QML app
(Quickshell, not a webview) with Kirigami-style sidebar navigation, opened with
`Super + ,`. It floats and centres on top of the current windows.

## Layout

- `backend/` One Go program, `ryoku-hub`, the hub's data plane. The QML front end
  shells out to it the same way the rest of the desktop talks to `ryoku-shell`:
  - `ryoku-hub keybinds` parses the live Hyprland binds
    (`~/.config/hypr/modules/binds.lua`, the single source of truth) into
    categorised, display-ready JSON.
  - `ryoku-hub config get|set <key> [value]` reads and writes the hub's TOML
    config at `~/.config/ryoku/hub.toml` (atomic write). Today it persists the
    last open section.
- `quickshell/` The UI, hand-written Quickshell (QML), deployed to
  `~/.config/quickshell/hub` and launched with `qs -c hub`:
  - `shell.qml` the `FloatingWindow`; `Hub.qml` the app (rail + content + the Go
    data fetch and config persistence).
  - `NavRail` the sidebar: brand header, the global `SearchField`, the section
    list with one sliding selection indicator, and a footer mark.
  - `KeybindsPage` + `KeybindGroup` + `KeybindRow` + `KeyCap` the keybind legend
    as a flat list (ember section headers with a hairline rule, mechanical
    keycaps).
  - `SearchResults` the global search view (shown whenever the sidebar search has
    a query): matching section names plus fuzzy-ranked keybinds, via `fuzzy.js`.
  - `UnderConstruction` the placeholder for sections still being built.
  - `ShellSettingsPage` + `SettingSection` + `NumberField` + `SliderRow` +
    `Slider` + `ColorField` + `ToggleRow` + `ChoiceRow` + `VizPreview` the Shell
    Settings editor: Frame, Island, and Visualizer tabs of grouped controls
    (steppers for exact pixels, sliders for opacity and feel, a swatch for colour,
    switches for on/off, segmented choices for style/shape/position) that write
    `~/.config/ryoku/shell.json` and `~/.config/ryoku/visualizer.json` live. The
    Visualizer tab also carries a live animated preview, since the real spectrum
    sits behind your windows.
  - `Icon` the stroked vector icon set; `Singletons/Theme.qml` the palette and
    motion tokens; `PageHeader` the page title block.

## Sections

- **Keybinds** functional: the full shortcut legend, read live from the Hyprland
  config so it never drifts from what is actually bound.
- **Shell Settings** functional: a live editor for the screen frame, the top
  island, and the desktop visualiser (size, rounding, colour, opacity, shadows;
  spectrum style/position/shape/mirror, bars, height, bloom, reflection). Edits
  apply to the running shell at once via `~/.config/ryoku/shell.json` and
  `~/.config/ryoku/visualizer.json` (the shell watches them); the frame and island
  preview on your actual desktop, the visualiser in a live pane. Save keeps
  changes, Revert/leaving restores them.
- **Updates** functional: the commits the checkout is behind on the `main`
  channel, and the auto-check schedule.
- **Extras** under construction. Its controls will likely be built with GTK4 +
  libadwaita through the Kirigami addons.

## Search

A global fuzzy finder lives in the sidebar (focus it with `Ctrl + K`). Typing
searches content across every section: it ranks matching keybinds (each tagged
with its category) and lists matching section names you can jump to. The matcher
is a small subsequence scorer in `quickshell/fuzzy.js`.

## Deploy

`ryoku/shell/deploy.sh` builds `ryoku-hub` onto `PATH` and copies the quickshell
config to `~/.config/quickshell/hub`. The installer
(`installation/backend/lib/deploy.sh`) installs the prebuilt binary and the
config; `installation/iso/build.sh` prebuilds the binary into the image payload,
since the target ships no Go toolchain. The `Super + ,` keybind and the
float/centre window rule live in `ryoku/hyprland/modules/binds.lua` and
`window_rules.lua`.
