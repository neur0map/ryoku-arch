# Changelog: ryoku/

## Unreleased

### Added
- `hyprland/themes/cassette`: a new flat, sharp, sepia theme rice (no blur or
  shadow, `rounding 0`, tight gaps) in a muted YoRHa/NieR palette, filling the gap
  left by the rounded, glassy default set. Opt-in from Ryoku Settings; the frame
  and island keep the Ryoku identity, and its fixed palette applies when colours
  are set to the theme rather than the wallpaper.
- `hyprland/monitors_user.lua.example`: a hand-written manual monitor override.
  `hyprland.lua` now `require`s `monitors_user` (a `pcall`, after the generated
  `monitors.lua`), so `~/.config/hypr/monitors_user.lua` wins and lets you force a
  mode, a custom modeline, position, scale, rotation, or mirror for a panel whose
  EDID is wrong (for example a fake/generic EDID). It is never shipped or
  overwritten, and `ryoku-monitor` leaves any output named in it alone.
- `hyprland/themes/`: full-system theme "rices", one folder each, with the look
  (`theme.json`), real Hyprland Lua (`init.lua`: motion and decoration finish), and
  a 16-colour `colors.json` for fixed palettes. Ships **default** (the shipped
  look), Tokyo Night, Aqua, Catppuccin, Gruvbox, Nord, and Rosé Pine. The active
  theme's `init.lua` is loaded by `hyprland.lua` (as `theme`) before `settings.lua`.
  Ryoku Settings applies them and toggles whether colours follow the wallpaper.
- `hyprland/hyprland.lua`: loads a generated `settings.lua` after the base modules
  and before `user.lua`, the override file Ryoku Settings writes. Missing by
  default (a `pcall` no-op); the hub creates it on first use. `window_rules` and
  the `Super + ,` legend now read "Ryoku Settings".
- `hyprland/hyprland.lua`: loads the runtime-generated drop-ins `gpu.lua` and
  `monitors.lua` with `pcall` (like `settings`, `theme`, and `user` already are),
  so a half-written or corrupt one -- which a crash or a GPU reset can leave behind,
  since those fire monitor events that rewrite `monitors.lua` -- falls back to
  Hyprland's defaults instead of dropping the whole config into emergency mode.
  `ryoku doctor` repairs the file and autoscale regenerates it on the next login.
- `hyprland/scripts/ryoku-cmd-nightlight`: `status`, `on [temp]`, and `off`
  subcommands (with the saved temperature persisted) so Ryoku Settings' Comfort
  tab can show and set the night light; the bare call still toggles for Super+U.
- `hyprland/modules/binds`: `Super + P` toggles the displays between mirror
  (duplicate) and extend, via `ryoku-monitor toggle`.
- `hyprland/modules/binds`: `Super + Tab` opens the pill's workspace switcher
  overview (`ryoku-shell workspaces`) for moving windows between workspaces.
- `hyprland/modules/binds`: `Super + M` toggles the desktop audio visualiser
  (`ryoku-shell visualizer`).
- `hyprland/modules/binds`: `Super + Shift + M` raises the visualiser over the
  windows on demand (`ryoku-shell visualizer-overlay`), flipping back to the desktop.
- `hyprland/modules/decoration`: a touch more room around tiled windows
  (`gaps_out` 24 -> 26, `gaps_in` 7 -> 8) for a clear frame-to-window vs
  window-to-window gap hierarchy that reads with the frame's new contact shadow.
- `hyprland/`: the Hyprland config in Lua, modular (entrypoint plus modules for
  input, decoration, animations, binds, window rules, ryoshot, and autostart)
  with hardware-managed gpu/keyboard/monitors. Launches the Ryoku shell and the
  laptop-only idle policy.
- `lockscreen/`: the vendored qylock clockwork theme, its installer, and the SDDM
  setup.
- `apps/`: kitty, fastfetch (with the branded wrapper), fish (greeting off),
  starship, and nautilus notes.
- `assets/`: the 力 brand logo and icons, plus the shipped wallpaper collection
  (`wallpapers/`) that installs to `~/Pictures/Wallpapers`; `ryoku-shell` picks a
  random one on first login.
- `shell/`: the Quickshell desktop UI (pill, sidebar, ryoshot),
  the wallust palette generation, the qt/kde theme, the user session target, and
  the `ryoku-shell` Go control-plane daemon (`ipc/`).
- `hyprland/` autostart and `shell/ipc`: apply wallust colors to
  OpenRGB-compatible keyboards and lighting devices through `ryoku-leds`.
- `hyprland/` autostart: set GTK apps to dark through `gsettings`
  (`color-scheme` prefer-dark, `gtk-theme` Adwaita-dark), so nautilus and other
  GTK apps match the dark Qt and kitty theme.
- `hyprland/` binds and autostart: tap ``Super+` `` to start Handy speech-to-text
  and the live mic wave, tap again to stop (`ryoku-shell voice`); autostart Handy hidden and
  tray-less (it is keybind-driven and configured from app search) when the
  optional `handy` binary is installed.
- `hyprland/` autostart: normalize the default microphone to unity gain on login
  through `ryoku-mic`, so an over-amplified codec does not clip Handy's recording
  or peg the voice wave.

### Changed
- `hyprland/modules/binds`: reworked the keymap. `Super + arrow` keys move focus
  between windows and `Super + Shift + arrow` move the active window; `Super + 1..0`
  still focus workspaces but moving the active window there is now `Super + Alt + 1..0`.
  `Super + A` floats and centres the active window as a toggle (press again to tile
  it back), replacing the old `Super + A` / `Super + Shift + A` float/tile pair.
  `Super + R` enters a resize mode (`hyprland/modules/resize`, a submap where the
  arrows resize and Escape exits) and `Super + H` toggles the scratchpad (special
  workspace). `Super + arrow` no longer cycles workspaces (the number row does).
- `hyprland/modules/binds`: `Super + 1..0` now shows that workspace on the monitor
  under the cursor (the workspace is pulled to the focused monitor first) instead
  of yanking focus to wherever the workspace lived, so the number keys drive
  whichever screen the mouse is on rather than always the laptop. `Super + Alt +
  1..0` sends the active window to that workspace, on that screen.
- Tuned Hyprland window decoration and motion for the Ryoku shell: stronger
  shadows, softer translucency, wider breathing room, and branded open/close
  curves.
- Consolidated everything under a single `ryoku/` tree: the former top-level
  `shell/` now lives at `ryoku/shell/`, its modular Hyprland config replaced the
  old flat `ryoku/hyprland` (one Hyprland config now), and the duplicate
  `shell/fish` (with its non-brand greeting) was dropped for `ryoku/apps/fish`.

### Fixed
- Hyprland: DPI autoscale now re-runs when a display is hotplugged, not only at
  login, so an external monitor plugged in mid-session is positioned and scaled
  immediately instead of coming up at 1x until the next relogin.
- Hyprland: a monitor connected mid-session now gets the current wallpaper painted
  onto it automatically. The hotplug handler repaints every output (via `ryoku-shell
  wallpaper refresh`) once autoscale has settled the new mode, so the screen no
  longer comes up on a black background until the next manual wallpaper change.
- Hyprland: the NVIDIA VA-API/GLX env hints (`LIBVA_DRIVER_NAME`,
  `__GLX_VENDOR_LIBRARY_NAME`, the `__GL_*` toggles) were set on every machine,
  breaking hardware video decode and Xwayland GL on AMD and Intel. They now
  apply only when the NVIDIA driver is present; mesa auto-detects elsewhere.
- Hyprland: a window stranded in maximize when a Chromium/Electron app leaves
  page fullscreen (a spurious mode-1 event on exit) is reset to normal, so the
  window returns to its original size instead of staying expanded.
