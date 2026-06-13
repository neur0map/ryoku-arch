# Ryoku: Animation, Bar/Popup Feel, Color & Transparency End-to-End

Scope: ryoku QML/quickshell shell at `~/Work/ryoku-arch/shell`. All claims cited `path:line`.
READ-ONLY investigation.

## TL;DR verdict (the headline)
- ryoku has **exactly ONE real transparency control path**: `GlobalConfig.appearance.transparency.{enabled,base,layers}` → `Tokens.transparency` → `Colours.layer()/tPalette` + `ContentWindow` Item.opacity + Hyprland blur IPC. It **is wired and live** (no restart). Slider UI: `settingsgui/.../UserInterface/AppearanceSubTab.qml`.
- `shell/settingsgui/` is a **vendored noctalia-shell** (N* widgets, `noctalia.svg`, noctalia `settings-default.json`, noctalia `Modules/Dock|OSD|MainScreen`). Most settings tabs were **rewired to `GlobalConfig.*`** ("RYOKU WIRED" comments), but noctalia's **per-surface opacity keys (`bar.backgroundOpacity`, `bar.capsuleOpacity`, `dock.*Opacity`, `notifications.backgroundOpacity`, `osd.backgroundOpacity`, `general.dimmerOpacity`) are NOT exposed as working ryoku sliders**, they were dropped from the UI, or left as disabled (`enabled:false`) stubs, or are read only by noctalia modules that **ryoku's `shell.qml` never instantiates**.
- "Settings don't feel like they do much" root causes: (1) `transparency.enabled` defaults **false**, and the opacity sliders are **hidden** until the toggle is on; (2) the inherited i18n strings advertise capsule/dock/notif/OSD/dimmer opacity that has **no live effect** in ryoku; (3) a **second, parallel legacy design system** (`modules/common/Appearance.qml`, end-4 heritage) with `backgroundTransparency: 0` hardcoded drives the retiring dashboard surfaces and ignores the slider entirely.

---

## 1. Animation system

### Central tokens (C++ Material-3 motion)
- Duration tokens: `plugin/src/Ryoku/Config/tokens.hpp:105-123` (`AnimDurationTokens`): small=200, normal=400, large=600, extraLarge=1000, expressiveFastSpatial=350, expressiveDefaultSpatial=500, expressiveSlowSpatial=650, expressiveFast/Default/SlowEffects=150/200/300.
- Curve control points: `tokens.hpp:10-42` (`AnimCurves`): emphasized, standard(+Accel/Decel), expressive{Fast,Default,Slow}{Spatial,Effects} as cubic-bezier point lists.
- Curves → `QEasingCurve` built in `anim.hpp:12-76` (`AnimTokens`, `buildCurve`).
- Binding: `tokensattached.cpp:76-79`, `bindDurations(GlobalConfig.appearance.anim.durations)` and `bindCurves(TokenConfig.appearance.curves)`. So durations come from `shell.json`/GlobalConfig (with `scale`), curves from `shell-tokens.json` (`tokens.cpp:21`).
- A global **duration scale** multiplies every duration: `appearanceconfig.cpp:151-189` (each getter `* m_scale`). Default scale=1 (`appearanceconfig.hpp:174`). Exposed as a live slider → `AppearanceSubTab.qml:149-154` writes `GlobalConfig.appearance.anim.durations.scale`.

### QML wrappers
- `components/Anim.qml`, `NumberAnimation` with an enum `Type` (StandardSmall…SlowSpatial); `duration`/`easing` resolved from `Tokens.anim.durations`/`Tokens.anim.*` (`Anim.qml:21-47`). Default type = `Standard`.
- `components/AnchorAnim.qml`, same enum over `AnchorAnimation`; default `DefaultSpatial` (`AnchorAnim.qml:19-50`).
- `components/CAnim.qml`, `ColorAnimation`, duration `normal`(400)/easing `standard` (`CAnim.qml:4-7`). Used by every `StyledRect`/`StyledText` color transition (`StyledRect.qml:8-10`, `StyledText.qml:22-24`).
- `components/StateLayer.qml`, Material ripple: radial-gradient `Shape` expanding to `endRadius`, `rippleAnim` uses `expressiveSlowEffects*2` (`StateLayer.qml:71-80`), fade `expressiveSlowEffects` (`:82-90`), hover `stateOpacity` 0→0.08 with `expressiveDefaultEffects` (`:14,184-188`). This is a genuinely rich, physically-plausible ripple.

### Are the curves actually USED on open/close? (audit)
YES, extensively, not merely defined:
- **Bar reveal/hide**: `modules/bar/BarWrapper.qml:107-128`, show/hide transitions animate `implicitWidth`/`implicitHeight` with `Anim{type:DefaultSpatial}`.
- **Drawer/panel frame**: `modules/drawers/ContentWindow.qml:356-360` `Behavior on extraWidth Anim{DefaultSpatial}`; `:491-492` `Behavior on deformAmount` (metaball deform); blob color `:175-177 CAnim`.
- **Bar popouts ("blob wrappers")**: `modules/bar/popouts/Wrapper.qml:189-203` open/close fade `Anim{type:DefaultSpatial}`; content swap `popouts/Content.qml:197-230` `Anim{StandardSmall}` with morph delay.
- **Notifications**: `modules/notifications/Content.qml:201-204` local `Anim` = `expressiveDefaultSpatial`; list move/displaced transitions (`:69-79`); swipe-dismiss `Notification.qml:36-39` `emphasizedDecel`; expand `:101-105 DefaultSpatial`; progress arc `:219-222 emphasizedDecel`.
- **Controls**: `FilledSlider.qml:141-144 StandardLarge`, `SplitButton.qml:85-87 Emphasized`, `Menu.qml:92-95 DefaultSpatial`, `CircularIndicator.qml:66-67` (`* durations.scale`).

Verdict: the Tokens.anim M3 system is **well-applied** across new surfaces. Richness is high and centralized, comparable structurally to noctalia's curve system and richer than end-4's element-move tokens. Weakness is **uniformity/spatial variety** (many `Anim{}` default to plain `standard`/`normal`), and the **legacy dashboard** uses a different curve set (see §6).

---

## 2. Bar / widget feel

- **Bar capsules / rounded widget backgrounds**: `modules/bar/components/Workspaces.qml:37` `color: Colours.tPalette.m3surfaceContainer`; `StatusIcons.qml:19`; `Clock.qml:17` (alpha gated on `Config.bar.clock.background`); `Tray.qml:34` (gated on `bar.tray.background`). All use **tPalette** → they inherit transparency.
- **Hover/press**: `StateLayer.qml` ripple+hover applied per-widget (e.g. `Menu.qml:141`). Hover bg opacity 0.08 (`StateLayer.qml:14`).
- **Popouts ("blob wrappers")**: built from the C++ `Ryoku.Blobs` metaball renderer, `modules/drawers/ContentWindow.qml:169-189` (`BlobGroup`+`BlobInvertedRect`), panels as `BlobRect` `PanelBg` (`:191-212,460+`). Bar popouts: `modules/bar/popouts/{Wrapper,Content,ClipWrapper}.qml`. Morph between popouts is a container deform, not a cross-fade (`Content.qml:217-230`).
- `services/BarDesign.qml` is **NOT** an opacity/feel service, it resolves the swappable bar *layout* design (sidebar-left/compact/top-notch), `templateId/edge/fillsEdge`, frozen at startup (`BarDesign.qml:72-89`).

---

## 3. TRANSPARENCY / OPACITY END-TO-END (critical)

### The one real path (WIRED, live)
- **Config keys** (`appearanceconfig.hpp:223-234`): `appearance.transparency.enabled` (bool, default **false**), `.base` (qreal 0.85), `.layers` (qreal 0.4). Persisted to `~/.config/ryoku/shell.json`.
- **Write site (UI)**: `settingsgui/Modules/Panels/Settings/Tabs/UserInterface/AppearanceSubTab.qml`:
  - toggle → `transparency.enabled` (`:20-24`)
  - "Panel opacity" slider (0.4–1.0) → `transparency.base` (`:35-40`), *only `visible:` when enabled (`:29`)*
  - "Surface opacity" slider (0.2–1.0) → `transparency.layers` (`:51-56`), *also visibility-gated (`:45`)*
- **Binding**: `tokensattached.cpp:94-96` `Tokens::transparency()` returns `GlobalConfig.appearance.transparency` ("always global").
- **Read sites (apply to rendered surfaces)**:
  - `services/Colours.qml:46-51` `layer(c,layer)`, if `!enabled` returns c unchanged; layer 0 → `Qt.alpha(c, base)`; other layers → `alterColour(c, layers, …)`.
  - `Colours.qml:154-213` `M3TPalette` (`Colours.tPalette`) applies `layer()` to all surface roles → consumed by bar capsules, notifications (`Notification.qml:24`), popouts (`Battery.qml:115`, `WirelessPassword.qml:127`, etc.).
  - `modules/drawers/ContentWindow.qml:161` whole panel/drawer Item `opacity: transparency.enabled ? transparency.base : 1` (the big surfaces dim via Item opacity, while blob fill stays `palette.m3surface`).
  - **Compositor blur**: `Colours.qml:96-106 reloadHyprRules()` pushes Hyprland `layerrule blur` + `ignore_alpha = base-0.03` for `ryoku-drawers`; re-fired on `base/enabled` change via debounce (`:138-152`).
- **Liveness**: writes mutate the in-process C++ `GlobalConfig` singleton (emits NOTIFY) → `tPalette`/`Item.opacity` recompute immediately; `GlobalConfig.save()` only persists. **No restart, no file-watch needed.** Hypr rules update after a 300 ms debounce.

### Verdict table: every opacity/transparency control the user can encounter

| Control (i18n / UI) | Writes to | Read by a ryoku rendered surface? | Verdict |
|---|---|---|---|
| Transparency **enable** toggle (UserInterface→Appearance) | `GlobalConfig.appearance.transparency.enabled` | `Colours.layer()` gate `Colours.qml:47`; `ContentWindow.qml:161`; Hypr blur `Colours.qml:100-105` | **WORKING (live)** |
| **Panel opacity** slider | `GlobalConfig.appearance.transparency.base` `AppearanceSubTab.qml:38` | `Colours.qml:50` (alpha), `ContentWindow.qml:161`, Hypr `ignore_alpha` `Colours.qml:101,105` | **WORKING (live)** |
| **Surface opacity** slider | `GlobalConfig.appearance.transparency.layers` `AppearanceSubTab.qml:54` | `Colours.qml:50` `alterColour` for layer≥1 via `tPalette` | **WORKING (live)** but subtle (only inner layered surfaces) |
| **Animation speed** slider | `GlobalConfig.appearance.anim.durations.scale` `AppearanceSubTab.qml:152` | every duration getter `appearanceconfig.cpp:151-189`; legacy `Style.qml:84-88` | **WORKING (live)** |
| "Bar background opacity" (`appearance-background-opacity-label`) | nothing in ryoku, dropped | DesignSubTab tells user it's global `Bar/common/DesignSubTab.qml:102` | **NO control / NO-OP** (key `bar.backgroundOpacity` only in noctalia `settings-default.json:16`) |
| "Capsule opacity" (`appearance-capsule-opacity-label`) | nothing, no slider rendered | capsules read `Colours.tPalette` only | **NO control / NO-OP** (`settings-default.json:10` unused) |
| "Use separate bar opacity" | nothing |, | **NO-OP** (`settings-default.json:17` unused) |
| Dock background/dead/indicator opacity | noctalia `Settings.data.dock.*` | only `Modules/Dock/*` & `Panels/Dock/StaticDockPanel.qml:10`, **not instantiated by `shell.qml`** | **DEAD (ryoku has no dock)** |
| Notification background opacity (`settings-background-opacity`) | dropped | `Notifications/GeneralSubTab.qml:10-12` says backend has no equivalent | **NO control / NO-OP** (ryoku notifs use `tPalette` `Notification.qml:24`) |
| OSD background opacity | dropped | `Osd/GeneralSubTab.qml:8-10` says dropped | **NO control / NO-OP** |
| Dimmer opacity (`dimmer-opacity-label`) | UI slider present but **`enabled:false`** `UserInterface/PanelsSubTab.qml:46-47` | ryoku session dim is fixed `Colours.palette.m3scrim @0.5` `ContentWindow.qml:151` | **DISABLED STUB** (TODO `PanelsSubTab.qml:36`) |
| "Panel background opacity" (UserInterface→Panels) | intentionally omitted `PanelsSubTab.qml:31-33` | (would dup `transparency.base`) | **REMOVED on purpose** |

Proof noctalia opacity readers are dead in ryoku: `shell.qml:1-78` instantiates `Background/Drawers/AreaPicker/Overlay/…` and imports only `settingsgui.Services.Platform` (`:16`), it does **not** instantiate noctalia `Modules/Dock`, `Modules/OSD`, `Modules/MainScreen`, or `Panels/Launcher`, which are the only readers of `Settings.data.*.backgroundOpacity`/`dimmerOpacity` (`Modules/Dock/DockContent.qml:29`, `Modules/OSD/OSD.qml:561`, `Modules/MainScreen/MainScreen.qml:76,82-83`, `Panels/Launcher/LauncherOverlayWindow.qml:101`). No `Settings.data.*Opacity` write exists anywhere in the settings tabs (searched, zero matches).

### Why it "doesn't feel like it does much"
1. `transparency.enabled` is **false by default** (`appearanceconfig.hpp:227`); the two opacity sliders are `visible:`-gated on it, so a user who never flips the toggle sees nothing move.
2. When on, **drawers dim correctly** (`base` via `ContentWindow.qml:161` + blur), and **bar capsules/notifications** lighten via `tPalette`. But the **blob fill itself is `Colours.palette.m3surface` (opaque)** (`ContentWindow.qml:172`); transparency is applied by the surrounding `Item.opacity`, so the perceived effect depends on the compositor actually blurring, if Hypr blur isn't active for `ryoku-drawers`, the result reads as a flat dim rather than glass.
3. `base` slider min is **0.4** (`AppearanceSubTab.qml:32`), can't go very sheer.
4. All the inherited noctalia opacity labels (capsule/dock/notif/OSD/dimmer) raise expectations the shell never fulfills.

---

## 4. Color system

- **Palette source**: Material-3 token palette. Defaults hardcoded in `Colours.qml:215-290` (`M3Palette`, the rose default scheme + `term0-15`). At runtime it's **wallpaper-derived / scheme-driven**, NOT static: `Colours.qml:125-130` watches `${Paths.state}/scheme.json` and `load()`s it (`:59-90`); on startup if `services.smartScheme` it derives from wallpaper (`:108-115`). Scheme files produced by the external `ryoku-theme-set`/`ryoku-scheme-set`/`scheme from-wallpaper` bridge (matugen-style), invoked from `ColorScheme/ColorsSubTab.qml:530-740`. So: **Material You via an external generator**, with predefined scheme tiles as the alternative.
- **How colors reach surfaces**: singleton `Colours.palette` (opaque `M3Palette`) and `Colours.tPalette` (transparency-applied `M3TPalette`). Surfaces choose: accent/text use `palette.*`; backgrounds that should respect transparency use `tPalette.*`.
- **Transparency vs color**: transparency is **applied as a separate alpha layer**, *not* baked into the scheme. `layer()` (`Colours.qml:46-51`) wraps a base color with `Qt.alpha`/`alterColour`; `tPalette` is the alpha-applied mirror of `palette`. `alterColour` (`:34-44`) also brightens by wall luminance so translucent layers stay legible. Net: a surface gets transparency **only if it references `tPalette` or sits inside the `ContentWindow` opacity Item**, surfaces hardcoded to `palette.*` (e.g. notification accent badges `Notification.qml:121,152`, ripple `StateLayer.qml:97`) are intentionally opaque.

---

## 5. Ryoku.Blobs renderer (`plugin/src/Ryoku/Blobs/`)
- C++ QSG metaball renderer: `BlobGroup` (parent, `smoothing` + single `color`), `BlobRect` (spring-physics deformable rounded rect: `stiffness/damping/deformScale`, per-corner radii, `exclude` list), `BlobInvertedRect` (border-carving frame), `blobshape.cpp`/`blobmaterial` + `shaders/blob.frag` (SDF metaball union, rounded corners, AA).
- **Opacity/blur exposure**: `BlobGroup` exposes only `color` (`blobgroup.hpp:15`) and `smoothing` (`:14`); `BlobShape`/`BlobRect`/`BlobInvertedRect` expose geometry/physics only, **NO opacity, NO blur, NO transparency property**. Translucency must be carried in the `QColor` alpha or via the parent `Item.opacity`. **Blur is entirely compositor-side** (Hyprland layerrule, §3), the blob shader does shape/AA, not gaussian blur.
- Usage: `modules/drawers/ContentWindow.qml:169-212,460+` is the unified frame; bar popouts use the same family. `BlobGroup.color` is fed `Colours.palette.m3surface` (opaque) with a `CAnim` color behavior (`:172-177`).

## 6. Second (legacy) design system: disorganization signal
`shell/modules/common/Appearance.qml` is an **end-4 "illogical-impulse" heritage** singleton coexisting with Tokens:
- own motion tokens (`Appearance.animation.elementMoveFast/elementMove/clickBounce`, `Appearance.animationCurves.expressiveFastSpatial`) used by dashboard/ii widgets (`NotificationGroup.qml`, `NotificationItem.qml`, `NotificationListView.qml`, `RippleButton.qml`, `ContextMenu.qml`, `GroupButton.qml`, `MaterialSymbol.qml`).
- own theme variants (`angelEverywhere`/`inirEverywhere`/`auroraEverywhere`) and `GlassBackground.qml` with a real `MultiEffect` wallpaper blur (`GlassBackground.qml:74-86`).
- **`Appearance.backgroundTransparency: 0` is hardcoded** (`Appearance.qml:25`) → these legacy surfaces are effectively opaque and **ignore the ryoku transparency slider**.
- Game-mode animation freeze lives here: `Appearance.qml:22-28` (`animationsEnabled = !(GameMode.enabled && gameMode.shellAnimations)`), gating legacy `Behavior`s; the new Tokens surfaces are instead slowed via `durations.scale`. Two different "disable animations" mechanisms.

This dual system (Tokens+Colours+Blobs vs Appearance+GlassBackground, plus the vendored noctalia settingsgui) is the concrete form of the "repo feels disorganized" complaint.

---

## Portable-to-ryoku recommendations (for Main's roadmap)
1. **Default `transparency.enabled = true`** (or surface the toggle prominently) and **always show** the opacity sliders (drop the `visible:` gate, just disable when off), the #1 reason settings "do nothing".
2. **Delete or relabel** the inherited noctalia opacity i18n keys (capsule/dock/notif/OSD/dimmer) and dead `settings-default.json` keys, so the UI only advertises wired controls. Implement the **dimmer** for real (`PanelsSubTab.qml:36` TODO) → wire `ContentWindow.qml:151` scrim to a config key.
3. **Per-surface opacity** (bar bg vs capsule vs notif) is what users expect from noctalia, add real `GlobalConfig.appearance.transparency.{bar,capsule,notif}` keys feeding `tPalette`/capsule alpha, instead of one global `base`.
4. **Verify Hyprland blur is actually applied** for `ryoku-drawers` on first run (the perceived "glass" depends on it; `reloadHyprRules` only fires on change/startup), consider a lower `base` floor than 0.4.
5. **Converge the two design systems**: migrate dashboard/ii widgets off `Appearance.*`/`GlassBackground` onto Tokens/Colours/Blobs, retire `Appearance.backgroundTransparency` hardcode; unify the animation-disable path (scale vs animationsEnabled).
6. Animation richness is already strong (M3 spatial/effects curves, ripple, metaball morph). Bigger wins are **spatial variety on open/close** (use Emphasized/Spatial types more, fewer bare `Anim{}`) and **consistency** between new and legacy surfaces.
