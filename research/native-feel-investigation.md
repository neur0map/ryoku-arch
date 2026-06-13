# Native-Feel Investigation: Ryoku vs Noctalia vs end-4 dots-hyprland

Deep comparative investigation into why ryoku's shell does not feel as native/smooth as
**noctalia-shell** and **end-4 dots-hyprland**, and a concrete roadmap to close the gap.

- Date: 2026-06-13
- Method: `prowl-agent init` on both reference repos + 8 parallel investigation agents
  (haiku/sonnet `task` agents) + web research. Manager-synthesized, every claim cited to
  `path:line` (ryoku paths relative to repo root; reference-shell paths relative to their clone).
- Raw per-agent findings preserved in [`research/native-feel/`](native-feel/) (8 cited docs).

> Tooling note: in this session the live `prowl-agent` MCP was bound to **ryoku-arch**, so
> ryoku was analyzed with prowl + LSP, and the two reference shells were analyzed by direct
> source reading after `prowl-agent init` (noctalia: 583 files / 56,575 symbols; dots: 763
> files / 16,687 symbols). Both reference repos now have `.mcp.json` + `.prowl/` registered
> for future prowl-agent use.

---

## 0. Executive summary (read this first)

**Ryoku is not a naive QML shell, and it does not need a rewrite.** It already ships the
machinery that makes noctalia/end-4 feel native:

- A **live, reactive, typed C++ config** (`GlobalConfig`, `Q_PROPERTY … NOTIFY`, 500 ms
  debounced autosave, `QFileSystemWatcher`, unknown-key round-trip), architecturally
  equivalent to noctalia's in-process synchronous reload and end-4's `FileView`+`JsonAdapter`.
  **Most settings already apply live; only bar *design* restarts the shell.**
- A complete **Material-3 motion token system** (`Ryoku.Config/tokens.hpp` + `anim.hpp`):
  emphasized / standard / expressive-spatial / expressive-effects cubic-béziers and M3 duration
  tiers, *richer* than end-4's, on par with noctalia's. And the curves are **genuinely
  applied** to bar/popout/drawer/notification open-close (verified, §4).
- A custom **GPU "blob" renderer** (`Ryoku.Blobs`: `BlobShape`/`BlobRect`/`BlobInvertedRect`
  via `QSGNode`+`blobmaterial`+`shaders/blob.frag`) doing SDF rounded-rect + **concave/inverted
  corners** + metaball merge + spring deform, the same class of primitive noctalia hand-wrote
  in GL, and *more* than end-4 (which uses plain `Rectangle`s).
- **Compositor backdrop blur already wired** for the `ryoku-drawers` layer via Hyprland
  `layerrule` IPC (`services/Colours.qml:96-106`), the exact native-blur technique noctalia and
  end-4 use (both delegate real blur to the compositor; neither blurs in-toolkit).

So the gap is **fragmentation and under-wiring, not missing technology.** Three findings explain
almost everything the user feels:

1. **The "settings don't do much" problem is a disconnected settings surface.**
   `shell/settingsgui/` is a **vendored noctalia settings app**. Its prominent per-surface
   opacity sliders (`bar.backgroundOpacity`, `capsuleOpacity`, `dock.*`, notif/OSD opacity,
   `dimmerOpacity`) are **NO-OP/DEAD in ryoku**: their only readers are noctalia
   `Modules/Dock|OSD|MainScreen|Launcher` that `shell.qml` never instantiates, and there are
   **zero `Settings.data.*Opacity` writes** in the tabs. Ryoku's *real* transparency lives under
   a different, modest control (User Interface → Appearance) with **3 keys**. The user fiddles
   with dead sliders.

2. **The transparency that works is off by default and skips the most-visible surface.**
   `appearance.transparency.enabled` defaults **false** (`appearanceconfig.hpp:227`); the opacity
   sliders are even `visible:`-gated on it. When on, drawers + control-center + capsules respond,
   but **the bar itself never consumes `appearance.transparency`** (it stays opaque), and
   transparency only reads as "glass" where a compositor blur region is active.

3. **Three parallel everything.** Ryoku carries **three UI surfaces** (settingsgui / dashboard
   [retiring] / controlcenter), **three config stores** (`shell.json` typed / `settings-gui/
   settings.json` vendored-noctalia / `dashboard/*.json`), and **three design systems**
   (canonical `Tokens`+`Colours`+`Blobs` / a vendored end-4 `modules/common/Appearance.qml` with
   `backgroundTransparency:0` hardcoded / the noctalia settingsgui store). This *is* the
   "unorganized" feeling, and it directly causes (1) and (2).

**Headline answer to the user's explicit questions:**
- *Is everything handled by their IPC?* **No.** Neither noctalia nor end-4 uses IPC for
  settings→shell. Noctalia mutates the live in-process config synchronously (same binary);
  end-4 watches a JSON file (`FileView`+`JsonAdapter`); ryoku already does the in-process
  reactive thing via `GlobalConfig` NOTIFY. **IPC is only for CLI/keybinds/scripts** in all three.
- *gtk4?* **No**, none of the shells are GTK. GTK4 appears only as a **theming target**
  (matugen renders `gtk.css`). All three are: noctalia = native C++/GLES2, end-4 = QML/quickshell,
  ryoku = QML/quickshell (+ C++ plugin).
- *The blob popups*, noctalia's "blob" is an SDF shader with concave bar-side corners that
  *grow out of the bar*. **Ryoku already has the renderer** (`Ryoku.Blobs`, incl. inverted
  corners); the gap is the *grows-out-of-bar reveal* + transparency/blur *behind* the blob.

---

## 1. The three shells at a glance

| Dimension | **noctalia-shell** | **end-4 dots-hyprland** | **ryoku** |
|---|---|---|---|
| Stack | Native C++/Wayland, **own GLES2 scene-graph renderer**, no Qt/GTK | QML / **quickshell** | QML / **quickshell** + C++ plugin (`Ryoku.*`) |
| Event model | Single binary, **one `poll()` loop**, `PollSource` per fd (`app/main_loop.cpp:290`) | Qt event loop (one `qs` process) | Qt event loop (one `qs` process, systemd unit) |
| Frame model | **vsync via `wl_surface.frame`, renders only on dirty/animating, idle otherwise** (`surface.cpp:1028-1034`) | QtQuick threaded render loop | QtQuick threaded render loop (`shell.qml:2` `QSG_RENDER_LOOP=threaded`) |
| Config store | TOML, atomic temp+rename, inotify (`config/atomic_file.cpp`, `config_service.cpp`) | `~/.config/illogical-impulse/config.json` via `FileView`+`JsonAdapter` (`Config.qml:10-76`) | **`~/.config/ryoku/shell.json`** typed C++ `GlobalConfig` + `QFileSystemWatcher` (`rootconfig.cpp`) |
| Settings→shell propagation | **Same binary, synchronous in-process reload** + change-set diff (`config_overrides.cpp:1226-1238`) | **File-watch**: settings is a separate `qs -p` process; both watch the JSON | **In-process `GlobalConfig` NOTIFY** binding (same idea as noctalia); 500 ms autosave is only persistence |
| IPC role | CLI/scripts only: `noctalia msg <verb>`, 1 socket, ~40 verbs | CLI/keybinds only: `qs ipc call <t> <fn>` | CLI/keybinds only: `qs ipc call`, 24 targets (`ipc-surface.txt`) |
| Animation | `AnimationManager` wall-clock tween, curves+100/200/400ms tiers, global `MotionService` | One `Appearance` singleton: bézier curves + durations as prebuilt `Component`s | `Ryoku.Config` M3 token system + `Anim`/`AnchorAnim`/`CAnim`/`StateLayer` wrappers |
| "Blob" chrome | SDF `RectProgram` w/ concave corners + ringed cutout shadow; **grows out of bar** via clip-node + bulgeRadius | Transparent `PanelWindow` + inset rounded `Rectangle` + `RectangularShadow` | **`Ryoku.Blobs` QSG metaball** (inverted corners, spring deform) + `ContentWindow.qml` |
| Real blur | **Compositor** `ext_background_effect set_blur_region` (region-locked) | **Compositor** Hyprland `layer_rule blur` on `quickshell:*` ns | **Compositor** Hyprland `layerrule blur` on `ryoku-drawers` ns (`Colours.qml:96-106`), *drawers only* |
| Theme | Material-You from 112×112 wallpaper buffer; `setPalette`→`paletteChanged`; **cross-fades** via `lerpPalette` | matugen → `colors.json` → `MaterialThemeLoader`→`Appearance.m3colors`; derived bindings | Material-You via external `ryoku-scheme-set`/matugen → `scheme.json` watch → `Colours.palette` |
| Native app theming | `TemplateApplyService` (worker thread) renders gtk/foot/kitty/… + hooks | matugen fan-out: gtk3/4 + Kvantum/kdeglobals + fuzzel + terminal in one run | Templates exist (`settingsgui/Assets/Templates/*`); Kvantum/kdeglobals parity unverified |

**Key structural truth:** noctalia feels native largely *because it is native* (custom GL
renderer, idle-until-dirty frame loop), ryoku **cannot and should not** copy that. The directly
transferable lessons come from **end-4 (same stack)** and from noctalia's *behaviors* (live
propagation, compositor blur, wall-clock motion, theme cross-fade).

---

## 2. Process & background model

**noctalia**, one binary, one `poll()` loop; every fd-owning subsystem is a `PollSource`
(`app/poll_source.h`); system state comes from **direct D-Bus (sd-bus), libpipewire, sysfs+inotify,
Wayland protocols**, not CLI scraping (`dbus/system_bus.cpp:34`, `pipewire_service.cpp:1445`,
`brightness_service.cpp:818`). `fork/exec` reserved for genuine externals (`ddcutil`, `wpctl`
persistence). Threads only for Luau scripts + child-process waits, marshalled back via
`DeferredCall`.

**end-4**, single `qs -c ii` process (`execs.lua:6`), one `ShellRoot`. **Long-lived subscriber
processes** gate cheap queries (`Network.qml:163-170` one `nmcli monitor` → triggers `update()`);
`execDetached` for fire-and-forget; centralized `Component.onCompleted` init (`shell.qml:25-33`).

**ryoku**, single `qs` process under `ryoku-shell.service`
(`config/systemd/user/ryoku-shell.service:13`); steady-state is long-lived service singletons
(`Network.qml:291-294` `nmcli m`; `GameMode.qml:320-323` `gdbus monitor`). **Jank sources:**
- `services/SystemUsage.qml:81-93` spawns **`lsblk` + `gpu` + `sensors` every tick** while resource
  widgets are visible (CPU/mem already use cheap `/proc` `FileView`).
- `services/CustomWidgets.qml:133-146` runs an arbitrary `sh -c` **per user widget per interval**.
- `Notes.qml:119`, `CustomWidgets.qml:330`, `LockThemes.qml` build JSON via `sh -c` pipelines
  instead of `FilesystemModel`/`FileView`.

*Gap:* ryoku is mostly fine, but a few per-tick subprocess spawns are the repeating micro-stutter
source. Candidates for native collectors in `Ryoku.Internal`/`Ryoku.Models` (noctalia-style).

---

## 3. Settings propagation: "is it IPC? gtk4?" (explicit user question)

**Answer: not IPC, not GTK.** Each shell propagates settings to the live UI *without* IPC and
*without* a toolkit reload:

- **noctalia** (`research/native-feel/noctalia-settings-theme.md`): the settings UI is the **same
  binary** (a separate xdg-toplevel surface sharing `RenderContext` + a pointer to the live
  `ConfigService`, `settings_window.h:46-54`). On a control commit it **persists TOML AND
  synchronously runs `loadAll()`+`fireReloadCallbacks()` in the same turn**
  (`config_overrides.cpp:1226-1238`), setting an own-write flag so the inotify echo is ignored
  (`config_service.cpp:802-805`). Subscribers consult a **change-set** so only the affected
  service re-applies (`bar.cpp:878-887`). inotify exists only for *external* edits/CLI. IPC
  (`noctalia msg`) is only for scripts/keybinds.
- **end-4** (`research/native-feel/end4-arch.md`): settings is a separate `qs -p settings.qml`
  process; both it and the bar watch the same JSON via `FileView{watchChanges:true}` +
  `JsonAdapter` (`Config.qml:64-76`). A widget binds `Config.options.x` directly; a write mutates
  the adapter → debounced file write → the other process's watch re-reads → bindings re-evaluate.
- **ryoku** (`research/native-feel/ryoku-arch.md`): `GlobalConfig` is a C++ singleton with
  `CONFIG_PROPERTY … NOTIFY` (`configobject.hpp:24-41`); a settings write sets the property → the
  NOTIFY fires → every QML binding updates **instantly, in-process**; a 500 ms timer
  (`rootconfig.cpp:73-74,180-186`) persists `shell.json` as a side-effect; `QFileSystemWatcher`
  + 50 ms debounce handles external edits (`rootconfig.cpp:102-105,172-178`) with self-write
  suppression. **This is the same "decouple persistence from live update" pattern noctalia uses.**

**So ryoku's propagation engine is already correct.** The reason settings *feel* dead is **not**
the engine, it is (a) controls that write to a **disconnected store** (vendored noctalia keys),
and (b) a value (`transparency`) gated off / not consumed by the bar. The one true restart path is
**bar design** (`services/BarDesign.qml:67-73` freezes `currentId` at startup; restart fired via
`systemctl --user restart ryoku-shell.service` in `DesignSubTab.qml`, `ControlCenterTab.qml:83`,
`Background.qml:457`).

*Anti-pattern to fix:* ~55 settings sites call `Quickshell.execDetached` directly (apps, `wl-copy`,
`ryoku-theme-set`, `systemctl`) instead of the typed `ryoku-shell ipc` surface, contradicting the
`AGENTS.md` "narrow IPC/command adapter" flow and blurring "who owns this value".

---

## 4. Animations (bar + frame): the user's "most important" axis

**Ryoku's motion foundation is strong and *applied*, this corrects the assumption that ryoku
"has weak animations".** (`research/native-feel/ryoku-anim-settings.md`)

- Tokens: `tokens.hpp:10-42` (curves) + `:105-123` (durations: small 200, normal 400, large 600,
  xl 1000, expressive spatial 350/500/650, effects 150/200/300) → `QEasingCurve` via `anim.hpp`.
  A global **duration `scale`** multiplies all durations (`appearanceconfig.cpp:151-189`), exposed
  as a live "Animation speed" slider.
- Wrappers: `components/Anim.qml` (NumberAnimation+enum), `AnchorAnim.qml`, `CAnim.qml` (color),
  `StateLayer.qml` (a genuinely rich Material ripple, `:71-90`).
- **Actually used on open/close** (verified): bar reveal `BarWrapper.qml:107-128`; drawer frame
  `ContentWindow.qml:356-360,491-492` (incl. metaball *deform* on open); popout open/close
  `bar/popouts/Wrapper.qml:180-209` (`Anim DefaultSpatial` on opacity, confirmed); notifications
  `notifications/Content.qml:201-204`, swipe `Notification.qml:36-39` (`emphasizedDecel`).

**How the references compare:**
- noctalia: wall-clock tween (`t=(now-startedAt)/duration`) so a 200 ms open stays exactly 200 ms
  under sparse frames; opens `EaseOutCubic`, closes `EaseInOutQuad`; **panel physically grows out
  of the bar** (clip-node + animated concave-corner `bulgeRadius`, `panel_manager.cpp:1328-1408`);
  global `MotionService` (speed + reduce-motion).
- end-4: one `Appearance` singleton exposing each named animation as a prebuilt
  `Component{NumberAnimation/ColorAnimation}` attached via
  `Behavior on X { animation: Appearance.animation.foo.createObject(this) }`; **expressive
  *overshooting* spatial curves** (control-y > 1) @ 350/500/650 ms; asymmetric enter(decel,400)/
  exit(accel,200); a **two-speed sliding pill** (`AnimatedTabIndexPair`: lead 100 ms / trail
  300 ms → the workspace indicator stretches as it moves); `alwaysRunToEnd:true` on micro-feedback.

**Ryoku's actual animation gaps (not "missing", but "uneven"):**
1. **Spatial variety**, many sites use bare `Anim{}` defaulting to `standard`/`normal` (400 ms),
   which reads flat/slow next to expressive overshoot. Default `normal`=400 ms is on the slow side
   (M3 medium is 300; effects 200).
2. **No "grows out of the bar" reveal**, ryoku has the `Blobs` deform primitive but popouts
   open via plain opacity (`Wrapper.qml:189-203`), not an attached-edge slide/bulge.
3. **Two divergent motion-disable mechanisms**, Tokens via `durations.scale` vs the legacy
   `Appearance.animationsEnabled`/`calcEffectiveDuration` (`modules/common/Appearance.qml:22-29`).
4. **The legacy `Appearance` curve set** drives dashboard/`ii` widgets separately from Tokens.

---

## 5. Bar / widgets feel & the "blob" chrome

- **Capsules respond to theme/transparency**: ryoku bar widgets read `Colours.tPalette.*`
  (`Workspaces.qml:37`, `StatusIcons.qml:19`, `Clock.qml:17`, `Tray.qml:34`), the
  transparency-applied palette, so they *do* lighten when transparency is on.
- **Popouts are real blobs**: `ContentWindow.qml:169-212` composes `BlobGroup`+`BlobInvertedRect`+
  `BlobRect`; morph between popouts is a container deform (`Content.qml:217-230`), not a cross-fade
 , closer to noctalia's attached feel than end-4's plain rectangles.
- **But the blob fill is opaque** (`BlobGroup.color = Colours.palette.m3surface`,
  `ContentWindow.qml:172`); transparency is applied via the surrounding `Item.opacity`
  (`:161`), so the glass effect depends on the compositor blur region actually being live.
- **The bar background itself doesn't consume `appearance.transparency`** at all (no `transparency`/
  `opacity` reference in `BarWrapper.qml`/`Bar.qml`), the single most-visible surface ignores the
  slider.

end-4's blob recipe worth mirroring exactly (`research/native-feel/end4-anim-bar.md`): full-edge
transparent `PanelWindow` + inset rounded `Rectangle` (margins = gap 5 + shadow gutter 10, `radius`
derived from `screenRounding` so the blob corner matches the *display* corner), 1px subtle border,
`cached RectangularShadow` (blur≈9, spread 1, offset(0,1), shadow@30%), and `mask: Region{blobRect}`
so only the blob takes input/draw, plus letting **Hyprland** animate the layer surface entrance
(`layerrule animation slide left/right/bottom/fade/popin` per namespace) while QML just flips
`visible`.

---

## 6. Transparency & blur (the #1 complaint): verdict table

Universal truth across all three shells: **a transparency slider only reads as "glass" when a
compositor blur region sits behind the surface.** noctalia delegates blur to the compositor
(`ext_background_effect set_blur_region`, region-locked to the animating shape, `surface.cpp:499-525`);
end-4 uses Hyprland `layer_rule blur` on `quickshell:*` namespaces (`rules.lua:130-159`); ryoku does
the same, *but only for `ryoku-drawers`* (`Colours.qml:96-106`).

Ryoku has **exactly one wired transparency path** and a pile of dead inherited controls:

| Control the user can find | Writes to | Read by a ryoku surface? | Verdict |
|---|---|---|---|
| Transparency **enable** toggle (UI→Appearance) | `appearance.transparency.enabled` (default **false**) | `Colours.layer()` gate `:47`; `ContentWindow.qml:161`; Hypr blur `:100-105` | **WORKS (live)** |
| **Panel opacity** slider | `appearance.transparency.base` (`AppearanceSubTab.qml:38`) | `Colours.qml:50`, `ContentWindow.qml:161`, Hypr `ignore_alpha` | **WORKS (live)** |
| **Surface opacity** slider | `appearance.transparency.layers` | `Colours.qml:50` (`alterColour`, layers ≥1 via tPalette) | **WORKS** (subtle; inner layers only) |
| **Animation speed** slider | `appearance.anim.durations.scale` | every duration getter `appearanceconfig.cpp:151-189` | **WORKS (live)** |
| "Bar background opacity" | nothing (dropped) | bar never reads it | **NO-OP** (`settings-default.json:16`) |
| "Capsule opacity" | nothing | capsules read `tPalette` only | **NO-OP** (`settings-default.json:10`) |
| "Use separate bar opacity" | nothing |, | **NO-OP** (`settings-default.json:17`) |
| Dock background/dead/indicator opacity | noctalia `Settings.data.dock.*` | only `Modules/Dock/*`, **not instantiated** by `shell.qml` | **DEAD (ryoku has no dock)** |
| Notification background opacity | dropped | ryoku notifs use `tPalette` | **NO-OP** |
| OSD background opacity | dropped |, | **NO-OP** |
| Dimmer opacity | UI slider present but **`enabled:false`** (`PanelsSubTab.qml:46-47`) | scrim fixed at `m3scrim@0.5` (`ContentWindow.qml:151`) | **DISABLED STUB** |

Proof the noctalia keys are dead: `shell.qml:1-78` never instantiates `Modules/Dock|OSD|MainScreen|
Launcher` (the only readers); **zero `Settings.data.*Opacity` writes** exist in the settings tabs.
(Independently re-verified by manager: searching `shell/{modules,services,components}` for
`backgroundOpacity|capsuleOpacity|dimmerOpacity|deadOpacity|indicatorOpacity` returns only the
vendored end-4 `modules/ii/overlay/` config, not the settingsgui store.)

**Why it "does nothing" in one sentence:** the controls users actually see are mostly dead vendored
noctalia sliders; the one real control is **off by default, its sliders are hidden until you flip a
toggle, the bar ignores it, and the blob fill is opaque so the effect only shows where Hyprland blur
is active.**

---

## 7. Color / theme (Material You)

All three are Material-You. **ryoku** derives a scheme from the wallpaper via an external
`ryoku-scheme-set`/matugen-style bridge → writes `${state}/scheme.json` → `Colours.qml:125-130`
watches and loads it → `Colours.palette` (opaque) + `Colours.tPalette` (alpha-applied mirror). This
is solid. Gaps vs the references:
- **No theme cross-fade**: noctalia animates `lerpPalette(from,target,t)` with `EaseOutCubic`
  (`theme_service.cpp:565-578`) so theme switches glide; ryoku snaps. (Easy, high-perceived-quality.)
- **Native app theming parity unverified**: end-4's matugen `config.toml` fans out to gtk3/4 +
  Kvantum/kdeglobals + fuzzel + terminal in one run (`matugen/config.toml:4-35`) + `kde-material-
  you-colors` for Qt/KDE; ryoku has `settingsgui/Assets/Templates/*` but Qt/GTK app parity should be
  confirmed/extended so non-shell apps match the shell (a big part of "feeling native").

---

## 8. Organization (the "unorganized" complaint): evidence

`research/native-feel/ryoku-arch.md` + `ryoku-anim-settings.md` document the concrete sprawl:

- **Repo root mixes the shell with whole-distro tooling**: `shell/`, `bin/` (**240** `ryoku-*`),
  `migrations/` (**402** `.sh`), `lib/`, `default/`, `config/`, `install/`, `iso/`, `shell-install/`,
  `distro/`, `themes/`, `wallpapers/`, `videowalls/`, `tui/` (Go), `vendor/qylock/`,
  `legacy/controlcenter/`, `tests/` (180+).
- **Three parallel UI surfaces** loaded together: settingsgui (canonical) / dashboard (**retiring**,
  per `AGENTS.md:96-97`) / controlcenter.
- **Three coexisting config stores**: `shell.json` (typed C++), `settings-gui/settings.json`
  (1000-line vendored-noctalia JsonAdapter, `settingsVersion 59`), `dashboard/*.json` (7 FileViews).
  A single panel can read/write **both** `Settings.data.*` and `GlobalConfig.*` → ambiguous ownership.
- **Three design systems**: canonical `Tokens`+`Colours`+`Blobs`; vendored end-4
  `modules/common/Appearance.qml` (**`backgroundTransparency:0` hardcoded**, own curves +
  `GlassBackground` MultiEffect blur, separate anim-disable gate); vendored noctalia settingsgui.
- **Vendored-from-two-upstreams**: `settingsgui/` ≈ noctalia; `modules/ii/` ≈ end-4 (Spanish
  comments, `Config.options.overlay.*`). Neither fully folded into ryoku's canonical layers.

This fragmentation is not cosmetic, it is the *mechanical cause* of "settings don't do much"
(dead store) and "weak/inconsistent animation" (two motion systems).

---

## 9. Root-cause summary: why ryoku doesn't feel like them

1. **Disconnected settings surface**, dead vendored opacity sliders dominate the UI; the one real
   transparency control is buried, off by default, and the bar ignores it. (§3, §6)
2. **Transparency without blur-behind reads as flat dim**, blur layerrule exists only for drawers,
   not the bar/other surfaces; blob fills are opaque. (§5, §6)
3. **Motion is uneven**, strong M3 tokens, but bare `Anim{}`/400 ms defaults dominate, no
   grows-out-of-bar reveal, and a second legacy curve system runs in parallel. (§4)
4. **No theme cross-fade**, and unverified native Qt/GTK app theming. (§7)
5. **Triple fragmentation** (surfaces/stores/design systems) makes the whole thing feel inconsistent
   and unreliable. (§8)
6. **A few per-tick subprocess spawns** cause occasional micro-stutter. (§2)

noctalia's *fundamental* native edge (custom GL renderer, idle-until-dirty vsync loop) is **not
copyable** in QML and is **not** where ryoku's perceived gap mainly comes from, the items above are.

---

## 10. Roadmap to native feel (prioritized, file-level)

Tiers ordered by impact-per-risk. Items marked **[decision]** change a default / delete vendored
code / retire a surface and should be confirmed with the user (per `AGENTS.md`: default changes for
existing users need a `[global]` migration; deletions of vendored code need buy-in).

### Tier 0: Make the existing machinery visibly work (high impact, low risk, ~days)
- **T0.1 Wire the bar to transparency.** Make `BarWrapper`/`Bar` background consume
  `Colours.tPalette`/`appearance.transparency` like drawers/capsules do. *(The single most-visible
  surface currently ignores the slider, §5/§6.)*
- **T0.2 Add a Hyprland blur layerrule for the bar (+ other surfaces) namespace**, mirroring
  `Colours.qml:96-106` for `ryoku-drawers`. Ensure stable `WlrLayershell.namespace` per surface
  (`ryoku-bar`, `ryoku-notifications`, …) and `noanim` on launcher/overview. *(Glass needs blur-behind.)*
- **T0.3 Un-gate the opacity sliders**, show-but-disable instead of `visible:`-gated on `enabled`
  (`AppearanceSubTab.qml:29,45`); lower the `base` floor below 0.4 so it can go sheer.
- **T0.4 Remove/relabel the dead noctalia opacity controls + i18n** (capsule/dock/notif/OSD and the
  `settings-default.json` keys) so the UI only advertises wired controls. Implement the **dimmer**
  for real (`PanelsSubTab.qml:36` TODO → wire `ContentWindow.qml:151` scrim to a config key).
- **T0.5 Spatial-variety pass on open/close**, replace bare `Anim{}`/`standard` with
  `Emphasized`/`DefaultSpatial` on bar/popout/drawer reveals; verify default durations feel snappy
  (consider `normal` 400→~300, or rely on `durations.scale`).
- **T0.6 [decision] Default `transparency.enabled = true`** via a `[global]` migration (per the
  config contract) so the feature is on out-of-the-box.

### Tier 1: Native-feel parity (medium effort)
- **T1.1 Per-surface transparency keys**, add `appearance.transparency.{bar,capsule,notif}`
  (feeding `tPalette`/capsule alpha) instead of one global `base`; this is the control users expect
  from noctalia/end-4.
- **T1.2 Named transparency modes (Solid / Soft / Glass)** as preset mappings over the opacity keys
  (noctalia `config_types.cpp:130-153` pattern), legible discrete choices instead of a raw alpha.
- **T1.3 "Grows out of the bar" popout reveal**, use the `Ryoku.Blobs` deform/inverted-corner
  primitive with a clip + animated radius/bulge so popouts attach to the bar (noctalia
  `panel_manager.cpp:1328-1408`), instead of plain opacity (`Wrapper.qml:189-203`).
- **T1.4 Theme cross-fade**, interpolate `Colours.palette` over a short eased duration on scheme
  switch (noctalia `lerpPalette`/`theme_service.cpp:565-578`).
- **T1.5 Two-speed workspace/tab indicator**, port end-4's `AnimatedTabIndexPair` (lead 100 ms /
  trail 300 ms → stretch).
- **T1.6 Native app theming audit/extension**, confirm matugen→Kvantum/kdeglobals/gtk parity so
  Qt/GTK apps match the shell (end-4 `matugen/config.toml`, `kde-material-you-colors`).

### Tier 2: Consolidation (structural; **[decision]**-heavy, the real "organized" fix)
- **T2.1 Converge the three design systems → one** (`Tokens`+`Colours`+`Blobs`): migrate dashboard/
  `ii` widgets off `modules/common/Appearance.qml` + `GlassBackground`; delete the
  `backgroundTransparency:0` hardcode; unify the anim-disable path (`durations.scale` vs
  `animationsEnabled`).
- **T2.2 Converge the three config stores → `shell.json`** (typed): migrate
  `settings-gui/settings.json` + `dashboard/*.json` keys into `GlobalConfig` (per `AGENTS.md:85-92`),
  so one store = one source of truth and every control binds live.
- **T2.3 Retire the dashboard surface** (already flagged retiring) and finish folding settingsgui
  controls onto `GlobalConfig` (the "RYOKU WIRED" migration), deleting dead vendored modules
  (`Modules/Dock|OSD|MainScreen`, `Panels/Launcher`) ryoku never instantiates.
- **T2.4 Route settings actions through `ryoku-shell ipc`** instead of ~55 `execDetached` sites.
- **T2.5 Repo-root tidy**, clarify shell vs distro-tooling boundaries (`bin/`, `migrations/`,
  `iso/`, `install/`, `legacy/`); the shell is freely reorganizable per `AGENTS.md:70-81`.

### Tier 3: Smoothness / perf hygiene
- **T3.1 Kill per-tick subprocess spawns**, replace `SystemUsage.qml:81-93` (`lsblk`/`gpu`/`sensors`
  per tick) and `CustomWidgets`/`Notes` `sh -c` polling with native collectors in
  `Ryoku.Internal`/`Ryoku.Models` (noctalia reads sysfs/D-Bus/pipewire directly).
- **T3.2 QML jank audit** (quickshell FAQ / KDAB): `RectangularShadow` over `MultiEffect`;
  `Image.sourceSize` everywhere; keep hot popups resident + toggle `visible`/opacity (don't re-Load);
  animate opacity/scale/transform, never anchors/layout; set window `surfaceFormat` transparency once.
- **T3.3 Reduce-motion + global motion speed** service (noctalia `MotionService`) layered over
  `durations.scale`.

---

## 11. Appendix: raw findings & sources

Per-agent cited findings (in [`research/native-feel/`](native-feel/)):
- `noctalia-arch.md`, process/poll loop, IPC socket, atomic-write + inotify + targeted reload, direct D-Bus/pipewire/sysfs.
- `noctalia-render-anim.md`, GLES2 scene graph, vsync idle-until-dirty, `AnimationManager` wall-clock tween, SDF blob + concave corners, compositor blur.
- `noctalia-settings-theme.md`, same-binary settings, synchronous in-process reload, slider→pixels path, Material-You + template worker thread + cross-fade.
- `end4-arch.md`, single `qs` process, `FileView`+`JsonAdapter` live loop, matugen fan-out, `MaterialThemeLoader`.
- `end4-anim-bar.md`, `Appearance` motion singleton (bézier `Component`s), blob recipe, Hyprland layerrule blur + entrance, two-speed pill.
- `ryoku-arch.md`, startup/systemd, process model + jank, IPC surface, live-vs-restart, three stores, C++ plugin map.
- `ryoku-anim-settings.md`, transparency verdict table, Tokens usage audit, Blobs renderer, the second design system.
- `online-research.md`, noctalia philosophy, M3 motion curves+durations, quickshell jank causes, Hyprland blur layerrules, free-wins vs compositor-dependent.

Selected external sources:
- noctalia: <https://github.com/noctalia-dev/noctalia-shell> · <https://docs.noctalia.dev/v5/>
- end-4: <https://deepwiki.com/end-4/dots-hyprland> · Appearance.qml (curves) raw on GitHub
- quickshell FAQ: <https://quickshell.org/docs/v0.3.0/guide/faq/> · blur issue #24 (compositor blur, by author)
- Hyprland layer rules: <https://github.com/hyprwm/Hyprland/discussions/12748>
- Material 3 motion: <https://m3.material.io/styles/motion/easing-and-duration/tokens-specs> · curves: material-web `internal/motion/animation.ts`
