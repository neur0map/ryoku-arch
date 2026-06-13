# Native-feel TODO (ryoku shell)

Closing the smooth/glassy gap to noctalia/end-4. Every item below is wired to an
existing (or one new) `GlobalConfig` key, no hardcoded one-offs. Ranked by
impact-per-risk at the bottom.

Conventions: **wired key** = the `GlobalConfig.<...>` (or `Colours.transparency`)
property the behaviour reads; **needs-compositor?** = requires a Hyprland
`layerrule`/global, not pure QML.

---

## 1. Compositor blur coverage: surfaces on separate layer namespaces get NO blur

`services/Colours.qml:96-106` (`reloadHyprRules`) only pushes `blur` +
`ignore_alpha` for `match:namespace ryoku-drawers` (lua regex `^(ryoku-drawers)$`
at `:100-101`). Every shell surface is a `StyledWindow` whose namespace is
`ryoku-${name}` (`components/containers/StyledWindow.qml:10`), or a hand-rolled
namespace. Full surface map:

| Surface | File:line | Layer namespace | In `ryoku-drawers`? | Blurred today? |
|---|---|---|---|---|
| Bar + all panels (dashboard, settings, launcher, sidebar, utilities, **notifications**, **osd**, session) | `modules/drawers/ContentWindow.qml:89`; panels hosted in `modules/drawers/Panels.qml:75,208` | `ryoku-drawers` | yes (children) | ✅ yes |
| Background / wallpaper | `modules/background/Background.qml:23` | `ryoku-background` | no | n/a (wallpaper layer, blur undesirable) |
| Border exclusion (invisible mask) | `modules/drawers/Exclusions.qml:37` | `ryoku-border-exclusion` | no | n/a (no content) |
| Plugin menu | `modules/PluginMenu.qml:65`, layer Overlay | `ryoku-plugin-menu` | no | ❌ **NO** |
| ii / GameMode overlay | `modules/ii/overlay/Overlay.qml:69`, layer Overlay | `quickshell:overlay` | no | ❌ **NO** |
| Area picker (screenshot) | `modules/areapicker/AreaPicker.qml:27`, layer Overlay | `ryoku-area-picker` | no | ❌ no (transient; low value) |
| Context-menu click-backdrop (niri only) | `modules/common/widgets/ContextMenu.qml:293` | `quickshell:contextMenuBackdrop` | no | n/a (transparent catcher) |
| Tray / text-input context menu (the visible menu) | `modules/common/widgets/ContextMenu.qml:53` `PopupWindow` + `GlassBackground:147` | xdg-popup of `ryoku-drawers` | popup-of-blurred-layer | ❌ unless Hyprland `blur:popups=on` |
| Standalone OSD (legacy/parallel, see note) | `settingsgui/Modules/OSD/OSD.qml:511` | `ryoku-osd-<screen>` | no | ❌ (but likely dead, see note) |

**Note on OSD:** the LIVE OSD is `modules/osd/Wrapper.qml` (instantiated via
`Panels.qml:13` `import qs.modules.osd`), rendered inside `ryoku-drawers` → already
blurred, and it already reads the correct key `Config.osd.hideDelay`
(`modules/osd/Wrapper.qml:89`). The `settingsgui/Modules/OSD/OSD.qml` window (its own
`ryoku-osd-<screen>` namespace, reads `osd.autoHideMs` at `:513`) appears to be the
unused end-4-derived parallel implementation. Confirm it is not instantiated before
spending effort there.

**Fix.** Widen the namespace match in `reloadHyprRules` to cover the real glassy
top-level surfaces, still gated on `transparency.enabled`. Lua path (`:100-101`):
`match = { namespace = "^(ryoku-drawers|ryoku-plugin-menu|quickshell:overlay)$" }`;
hyprlang fallback (`:104-105`) needs one `keyword layerrule` line per namespace
(the `match:namespace` form takes a single value), so emit the batch per surface.
For tray/context menus, the cheap win is the Hyprland **global** `decoration:blur:popups = true`
(+ optionally `blur:popups_ignorealpha`) so popups of the already-blurred drawers
layer inherit blur, this is compositor config, not a layerrule.

- **wired key:** `Colours.transparency.enabled` / `transparency.base` (already the gate at `Colours.qml:100-105`)
- **risk:** low (QML namespace widening) / low (popups global is one Hypr keyword)
- **needs-compositor?:** YES (Hyprland layerrule + `blur:popups` global)

---

## 2. Motion: symmetric reveals, no M3 asymmetric snappy exit; accel curves unused

The expressive spatial curves ARE used for the big reveals: bar reveal
`modules/bar/BarWrapper.qml:107-128` uses `Anim.DefaultSpatial` for **both**
open and close; docked popouts grow via clip-morph (`modules/bar/popouts/Wrapper.qml:43-49,140-155`)
using `expressiveDefaultSpatial`; notification panel slides into the frame border
with `Anim.DefaultSpatial` (`modules/notifications/Wrapper.qml:27-31`); panels grow
out of the bar via `Ryoku.Blobs` deform (`PanelBg` `deformAmount`,
`modules/drawers/ContentWindow.qml:281-308`). So the "grows out of the bar" blob
reveal exists, good.

**Weak spot, exit is not snappy (non-M3).** Open and close use the *same*
`DefaultSpatial` curve+duration. M3 expressive wants the exit to *accelerate* and be
shorter (enter = decelerate/longer, exit = accelerate/shorter). The C++ tokens
already expose `emphasizedAccel` / `emphasizedDecel` and `expressiveFastSpatial`
(`plugin/src/Ryoku/Config/anim.hpp:19-24,45`, built at `anim.cpp:85-90`), but
`components/Anim.qml:5-17` enum has **no** Accel/Decel entries, so nothing can select
them. Result: the close of the bar (`BarWrapper.qml:118-127`) and detached/docked
popouts (`popouts/Wrapper.qml:195-208`) reuses the slow decel curve → exits feel
heavy vs end-4's snap-shut.

**Fix.** Add `EmphasizedAccel`/`EmphasizedDecel` cases to the `Anim.qml` enum (map to
`Tokens.anim.emphasizedAccel/Decel`), then set the `to: ""` (close) transitions in
`BarWrapper.qml:118-127`, `popouts/Wrapper.qml:195-208`, and the close branch of
`notifications/Wrapper.qml` Behavior to `expressiveFastSpatial` (shorter) +
`emphasizedAccel` easing. No new key, durations/curves already flow from
`Tokens.anim.durations.*` (config-backed `AnimDurations` Q_PROPERTY).

- **wired key:** `Tokens.anim.durations.expressiveFastSpatial` + `Tokens.anim.emphasizedAccel` (existing, config-backed)
- **risk:** low (pure QML, additive enum)
- **needs-compositor?:** NO, pure-QML free win

---

## 3. Perf/jank: per-tick subprocess forks cause micro-stutter

Confirmed: `services/SystemUsage.qml:81-93` Timer (interval **is** config-wired:
`GlobalConfig.dashboard.resourceUpdateInterval:83`) fires every tick and starts
THREE `Process` forks each tick:

- `storage`, `lsblk -J -b ...` (`:139-144`): full lsblk fork; disk topology/usage
  changes on the order of minutes, not the resource interval.
- `sensors`, `["sensors"]` (`:283-329`): forks the heavy `lm_sensors` binary +
  regex-parses its text every tick.
- `gpuUsage`, GENERIC path `sh -c "cat /sys/class/drm/card*/device/gpu_busy_percent"`
  (`:261-264`): a shell fork just to `cat` a sysfs file.

CPU/mem are already cheap (`FileView` on `/proc/stat`, `/proc/meminfo` `:107-137`).
`services/CustomWidgets.qml:133-146` and the Notes/CustomWidgets scan procs
(`CustomWidgets.qml:330-348`, `Notes.qml:119-136`) are `sh -c` polled on their own
timers (`CustomWidgets.qml:141-146` user-configurable `${ms}`, fine, opt-in).

**Fix (pure QML, no fork = no stutter):**
1. GPU GENERIC + (where present) sysfs temps → `FileView` on
   `/sys/class/drm/card*/device/gpu_busy_percent` and `/sys/class/hwmon/*/temp*_input`
   instead of `Process`. Native read, zero fork.
2. Move `storage` (lsblk) onto a separate, much slower timer (e.g. 30–60 s) decoupled
   from `resourceUpdateInterval`; expose as a new `dashboard.storageUpdateInterval`
   key (default 60000) rather than hardcoding.
3. NVIDIA path still needs `nvidia-smi`; keep it but on the slow timer or coalesce the
   util+temp queries (already one call at `:264`).

- **wired key:** `GlobalConfig.dashboard.resourceUpdateInterval` (existing) + new `dashboard.storageUpdateInterval`
- **risk:** med (sysfs parsing differs across GPUs; needs the existing GENERIC/NVIDIA branch guard)
- **needs-compositor?:** NO, pure-QML free win

---

## 4. Native app theming: GTK/Qt apps do NOT follow the dynamic scheme

end-4 regenerates `gtk.css` + `kdeglobals` colors + Kvantum on every scheme change so
apps recolor with the shell. ryoku's template pipeline (`bin/ryoku-theme-set-templates`,
sed-based, no matugen) generates only **terminal/btop/chromium/obsidian/keyboard**
configs, the shipped templates are `default/themed/{alacritty.toml,btop.theme,chromium.theme,ghostty.conf,kitty.conf,obsidian.css,keyboard.rgb}.tpl`.
**No `gtk.css`, no Qt/Kvantum, no `kdeglobals` color palette template exists.**

On scheme change `bin/ryoku-scheme-set:80-101` calls `ryoku-theme-set-templates` then
`ryoku-theme-set-gnome`, but `bin/ryoku-theme-set-gnome:19-45` only flips GTK between
stock **Adwaita / Adwaita-dark** and sets the **icon** theme. `bin/ryoku-refresh-icon-theme:84-138`
likewise only writes the icon-theme *name* into `kdeglobals`/`qt6ct`/`gtk-{3,4}.0/settings.ini`
- never colors. So GTK/Qt apps stay on default Adwaita colors while the shell adopts a
fully custom dynamic palette → visible mismatch (the opposite of native feel).

**Fix.** Add color templates consumed by the same `current/theme` output dir:
1. `default/themed/gtk.css.tpl` (libadwaita `@define-color` overrides for GTK4 +
   GTK3 widget colors) → install/symlink to `~/.config/gtk-3.0/gtk.css` and
   `~/.config/gtk-4.0/gtk.css`.
2. `default/themed/kdeglobals.tpl` `[Colors:*]` sections (or extend the existing
   kdeglobals writer) for Qt color-scheme.
3. Optional `default/themed/kvantum.kvconfig.tpl` for Kvantum-styled Qt apps.
   Wire the apply step into `ryoku-theme-set-gnome` (or a new `ryoku-theme-set-qtgtk`),
   gated on a config flag so users on stock Adwaita aren't overridden.

- **wired key:** reuse `GlobalConfig.services.syncSystemTheme` (already gates `ryoku-theme-set-gnome` at `ryoku-scheme-set:94`); optionally add `services.syncAppColors`
- **risk:** med/high (writing user `gtk.css`/`kdeglobals` can clash with user customizations; must be opt-in + backup)
- **needs-compositor?:** NO (but is shell-script/pipeline work, not QML)

---

## 5. Other clearly-native wins

**5a. User "reduce motion" toggle.** `modules/common/Appearance.qml:22-28`
(`animationsEnabled`/`effectsEnabled` + `calcEffectiveDuration`) is driven ONLY by
`GameMode.enabled && GlobalConfig.gameMode.shellAnimations`, there is no user-facing
reduce-motion preference, and the native blob `components/Anim.qml` ignores it
entirely (durations always come from Tokens). A `GlobalConfig.appearance.reduceMotion`
key feeding `Anim.qml` `duration` (return 0 when set) + the existing `Appearance`
gate would be an accessibility/native win.
- **wired key:** new `GlobalConfig.appearance.reduceMotion`; risk low; pure-QML.

**5b. Notification popup enter as spring/scale, not pure slide.** The native popup
path slides via `anchors.rightMargin` only (`modules/notifications/Wrapper.qml:23-31`);
adding a subtle scale/overshoot on first appear (matugen/noctalia feel) using
`expressiveFastSpatial` would read more alive. Pure-QML, risk low, reuse existing
Tokens curve.

---

## Priority (impact-per-risk; ⚡ = pure-QML free win)

| # | Improvement | Impact | Risk | Compositor? | Files (primary) |
|---|---|---|---|---|---|
| 1 | ⚡ Snappy M3 exit curves (Anim Accel/Decel + fast-spatial close) | High | Low | No | `components/Anim.qml:5-17`; `modules/bar/BarWrapper.qml:118-127`; `modules/bar/popouts/Wrapper.qml:195-208` |
| 2 | Hyprland `blur:popups` global (tray/context menus glassy) | High | Low | Yes (1 keyword) | Hypr config; ties to `Colours.qml:96-106` |
| 3 | Extend `reloadHyprRules` namespaces (plugin-menu, overlay) | Med-High | Low | Yes | `services/Colours.qml:100-105` |
| 4 | ⚡ Replace per-tick lsblk/sensors/gpu forks w/ FileView + slow storage timer | Med-High | Med | No | `services/SystemUsage.qml:81-93,139-144,261-264,283-329` |
| 5 | GTK/Qt dynamic color templates (gtk.css/kdeglobals/Kvantum) | High | Med-High | No (pipeline) | `bin/ryoku-theme-set-templates`, `default/themed/*.tpl`, `bin/ryoku-theme-set-gnome:19-45` |
| 6 | ⚡ User `reduceMotion` config wired into Anim.qml | Med | Low | No | `components/Anim.qml`; `modules/common/Appearance.qml:22-28` |
| 7 | ⚡ Notification popup spring/scale on enter | Low-Med | Low | No | `modules/notifications/Wrapper.qml:23-31` |

**Top 5 highest-value, lowest-risk, clearly-wired:** #1, #2, #3, #4, #6.
