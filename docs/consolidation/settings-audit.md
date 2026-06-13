# Settings Audit: "settings must change stuff"

Scope: every user-facing control under `shell/settingsgui/Modules/Panels/Settings/Tabs/**` +
`…/Panels/ControlCenter/Widgets/**`, cross-referenced against the **live** consumers in
`shell/modules`, `shell/services`, `shell/components`, `shell/dashboard` and the C++
`shell/plugin/src/Ryoku/Config`. READ-ONLY audit; all claims cited `path:line`.

## TL;DR

The migrated `GlobalConfig` controls **overwhelmingly work**, a live surface reads the same key
the control writes. The genuinely actionable problems are small and fall into three buckets:

1. **The 3 "known disconnections" are STALE.** The live consumers were *already* rewired to the key
   the UI writes (toasts → `utilities.toasts.*`; OSD → `osd.hideDelay`). The mismatched keys
   (`notifs.enable*Toast`, `osd.autoHideMs`, per-urgency durations) are read **only by dead
   noctalia leftover code** that the live shell never instantiates. So they are not functional
   disconnections, they are **dead/orphan config schema** that will mislead the next dev into
   wiring the wrong key. Fix = delete them, do **not** repoint the working controls.
2. **One missing control / ignored sibling key:** `services.useFahrenheitPerformance` has a live
   consumer but **no settings control**, the Region tab's `useFahrenheit` does not drive the
   dashboard performance temps. (Genuine "a setting that should change stuff but can't be reached".)
3. **Hardcodes in the end-4-ported overlay** (`modules/common/Appearance.qml`) bypass
   `GlobalConfig.appearance.transparency`, notification-card alpha is pinned opaque.

### Architecture note (decides every verdict)

`shell.qml` is the live shell. It imports `modules` + `qs.services` and only these slices of the
old noctalia app: `qs.settingsgui.Services.Platform` (plugins), `…Services.Location`/`…Services.Power`
(used by `GameMode.qml`), and `qs.settingsgui.Modules.Panels.Settings` (the settings window host,
`shell/modules/controlcenter/Wrapper.qml:8`). **Everything else under `shell/settingsgui/Modules/*`
and the rest of `shell/settingsgui/Services/*` is noctalia leftover that is never instantiated** -
so a key consumed *only* there is effectively a NO-OP. Verified: no live file imports
`settingsgui.Modules.{MainScreen,Bar,OSD,Dock}` or `settingsgui.Services.System/Hardware/Keyboard`
(grep across `shell/modules|services|components|dashboard|shell.qml` returns only the four slices above).

Live config reads use either `GlobalConfig.<x>` or the attached `Config.<x>` / `Tokens.<x>`
(`Tokens.rounding` etc. resolve to the **scaled** `appearance.*` proxies, `tokensattached.cpp:87-95`).

---

## 1. The three "known disconnections": corrected

| # | Control (write-site) | Mismatched read Main flagged | Actual LIVE consumer | Verdict | One-key fix |
|---|---|---|---|---|---|
| a | Charging/kb-layout/now-playing toast toggles, `ToastSubTab.qml:65,130,163` write `utilities.toasts.{chargingChanged,kbLayoutChanged,nowPlaying}` | `settingsgui/Services/.../{BatteryService.qml:324,KeyboardLayoutService.qml:77,NotificationService.qml:1122}` read `notifs.enable{Battery,KeyboardLayout,Media}Toast` (DEAD) | `BatteryMonitor.qml:15,18`, `Hypr.qml:222`, `Players.qml:54` read `utilities.toasts.*` | **WORKING** (live). Dead keys exist. | Delete `notifs.enable{Media,KeyboardLayout,Battery}Toast` (`notifsconfig.hpp:64-66`) + the dead settingsgui services; do **not** touch the toggles. |
| b | OSD hide delay slider, `Osd/GeneralSubTab.qml:41` writes `osd.hideDelay` | `settingsgui/Modules/OSD/OSD.qml:542` reads `osd.autoHideMs` (DEAD) | `modules/osd/Wrapper.qml:89` reads `Config.osd.hideDelay` | **WORKING** (live). `autoHideMs` orphan. | Delete `osd.autoHideMs` (`osdconfig.hpp:20`) + dead `settingsgui/Modules/OSD/OSD.qml`. |
| c | Per-urgency durations | `notifs.{low,normal,critical}UrgencyDuration` (`notifsconfig.hpp:61-63`) | **none** (no UI writes them, no live read). UI exposes only `defaultExpireTimeout` + `fullscreenExpireTimeout`, both consumed at `NotifData.qml:36,54` | **NO-OP orphan keys** | Delete the 3 keys. `DurationSubTab.qml:8-10` already documents per-urgency as "a fiction". |

Verified zero live consumers for `enableMarkdown`, `respectExpireTimeout`, the 3 urgency durations,
the 3 `enable*Toast`, and `autoHideMs` (grep across the whole live tree → no matches).

---

## 2. Control inventory by tab: writes key / live consumer / verdict

Representative consumer cited per row; domains marked WORKING were each confirmed by a live read.

### Notifications
| Control | Writes | Live consumer reads | Verdict |
|---|---|---|---|
| Toast: charging/audioOut/audioIn/gameMode/caps/num/kbLayout/dnd/nowPlaying/vpn (`ToastSubTab.qml`) | `utilities.toasts.*` | `BatteryMonitor:15`, `Audio:152,164`, `GameMode:152,190`, `Hypr:202,212,222`, `Notifs:41`, `Players:54`, `VPN:281` | **WORKING** |
| Max toasts (`ToastSubTab.qml:45`) | `utilities.maxToasts` | `modules/utilities/toasts/Toasts.qml:50,73` | **WORKING** |
| Dismiss after / fullscreen / respect-expire (`DurationSubTab.qml:24,42,60`) | `notifs.{expire,defaultExpireTimeout,fullscreenExpireTimeout}` | `NotifData.qml:36,54,57` | **WORKING** |
| Open expanded / action-on-click / hold-while-fullscreen (`GeneralSubTab.qml:36,48,61`) | `notifs.{openExpanded,actionOnClick,fullscreen}` | `Notification.qml:22,83`; `Notifs.qml:35` | **WORKING** |
| (no control) clear/expand threshold, groupPreview | `notifs.{clearThreshold,expandThreshold,groupPreviewNum}` | `Notification.qml:70,78`, `NotifGroupList.qml:45`, `NotifDockList.qml:90,95` | **WORKING** (no UI, but live) |
| (no control) markdown | `notifs.enableMarkdown` | none, body format is a hardcoded heuristic `Notification.qml:20` | **NO-OP/HARDCODED** |
| (no control) master enable | `notifs.enabled` | none (gating is via DND only) | **NO-OP orphan** |

### OSD
| Control | Writes | Live consumer | Verdict |
|---|---|---|---|
| Enabled (`Osd/GeneralSubTab.qml:23`) | `osd.enabled` | `modules/osd/Wrapper.qml:18` | **WORKING** |
| Hide delay (`Osd/GeneralSubTab.qml:41`) | `osd.hideDelay` | `modules/osd/Wrapper.qml:89` | **WORKING** |
| Brightness/Mic events (`EventsSubTab.qml:31,44`) | `osd.{enableBrightness,enableMicrophone}` | `osd/Content.qml:56,82` | **WORKING** |

### User Interface / Appearance
| Control | Writes | Live consumer | Verdict |
|---|---|---|---|
| Transparency enable/base/layers (`AppearanceSubTab.qml:23,56,75,91`) | `appearance.transparency.*` | `Colours.qml:146-148,100` via `Tokens.transparency` (`tokensattached.cpp:94`) | **WORKING** |
| Deform scale (`:110`) | `appearance.deformScale` | `ContentWindow.qml:487` | **WORKING** |
| Rounding/Spacing/Padding/Font scale (`:125,140,155,170`) | `appearance.{rounding,spacing,padding,font.size}.scale` | every `Tokens.{rounding,spacing,padding,font}.*` reader; scale applied in `appearanceconfig.cpp:35-44` and surfaced via `tokensattached.cpp:87-90` | **WORKING** |
| Animation speed (`:189`) | `appearance.anim.durations.scale` | `Tokens.anim.durations` bound at `tokensattached.cpp:77` | **WORKING** |
| Panel dimmer (`PanelsSubTab.qml:48`) | `appearance.dimmerOpacity` | `ContentWindow.qml:151` | **WORKING** |
| Border thickness/rounding/smoothing (`ScreenCornersSubTab.qml:26,41,56`) | `border.*` | widely (e.g. `Background.qml:68`, `Visualiser.qml:63`) | **WORKING** |

### Bar / Top-notch / Sidebar widgets
| Control | Writes | Live consumer | Verdict |
|---|---|---|---|
| Scroll actions ws/vol/bright (`BehaviorSubTab.qml:28,38,48`) | `bar.scrollActions.*` | `Bar.qml:101`, `TopNotch.qml:86` | **WORKING** |
| Popouts activeWin/tray/status (`:70,80,90`) | `bar.popouts.*` | bar popout host (`modules/bar`) | **WORKING** |
| Design / persistent / showOnHover / dragThreshold (`DesignSubTab.qml:45,71,90`) | `bar.{design,persistent,showOnHover,dragThreshold}` | `services/BarDesign.qml` + bar visibility | **WORKING** |
| Excluded screens (`common/MonitorsSubTab.qml:32`) | `bar.excludedScreens` | bar per-screen loader | **WORKING** |
| Sidebar entries / layout (`LayoutSubTab.qml:48`) | `bar.entries` | bar entry model | **WORKING** |
| Workspaces shown/indicator/windows/etc (`WidgetsSubTab.qml`) | `bar.workspaces.*` | `Bar.qml:103`, `TopNotch.qml:87`, workspace widget | **WORKING** |
| activeWindow / tray / clock / status sub-toggles (`WidgetsSubTab.qml`) | `bar.{activeWindow,tray,clock,status}.*` | respective bar widgets | **WORKING** |
| Top-notch status/clock toggles (`NotchSubTab.qml`) | `bar.topNotch.*` | `TopNotch.qml:211` (clock) + notch widgets | **WORKING** |

### Audio / Display / Media
| Control | Writes | Live consumer | Verdict |
|---|---|---|---|
| Default player (`MediaSubTab.qml:21`) | `services.defaultPlayer` | `Players.qml` active-player pref | **WORKING** |
| Visualiser style/bars/smoothing/autoSens/etc (`VisualizerSubTab.qml`) | `background.visualiser.*`, `services.visualiser*` | `Visualiser.qml:19,74-87`, `Audio.qml:207-209`, `dashboard/Media.qml:125` | **WORKING** |
| Audio increment / max volume (`VolumesSubTab.qml:127,149`) | `services.{audioIncrement,maxVolume}` | `Audio.qml:74,79,89`, `osd/Content.qml:49` | **WORKING** |
| Brightness increment/min/ddc (`BrightnessSubTab.qml:175,188,201`) | `services.brightness*` | `Brightness.qml:53,169,200`, `Bar.qml:123` | **WORKING** |

### Region / clocks / weather
| Control | Writes | Live consumer | Verdict |
|---|---|---|---|
| Weather location / units / 12h clock (`RegionTab.qml:32,57,76,95`) | `services.{weatherLocation,useFahrenheit,useTwelveHourClock}` | `Weather.reload`, `WeatherTab.qml:196`, `DateTime.qml:54`, `DesktopClock.qml:192`, `Clock.qml:65`, `WeatherUnitSync.qml:14` | **WORKING** |
| **(no control)** perf-temp unit | `services.useFahrenheitPerformance` (`serviceconfig.hpp:22`) | `dashboard/Performance.qml:17` | **NO-OP / MISSING CONTROL** |

### Other domains (consumer-confirmed WORKING)
| Domain | Sample write → live consumer |
|---|---|
| Launcher | `launcher.{maxShown,actionPrefix,useFuzzy.*,favouriteApps,enableDangerousActions}` → `AppList:27`, `Content:60,88`, `Apps.qml:69,75`, `Actions.qml:18,23` |
| Clipboard | `clipboard.{enabled,maxEntries,autoCleanup}` → clipboard module / `ClipboardMaintenance.qml` |
| System monitor | `systemMonitor.*Threshold/colors` → `services/SystemUsage` + bar/dashboard gauges |
| Night light | `nightLight.{enabled,forced,nightTemp,dayTemp,autoSchedule,...}` → `NightLightService` (CC widget `NightLight.qml`, `DisplayTab.qml:46`) |
| Game mode | `gameMode.*` → `services/GameMode.qml:152,190`; `common/Appearance.qml:22` (`shellAnimations`) |
| Desktop widgets / wallpaper | `background.{widgets,desktopClock,wallpaperEnabled,visualiser}` → `Background.qml`, `DesktopClock.qml`, `Wrapper`/`Visualiser` |
| Idle | `general.idle.{timeouts,inhibitWhenAudio,lockBeforeSleep,...}` → `IdleMonitors.qml:20,43`, `LockBridge.qml:67` |
| Paths / general | `paths.obsidian*`, `general.{reverseScroll,apps.terminal,mediaGifSpeedAdjustment}` → `ObsidianNotes`, `Bar.qml:100`, `Apps.qml:16`, `dashboard/Media.qml:407` |
| Color schemes / templates | `colorSchemes.*`, `services.{syncSystemTheme,smartScheme}`, `templates.*` → `ColorSchemeService`, `AppThemeService`, `TemplateRegistry` |
| Bluetooth/Wifi | `network.bluetooth*`, `network.{wifi,bluetooth}DetailsViewMode` → `BluetoothService` / view state |
| CC widgets | `colorSchemes.darkMode`, `nightLight.{enabled,forced}` → `Colours`, `NightLightService` |

---

## 3. Orphan / dead config keys (no UI **and** no live consumer): schema cleanup

| Key | Defined | Read only by | Action |
|---|---|---|---|
| `notifs.enableMediaToast` / `enableKeyboardLayoutToast` / `enableBatteryToast` | `notifsconfig.hpp:64-66` | dead `settingsgui/Services/{System/NotificationService:1122, Keyboard/KeyboardLayoutService:77, Hardware/BatteryService:324}` | delete keys + dead services |
| `osd.autoHideMs` | `osdconfig.hpp:20` | dead `settingsgui/Modules/OSD/OSD.qml:542` | delete key + dead OSD |
| `notifs.{low,normal,critical}UrgencyDuration` | `notifsconfig.hpp:61-63` | nothing | delete |
| `notifs.respectExpireTimeout` | `notifsconfig.hpp:60` | nothing (toggle writes `notifs.expire`) | delete |
| `notifs.enableMarkdown` | `notifsconfig.hpp:59` | nothing (`Notification.qml:20` auto-detects) | delete, or wire `bodyTextFormat` to it |
| `notifs.enabled` | `notifsconfig.hpp:58` | nothing | delete, or gate the server on it |

---

## 4. Hardcoded values that ignore an existing setting

| Location | Hardcode | Should be | Verdict |
|---|---|---|---|
| `modules/common/Appearance.qml:25` | `backgroundTransparency: 0` (end-4 store), consumed by `common/widgets/NotificationGroup.qml:154` to compute `1 - backgroundTransparency` card alpha | derive from `GlobalConfig.appearance.transparency.{enabled,base}` | **HARDCODED**, overlay notification cards always opaque, never glassy. Lives in the end-4-ported overlay (separate `Appearance`/`Config.options` store, not GlobalConfig). |
| `modules/common/widgets/AngelPartialBorder.qml:44,65,86,107` | `NumberAnimation { duration: 300 }` | `Tokens.anim.durations.*` (so the Animation-speed slider applies) | **HARDCODED** (minor; end-4 widget) |
| `Notification.qml:20` | `bodyTextFormat` markdown via regex heuristic | honor `notifs.enableMarkdown` | **HARDCODED** (markdown always auto) |

Note: `ContentWindow.qml:151` scrim is now correctly `GlobalConfig.appearance.dimmerOpacity` (confirmed
WORKING), the analogous remaining gap is the **end-4 overlay** path above, which never reads the
transparency setting. (Overlaps `NativeFeelAudit`'s glass/consistency scope.)

---

## 5. Fix these first (low-risk, high-impact, clearly wired)

1. **Delete the dead duplicate keys + dead noctalia code** (`notifs.enable*Toast` `notifsconfig.hpp:64-66`,
   `osd.autoHideMs` `osdconfig.hpp:20`, plus dead `settingsgui/Modules/OSD/OSD.qml` &
   `settingsgui/Services/{System,Hardware,Keyboard}` toast paths). **Risk: ~0** (no live reader).
   Highest value: it removes the trap that makes the toasts/OSD *look* disconnected and stops a future
   dev from "fixing" a working control onto a dead key. Do **NOT** repoint `ToastSubTab`/`Osd/GeneralSubTab`.
2. **Wire dashboard perf-temp unit to the Region setting**, change `dashboard/Performance.qml:17` to read
   `GlobalConfig.services.useFahrenheit` (drop the orphan `useFahrenheitPerformance`), or add a toggle in
   `RegionTab.qml`. One line; makes the only reachable-but-ignored unit setting actually apply.
3. **Delete orphan per-urgency / markdown / respectExpire / notifs.enabled keys**
   (`notifsconfig.hpp:58-63`). Risk ~0; the live model is `defaultExpireTimeout`+`fullscreenExpireTimeout`,
   already exposed and working (`NotifData.qml:54`).
4. **Make the end-4 overlay honor transparency**, `modules/common/Appearance.qml:25`
   `backgroundTransparency` should derive from `GlobalConfig.appearance.transparency.base` so overlay
   notification cards (`NotificationGroup.qml:154`) get the same glass as the drawer surface. Low risk,
   visible native-feel win.
5. **Honor `notifs.enableMarkdown`** (if kept), gate `Notification.qml:20` `bodyTextFormat` on the key
   instead of the unconditional regex heuristic. Trivial; otherwise delete the key per #3.
