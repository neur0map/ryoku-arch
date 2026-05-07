# Dynamic Island for the Topbar Center

**Status:** Approved design, awaiting implementation plan
**Date:** 2026-05-07
**Scope:** Topbar (`shell/modules/bar/threeIsland/`), bar settings page, niri keybinds, Mod+S tools mode

## Summary

Replace the static center island (kanji clock + weather + date) with a state-driven "Dynamic Island" that morphs to show contextual information - recording, music, timer, screenshot toast, voice search - and expands into a full-bar **Tools Mode** when the user presses **Mod+S**. Visual inspiration: iOS Dynamic Island plus Axenide/Ambxst's Super+S tools mode. Music waveform inspiration: neur0map/Brain_Shell.

## Goals

- One always-visible status surface that adapts to what the user is doing.
- Reuse existing services (`RecorderStatus`, `MprisController`, `VoiceSearch`, `TimerService`, `Idle`, `SongRec`) without new polling loops.
- Reuse the existing center-notch width animation (`Behavior on centerNotchWidth` with `OutBack` easing) so morphs come for free.
- Mod+S triggers Ambxst-style "tools mode": a single wide pill replacing all three islands, hosting Ryoku's existing quicktools + Lens/Music-recognition/Caffeine.
- Every visible state and tool button is **toggleable, removable, and rearrangeable** from Settings → Bar.
- No regression vs. today's idle layout.

## Non-goals

- Repositioning the bar to the bottom (use existing `bar.bottom` flag instead).
- New compositor IPC - Mod+S goes through the existing `ryoku-shell` launcher script.
- Vendoring Brain_Shell or Ambxst code - those are visual references only.
- Replacing the existing `Recorder.qml` overlay; we link to it from the recording pill's right-click.
- Adding new theme tokens - reuse `Appearance.colors.*` and `Appearance.ryoku.*`.

---

## Architecture

The dynamic island is a **state machine that selects which "pill" component to render in the center notch.** The notch width binding in `RyokuThreeIslandContent.qml` already animates with `OutBack` easing, so growing/shrinking between states is automatic.

```
RyokuThreeIslandContent.qml
    ├─ leftNotch  → RyokuLeftIsland          (untouched)
    ├─ centerNotch → RyokuDynamicIsland       (NEW - replaces RyokuCenterIsland)
    │                  ├─ activeState property (computed from services)
    │                  ├─ Loader → loads matching pill component
    │                  └─ pills/{Idle,Recording,Music,Timer,ScreenshotToast,VoiceSearch}StatePill.qml
    └─ rightNotch → RyokuRightIsland         (untouched)
    
    + tools/RyokuToolsMode.qml - overlays/replaces all three islands when GlobalStates.toolsModeOpen
```

### File layout

**New files (under `shell/modules/bar/threeIsland/dynamicIsland/`):**

| Path | Purpose |
|------|---------|
| `RyokuDynamicIsland.qml` | Orchestrator. Computes `activeState`, loads the matching pill. |
| `pills/IdleStatePill.qml` | Wraps the existing kanji clock + weather + date stack. |
| `pills/RecordingStatePill.qml` | Red gradient · pulsing dot · `REC HH:MM:SS`. |
| `pills/MusicStatePill.qml` | CAVA waveform + scrolling track title. |
| `pills/TimerStatePill.qml` | Amber ring + remaining time. |
| `pills/ScreenshotToastPill.qml` | Green ✓ + "Copied" or "Saved" - auto-fades after 2s. |
| `pills/VoiceSearchPill.qml` | Purple listening waveform + "Listening". |
| `tools/RyokuToolsMode.qml` | Wide tools pill (Mod+S target). |
| `tools/ToolButton.qml` | Circular icon button (reuses `CircleUtilButton` styling). |
| `tools/toolRegistry.js` | Maps tool ids to action lambdas + icon + label. Single source of truth. |
| `CavaWaveform.qml` | Reusable visualizer that subscribes to `Cava` singleton. |

**New singletons (under `shell/services/`):**

| Path | Purpose |
|------|---------|
| `Cava.qml` | Wraps the `cava` CLI in raw output mode. Provides `bars` array (7 floats 0–1) for waveform widgets. Started/stopped on demand - no CPU cost when idle. |
| `ScreenshotEvents.qml` | Holds `toastVisible`, `toastText`, `lastFilePath`. Exposes `IpcHandler` so any script can fire `quickshell ipc call screenshotEvents captured "Saved" "/path"`. |

**Modified files:**

| Path | Modification |
|------|--------------|
| `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml` | Replace `RyokuCenterIsland` with `RyokuDynamicIsland`; add tools-mode overlay logic. |
| `shell/modules/bar/threeIsland/RyokuCenterIsland.qml` | Kept as the body of `IdleStatePill` (or imported by it). |
| `shell/modules/bar/Media.qml` | Music popup positioning - anchor snug to island bottom (continuous shape). |
| `shell/modules/mediaControls/BarMediaPopup.qml` | Top corners flatten when `continuous` mode active. |
| `shell/modules/bar/UtilButtons.qml` | Tool list extracted into shared `tools/toolRegistry.js`. |
| `shell/modules/common/Config.qml` | New `bar.dynamicIsland` JsonObject (schema below). |
| `shell/modules/settings/BarConfig.qml` | New "Dynamic Island" section with drag-to-reorder lists. |
| `shell/GlobalStates.qml` | New `toolsModeOpen` flag (parallel to `mediaControlsOpen`). |
| `config/niri/config.d/70-binds.kdl` | New bind: `Mod+S { spawn "ryoku-shell" "tools-mode" "toggle"; }`. |
| `shell/scripts/ryoku-shell` | New `tools-mode toggle` subcommand → IPC → flip `toolsModeOpen`. |

### Reused without changes

- `shell/services/RecorderStatus.qml` - `isRecording`, `elapsedSeconds`.
- `shell/services/MprisController.qml` - `activePlayer`, `isPlaying`, `togglePlaying()`, `activeTrack`.
- `shell/services/VoiceSearch.qml` - `running` (computed: `recording || transcribing`).
- `shell/services/TimerService.qml` - `pomodoroRunning`, `countdownRunning`, `stopwatchRunning`, plus their `*SecondsLeft` props.
- `shell/services/Idle.qml` - `inhibit`, `toggleInhibit()` (caffeine).
- `shell/services/SongRec.qml` - for the music-recognize tool button.
- `shell/modules/ii/overlay/recorder/Recorder.qml` - opened on right-click of recording pill.
- Center-notch width binding + `Behavior on centerNotchWidth` with `OutBack` 1.6 overshoot.

---

## Data flow & state machine

`RyokuDynamicIsland.activeState` is recomputed reactively from singleton signals:

```qml
property string activeState: {
    if (GlobalStates.toolsModeOpen) return "tools";
    if (Config.options.bar.dynamicIsland.states.voiceSearch    && VoiceSearch.running)            return "voiceSearch";
    if (Config.options.bar.dynamicIsland.states.recording      && RecorderStatus.isRecording)     return "recording";
    if (Config.options.bar.dynamicIsland.states.timer          && _anyTimerRunning())             return "timer";
    if (Config.options.bar.dynamicIsland.states.screenshotToast && ScreenshotEvents.toastVisible) return "screenshotToast";
    if (Config.options.bar.dynamicIsland.states.music          && MprisController.isPlaying)      return "music";
    return "idle";
}
```

Where `_anyTimerRunning()` returns `TimerService.pomodoroRunning || TimerService.countdownRunning || TimerService.stopwatchRunning`.

**Default precedence** (from highest to lowest): `voiceSearch > recording > timer > screenshotToast > music > idle`. User can rewrite this order via `Config.options.bar.dynamicIsland.statePrecedence` (drag-to-reorder list in Settings).

A 250ms debounce (Timer with `restart()`) guards `activeState` against rapid thrashing - e.g. `MprisController.isPlaying` flapping during track transitions.

### Per-state component breakdown

| State | Data source | Visual | Approx width |
|-------|-------------|--------|--------------|
| `idle` | existing | kanji clock + weather + date stack (current behavior) | ~140px |
| `recording` | `RecorderStatus` | red gradient pill · pulsing dot · `REC MM:SS` mono digits | ~140px |
| `music` | `MprisController` + `Cava` | CAVA bars (7) + scrolling title (`activeTrack.title`) | ~180px |
| `timer` | `TimerService` | amber ring · remaining time mono digits | ~120px |
| `screenshotToast` | `ScreenshotEvents` | green ✓ · "Copied" / "Saved" · auto-fade 2s | ~110px |
| `voiceSearch` | `VoiceSearch` + `Cava` (mic source) | purple pill · live waveform · "Listening" | ~150px |
| `tools` | `Config.options.bar.dynamicIsland.tools.order` | wide neutral pill · 12 buttons grouped by `DIVIDER` token | ~520px |

### Click / interaction behaviors

| State | Left-click | Right-click | Hover | Wheel |
|-------|-----------|-------------|-------|-------|
| `idle` | - | bar context menu (Mission Center) | existing clock + weather popups | existing scroll action |
| `recording` | stop recording (`pkill -SIGINT wf-recorder`) | open `Recorder.qml` overlay | tooltip: "Recording - click to stop" | - |
| `music` | `MprisController.togglePlaying()` | open `BarMediaPopup` (continuous expansion) | title + artist + album tooltip | volume ±5% (existing `Media.qml` behavior) |
| `timer` | open existing `TimerIndicator` popup | pause/resume active timer | tooltip: "MM:SS remaining" | - |
| `screenshotToast` | open `lastFilePath` in default viewer | open enclosing folder | - (auto-fades) | - |
| `voiceSearch` | `VoiceSearch.stop()` | - | tooltip: "Listening - click to cancel" | - |
| `tools` | per-button | close tools mode (`toolsModeOpen = false`) | per-button tooltip | - |

---

## Visual design

### Color tokens (theme-aware)

| State | Background tint | Accent / icon |
|-------|----------------|---------------|
| `recording` | `Appearance.colors.colError` @ 12–20% alpha gradient | `colError` |
| `music` | `Appearance.colors.colPrimary` @ 12–20% alpha gradient | `colPrimary` |
| `timer` | `Appearance.colors.colTertiary` (or amber) @ 12–18% | amber |
| `screenshotToast` | success-green @ 12–20% | success-green |
| `voiceSearch` | `Appearance.colors.colSecondary` (or violet) @ 12–20% | `colSecondary` |
| `tools` | `Appearance.colors.colLayer1/2` neutral | `colOnLayer2` |

Fall back to `Appearance.ryoku.*` tokens when `Appearance.ryokuEverywhere` is true (consistent with existing center-island code).

### Animation

| Event | Behavior |
|-------|----------|
| Width morph between states | existing 320ms `OutBack` overshoot 1.6 (no change to `centerNotchWidth` binding) |
| Pill content swap | 200ms `OutQuad` cross-fade (opacity); old pill fades out, new fades in |
| Tools mode entry | 320ms - left + right islands shrink width→0 + opacity→0 in parallel; tools pill grows from center |
| Tools mode exit | reversed |
| Recording dot pulse | reuse existing 1s sequential animation from `UtilButtons.qml` |
| CAVA bars | bar heights tween to new values with 80ms `OutQuad` (smooths irregular emit rates) |
| Reduce motion | when `Appearance.animationsEnabled === false`: instant width changes, no pulse, no cross-fade, CAVA replaced by static `music_note` icon |

### Music popup continuous expansion

When `bar.dynamicIsland.musicPopupContinuous === true` (default):

- `BarMediaPopup` anchors directly under the music pill with **zero gap**.
- Top-left and top-right corner radii of the popup are set to `0`.
- Bottom corner radii match the bar's island radius.
- Popup width is `max(islandWidth, 280px)`.
- Visually: the island + popup look like one continuous rounded shape that grew downward.
- If `bar.bottom === true`, mirror vertically: popup attaches to island TOP, bottom corners flatten, top corners stay rounded.

Falls back to today's floating-detached popup when the toggle is off.

---

## Mod+S Tools Mode

### Lifecycle

1. User presses **Mod+S** in niri.
2. niri executes `spawn "ryoku-shell" "tools-mode" "toggle"`.
3. `ryoku-shell` invokes `quickshell ipc call toolsMode toggle` (new `IpcHandler` in `RyokuToolsMode.qml`).
4. The IpcHandler flips `GlobalStates.toolsModeOpen`.
5. `RyokuDynamicIsland.activeState` recomputes → `"tools"`.
6. Three-island layout: left + right notches animate `width → 0` + `opacity → 0`. Center notch grows to `~520px` and renders `RyokuToolsMode`.
7. Tool buttons render in the order from `Config.options.bar.dynamicIsland.tools.order`. The literal token `"DIVIDER"` renders as a vertical separator (auto-hidden if either side is empty after filtering by `tools.buttons.*` flags).
8. **Action buttons** (screenshot / record / lens / colorPicker / musicRecognize) → execute their action then call `GlobalStates.toolsModeOpen = false` if `tools.autoCloseAfterAction === true`.
9. **Toggle buttons** (mic / caffeine / osk / notepad / cast / dark / power) → flip their state, do NOT close.
10. **Esc** while tools mode is open → close (when `tools.closeOnEsc === true`).
11. **Right-click** on any non-button area of the tools pill → close.
12. If a higher-priority state fires while tools mode is open (e.g. recording starts), tools mode is **forcibly closed** and the higher state takes over. (Recording wins, you'd want to see your recording timer.)

### Tool registry

`shell/modules/bar/threeIsland/dynamicIsland/tools/toolRegistry.js` exports a flat dictionary keyed by tool id:

```js
{
  screenshot:    { icon: "screenshot_region", label: "Screenshot region",
                   kind: "action",
                   action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "region", "screenshot"]) },
  record:        { icon: "videocam",  label: "Screen record",
                   kind: "action",
                   action: () => Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]),
                   activeWhen: () => RecorderStatus.isRecording },
  lens:          { icon: "search",   label: "Google Lens",
                   kind: "action",
                   action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "region", "search"]) },
  colorPicker:   { icon: "colorize", label: "Color picker",
                   kind: "action",
                   action: () => Quickshell.execDetached(["/usr/bin/hyprpicker", "-a"]) },
  musicRecognize:{ icon: "graphic_eq", label: "Recognize music",
                   kind: "action",
                   action: () => SongRec.toggleRunning(true),
                   activeWhen: () => SongRec.running },
  micToggle:     { icon: () => Audio.micMuted ? "mic_off" : "mic", label: "Mic toggle",
                   kind: "toggle",
                   action: () => Audio.toggleMicMute(),
                   activeWhen: () => !Audio.micMuted && Privacy.micActive },
  osk:           { icon: "keyboard", label: "On-screen keyboard",
                   kind: "toggle",
                   action: () => GlobalStates.oskOpen = !GlobalStates.oskOpen,
                   activeWhen: () => GlobalStates.oskOpen },
  caffeine:      { icon: "coffee",   label: "Keep awake",
                   kind: "toggle",
                   action: () => Idle.toggleInhibit(),
                   activeWhen: () => Idle.inhibit },
  notepad:       { icon: "edit_note", label: "Notepad",
                   kind: "action",
                   action: () => { GlobalStates.sidebarRightOpen = true; ... } },
  screenCast:    { icon: "visibility", label: "Screen cast",
                   kind: "toggle",
                   action: ..., activeWhen: () => Persistent.states.screenCast.active },
  darkMode:      { icon: () => Appearance.m3colors.darkmode ? "light_mode" : "dark_mode", label: "Dark mode",
                   kind: "toggle",
                   action: () => MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode) },
  powerProfile:  { icon: ..., label: "Power profile",
                   kind: "toggle",
                   action: ... }
}
```

`UtilButtons.qml` is refactored to read from this same registry, eliminating duplication between the legacy bar layout and tools mode.

---

## Settings & customization

### Config schema additions

Extends `Config.options.bar` (parallel to `modules`, `modulesLayout`, `utilButtons`):

```qml
property JsonObject dynamicIsland: JsonObject {
    property bool enabled: true

    // Per-state on/off (idle is always on - fallback)
    property JsonObject states: JsonObject {
        property bool voiceSearch: true
        property bool recording: true
        property bool timer: true
        property bool screenshotToast: true
        property bool music: true
    }

    // Custom precedence (highest → lowest). Empty = built-in default.
    property list<string> statePrecedence: [
        "voiceSearch", "recording", "timer", "screenshotToast", "music"
    ]

    property JsonObject tools: JsonObject {
        property bool enabled: true
        property string keybind: "Mod+S"  // documentation only; actual bind in niri config

        // Drag-to-reorder writes this list. "DIVIDER" is a literal renderable token.
        property list<string> order: [
            "screenshot", "record", "lens", "colorPicker", "musicRecognize",
            "micToggle", "osk",
            "DIVIDER",
            "caffeine", "notepad", "screenCast", "darkMode", "powerProfile"
        ]

        property JsonObject buttons: JsonObject {
            property bool screenshot: true
            property bool record: true
            property bool lens: true
            property bool colorPicker: true
            property bool musicRecognize: true
            property bool micToggle: true
            property bool osk: true
            property bool caffeine: true
            property bool notepad: true
            property bool screenCast: false
            property bool darkMode: true
            property bool powerProfile: false
        }

        property bool autoCloseAfterAction: true
        property bool closeOnEsc: true
    }

    property bool musicPopupContinuous: true
}
```

### Migration

On first launch after the upgrade, `Config.qml`'s init step copies the user's existing `bar.utilButtons.show*` flags into `bar.dynamicIsland.tools.buttons.*` as defaults - so existing users get a tools row that matches their current bar configuration. The legacy `utilButtons.show*` flags continue to work for the legacy bar layout (`cornerStyle !== 4`).

### Settings UI: `BarConfig.qml` - new "Dynamic Island" section

Layout, top-down:

1. **Master toggle**: `bar.dynamicIsland.enabled`. When off, center island falls back to `RyokuCenterIsland` directly.
2. **Visible states** - a `ListView` driven by `statePrecedence`, each row has a drag handle (≡), state name, on/off toggle. Drag rewrites the list. Long-press × removes (toggle off).
3. **Mod+S Tools pill** - same `ListView` pattern over `tools.order`. Each row: drag handle, icon, label, on/off toggle, × remove. A "DIVIDER" row is visually distinct and can be moved or deleted (delete removes from `order`). Below the list: "Add hidden buttons" expander that lets the user re-add removed buttons.
4. **Tools mode behavior** - two switches: "Auto-close after action", "Close on Esc".
5. **Music popup** - switch: "Continuous expansion (attached to island)".

Drag-to-reorder reuses the existing pattern from `shell/modules/dock/DockApps.qml` (which already implements `DragHandler`-based reorder with displacement transforms for non-dragged items - see lines around `dragIndex` / `dropTargetIndex`).

---

## Phased rollout

To ship safely and bisect any regression, the work is split into 6 commits/PRs that each leave the bar in a working state:

1. **Phase 1 - Plumbing**
   - `Config.qml` schema additions
   - `RyokuDynamicIsland.qml` orchestrator (only the `idle` state)
   - `IdleStatePill.qml` wraps existing `RyokuCenterIsland` content
   - `RyokuThreeIslandContent.qml` wired to use it
   - **No visible change.** Default `bar.dynamicIsland.enabled = true` immediately (since idle = current behavior).

2. **Phase 2 - Recording state**
   - `RecordingStatePill.qml` + plumbing in orchestrator
   - Click → stop, right-click → open `Recorder.qml`
   - First user-visible morph

3. **Phase 3 - Music + CAVA**
   - `Cava.qml` singleton
   - `CavaWaveform.qml` widget
   - `MusicStatePill.qml`
   - `Media.qml` + `BarMediaPopup.qml` continuous-expansion mode
   - cava CLI dependency check at install time + runtime fallback

4. **Phase 4 - Timer + Screenshot toast + Voice search**
   - `TimerStatePill.qml`
   - `ScreenshotEvents.qml` singleton + IpcHandler
   - Hook the existing region selector / grim wrapper to fire the toast IPC
   - `VoiceSearchPill.qml` (reuses `Cava` pointed at mic input)

5. **Phase 5 - Mod+S Tools Mode**
   - `tools/toolRegistry.js`
   - `RyokuToolsMode.qml` + `ToolButton.qml`
   - `GlobalStates.toolsModeOpen` flag
   - niri keybind in `70-binds.kdl`
   - `ryoku-shell tools-mode toggle` subcommand
   - Refactor `UtilButtons.qml` to read from registry

6. **Phase 6 - Settings UI**
   - "Dynamic Island" section in `BarConfig.qml`
   - Drag-to-reorder for state precedence + tools order
   - Per-state and per-button toggles
   - Migration step copying legacy `utilButtons.show*` flags

---

## Edge cases

| Case | Handling |
|------|----------|
| Multi-monitor (bar per screen) | Tools mode + active state are per-screen-instance, not global. Each `RyokuDynamicIsland` reads `GlobalStates.toolsModeOpen` (global) but pill rendering is local. |
| Bar at bottom (`bar.bottom = true`) | Music popup expansion direction flips: anchors to island TOP, bottom corners flatten. Tools mode unaffected. |
| Reduce motion (`Appearance.animationsEnabled = false`) | Instant width transitions, no pulse, no cross-fade, no CAVA - falls back to static icon. |
| `cava` binary missing | `Cava.qml` detects at startup, sets a `unavailable` flag. Music pill renders a static `music_note` icon + "▶" indicator. Settings shows a dependency hint. |
| Title overflow | Music pill title elides with ellipsis at ~160px; full title in tooltip + popup. |
| Multiple states active simultaneously | Strict precedence resolves; lower-priority states are tracked but hidden. |
| State change while tools mode open | Higher-priority state forcibly closes tools mode and takes over. |
| Bar collapsed via `autoHide` | Mod+S forces the bar to slide in before opening tools mode. |
| Theme change | Per-state colors recompute live from `Appearance.colors.*` (existing pattern). |
| Mod+S spam | Existing `Behavior on centerNotchWidth` debounces visually; second press during animation cancels and reverses. |
| `VoiceSearch.running` never clears (network drop, etc.) | 30s safety timeout in the pill - clears state to idle and surfaces a notification. |
| User has Mod+S already bound | Install-time check: if Mod+S is taken in the user's `config.kdl`, the new bind is added commented-out with an explanatory note. |
| `bar.cornerStyle !== 4` (not three-island layout) | Dynamic Island doesn't render. Tools mode binding still works but opens the legacy `Recorder.qml` overlay instead. |

---

## Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Frequent state thrashing causes twitchy morphs | 250ms debounce on `activeState` |
| `cava` CPU usage | Raw output mode, 30fps cap, stop process when music pauses |
| Tools mode breaks if Mod+S already bound | Install-time pre-flight check; commented-out fallback bind |
| Heavily-customized bar overlaps new states | Migration step + every state behind a Settings toggle |
| Continuous-expansion popup clips on small screens | `maximumWidth = screen.width − margins`; auto-fallback to legacy floating popup |
| `Cava.qml` quickshell wrapper introduces a dependency users don't have | Soft dependency - fallback static icon + Settings hint, install script suggests `pacman -S cava` |

---

## Acceptance criteria

The spec is "done" when implementation produces:

- [ ] All 6 states render correctly on the live shell.
- [ ] Mod+S toggles tools mode without breaking other bar bindings.
- [ ] All states + tool buttons are toggleable in Settings → Bar → Dynamic Island.
- [ ] Drag-to-reorder works for both state precedence and tools order, persists across restart.
- [ ] No idle CPU regression (`cava` only runs when music is playing or voice search is active).
- [ ] Theme switch (kanagawa / lumon / retro-82 / ...) refreshes per-state colors live.
- [ ] Existing bar tests pass (no regressions in clock / weather / workspaces / battery / SecPulse).
- [ ] Bar works correctly on `bar.bottom = true`.
- [ ] Bar works correctly with `bar.cornerStyle !== 4` (dynamic island gracefully no-ops).
- [ ] Mod+S works on multi-monitor - tools mode renders on **all** monitor bars simultaneously when toggled (each bar shares the global `GlobalStates.toolsModeOpen`).

---

## Manual test plan (post-implementation)

1. **Idle**: kanji clock + weather + date visible; matches today's behavior.
2. **Recording**: `ryoku-shell region recordWithSound` → red pill morphs in within ~320ms; elapsed counter ticks; click pill → recording stops; pill morphs back to idle.
3. **Music**: play Spotify/YouTube → blue pill with CAVA bars + scrolling title; click → toggles play/pause; click while playing → popup expands DOWN from island with no gap.
4. **Timer**: start a 5-min timer → amber ring pill; click → existing timer popup opens.
5. **Screenshot toast**: take a region screenshot → green ✓ pill for ~2s then morphs back; click during the 2s → file opens in viewer.
6. **Voice search**: trigger VoiceSearch → purple listening waveform pill; click → cancels, returns to idle.
7. **Tools mode**: press Mod+S → all three islands shrink + fade out; tools pill morphs in (~520px); click an action button (screenshot) → tools mode auto-closes; click a toggle (caffeine) → coffee icon highlights, mode stays open; press Esc → tools mode closes.
8. **Precedence**: start music → blue pill. Start recording → recording wins, pill turns red. Stop recording → music re-emerges automatically.
9. **Settings**: disable "Recording" state → recording happens, pill stays as idle. Reorder tool buttons via drag → next Mod+S shows new order. Toggle "Music popup attached to island" off → next click on music pill opens detached floating popup.

---

## Open questions

None at design time. Multi-monitor behavior is locked: tools mode is **global** (all monitor bars switch together via the shared `GlobalStates.toolsModeOpen` flag); per-screen state pills (recording, music, etc.) render independently on each bar.

---

## References

- Existing center island: `shell/modules/bar/threeIsland/RyokuCenterIsland.qml`
- Existing notch animation: `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml` lines 105–120
- Visual inspiration: [Axenide/Ambxst](https://github.com/Axenide/Ambxst) (tools mode)
- Music waveform inspiration: [neur0map/Brain_Shell](https://github.com/neur0map/Brain_Shell)
