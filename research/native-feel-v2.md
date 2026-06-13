# Native-feel research loop v2: synthesis

Second comparative pass (after the first `native-feel-todo.md` was fully shipped),
targeting the angles the first loop under-mined: **perceived speed / panel-open
latency**, **background-process & service handling** (a first-class user ask), and
**micro-interaction feedback** (the bar widgets in the user's screenshot). Three
parallel scouts compared ryoku to noctalia + end-4 dots; per-area evidence with
`repo:file:line` citations lives in:

- `research/native-feel-v2/latency.md`
- `research/native-feel-v2/processes.md`
- `research/native-feel-v2/micro-interactions.md`

Every item is wired to a real `GlobalConfig` key (existing or proposed), no
hardcoded one-offs. Status is honest: SHIPPED items are built/linted/verified this
turn; BACKLOG items are deferred with the specific reason (almost always: needs
live-shell runtime verification that a static build can't provide, or is
device-specific).

## Shipped this loop (verified: qmllint-clean, build green where C++ touched)

- **Settings open no longer hitches (the user's #1 complaint).** The in-bar settings
  rebuilds the 1325-line `SettingsContent` synchronously on open; its tab Loaders now
  carry `asynchronous: true` (`SettingsContent.qml:1220,1259`), so the tab mounts off
  the main thread behind the existing opacity fade-in. No key, ships unconditionally.
  Ref: dots `sidebarRight` keep-warm; ryoku's own loaders simply missed `asynchronous`.
- **`appearance.reduceMotion` now actually reaches hover/ripple feedback.** Real wiring
  bug: `StateLayer.qml`'s three `Anim` instances set `duration:` explicitly
  (`:79,89,187`), overriding `Anim.qml`'s default binding that carries the reduceMotion
  gate, so the toggle silently did nothing for state-layer feedback. The three
  durations now gate on `GlobalConfig.appearance.reduceMotion`. (Exactly the
  "settings must change stuff" class of bug.)
- **Bar logo button feels alive.** `OsIcon.qml`'s bare `MouseArea` is now a `StateLayer`
  (hover wash + ripple + pointing-hand), matching `Power.qml`; the launcher toggle is
  preserved. Zero risk, it had no hover-popout to disturb.

## Backlog (ranked impact-per-risk; each deferred for a stated reason)

### Latency
1. **Settings keep-warm**, controlcenter destroys `SettingsContent` on close and
   rebuilds on open (`controlcenter/Wrapper.qml:73-88`). Keep it warm behind a new
   `GlobalConfig.controlcenter.keepWarm` (bool, default false; ~15MB RAM tradeoff, like
   dots `Config.qml:499`). DEFER: must drive `SystemStatService` polling off a
   `shouldBeActive` when warm (`SettingsContent.qml:35,404`) or it burns CPU while
   hidden, needs runtime verification.
2. **Bar popout content async**, `popouts/Wrapper.qml:116-126` recreates content via the
   `Comp` lazy-loader. DEFER: must confirm `Comp` forwards `asynchronous` + that the
   clip-morph open tolerates it. No key.
3. **Idle pre-warm** to prime the QML component cache → `controlcenter.preloadOnIdle`
   (bool, default true). Launcher already does a lighter version (why it feels instant).

### Background processes (user explicitly asked)
4. **`sensors` lm_sensors fork every resource tick** (`SystemUsage.qml:96,317`), the
   last per-tick fork on every machine (the gpuBusy/lsblk forks were already fixed).
   Fix: resolve a `/sys/class/hwmon/.../tempN_input` once → per-tick `FileView`, the
   shipped gpuBusy pattern; reuses `dashboard.resourceUpdateInterval`. DEFER: CPU-temp
   hwmon selection is device-specific (k10temp/coretemp/zenpower/acpitz + label match);
   the current lm_sensors path works, so this needs a resolver + multi-hardware runtime
   verification (and a keep-lm_sensors fallback) before shipping.
5. **NVIDIA `nvidia-smi` fork every tick** (`SystemUsage.qml:93-94,274`), fires on this
   RTX 4060 box. Fix: one long-lived `nvidia-smi -lms <interval>` `SplitParser` stream
   (reuses `dashboard.resourceUpdateInterval`) or NVML dlopen in the plugin (noctalia
   `system_monitor_service.cpp:586-687`). DEFER: med risk, needs runtime verification.
6. **Custom command widgets fork `sh -c` every tick, ungated by visibility, no floor**
   (`CustomWidgets.qml:133-147`). Fix: gate `Timer.running` on widget visibility + clamp
   to a new `GlobalConfig.services.customWidgetMinIntervalMs` (default 1000). Low-med.
7. Recorder `pidof` poll every 2s while recording → `services.recorderReconcileIntervalMs`
   or managed-Process `onExited` (`Recorder.qml:92-97`). 8. `RyokuExtras.qml:262-269`
   timer redundantly reloads an already-watched `FileView`, dead-work removal. 9. Weather
   interval hardcoded 1h + ungated → `services.weatherRefreshIntervalMs` (`Weather.qml:221`).
   Aspirational: split `SystemUsage` coarse `refCount` into per-metric retain/release
   like noctalia (`system_monitor_service.cpp:797-834`).

### Micro-interactions (ryoku already owns `StateLayer`; gap is adoption, not feature)
10. **StatusIcons + Clock bar clusters are static** (`StatusIcons.qml:13`, `Clock.qml:8`).
    DEFER with a hard constraint: a hoverEnabled `StateLayer` (MouseArea) on these
    **breaks their hover-popout**, popouts are driven by the single top-level
    `Interactions.qml` `CustomMouseArea` via geometry (`Bar.qml:34 checkPopout`/`childAt`),
    and a child MouseArea starves its `positionChanged` (this is exactly why
    `ActiveWindow.qml:44-64` click-drives its popout when it has a MouseArea). Safe fix:
    a NON-consuming feedback, a `HoverHandler`-driven wash, or bind a wash overlay's
    opacity to the existing `popouts.currentName`/hovered state, not a `StateLayer`.
    Needs runtime verification. No new key (reuse `Colours.palette` + `Tokens.anim`).
11. Tray items (`TrayItem.qml:10`), workspace dots (`Workspace.qml`, med risk, geometry
    feeds the bar hit-test), bar `ActiveWindow` (cursor-only), same non-consuming
    constraint applies per widget.
12. settings-gui `NButton`/`NIconButton` have hover but **no press state** (parity gap vs
    noctalia `pressed→Primary`). Add a pressed visual. No new key. Low risk, candidate
    for the next shippable batch (settings-gui buttons have no popout hit-test concern).
13. Optional tunability: `appearance.stateLayerOpacity`, only if wanted; references
    hardcode it, so default is no new key.

## Notes
- noctalia is now pure C++ (no QML), dots + ryoku's own noctalia-derived `settingsgui`
  are the live QML references for these comparisons.
- The recurring deferral reason is the same: many feel-fixes (keep-warm CPU lifecycle,
  hwmon temp selection, popout-hover coexistence) can only be *correctly* validated by
  running the live shell, which is the user's active desktop. They are real and wired;
  they want a runtime-verify pass, not a blind static edit.
