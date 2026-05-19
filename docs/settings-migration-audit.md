# Ryoku Settings Migration Audit

This tracks every option that exists in the legacy settings panel (`shell/settings.qml`
+ `shell/modules/settings/*.qml`) and whether the new official settings surface
(`shell/ryokuSettings.qml`) covers it. The goal is **zero feature loss** during the
migration to the new UI style.

> Legend per row in the matrices below:
> - **✅ Ported** - the new UI exposes the setting natively in its own style
> - **🧱 Embedded** - the new UI mounts the legacy QML page as a Loader (works, but
>   keeps the old visual style - needs reskinning)
> - **❌ Missing** - no destination in the new UI yet; user loses access unless they
>   launch `ryoku-shell legacy-settings-window`
> - **🟡 Partial** - some controls present, others missing (gap detailed in row)

Numbers like "12/22" mean "12 of the 22 individual sub-toggles in this legacy
section made it across".

## Legacy reference files kept on disk

- `shell/settings.qml` (entrypoint, 2596 lines, 177-entry search index)
- `shell/modules/settings/QuickConfig.qml`
- `shell/modules/settings/GeneralConfig.qml`
- `shell/modules/settings/BarConfig.qml`
- `shell/modules/settings/BackgroundConfig.qml`
- `shell/modules/settings/ThemesConfig.qml`
- `shell/modules/settings/InterfaceConfig.qml`
- `shell/modules/settings/ToolsConfig.qml`
- `shell/modules/settings/ServicesConfig.qml`
- `shell/modules/settings/AdvancedConfig.qml`
- `shell/modules/settings/CheatsheetConfig.qml`
- `shell/modules/settings/ModulesConfig.qml`
- `shell/modules/settings/WaffleConfig.qml`
- `shell/modules/settings/NiriConfig.qml`
- `shell/modules/settings/LoginScreenConfig.qml`
- `shell/modules/settings/About.qml`
- `shell/modules/settings/ExtrasConfig.qml`
- `shell/modules/settings/AngelStyleEditor.qml`
- `shell/modules/settings/AuroraStyleEditor.qml`
- `shell/modules/settings/CustomThemeEditor.qml`
- `shell/modules/settings/GowallWallpaperEditor.qml`

Compatibility launcher: `ryoku-shell legacy-settings-window`.

## Migration scale at a glance

| Legacy file | Lines | Approx. controls | Coverage |
|---|---:|---:|---|
| `shell/settings.qml` (entrypoint) | 2596 | 20+ inline + 177 search index | 🟡 Partial |
| `QuickConfig.qml` | 1746 | ~55 | 🟡 Partial |
| `GeneralConfig.qml` | 1101 | ~85 | 🟡 Partial |
| `BarConfig.qml` | 1058 | ~75 | 🟡 Partial |
| `BackgroundConfig.qml` | 2957 | ~140 | 🧱 Embedded |
| `ThemesConfig.qml` | 1726 | ~45 | 🟡 Partial |
| `InterfaceConfig.qml` | 2553 | ~210 | 🟡 Partial |
| `ToolsConfig.qml` | 952 | ~45 | 🟡 Partial |
| `ServicesConfig.qml` | 1957 | ~70 | 🟡 Partial |
| `AdvancedConfig.qml` | 422 | ~35 | 🟡 Partial |
| `CheatsheetConfig.qml` | 777 | dynamic keybind editor | ❌ Missing |
| `ModulesConfig.qml` | 1043 | ~55 | 🟡 Partial |
| `WaffleConfig.qml` | 666 | ~50 | 🟡 Partial |
| `NiriConfig.qml` | 3231 | ~120 | 🟡 Partial |
| `LoginScreenConfig.qml` | 866 | provider cards + 21 themes | ❌ Missing |
| `About.qml` | 612 | ~15 | ✅ Ported |
| `ExtrasConfig.qml` | 682 | dynamic profiles | 🧱 Embedded |
| `AngelStyleEditor.qml` | 1037 | ~40 sliders + profiles | ❌ Missing |
| `AuroraStyleEditor.qml` | 374 | 9 sliders + presets | ❌ Missing |
| `CustomThemeEditor.qml` | 2183 | ~50 color pickers + flows | ❌ Missing |
| `GowallWallpaperEditor.qml` | 836 | 5 ops + palette editor | ❌ Missing |

---

## Ported in this pass (already in new UI)

### Top-level / window
- Official entrypoint: `shell/ryokuSettings.qml`
- Primary launcher / Mod+Comma path: `ryoku-shell settings`
- Centered vs window launch mode (`settingsUi.launchMode`, read through `RYOKU_SETTINGS_MODE`)
- 15 pages with sidebar nav (General, Appearance, Wallpaper & Desktop, Bar & Dock,
  Panels & Modules, Control Center, Launcher, Notifications, Audio & Display,
  Lock & Power, Services, Tools & Capture, Advanced, Extras, About)

### General > Quick Rice
- Favorite theme swatch cards, wallpaper-colors toggle, palette variant combo
- Automatic transparency toggle + shell surface / content transparency sliders
- Inactive window opacity (via `scripts/niri-config.py`)
- Focus ring enable / width / follow-theme
- Cursor theme / size
- GPK quick actions: Open GPK, Install, Uninstall, Update, Outdated

### General > Window / Fonts / Language
- Settings window open mode (Centered / Normal)
- Main / Title / Mono font combos (curated short list)
- Default font size 75–135%
- Language combo (Auto / en_US / es_ES) - **legacy supported the full Translation.allAvailableLanguages list, see gaps**
- "Launch the setup wizard" button

### Appearance
- Header shell style selector + theme mode segment + wallpaper-colors segment + Matugen scheme type
- Theme search + filter + preset grid + day/night schedule combos
- 9 template scopes + 10 terminal template toggles + 4 terminal color shaping sliders
- Animation scale slider + reduce motion switch

### Wallpaper & Desktop
- Wallpaper directory text, selector style combo, selection target combo
- Wallpaper blur + radius + dim + animated wallpapers
- Backdrop / parallax / ripple enable toggles (3-toggle grid)
- 6 desktop widget enables
- 🧱 Embeds **BackgroundConfig.qml** and **DesktopWidgetsConfig.qml** in full

### Bar & Dock
- Bar position segment + corner style + 4 layout toggles
- 12 bar module toggles
- Dock enable / position / height / icon size + 4 dock toggles

### Panels & Modules
- Panel family combo (ii / Waffle)
- 9 ii enabledPanels toggles + 6 Waffle enabledPanels toggles
- 6 Waffle tweak toggles
- Compositor: auto-expand single tiling window

### Control Center / Sidebar / Launcher / Notifications
- 6 control panel section toggles
- Sidebar left width + cardStyle + keepLoaded
- Search: sloppy / nonAppResultDelay / engineBaseUrl
- 5 global action toggles
- Shortcut buttons: Open overlay, Edit Niri keybinds
- Notifications: DND, position, normal/critical timeouts
- OSD: media enabled + timeout
- Sounds: notifications.enable + critical.enable

### Audio & Display
- Earbang protection trio
- Primary monitor combo + dynamic Niri output controls (resolution, refresh,
  scale, transform), VRR toggle, refresh button
- 4 overview/screen-corners toggles
- Full focus-ring native section (enable, width, follow-theme, active gradient
  toggle, from/to colors, angle, inactive color)
- Cursor theme / size / hide-on-type, refresh button
- Pointer: accel-profile, accel-speed, natural-scroll, left-handed, middle-emulation
- Touchpad: accel-profile, tap, natural-scroll, dwt, disabled-on-external-mouse
- Keyboard: layout, options, repeat-delay, repeat-rate, numlock
- Focus behavior: warp-pointer + warp-mode, focus-follows-mouse + scroll limit,
  workspace-auto-back-and-forth, disable-power-key-handling
- Resources: update interval, CPU warning, monitorGpu + 3 indicator toggles

### Lock & Power
- 6 lock toggles + lock clock-style combo
- Session screen toggle + close-confirm toggle
- Power profile combo

### Tools & Capture
- Recorder: quality preset, FPS, video codec, Discord target size
- Capture: screenshot name format, darken screen
- Apps: AppLauncher slot Repeater + Discord / update command / music dir TextFields

### Advanced
- Coverage rows + raw config browser (per category)
- 12-target theme application grid
- Game mode 6-toggle grid + updates check interval
- Login: "Apply ii-pixel" button + "Open qylock folder" button + path labels

### Services / Extras
- 🟡 **Services** page is native: Idle and sleep, AI providers, Music recognition,
  Hotspot, Search and networking, Resources, Updates, Ryoku shell updates,
  Weather, and Calendar sync.
- 🧱 **Extras** page embeds full `ExtrasConfig.qml`

### About
- Version label, repository link, docs/issues/check-updates/update-details
- System info: distro, migrated legacy groups, copy-path rows for runtime config /
  shell runtime / niri config / dotfiles
- Credit cards: iNiR, illogical-impulse, Omarchy, qylock

---

## Definitive gap matrix (legacy → new)

### Legacy: `shell/settings.qml` (entrypoint)

| Legacy feature | New surface | Status | Notes |
|---|---|---|---|
| User avatar in titlebar (multi-source fallback) | - | ❌ Missing | No avatar in new UI |
| Easy/Advanced mode toggle (school ↔ tune) | - | ❌ Missing | `cfg:settingsUi.easyMode` not honored by new sidebar; 8 non-essential pages can't be hidden |
| Lock button in titlebar (`ryoku-shell lock activate`) | - | ❌ Missing | Quick lock action removed |
| Search field with Ctrl+F shortcut, animated icon, results badge | Sidebar search | 🟡 Partial | New has search; missing the animated morph (Cookie7Sided↔SoftBurst), badge count, breadcrumb in results, 177-entry pre-built index, scoring heuristics, spotlight-with-retry |
| Global page-cycle shortcuts (Ctrl+PgUp/PgDn, Ctrl+Tab) | - | ❌ Missing | No keyboard page navigation |
| Page preload on first search | - | ❌ Missing | All pages are Loader-based but no async preload |
| FAB "Config file" (open / right-click copy path, 1500ms revert) | About copy-path rows | 🟡 Partial | Copy rows exist but no single-FAB affordance; no right-click "copy path" gesture |
| Overlay mode toggle at nav rail bottom | - | ❌ Missing | `cfg:settingsUi.overlayMode` no longer toggleable from new UI |
| Startup deep-link via `QS_SETTINGS_PAGE` / `QS_SETTINGS_SECTION` | `applyInitialTabFromEnv()` | ✅ Ported | New has equivalent env-based entry |
| Spotlight section highlight (15-retry timer, scroll-into-view) | - | ❌ Missing | Search results don't scroll to a specific control |
| Window title "illogical-impulse Settings" / "Ryoku Settings" | "Ryoku Settings" | ✅ Ported | |

### Legacy: `QuickConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Wallpaper & Colors hero card with Light/Dark + Random (Konachan/osu) + Choose file | - | ❌ Missing | Hero card + animated weeb random buttons + Ctrl+Alt+T file picker are not in the new UI |
| Color scheme variant chip group (9 options incl. Fruit Salad) | Appearance > Colors > Matugen | 🟡 Partial | New is missing "Fruit Salad" variant value |
| Wallpaper color strength % | - | ❌ Missing | `cfg:appearance.wallpaperTheming.colorStrength` slider not in new UI |
| Transparency switch | General > Quick Rice | ✅ Ported | |
| Colors only mode | - | ❌ Missing | `cfg:appearance.wallpaperTheming.colorsOnlyMode` slider not exposed |
| Quick Select panel: folder breadcrumb, Current folder, Selector, wallpaper grid Repeater, backdrop selection mode | - | ❌ Missing | The in-settings wallpaper grid + folder breadcrumb is gone |
| Per-monitor wallpapers visual layout (stacked preview, per-monitor random/reset/apply/backdrop, media-type badges) | Wallpaper > Wallpaper (basic) | 🟡 Partial | New only has 3 wallpaper TextField/combo rows; the rich per-monitor card is only reachable through the embedded BackgroundConfig.qml page |
| Derive theme colors from backdrop | (lives in embedded BackgroundConfig) | 🧱 Embedded | |
| Bar position 4-icon segment | Bar & Dock > Bar | ✅ Ported | |
| Bar style Hug/Float/Rect/Card | Bar & Dock > Bar | ✅ Ported | |
| Screen round corner No/Yes/When-not-fullscreen | - | ❌ Missing | `cfg:appearance.fakeScreenRounding` not in new UI |
| Wallpaper mode Normal/Backdrop only | - | ❌ Missing | Only available through embedded BackgroundConfig |
| Game Mode block (7 switches) | Advanced > Automation | 🟡 Partial | New has 6 of 7; **missing `disableNiriAnimations` and `disableDiscoverOverlay`** |
| Quick Actions: Reload Shell / Open Config / Shortcuts | About copy rows + Launcher>Shortcuts | 🟡 Partial | No "Reload Shell" button in new UI |
| Show reload toasts | Advanced > Automation | ✅ Ported | |
| Hide reload toasts in Game Mode | - | ❌ Missing | `cfg:gameMode.disableReloadToasts` not exposed |
| Confirm before closing windows | Lock & Power > Session | ✅ Ported | |

### Legacy: `GeneralConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Audio: earbang trio | Audio & Display > Audio | ✅ Ported | |
| Displays: connected monitors info | - | ❌ Missing | New shows only "Primary monitor" combo |
| Displays: primary monitor | Audio & Display > Display | ✅ Ported | |
| Displays: per-monitor bar visibility (multi-mon) | - | ❌ Missing | `cfg:bar.screenList` editor gone |
| Displays: per-monitor dock visibility | - | ❌ Missing | `cfg:dock.screenList` editor gone |
| Battery: low / critical / full warning thresholds | - | ❌ Missing | `cfg:battery.low/critical/full` not in new UI |
| Battery: automaticSuspend + suspend % | - | ❌ Missing | |
| Battery: chargeLimit enable + threshold + current status display | - | ❌ Missing | |
| Language: full languages list (auto + Translation.allAvailableLanguages) | General > Language (3-option short list) | 🟡 Partial | New combo is hard-coded to auto / en_US / es_ES |
| Language: Gemini translation generation (locale field + Generate button with progress) | - | ❌ Missing | |
| Policies: AI (No/Yes/Local) | - | ❌ Missing | `cfg:policies.ai` editor gone (still used by sidebar) |
| Policies: Weeb (No/Yes/Closet) | - | ❌ Missing | `cfg:policies.weeb` editor gone |
| Sounds: battery / timer / pomodoro / notifications | Notifications > Sounds | 🟡 Partial | New only has notifications + critical; **missing battery, timer, pomodoro** |
| Time: second precision | - | ❌ Missing | `cfg:time.secondPrecision` switch gone |
| Time: time format 24h / 12h-am/pm / 12h-AM/PM | - | ❌ Missing | `cfg:time.format` combo gone |
| Time: long date format + short date format TextFields | - | ❌ Missing | `cfg:time.dateFormat` and `cfg:time.shortDateFormat` gone |
| Keyboard popups: master + layout/caps/num | - | ❌ Missing | 4 `cfg:keyboardIndicators.popup.*` toggles gone |
| Keyboard panel indicators: master + layout/caps/num | - | ❌ Missing | 4 `cfg:keyboardIndicators.panel.*` toggles gone |
| Window Management: Confirm close (advanced mode) | Lock & Power > Session | ✅ Ported | |
| Work Safety: hide clipboard images / hide sussy wallpapers | - | ❌ Missing | `cfg:workSafety.enable.{clipboard,wallpaper}` gone |
| Lock screen full block (Hyprlock toggle, security, notifications, clock, dim/blur, widgets, varying shapes, animated GIF wallpapers) | Lock & Power > Lock (6 toggles + clock-style) | 🟡 Partial | New has only 6 of the ~25 controls. Missing: notifications.{enable,showBody,maxCount,position}, clock.position, status.enable, centerClock, showLockedText, materialShapeChars, enableAnimation, all 4 widget toggles (weather/media/powerButtons/hintText), blur.radius, blur.extraZoom, dim.opacity |

### Legacy: `BarConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Position + corner style + custom bar rounding | Bar & Dock > Bar | 🟡 Partial | New is missing `cfg:bar.customRounding` (-1..50) spinner |
| Group style Pills / Seamless (`cfg:bar.borderless`) | Bar & Dock > Bar (toggle) | ✅ Ported | (as a toggle, not as Pills/Seamless segment) |
| Auto-hide | Bar & Dock > Bar (toggle) | ✅ Ported | |
| Show background | Bar & Dock > Bar (toggle) | ✅ Ported | |
| Show scroll hints | - | ❌ Missing | `cfg:bar.showScrollHints` gone |
| Left scroll action combo | - | ❌ Missing | `cfg:bar.leftScrollAction` gone |
| Right scroll action combo | - | ❌ Missing | `cfg:bar.rightScrollAction` gone |
| Vignette enabled + intensity % + radius % | - | ❌ Missing | All 3 `cfg:bar.vignette.*` controls gone |
| Modules visibility (13 toggles) | Bar & Dock > Modules (12 toggles) | 🟡 Partial | **Missing taskbar toggle** (`cfg:bar.modules.taskbar`) - note legacy disables Active Window when taskbar enabled |
| Resources: 5 show-indicator toggles | Audio & Display > Monitor (3 toggles) | 🟡 Partial | Missing GPU indicator and swap indicator toggles |
| Resources: alwaysShowCpu / alwaysShowGpu / alwaysShowTemp | - | ❌ Missing | |
| Resources: 6 warning threshold spinners | Audio & Display > Monitor (only CPU warning) | 🟡 Partial | Missing RAM / GPU / swap / temp caution / temp warning thresholds |
| Media popup mode Dock/Bar | - | ❌ Missing | `cfg:media.popupMode` gone |
| Workspaces (10 controls incl. number style/map) | Bar & Dock > Bar (1 "Numbers" toggle) | 🟡 Partial | Missing: scrollBehavior, showAppIcons, monochromeIcons, dynamicCount, wrapAround, perMonitor, invertScroll, shown count, scrollSteps, showNumberDelay, numberMap combo |
| System Tray (3 toggles) | - | ❌ Missing | `cfg:bar.tray.{invertPinnedItems,monochromeIcons,showItemId}` gone |
| Utility Buttons (10 toggles + screenCastOutput TextField) | - | ❌ Missing | Per-button visibility cannot be edited |
| Bar indicators: show unread count | - | ❌ Missing | `cfg:bar.indicators.notifications.showUnreadCount` gone |

### Legacy: `BackgroundConfig.qml`

| Status | Notes |
|---|---|
| 🧱 Embedded | Reachable via Wallpaper > Background Controls; legacy QML rendered inside the new shell. ~140 cfg keys covered. **TODO: native reskin** so the parallax visual profile, multi-monitor layout card, fluid ripple block, backdrop aurora block, transition style list, pan/zoom interactive viewport, and the 4 legacy widget blocks (Clock/Weather/Media/Visualizer) render in the new UI style. |

### Legacy: `ThemesConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Theme search + filter + dynamic tag filter + clear-tag | Appearance > Themes | 🟡 Partial | New has search and All/Dark/Light/Saved filter; **missing dynamic tag filters** (from ThemePresets.availableTags) and the clear-tag chip |
| Soften colors toggle | - | ❌ Missing | `cfg:appearance.softenColors` gone |
| Quick access: favorites + recents merged | Appearance > Themes ("Saved" filter) | 🟡 Partial | "Recent themes" no longer surfaced separately |
| Wallpaper dominant colors swatches (clickable to copy hex) | - | ❌ Missing | |
| Theme grid (ThemePresetCard with double-click to apply) | Appearance > Themes | ✅ Ported | |
| Scheme Variant combo (9 options incl. Fruit Salad) | Appearance > Colors > Matugen (8 options) | 🟡 Partial | New is missing "Fruit Salad" |
| Theme Schedule: day/night theme dropdowns | Appearance > Themes | ✅ Ported | |
| Theme Schedule: day start hour/minute + night start hour/minute | - | ❌ Missing | `cfg:appearance.themeSchedule.dayStart` and `nightStart` not in new UI (only enabled toggle and per-side theme combos) |
| Terminal theming master + 10 per-terminal toggles | Appearance > Templates | ✅ Ported | |
| Terminal install detection "Auto-detect installed" button | - | ❌ Missing | The detection script + status display is gone |
| Terminal 16-color preview | - | ❌ Missing | |
| Terminal color adjustments (4 sliders) | Appearance > Templates | ✅ Ported | |
| "Apply to open terminals" button (runs scripts/colors/applycolor.sh) | - | ❌ Missing | |
| Global Style combo (Material/Cards/Aurora/Ryoku/Angel + cascading side-effects) | Appearance > Colors + General > Quick Rice | 🟡 Partial | New sets globalStyle but does not perform the cascading side-effects (dock.cardStyle, sidebar.cardStyle, bar.cornerStyle, transparency.enable) per legacy mapping |
| Aurora Style Editor (loader) | - | ❌ Missing | **AuroraStyleEditor.qml not reachable from new UI** |
| Angel Style Editor (loader) | - | ❌ Missing | **AngelStyleEditor.qml not reachable from new UI** |
| Custom Theme Editor (loader) | - | ❌ Missing | **CustomThemeEditor.qml not reachable from new UI** |
| Gowall Wallpaper Editor (lazy loader) | - | ❌ Missing | **GowallWallpaperEditor.qml not reachable from new UI** |
| Typography: font preset quick buttons | - | ❌ Missing | `StylePresets.applyPreset()` button row gone |
| Typography: main / title / mono font selectors | General > Fonts | 🟡 Partial | New uses curated short combos; legacy used full FontSelector dropdowns |
| Typography: sizeScale | General > Fonts | ✅ Ported | |
| Typography: variable axes (wght/wdth/grad) collapsible | - | ❌ Missing | `cfg:appearance.typography.variableAxes.*` 3 spinners gone |
| Typography: reset typography button | - | ❌ Missing | |
| Icon Theme: System and Dock IconThemeSelector | - | ❌ Missing | `cfg:appearance.iconTheme` + `cfg:appearance.dockIconTheme` editors gone |

### Legacy: `InterfaceConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Alt-Tab switcher (15+ controls: noVisualUi, monochromeIcons, enableAnimation, animationDurationMs, useMostRecentFirst, backgroundOpacity, blurAmount, scrimDim, autoHideDelayMs, showOverviewWhileSwitching, preset, compactStyle, panelAlignment, useM3Layout) | - | ❌ Missing | None of `cfg:altSwitcher.*` are exposed in the new UI; only the corresponding Waffle-side toggles (3) are in the Waffle sub-tab |
| Dock: 22 controls (enable, style, position, hoverToReveal, showOnDesktop, pinnedOnStartup, monochromeIcons, showBackground, separatePinnedFromRunning, enableDragReorder, cardStyle, height, iconSize, hoverRegionHeight, smartIndicator, showAllWindowDots, maxIndicatorDots, hoverPreview, hoverPreviewDelay, keepPreviewOnClick) | Bar & Dock > Dock (10 controls) | 🟡 Partial | Missing: style (Panel/Pill/macOS), showOnDesktop, pinnedOnStartup, monochromeIcons, separatePinnedFromRunning, enableDragReorder, cardStyle, hoverRegionHeight, showAllWindowDots, maxIndicatorDots, hoverPreviewDelay, keepPreviewOnClick |
| Notifications: scaleOnHover, edgeMargin, useLegacyCounter (badge sync) | Notifications > Notifications | 🟡 Partial | Only the 4 base controls (DND, position, timeoutNormal, timeoutCritical) are ported |
| Control Panel (9 toggles incl. wallpaper section, wallpaper scheme chips, keepLoaded) | Control Center > Control Center (6 toggles) | 🟡 Partial | Missing: showWallpaperSection, showWallpaperSchemeChips, keepLoaded |
| Sidebars > General: animationType combo (7 modes), instantOpen, openFolderOnDownload, keepRightSidebarLoaded | Control Center > Sidebar (3 controls) | 🟡 Partial | Most controls missing |
| Sidebars > Left Sidebar: 10 module toggles (Widgets/AI/Translator/Anime/Wallhaven/AnimeSchedule/Reddit/Tools/Software/YT Music) | - | ❌ Missing | The entire left-sidebar visibility editor is gone |
| Sidebars > YT Music: upNextNotifications, suppressUpNextInFullscreen, audioQuality (Best/Medium/Low) | - | ❌ Missing | |
| Sidebars > Right Sidebar: 11 widget toggles (calendar/events/todo/notepad/calculator/sysmon/timer/openvpn/hosts/netmon/firewall) | - | ❌ Missing | The right-sidebar widget visibility editor is gone |
| Sidebars > Reddit: limit + subreddit chip editor | - | ❌ Missing | `cfg:sidebar.reddit.{limit,subreddits}` editor gone |
| Sidebars > Anime Schedule: showNsfw + watchSite | - | ❌ Missing | |
| Sidebars > Booru download paths (SFW + NSFW) | - | ❌ Missing | |
| Sidebars > Wallhaven: limit + API key (password) | - | ❌ Missing | |
| Sidebars > Quick toggles: style Classic/Android + columns | - | ❌ Missing | |
| Sidebars > Sliders: enable + brightness/volume/mic | - | ❌ Missing | |
| Sidebars > Corner open: 9 controls (enable, clickless, clicklessCornerEnd, verticalOffset, bottom, valueScroll, visualize, region width/height) | - | ❌ Missing | |
| Widgets > Visibility: 10 widget enable toggles | - | ❌ Missing | |
| Widgets > Visibility: Quick launch shortcuts editor (icon/name/cmd Repeater + drag handles + add/delete) | - | ❌ Missing | |
| Widgets > Layout: spacing | - | ❌ Missing | |
| Widgets > Crypto: refresh interval + coin chip editor with autocomplete | - | ❌ Missing | |
| Widgets > Wallpaper Picker: itemSize + showHeader | - | ❌ Missing | |
| Widgets > Glance Header: 3 toggles | - | ❌ Missing | |
| Widgets > Status Rings: 5 ring toggles | - | ❌ Missing | |
| Widgets > Controls Card: 8 toggles | - | ❌ Missing | |
| Overview: ~25 controls (enable, dashboard.* 5 toggles, centerIcons, showPreviews, activeScreenOnly, scale, rows, columns, backgroundBlur*, backgroundDim, scrimDim, respectBar, top/bottom margin, maxPanelWidthRatio, workspaceSpacing, windowTileMargin, iconMinSize, iconMaxSize, switchToWorkspaceOnOpen + index, scrollWorkspaceSteps, keepOverviewOpenOnWindowClick, closeAfterWindowMove, showWorkspaceNumbers, focusAnimation*) | Audio & Display > Display (3 toggles) | 🟡 Partial | New only has overview.enable, centerIcons, showPreviews. **~22 overview controls missing** |

### Legacy: `ToolsConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Recording: showOsd / recordingOsd.autoHide / showNotifications | - | ❌ Missing | |
| Quality preset | Tools > Recorder | ✅ Ported | |
| Acceleration mode (Auto/Prefer GPU/Software) | - | ❌ Missing | |
| Enable fallback switch | - | ❌ Missing | |
| Recording filename format | - | ❌ Missing | (capture format is ported, recording format is not) |
| Discord compression block: enabled + targetSizeMb + maxDimension + preset + audioBitrateKbps + onlyIfNeeded | Tools > Recorder (target size only) | 🟡 Partial | Missing: maxDimension, preset, audioBitrateKbps, onlyIfNeeded |
| Video custom subsection: codec / fps / bitrate / crf / preset / pixelFormat | Tools > Recorder (fps + codec) | 🟡 Partial | Missing: videoBitrateKbps, crf, preset, pixelFormat |
| Audio custom subsection: codec / bitrate / sampleRate / backend / source | - | ❌ Missing | |
| GPU hardware subsection: hardwareDevice / vaapiFilter | - | ❌ Missing | |
| Region selector hint targets (windows/layers/content) | - | ❌ Missing | |
| Google Lens selection style (Rectangular / Circle) | - | ❌ Missing | |
| Region selector screenshot name format | Tools > Capture | ✅ Ported | |
| Region selector borderSize / numSize | - | ❌ Missing | |
| Region selector rect.showAimLines | - | ❌ Missing | |
| Region selector circle.strokeWidth / .padding | - | ❌ Missing | |
| Crosshair overlay code editor (Valorant format) | - | ❌ Missing | |
| Overlay Discord launch command | Tools > Apps | ✅ Ported | |
| Overlay darkenScreen | Tools > Capture | ✅ Ported | |
| Overlay scrimDim, backgroundOpacity, openingZoomAnimation, animationDurationMs, scrimAnimationDurationMs | - | ❌ Missing | |
| OSD media-enabled + timeout | Notifications > OSD | ✅ Ported | |

### Legacy: `ServicesConfig.qml`

| Status | Notes |
|---|---|
| 🟡 Partial | Services is no longer embedded legacy QML. Native tabs cover Idle/Sleep, AI provider management, Music Recognition, Network/Search/Hotspot, Resources, Updates, Shell Updates, Weather, and Calendar Sync. Remaining work is parity polish for richer legacy status cards and edge-case provider/calendar flows. |

### Legacy: `AdvancedConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Color generation toggles (13) | Appearance > Templates + Advanced > Theme Targets (mostly) | 🟡 Partial | Missing or under-exposed: enableQtApps (only in Advanced grid), enableSpicetify, enablePearDesktop, enableZed, enableOpenCode, enableLazygit toggles |
| Cava: 11 detailed cava.* controls (colorSource, sensitivity, bars, framerate, stereo, waveOpacity, gradientCount, barWidth, barSpacing, foreground, background) | - | ❌ Missing | Entire Cava sub-section gone - `cfg:appearance.cava.*` only writable via raw config |
| Cava: "Reset to defaults" button | - | ❌ Missing | |
| Force dark mode in terminal | - | ❌ Missing | `cfg:appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode` not in new UI |
| Terminal: Harmony / Harmonize threshold / Foreground boost | Appearance > Templates (harmony only) | 🟡 Partial | Missing harmonizeThreshold and termFgBoost spinners |
| Resource Monitor: GPU monitoring | Audio & Display > Monitor | ✅ Ported | |

### Legacy: `CheatsheetConfig.qml`

| Status | Notes |
|---|---|
| ❌ Missing | New UI's Launcher > Shortcuts only has "Open overlay" and "Edit Niri keybinds" buttons (opens `70-binds.kdl` in terminal). **The full inline keybind editor is gone:** loaded/default status, per-category dynamic categories (Repeater over NiriKeybinds.enrichedCategories with auto-icon mapping), per-keybind edit form with key combo / action / options + conflict detection, per-keybind delete confirmation, add-keybind form, legacy Hyprland read-only fallback, save/remove/error feedback bar with auto-hide. Users can still edit shortcuts but only by hand-editing the KDL file. |

### Legacy: `ModulesConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| "Reset to defaults" button (restores enabledPanels to family defaults) | - | ❌ Missing | |
| Material (ii) / Waffle large-button family switcher | Panels & Modules > Panels (combo) | 🟡 Partial | New has a combo but doesn't reset enabledPanels to family defaults |
| Default Terminal preset buttons (Foot/Kitty/Ghostty/Alacritty/WezTerm/Konsole) | - | ❌ Missing | Single-click terminal preset switching is gone |
| Core (ii) modules: 7 toggles (iiBar, iiBackground, iiBackdrop, iiOverview, iiOverlay, iiSidebarLeft, iiSidebarRight) | Panels & Modules > Panels (9 toggles overlap) | 🟡 Partial | New is missing iiBackdrop, iiSidebarLeft, iiSidebarRight toggles |
| Feedback (ii): iiNotificationPopup, iiOnScreenDisplay, iiMediaControls | Panels & Modules > Panels | 🟡 Partial | Only iiNotificationPopup exposed |
| Utilities (ii): iiLock, iiPolkit, iiRegionSelector, iiWallpaperSelector, iiCheatsheet, iiOnScreenKeyboard, iiClipboard | Panels & Modules > Panels (only Clipboard) | 🟡 Partial | 6 of 7 missing |
| Optional (ii): iiDock, iiScreenCorners + Crosshair placeholder | Panels & Modules > Panels | 🟡 Partial | |
| Waffle Core: wBar, wBackground, wStartMenu, wActionCenter, wNotificationCenter, wNotificationPopup, wOnScreenDisplay, wWidgets | Panels & Modules > Waffle (6 toggles) | 🟡 Partial | Missing wBackground and wNotificationPopup, wOnScreenDisplay |
| Shared modules (Waffle support): full duplicate set | - | ❌ Missing | |
| Display scaling: UI scale 50–200% + reset button | General > Fonts (75–135%) | 🟡 Partial | New restricts the range and removes the reset-to-100% button |
| Wallpaper selector: coverflow / skew / system file picker | Wallpaper > Wallpaper (style combo) | 🟡 Partial | Missing skew view and useSystemFileDialog toggles |
| Settings UI: easyMode / overlayMode / overlay scrimDim / overlay backgroundOpacity / overlay enableBlur | General > Window (open mode only) | 🟡 Partial | None of the easy/overlay/overlay-appearance toggles are exposed |

### Legacy: `WaffleConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Wallpaper: useMainWallpaper / Pick main / Pick Waffle / hideWhenFullscreen / enableAnimation | - | ❌ Missing | `cfg:waffles.background.*` editors gone (waffles.background.{useMainWallpaper, wallpaperPath, hideWhenFullscreen, enableAnimation}) |
| Wallpaper effects: blur + dim + dynamicDim | - | ❌ Missing | `cfg:waffles.background.effects.*` gone |
| Backdrop (Niri overview): 10 controls (enable, enableAnimation, hideWallpaper, useMainWallpaper, Pick button, blurRadius, dim, saturation, contrast, vignette + intensity) | - | ❌ Missing | All `cfg:waffles.background.backdrop.*` gone |
| Taskbar: bottom / leftAlignApps / monochromeIcons / tintTrayIcons | - | ❌ Missing | All `cfg:waffles.bar.*` gone |
| Theming: useMaterialColors + font family combo (5 fixed + custom) + font.scale + reset | Panels & Modules > Waffle (useMaterialStyle only) | 🟡 Partial | |
| Behavior: allowMultiplePanels | - | ❌ Missing | |
| Family transition: animated transition | - | ❌ Missing | `cfg:familyTransitionAnimation` gone |
| Start Menu: size preset + text scale | - | ❌ Missing | |
| Tweaks: smootherMenuAnimations + switchHandlePositionFix | Panels & Modules > Waffle | ✅ Ported | |
| Calendar: force2CharDayOfWeek | - | ❌ Missing | |
| Alt+Tab: 13 controls (preset + 12 sub) | Panels & Modules > Waffle (3 toggles) | 🟡 Partial | Missing: preset combo, quickSwitch, autoHide, autoHideDelay, thumbnailWidth/Height, scrimOpacity, showOverviewWhileSwitching |
| Widgets Panel: 5 toggles (showDateTime/Weather/System/Media/QuickActions) | - | ❌ Missing | |

### Legacy: `NiriConfig.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Niri config status (custom config detection, overrides count, open folder/file, actionable file repeater with reasons) | - | ❌ Missing | The validation UI that warned about user overrides is gone |
| Displays: Resolution / Refresh / Scale / Rotation | Audio & Display > Display | ✅ Ported | |
| Displays: **Output position X/Y** (-10000..10000) | - | ❌ Missing | Cannot drag/place monitors in space from new UI |
| Displays: VRR | Audio & Display > Display | ✅ Ported | |
| Displays: monitor info (make/model/inches) | - | ❌ Missing | |
| Displays: **preview/confirm/revert flow** | - | ❌ Missing | "If display change breaks, revert in 15s" flow lost - high risk on bad mode change |
| Layout: gaps | - | ❌ Missing | `cfg:` equivalent absent from new UI |
| Layout: center-focused-column Never/Overflow/Always | - | ❌ Missing | |
| Layout: always-center-single-column | - | ❌ Missing | |
| Layout: auto-expand single tiling window | Panels & Modules > Compositor | ✅ Ported | |
| Layout: empty-workspace-above-first | - | ❌ Missing | |
| Layout: default-column-display normal/tabbed | - | ❌ Missing | |
| Layout: Border subsection (enabled/width/active/inactive/urgent colors) | - | ❌ Missing | All 5 border controls gone |
| Focus ring: width / colors / gradient | Audio & Display > Display | ✅ Ported | |
| Window shadow: enabled / softness / spread / offsetX/Y / color | - | ❌ Missing | `cfg:` shadow controls gone |
| Struts: Left/Right/Top/Bottom 0–512 | - | ❌ Missing | |
| Overview zoom 30–100% | - | ❌ Missing | `niri layout.overview.zoom` gone |
| Window rules: corner radius slider | - | ❌ Missing | `niri window-rules.corner-radius` gone |
| Window rules: inactive opacity slider | General > Quick Rice | ✅ Ported | |
| Window rules: clip windows to rounded geometry | - | ❌ Missing | |
| Keyboard: full layout list (12 presets + Custom) | Audio & Display > Input (raw text) | 🟡 Partial | New only has free-form text field; presets gone |
| Keyboard: numlock-on-startup | Audio & Display > Input | ✅ Ported | |
| Keyboard: track-layout Global/Per window | - | ❌ Missing | |
| Keyboard: variant TextField (e.g. colemak_dh) | - | ❌ Missing | |
| Keyboard: XKB options | Audio & Display > Input | ✅ Ported | |
| Keyboard: mod-key + mod-key-nested combos | - | ❌ Missing | `niri input.mod-key` and `mod-key-nested` not exposed |
| Keyboard: repeat-delay / repeat-rate | Audio & Display > Input | ✅ Ported | |
| Touchpad: 8 base switches | Audio & Display > Input (5 of 8) | 🟡 Partial | Missing: dwtp, left-handed, drag-lock |
| Touchpad: scroll-method (Two-finger/Edge/On button down/Disable) | - | ❌ Missing | |
| Touchpad: scroll-button-lock | - | ❌ Missing | |
| Touchpad: tap-button-map LRM/LMR | - | ❌ Missing | |
| Touchpad: click-method (Button areas/Clickfinger) | - | ❌ Missing | |
| Touchpad: speed slider -100..100 | Audio & Display > Input (via accel-speed) | 🟡 Partial | |
| Mouse: scroll-method + scroll-button-lock | - | ❌ Missing | |
| **Trackpoint: entire section** | - | ❌ Missing | `niri input.trackpoint.*` 6 controls gone (natural-scroll, left-handed, middle-emulation, accel-profile, scroll-method, scroll-button-lock, accel-speed) |
| Cursor: hide-cursor-when-typing | Audio & Display > Input | ✅ Ported | |
| General input: power-key / workspace-back-forth / warp-pointer / focus-follows-mouse | Audio & Display > Input | ✅ Ported | |
| Animations: enabled + global slowdown 50–500% | Appearance > Motion (scale slider) | 🟡 Partial | Slowdown semantic differs |
| **Animations: per-type Repeater** (11 animation types with damping-ratio + stiffness sliders) | - | ❌ Missing | Per-animation tuning for workspace-switch, window-open, window-close, horizontal-view-movement, window-movement, window-resize, config-notification-open-close, exit-confirmation-open-close, screenshot-ui-open, overview-open-close, recent-windows-close - **none of these are exposed** |
| Applications: per-slot Repeater (preset + custom command + current command display) | Tools > Apps | 🟡 Partial | New has a Repeater but the legacy view also shows current resolved command in monospace |

### Legacy: `LoginScreenConfig.qml`

| Status | Notes |
|---|---|
| ❌ Missing | New UI's Advanced > Login only has 2 buttons: "Apply ii-pixel" and "Open qylock folder", plus path labels. **The full provider experience is gone:** active SDDM theme banner, ii-pixel hero card with MIT license + 1 clickable theme tile, qylock hero card with status pill (Installed/Not installed) + GPL-3.0 license + dynamic theme tile grid of 20 qylock themes (dog-samurai, enfield, forest, Genshin, last-of-us, minecraft, nier-automata, ninja_gaiden, osu, pixel-coffee, pixel-dusk-city, pixel-hollowknight, pixel-munchlax, pixel-night-city, pixel-rainyroom, R1999_1, R1999_2, windows_7, winter, wuwa), Install / Update / Uninstall (with confirm dialog) buttons, working-status progress bar, toast notifications. |

### Legacy: `ExtrasConfig.qml`

| Status | Notes |
|---|---|
| 🧱 Embedded | Reachable via Extras tab. Package manager buttons (Open GPK + Install/Uninstall/Update/Outdated/Search Arch/Search AUR) + dynamic profile Repeater (each card with name/desc/icon/tags + 4 package lists + status badge + Install/Re-run) work. **TODO: native reskin.** |

### Legacy theme editors

| File | Status | Notes |
|---|---|---|
| `AngelStyleEditor.qml` | ❌ Missing | Not reachable from new UI. 4 presets + named-profile manager + ~40 sliders (color strength, blur, transparency, escalonado offsets, escalonado shadow incl. glass blur/overlay, partial border + accent + inset glow, surface borders, glow, rounding) - **all gone**. Angel users will not be able to tune their style. |
| `AuroraStyleEditor.qml` | ❌ Missing | Not reachable from new UI. 4 presets + Quick Save/Load + Reset + 5 transparency sliders (panel/cards/popup/tooltip/layer surface) - **all gone**. |
| `CustomThemeEditor.qml` | ❌ Missing | Not reachable from new UI. Live preview + Dark/Light segment + global adjustments (saturation/brightness/temperature + reset) + color harmony schemes (Complementary/Analogous/Triadic/Split + apply) + 13-preset dropdown (Angel Dark/Light, Gruvbox Material, Catppuccin Mocha/Latte, Nord, Material Black, Kanagawa, Kanagawa Dragon, Samurai, Tokyo Night, Sakura, Zen Garden) + Export/Import dialogs + Save/Load to `~/.config/illogical-impulse/themes/` + 6 palette cards (Accent / Secondary / Tertiary / Backgrounds / Borders & Shadows / Status) with ~24 individual color pickers and WCAG contrast badges + collapsible Surface Containers (8 colors) - **users on a custom theme have no edit UI**. |
| `GowallWallpaperEditor.qml` | ❌ Missing | Not reachable from new UI. Source picker + 5 operation tabs (Recolor / Effects / Invert / Pixelate / Upscale) + theme selector + custom palette editor + upscale model picker (3 models) + 4 effect modes + brightness slider + pixelation slider + output format selector (PNG/WebP/JPG) + Preview/Apply buttons + side-by-side comparison + Extract Colors palette extractor - **users cannot reach the gowall wallpaper recoloring tool**. |

### Legacy: `About.qml`

| Legacy section | New surface | Status | Notes |
|---|---|---|---|
| Ryoku hero card (icon, version, branch badge, GitHub link, tagline, Docs/Issues/Check-Updates/Update-Available buttons, easter-egg avatar click) | About page | ✅ Ported | Missing: easter-egg celebration animation, branch badge color logic on non-main branches |
| System Info card (distro icon, name, URL link, Docs button, Report-bug button) | About page | 🟡 Partial | Distro icon (colorized to primary) and Docs/Report-bug buttons not exposed |
| Credit cards × 4 | About page | ✅ Ported | |

---

## High-priority remaining legacy coverage (prioritized)

Ordered roughly by user-visible impact:

### P0 - Editor flows users will miss the most
1. **Theme editors** - Angel / Aurora / Custom Theme / Gowall Wallpaper editors are completely unreachable from the new UI. If a user picks the "custom" theme they have no way to edit the colors. Angel-style users cannot tune escalonado / shadow / blur.
2. **Keybind editor** (CheatsheetConfig) - full conflict detection, add/edit/remove flow, and load-status feedback are gone.
3. **Login screen provider experience** (LoginScreenConfig) - qylock theme cards, install/update/uninstall flow, active-theme indicator, progress bar.

### P1 - Frequently-used controls that vanished
4. **Niri display safety** - preview confirm + revert timer + output X/Y position + custom config validation status.
5. **Niri animation per-type tuning** - 11 animation types with damping/stiffness sliders all gone.
6. **Niri layout details** - gaps, border, shadow, struts, overview zoom, window-rules corner radius and clip-to-geometry.
7. **Lock screen full block** - only 6 of ~25 GeneralConfig lock controls ported (no notifications, clock position, status indicators, varying shapes, animated GIF wallpapers, dim amount, blur radius, extra zoom, widget toggles).
8. **Battery block** - low/critical/full thresholds, automatic suspend %, charge limit all gone.
9. **Sidebars** - left sidebar module visibility, right sidebar widget visibility (11 widgets), Reddit/Wallhaven/YT Music/Anime Schedule/Booru/Crypto editors, Quick launch shortcuts editor, Glance Header, Status Rings, Controls Card - entire InterfaceConfig sidebars region is unreachable.
10. **Overview tuning** - ~22 of ~25 overview controls missing (rows/columns/scale/blur/dim/margins/icon sizes/animation/switchToWorkspaceOnOpen).
11. **Recorder advanced** - codec/bitrate/CRF/preset/pixel format/audio source/audio backend/hardware device/VAAPI filter all gone for Custom preset users.

### P2 - Useful but lower priority
12. **Bar details** - workspaces sub-block (number style, scrollBehavior, app icons, dynamicCount, perMonitor, etc.), tray block, utility buttons block, vignette, scroll actions, custom bar rounding.
13. **GeneralConfig misc** - Time format / date format / second precision, Keyboard popup + panel indicators (8 toggles), Policies (AI/Weeb), Work Safety, Sounds (battery/timer/pomodoro), Per-monitor bar/dock visibility.
14. **ThemesConfig misc** - Soften colors, dynamic tag filters, dominant color swatches, font preset quick buttons, variable axes spinners, icon theme selectors, Apply-to-open-terminals button, terminal install detection.
15. **ModulesConfig "Reset to defaults" + terminal preset buttons.**
16. **Waffle full coverage** - wallpaper, effects, backdrop, taskbar, behavior, start menu, calendar, alt-tab preset & details, widgets panel.
17. **Quick UX features in the entrypoint** - Easy/Advanced mode toggle, lock button in titlebar, Ctrl+F shortcut, Ctrl+Tab page cycling, FAB "Config file" with right-click-copy, overlay mode toggle at nav rail bottom.

### Reskinning (already reachable but visually legacy)
- Wallpaper > Background Controls - reskin BackgroundConfig.qml card-by-card.
- Wallpaper > Widget Controls - reskin DesktopWidgetsConfig.qml card-by-card.
- Extras - reskin ExtrasConfig.qml profile cards.

---

## Guardrails

- **Do not remove** any legacy reference file until every setting in the matrix
  above has either ✅ Ported or 🧱 Embedded status, with the embedded ones also
  reskinned.
- Friendly pages stay task-focused; raw paths belong in **Advanced > Inspector**.
- Settings that write external files must keep using the existing service/helper
  APIs (`scripts/niri-config.py`, `KeyringStorage`, `pkexec ryoku-*`) rather than
  inline `Process` writes.
- When porting a Niri-backed setting, keep the same backend (`niri-config.py`)
  used by the legacy module to avoid divergence.
- For multi-step flows (install/uninstall, preview/confirm/revert,
  fetch-and-validate) preserve **both** the progress feedback and the
  cancel/revert affordance - don't ship a one-shot button where the legacy had
  safety rails.
