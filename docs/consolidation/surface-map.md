# Stage 0 Inventory: Surface Map (`shell/dashboard/`, AGPL, flagged retiring)

Scope: the **Ambxst-derived AGPL-3.0** dashboard subtree at `shell/dashboard/`
(per `shell/dashboard/ATTRIBUTION.md:1-24`). This is distinct from the canonical
MIT drawers dashboard at `shell/modules/dashboard/` and the settings host at
`shell/modules/controlcenter/`. Read-only inventory; no deletions proposed.

---

## 1. Instantiation / trigger: STILL LIVE (not dormant)

The surface is **wired into the running shell**, contradicting a "dormant" assumption.
Three live entry points pull from `qs.dashboard.*`:

| Entry point | What it loads | Cite |
|---|---|---|
| **Island content** (primary view) | `DashboardContent.DashboardView {}`, the full dashboard widget | `shell/modules/island/Content.qml:12` (import), `:67` (instantiation) |
| Island open-state driver | `Binding` sets `GlobalStates.ryokuDashboardOpen = island visible && !recordMode`; `Dashboard.isVisible: GlobalStates.dashboardOpen` | `shell/modules/island/Content.qml:47-51`; `shell/dashboard/.../Dashboard.qml:84` |
| Webcam **MirrorWindow** | shell-root `LazyLoader` → `dashboard/modules/tools/MirrorWindow.qml`, gated on `DashGlobals.GlobalStates.mirrorWindowVisible` | `shell/shell.qml:15` (import), `:74-77` |
| Image **ClipboardTab** (Super+V) | `shell/modules/clipboard/Wrapper.qml` hosts `../../dashboard/.../clipboard` ClipboardTab | `shell/modules/clipboard/Wrapper.qml:7-12` |

**Visibility trigger:** the island (and thus the dashboard view) opens from the
top-centre notch hover / drag / shortcut. The island is the host; `visibilities.island`
drives it (`shell/modules/drawers/Interactions.qml:302-321`, `shell/modules/Shortcuts.qml:62-84`).
Note: the old `visibilities.dashboard` flag in drawers now refers to the **canonical**
`shell/modules/dashboard/` panel (`shell/modules/drawers/Panels.qml:8,139-143`), **not**
this AGPL surface, the AGPL view rides inside the island.

**Also depended on (services/config, not view):**
- `qs.dashboard.modules.services` ClipboardService eagerly started by `shell/modules/ClipboardMaintenance.qml:7`.
- `qs.dashboard.config` weather unit mirrored by `shell/modules/WeatherUnitSync.qml:5`.
- `qs.dashboard.modules.services` referenced by settings `ClipboardSubTab.qml:7`.

`shell/dashboard/modules/notifications/` contains only `AGENTS.md` (no live code).
`shell/dashboard/modules/notch/` contains only `NotchAnimationBehavior.qml` (the
animation base class `Dashboard.qml` extends).

---

## 2 & 3. Feature inventory + duplication analysis

The AGPL view is `Dashboard.qml` with **2 tabs**, WidgetsTab (`Icons.widgets`) and
MetricsTab (`Icons.heartbeat`), plus a gear button that execs `ryoku-shell settings`
(`Dashboard.qml:24,312,398-408,514-524`). ClipboardTab + MirrorWindow are surfaced
outside the island.

| Feature | `shell/dashboard/` files | Duplicated-by (canonical) | Proposed action |
|---|---|---|---|
| **Media player** (full player w/ cover, controls, visualiser) | `widgets/dashboard/widgets/FullPlayer.qml`; in `WidgetsTab.qml:26-29` | `shell/modules/dashboard/Media.qml`, `MediaWrapper.qml`, `LyricMenu.qml`, `LyricsView.qml`, `dash/Media.qml`; `settingsgui/.../Media/MediaPlayerPanel.qml`; bar `MediaWidget.qml` | **drop-as-dup** (canonical dashboard Media tab covers it) |
| **Weather card + 5-day forecast** | `widgets/dashboard/widgets/WeatherWidget.qml`; forecast strip `WidgetsTab.qml:71-157` | `shell/modules/dashboard/WeatherTab.qml`, `dash/SmallWeather.qml`; `settingsgui/.../Cards/WeatherCard.qml` | **drop-as-dup** (canonical Weather tab) |
| **Calendar** (month grid) | `widgets/dashboard/widgets/calendar/{Calendar,CalendarDayButton}.qml`, `layout.js`; in `WidgetsTab.qml:57-60` | `shell/modules/dashboard/dash/Calendar.qml` | **drop-as-dup** |
| **System metrics** (CPU/GPU/RAM/disk/net/battery) | `widgets/dashboard/metrics/MetricsTab.qml` (already rebuilt on ryoku `SystemUsage`/`NetworkUsage`, see `:10-15`) | `shell/modules/dashboard/Performance.qml`; `settingsgui/.../SystemMonitor/PerformanceSubTab.qml`; bar `Widgets/PerformanceMode.qml` | **drop-as-dup** (canonical Performance tab) |
| **User / datetime / resources panel** | (not in AGPL WidgetsTab; AGPL has no user card) | canonical-only: `shell/modules/dashboard/dash/{User,DateTime,Resources}.qml` | n/a, canonical superset |
| **Screen tools row** (Google Lens, Color Picker, OCR, QR scan) | `widgets/dashboard/widgets/QuickControls.qml:34-68` (+ `ControlButton.qml`) | **UNIQUE**, only execs `ryoku-cmd-{google-lens,color-picker,ocr,qr-scan}`; island has stub `openLens`/`openColorPicker` (`island/Content.qml:27-35`, "not wired yet") | **re-home-to-controlcenter/island** (trivial; see §4) |
| **Webcam mirror** (PiP self-view window) | `tools/MirrorWindow.qml` (toggled by QuickControls button `QuickControls.qml:71-78`; state `globals/GlobalStates.qml:93`) | **UNIQUE**, no other mirror surface in shell | **re-home-to-controlcenter/shell-root** (see §4) |
| **Image clipboard** (Super+V, text+image, SQLite) | `widgets/dashboard/clipboard/{ClipboardTab.qml,clipboard_utils.js}`; service `modules/services/ClipboardService.qml`; `scripts/clipboard_*.sh` | Partial: launcher `settingsgui/.../Launcher/Providers/ClipboardProvider.qml` (text); settings `ClipboardSubTab.qml`; maintenance `shell/modules/ClipboardMaintenance.qml`. **The image-capable overlay UI + capture service are UNIQUE** | **re-home-to-controlcenter** (overlay UI + ClipboardService), see §4 |
| **Tab chrome / LRU / swipe nav** | `Dashboard.qml`, `DashboardView.qml`, `Tabs`-style highlight | canonical `shell/modules/dashboard/{Content,Tabs}.qml` provides equivalent tabbed shell | **drop-as-dup** (use canonical tab host) |
| Theme generators (Discord/GTK/Kitty/Qt/NvChad/Pywal) | `modules/theme/*Generator.qml`, `Colors.qml`, `Styling.qml`, `Icons.qml` | overlaps `settingsgui/.../Services/Theming/*` + `services/Colours.qml` (DesignMap axis) | defer to **design-map** axis; flag overlap |
| Shader/components (`StyledRect`, shaders, `CircularSeekBar`, `SearchInput`) | `modules/components/*` | overlaps `shell/components/*` (DesignMap axis) | defer to **design-map** axis |

---

## 4. UNIQUE features needing re-home (AGPL decision for manager)

These have **no canonical equivalent** and must be re-homed (not dropped). The AGPL
flag matters only when *AGPL source code* would move into the MIT `settingsgui`/
`controlcenter` trees, that relicensing decision is the manager's.

1. **Screen tools row**, Lens / Color Picker / OCR / QR scan buttons.
   `QuickControls.qml:34-68`. **AGPL flag: LOW.** The buttons are trivial
   `Quickshell.execDetached(["ryoku-cmd-…"])` calls; the actual logic lives in MIT
   `bin/ryoku-cmd-*` scripts. Can be **re-implemented clean** in MIT controlcenter/island
   without copying AGPL code. Island already has stub hooks (`island/Content.qml:27-35`).

2. **Webcam mirror window**, `tools/MirrorWindow.qml` (+ `GlobalStates.mirrorWindowVisible`).
   **AGPL flag: HIGH.** This is a substantial AGPL QML `PanelWindow` (geometry, drag,
   controls). Moving it verbatim into MIT trees relicenses it; either keep it in an
   AGPL-segregated module or rewrite clean. Manager decision.

3. **Image-capable clipboard**, overlay UI `clipboard/ClipboardTab.qml` + `clipboard_utils.js`
   + capture service `modules/services/ClipboardService.qml` + `scripts/clipboard_*.sh`.
   **AGPL flag: HIGH** (ClipboardTab UI is AGPL; the SQLite/service plumbing is the only
   image-clipboard implementation in the shell, `Wrapper.qml:9-10` calls it "the only
   place in ryoku that surfaces it"). Settings already wires its config (`ClipboardSubTab.qml`),
   so re-homing the *UI* into MIT controlcenter carries an AGPL relicensing decision; the
   service is already eagerly owned by MIT `ClipboardMaintenance.qml`.

**Theme generators / components / shaders** are unique-ish but belong to the **design-system
axis** (DesignMap), flagged here, not resolved.

---

## Cleanest first sub-stage to flip
Drop the **Media, Weather, Calendar, Metrics** tabs as duplicates: the canonical
`shell/modules/dashboard/` already ships equivalent Media / Weather / Performance / Dash
tabs, so retiring the AGPL WidgetsTab/MetricsTab content is pure subtraction with a
ready landing surface. That removes the bulk of the AGPL view in one move, leaving only
the 3 UNIQUE re-home items (screen tools, mirror, image clipboard) for the AGPL decision.
