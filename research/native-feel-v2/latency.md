# Native-feel v2: Perceived speed & navigation latency

Why noctalia/dots panels open instantly and feel fluid vs ryoku's "settings apps
opening" lag. Investigation only, Main implements + owns the build/verify gate.

Reference note: **noctalia-shell has been rewritten to C++** (`~/Work/noctalia-shell/src/`,
`meson.build`), no `.qml` files remain, so its panel-instantiation patterns are
not citable as QML. The live QML reference is **dots-hyprland**
(`~/Work/dots-hyprland/dots/.config/quickshell/ii`). Ryoku's own
`shell/settingsgui/` is itself old-noctalia-QML-derived (N-prefixed widgets), so
the "noctalia way" is largely already in-tree.

Ranked by impact-per-risk. The first two are the direct cause of the settings lag.

---

## 1. Settings panel is destroyed on close → entire 1.3k-line UI rebuilt **synchronously** on every open  [HIGH impact / LOW risk / no compositor]

**Gap.** Ryoku's settings surface (the in-bar ControlCenter) tears its whole
content tree down when the panel closes and reconstructs it from scratch on the
next open, on the UI thread, on the opening frame. That single synchronous build
(sidebar + search + first tab + all the `Component{}` templates) is the "settings
apps opening" hitch.

**Reference evidence (dots, keep-warm, config-gated).**
- `dots-hyprland/dots/.config/quickshell/ii/modules/ii/sidebarRight/SidebarRight.qml:50`
 , `active: GlobalStates.sidebarRightOpen || Config?.options.sidebar.keepRightSidebarLoaded`
  The content Loader stays loaded while closed when the toggle is on.
- `…/modules/common/Config.qml:499`, `property bool keepRightSidebarLoaded: true` (default ON).
- `…/modules/settings/InterfaceConfig.qml:471-477`, user toggle "Keep right sidebar loaded"
  with tooltip: *"keeps the content of the right sidebar loaded to reduce the delay when
  opening, at the cost of around 15MB of consistent RAM usage."*, exactly this tradeoff.

**Ryoku evidence (current state).**
- `shell/modules/controlcenter/Wrapper.qml:73-88`, `Loader { id: content; active: root.shouldBeActive || root.visible; sourceComponent: SettingsContent {…} }`.
  `visible: offsetScale < 1` (line 44) and `shouldBeActive: visibilities.settings` (line 23),
  so once closed (`offsetScale === 1`) the Loader goes inactive → `SettingsContent` is **destroyed**.
- `shell/settingsgui/Modules/Panels/Settings/SettingsContent.qml:32` is a ~1325-line `Item`;
  `Component.onCompleted` (line 403) registers system-stat polling and the first
  `initialize()`/`updateTabsModel()` run rebuilds the whole tab model each open.
- The Loader has **no `asynchronous: true`**, so the rebuild blocks the compositor frame.

**Fix.**
1. Gate the Loader: `active: GlobalConfig.controlcenter.keepWarm || root.shouldBeActive || root.visible`.
   When warm, the panel is built once and survives close → opens are instant.
2. Add `asynchronous: true` to the same Loader so even the *cold* (first-ever) build
   happens off the render thread, the morph/clip animation already masks the brief
   not-ready frame.
3. Implementation note for Main: `SettingsContent` registers `SystemStatService` on
   completion and unregisters on destruction (lines 35, 404). When kept warm, pause
   that polling while `!shouldBeActive` (e.g. drive `SystemStatService` register/
   unregister off `shouldBeActive` instead of component lifetime) so warm-keep costs
   RAM but not CPU.

**Config key.** New `CONFIG_PROPERTY(bool, keepWarm, false)` → `GlobalConfig.controlcenter.keepWarm`.
Home: `shell/plugin/src/Ryoku/Config/controlcenterconfig.hpp` (currently empty -
the header comment "no serialized properties" must be updated and the prop wired in
`rootconfig.cpp`). Default `false` (opt-in, mirrors dots' RAM-vs-latency note; dots
defaults ON, but ryoku's settings tree is heavier so opt-in is safer). Alternative
home if a generic toggle is preferred: `GlobalConfig.appearance.keepPanelsWarm`
alongside the existing `appearance.reduceMotion` (`appearanceconfig.hpp:242`).

**Risk.** Low. Async-only (step 2) is a pure win and could ship unconditionally;
the warm-keep adds the resident-RAM tradeoff, hence the off-by-default key.

---

## 2. Settings tab content Loaders are **synchronous** and **non-retained** → every tab click blocks + rebuilds  [HIGH impact / LOW risk / no compositor]

**Gap.** Switching settings tabs (sidebar click) destroys the previous tab and
builds the new one synchronously on the click frame; switching back rebuilds again.
This is the in-panel navigation jank (distinct from first-open in #1).

**Reference evidence.** ryoku and dots already use `asynchronous: true` pervasively
for comparable content, e.g. `shell/modules/bar/Bar.qml:227`,
`shell/modules/background/Background.qml:46`, dots
`…/ii/bar/Bar.qml:26` (`LazyLoader`). The settings tab loader simply never got it.

**Ryoku evidence.**
- `shell/settingsgui/Modules/Panels/Settings/SettingsContent.qml:1214-1283` -
  `Repeater { model: tabsModel; delegate: Loader { active: index === root.currentTabIndex; … } }`
  No `asynchronous`. `active` is true only for the current tab → inactive tabs are
  destroyed, so navigating away then back is a full rebuild.
- Inner `Loader` at line 1256 (`active: true`, `sourceComponent: tabsModel[index].source`)
  is also synchronous; the heavy tab bodies (e.g. `ColorSchemeTab`, `BarTab`,
  `SystemMonitorTab`) build on-thread.

**Fix.**
1. Add `asynchronous: true` to the per-tab delegate Loader (line 1217) and the inner
   content Loader (line 1256). The existing `opacity` fade-in (lines 1220-1229) already
   masks the async gap, so this is nearly free visually.
2. Optional retention: keep the N most-recent tabs alive (e.g. `active: index === currentTabIndex || cached.includes(index)`)
   so back-and-forth is instant. Bounded cache avoids holding all ~22 tabs.

**Config key.** Internal perf fix, **no user-facing key needed** (strictly better).
If a toggle is wanted, fold it under the same `controlcenter.keepWarm` (retention)
and let `appearance.reduceMotion` skip the fade (instant swap when motion is reduced).

**Risk.** Low. Async Loaders can show a one-frame empty content area; the fade
already covers it.

---

## 3. Bar popouts recreate their whole container + content **synchronously** on each open  [MED impact / LOW-MED risk / no compositor]

**Gap.** The bar dropdown popouts (network, bluetooth, audio, battery, active-window,
tray menus) destroy their container when idle and rebuild synchronously when hovered,
so each first-hover of a heavier popout (Network ≈ 12.6KB with lists) hitches.

**Reference evidence.** dots loads popups via background `LazyLoader`:
`…/ii/bar/StyledPopup.qml:9` (`LazyLoader { … }`), and uses `asynchronous: true`
for popup imagery (`…/ii/bar/SysTrayMenuEntry.qml:102`).

**Ryoku evidence.**
- `shell/modules/bar/popouts/Wrapper.qml:116-126`, `Comp { id: content; shouldBeActive: !root.detachedMode && (root.hasCurrent || root.offsetScale < 1); sourceComponent: Content {…} }`.
- `Comp` is a plain `Loader` (lines 157-210) toggling `active` via state, **no `asynchronous`** →
  whole popout `Content` container destroyed at idle and rebuilt on open.
- `shell/modules/bar/popouts/Content.qml:170-234`, `component Popout: Loader { active: … }`,
  per-popout, also synchronous: opening Network builds `Network.qml` on the open frame.

**Fix.**
1. `asynchronous: true` on the `Comp` loader (Wrapper.qml ~line 166) and on the
   `Popout` loader (Content.qml ~line 170). Morph/fade already mask the load gap.
2. Optional: keep the `Content` container warm (it is light scaffolding; the per-popout
   Loaders stay lazy), e.g. `shouldBeActive` also true under a keep-warm flag.

**Config key.** Async is internal perf, **no key needed**. If the container warm-keep
is wanted, wire to a new `CONFIG_PROPERTY(bool, keepPopoutsWarm, false)` in
`barconfig.hpp` under the existing `bar` tree → `GlobalConfig.bar.keepPopoutsWarm`.

**Risk.** Low-med. An async loader can briefly report 0 size; the ClipWrapper morph
(`ClipWrapper.qml:60-61`) drives geometry off `content.implicitWidth/Height`, so verify
the box doesn't pop a degenerate frame, the existing `morphProg` clamp largely covers it.

---

## 4. No idle pre-warm: the first-ever open is always cold (component cache not primed)  [MED impact / LOW risk / no compositor]

**Gap.** Even with #1/#2 async'd, the *first* open of settings (and popouts) pays the
full QML component compilation cost because nothing instantiated those Components yet.
dots sidesteps this by defaulting `keepRightSidebarLoaded: true` (Config.qml:499), the
panel is built at startup, so the user's first open is already warm.

**Reference evidence.** dots `Config.qml:499` default-ON keep-loaded; the launcher
in ryoku already does a lighter version of this, `shell/modules/launcher/Wrapper.qml:46`
`Component.onCompleted: Qt.callLater(() => Apps)` (pre-touch the apps service) and its
content Loader is `active: true` (kept warm, line 64), which is why the launcher
already feels instant. Settings/popouts lack the equivalent.

**Ryoku evidence.** `shell/modules/controlcenter/Wrapper.qml:78` has no warm/preload;
`SettingsContent` is never instantiated until the first user open.

**Fix.** When `keepWarm` is off, do a one-shot idle pre-warm shortly after shell
startup: instantiate `SettingsContent` once via `Qt.callLater`/low-priority `Timer`
(it can be immediately freed, instantiating once compiles and caches the Component
in the engine, so subsequent real builds are markedly faster). Equivalent to dots'
default-loaded behaviour but without the resident RAM cost.

**Config key.** New `CONFIG_PROPERTY(bool, preloadOnIdle, true)` →
`GlobalConfig.controlcenter.preloadOnIdle` (same header as #1). Default ON, it only
costs a brief one-time build during idle startup, no resident memory.

**Risk.** Low. Worst case is a few ms of extra startup work scheduled off the critical path.

---

## 5. Panel imagery lacks `retainWhileLoading` / DPR-capped `sourceSize` → reload flash + over-decode on open  [LOW-MED impact / LOW risk / no compositor]

**Gap.** Async images that drop their pixels while reloading flash empty on re-open,
and images without a `sourceSize` cap decode at full source resolution (large themed
SVGs / album art), extra work right on the open path.

**Reference evidence.**
- `dots-hyprland/…/modules/common/widgets/StyledImage.qml:9-30`, the house image
  type: `asynchronous: true`, **`retainWhileLoading: true`**, and DPR-capped
  `sourceSize: Qt.size(width*dpr, height*dpr)`.
- `…/ii/modules/common/widgets/MediaWidget.qml` analog and ryoku's own
  `shell/components/background/MediaWidget.qml:54-56` already cap (`sourceSize.width: 96`),
  proving the pattern is accepted in-tree, it's just not applied everywhere.

**Ryoku evidence.** `shell/modules/launcher/items/AppItem.qml:35-43`, `IconImage`
is `asynchronous: true` but sets no `retainWhileLoading` (re-open can flash) and relies
on `implicitSize` only. Popout/notification/media artwork `Image`s should be audited
for missing `sourceSize` caps (full audit is a follow-up; `IconImage` is bounded by
`implicitSize`, so this is polish, not the main lever).

**Fix.** Add `retainWhileLoading: true` to async `IconImage`/`Image` on hot open
paths, and a DPR-capped `sourceSize` to any uncapped artwork `Image`. Cheapest as a
shared `StyledImage`-style component if not already centralized.

**Config key.** Internal perf/polish, **no user-facing key** (strict improvement).

**Risk.** Low. `retainWhileLoading` slightly raises peak memory during reload; negligible.

---

### Summary of wired keys
| # | Fix | Key | Default | Header |
|---|-----|-----|---------|--------|
| 1 | Keep settings panel warm + async cold build | `GlobalConfig.controlcenter.keepWarm` (new) | `false` | `controlcenterconfig.hpp` |
| 2 | Async + retain settings tab loaders | none (internal) |, |, |
| 3 | Async bar popout loaders (+ optional warm-keep) | `GlobalConfig.bar.keepPopoutsWarm` (new, optional) | `false` | `barconfig.hpp` |
| 4 | Idle pre-warm of settings component cache | `GlobalConfig.controlcenter.preloadOnIdle` (new) | `true` | `controlcenterconfig.hpp` |
| 5 | `retainWhileLoading` + capped `sourceSize` on open-path images | none (internal) |, |, |

Top 3 by impact-per-risk: **#1** (warm/async settings → kills the open lag),
**#2** (async tab loaders → kills navigation jank, no key, ship now),
**#3** (async popout loaders → kills per-hover hitch, no key for the async part).
