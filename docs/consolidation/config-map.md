# Stage 0 Inventory: Config Key Map (`Settings.data.*` + dashboard store)

**Scope:** every runtime config key that lives **outside** the typed `GlobalConfig`
(C++ `Ryoku.Config`, persisted `~/.config/ryoku/shell.json`). Non-destructive
inventory + proposed target only. No code changed.

## Method & totals

- Source of truth for the key set: `shell/settingsgui/Assets/settings-default.json`
  (the full default tree, 24 top-level domains).
- Reference census across `shell/**/*.{qml,js}` (regex `Settings\.data\.<path>`):
  - **1335** total `Settings.data.*` occurrences
  - **309** distinct ref-paths → **308 real** (`xxx.yyy` at
    `shell/settingsgui/Commons/Settings.qml:27` is a doc-comment example, not a key)
  - spanning **24** config domains.
- `Settings.data` is the alias for the settings-gui `JsonAdapter`
  (`shell/settingsgui/Commons/Settings.qml:27`, `settingsVersion: 59`), persisted to
  the settings-gui store (NOT `shell.json`).

### Critical finding: where the readers live

The **entire active ryoku bar + modules + services are bundled *inside*
`shell/settingsgui/`** (`Modules/Bar/`, `Commons/Style.qml`, `Commons/Color.qml`,
`Services/`). So almost every `Settings.data.*` reader is *inside* settingsgui.
Genuine live-shell consumers **outside** `shell/settingsgui/` are only **two files /
6 refs**:

| Domain | Outside-settingsgui live reader (path:line) |
|---|---|
| wallpaper | `shell/modules/WallpaperRotation.qml:10,34,51,52` |
| clipboard | `shell/modules/ClipboardMaintenance.qml:12,17` |

Everything else is read only by settings-gui-bundled QML. This makes most domains
"internal to the settings-gui surface", the consolidation is mostly about *re-homing
the schema*, not chasing scattered readers.

---

## A. settings-gui store (`Settings.data.*`): per-domain map

Counts: `#keys` = distinct ref-paths in that domain; `#wr` = write-ref count
(`Settings.data.x = …`); inside-readers are all under `shell/settingsgui/`.

| Domain | #keys | #wr | Sample write site(s) `path:line` | Live reader(s) **outside** settingsgui | GlobalConfig equivalent? | Proposed target |
|---|---|---|---|---|---|---|
| **bar** | 41 | 12 | `…/Tabs/Bar/*` widget toggles; `Modules/Bar/Widgets/AudioVisualizer.qml:149,172` (visualizerType lives in audio) | none (all readers in `settingsgui/Modules/Bar`, `Commons/Style.qml:44-218`, `Bar.qml`) | **partial**, `GlobalConfig.bar` exists but models a *different* (end-4) bar: `design/edge/entries/workspaces/tray/status/clock/topNotch` (`barconfig.hpp`). No 1:1 with Noctalia `barType/position/density/widgets/capsule*/margin*/scroll`. | `GlobalConfig.bar` (schema must absorb Noctalia keys) |
| **wallpaper** | 38 | 38 | `…/Tabs/Wallpaper/AutomationSubTab.qml:21,44,60`, `GeneralSubTab.qml:111` | **`shell/modules/WallpaperRotation.qml:10,34,51,52`** | **no** (only `background.wallpaperEnabled` overlaps, `backgroundconfig.hpp:126`) | new `GlobalConfig.wallpaper` section |
| **dock** | 32 | 15 | `…/Tabs/Dock/*SubTab.qml` | none | **no** | new `GlobalConfig.dock` section |
| **appLauncher** | 27 | 2 | `…/Tabs/Launcher/*`; clipboard sub-keys live here too | none | **partial**, `GlobalConfig.launcher` (`enabled/useVicinae/useFuzzy/prefixes/maxShown`, `launcherconfig.hpp`) | `GlobalConfig.launcher` (extend) |
| **general** | 25 | 5 | `…/Tabs/General/*`, `…/LockScreen/*` | none (read by `Commons/Style.qml:44,80,81`, `Commons/I18n.qml:127,129,167`) | **partial**, `general.reverseScroll`/`logo` (`generalconfig.hpp:108,111`); lock-screen keys → `LockConfig`; ratios/shadows → `appearance` | split: `GlobalConfig.general` + `GlobalConfig.lock` + `GlobalConfig.appearance` |
| **systemMonitor** | 22 | 31 | `…/Tabs/SystemMonitor/ThresholdsSubTab.qml:55-302`, `GeneralSubTab.qml:20-102` | none | **no** (dashboard `DashboardPerformance` toggles only, `dashboardconfig.hpp`) | new `GlobalConfig.systemMonitor` |
| **location** | 14 | 1 | `…/Tabs/General/` weather/calendar toggles | none | **partial**, `services.weatherLocation/useFahrenheit/useTwelveHourClock` (`serviceconfig.hpp:16-25`) | `GlobalConfig.services` (+ new weather/calendar) |
| **ui** | 12 | 1 | `…/Tabs/General/UISubTab` | none (read by `Commons/Style.qml:74,155`, `Color.qml:126,128`) | **partial**, `appearance.font.family.sans/mono` (`appearanceconfig.hpp:113-114`), `appearance.transparency.*` (`:227-229`) | `GlobalConfig.appearance` |
| **audio** | 9 | 2 | `Modules/Bar/Widgets/AudioVisualizer.qml:149,172` | none | **partial**, `services.maxVolume/audioIncrement/defaultPlayer/playerAliases/visualiser*` (`serviceconfig.hpp`) | `GlobalConfig.services` |
| **network** | 9 | 10 | `…/Tabs/Connections/BluetoothSubTab.qml:351-353` | none | **no** | new `GlobalConfig.network` |
| **sessionMenu** | 9 | 0 | (read-only in UI; defaults seeded) | none | **partial**, `GlobalConfig.session` (`enabled/dragThreshold/vimKeybinds/icons/commands`, `sessionconfig.hpp`); differs (countdown/powerOptions/largeButtons) | `GlobalConfig.session` (extend) |
| **colorSchemes** | 8 | 17 | `Modules/Bar/Widgets/DarkMode.qml:39`, `…/Tabs/ColorScheme/*` | none (token live-system is `services/Colours.qml`) | **partial**, `services.smartScheme` (`serviceconfig.hpp:40`) | new `GlobalConfig.colorScheme` + bind `Colours.qml` |
| **controlCenter** | 8 | 0 | (defaults/cards seeded) | none | **no**, `ControlCenterConfig` is *empty by design* (`controlcenterconfig.hpp:7-8`) | populate `GlobalConfig.controlCenter` |
| **nightLight** | 8 | 22 | `Modules/Bar/Widgets/NightLight.qml:56-61`, `…/Tabs/` | none | **no** (only `gameMode.nightLightOff` toggle, `gamemodeconfig.hpp:18`) | new `GlobalConfig.nightLight` |
| **idle** | 8 | 0 | (defaults seeded) | none (live shell already uses GlobalConfig, see below) | **DUPLICATE**, `GlobalConfig.general.idle` is the live source (`generalconfig.hpp:27-64`), read by `shell/modules/IdleMonitors.qml` | `GlobalConfig.general.idle` (drop `Settings.data.idle`) |
| **notifications** | 7 | 0 | (defaults seeded) | none | **partial**, `GlobalConfig.notifs` (`expire/fullscreen/timeouts/actionOnClick`, `notifsconfig.hpp`); differs (per-urgency duration, sounds) | `GlobalConfig.notifs` (extend) |
| **osd** | 7 | 0 | (defaults seeded) | none | **partial**, `GlobalConfig.osd` (`enabled/hideDelay/enableBrightness/enableMicrophone`, `osdconfig.hpp`) | `GlobalConfig.osd` (extend) |
| **brightness** | 6 | 1 | `Modules/Bar/Widgets/Brightness.qml` | none | **partial**, `services.brightnessDdc/EnforceMin/Increment` (`serviceconfig.hpp:33-38`) | `GlobalConfig.services` |
| **clipboard** | 4 | 3 | `…/Tabs/Launcher/ClipboardSubTab.qml:31,45,69` | **`shell/modules/ClipboardMaintenance.qml:12,17`** | **no** | new `GlobalConfig.clipboard` (or `launcher.clipboard`) |
| **desktopWidgets** | 4 | 7 | `Modules/DesktopWidgets/DraggableDesktopWidget.qml:169,193,217`, `Services/Platform/PluginService.qml:1471` | none | **partial/DUPLICATE**, `GlobalConfig.background.widgets` + `DesktopClock` (`backgroundconfig.hpp:63-137`) | `GlobalConfig.background.widgets` |
| **templates** | 4 | 2 | `…/Tabs/ColorScheme/TemplatesSubTab.qml:167,293` | none | **no** | new `GlobalConfig` theming/templates section |
| **performanceMode** | 2 | 2 | `…/Tabs/SystemMonitor/PerformanceSubTab.qml:18,27` | none | **partial**, `gameMode.pauseWallpaper` (`gamemodeconfig.hpp:19`) | fold into `GlobalConfig.gameMode` |
| **plugins** | 2 | 2 | `…/Tabs/Plugins/InstalledSubTab.qml:37,44` | none | **no** | new `GlobalConfig.plugins` |
| **hooks** | 1* | 0 | (object read; `hooks.*` accessed dynamically, 18 reads) | none | **no** | new `GlobalConfig.hooks` |
| **calendar** | 1* | 0 | (`calendar.cards` array) | none | **no** | new `GlobalConfig` calendar section |

`*` accessed mostly as a whole object rather than per-leaf, so the distinct-ref count
understates leaf keys (see `settings-default.json` for the full leaf set, e.g. `hooks`
has 10 leaves, `calendar.cards` is an array).

**GlobalConfig top-level sections available as targets** (`config.hpp:53-72`):
`appearance, general, background, bar, border, dashboard, gaming, gameMode,
controlCenter(empty), launcher, notifs, osd, session, winfo, lock, utilities,
sidebar, services, paths`.

---

## B. dashboard store (`qs.dashboard` `Config` singleton)

A **third, independent** config system: `shell/dashboard/config/Config.qml`
(`pragma Singleton`), *not* `Settings.data`, *not* `GlobalConfig`.

- **On disk:** one JSON file per module under
  `${XDG_CONFIG_HOME:-~/.config}/ryoku/dashboard/` (`Config.qml:26`), seeded from
  the preset dir (`Config.qml:48-66`). Legacy `hyprland.json` auto-migrates to
  `compositor.json` (`Config.qml:68-72`).
- **Modules (FileView + JsonAdapter, one per file):** `theme, bar, workspaces,
  overview, notch, compositor, performance, weather, desktop, lockscreen, prefix,
  system` (`Config.qml:10-44`).
- **Key sets** live in `shell/dashboard/config/defaults/*.js` and the inline
  `JsonAdapter` blocks. Examples:
  - `theme.*` (`defaults/theme.js`, ~343 lines): `oledMode, lightMode, roundness,
    font, fontSize, monoFont, monoFontSize, tintIcons, enableCorners, animDuration,
    shadow{Opacity,Color,XOffset,YOffset,Blur}`, plus ~20 `sr*` styled-rect gradient
    objects (`srBg, srPopup, srPane, srPrimary, …`).
  - `bar.*` (`defaults/bar.js`): `position, launcherIcon, launcherIconTint,
    pillStyle, screenList, enableFirefoxPlayer, barColor, frameEnabled,
    frameThickness, pinnedOnStartup, hoverToReveal, hoverRegionHeight, showPinButton,
    availableOnFullscreen, use12hFormat, containBar, keepBar{Shadow,Border}`.
  - `performance.*`: `dashboardPersistTabs, dashboardMaxPersistentTabs, wavyLine,
    rotateCoverArt` (read at `modules/widgets/dashboard/Dashboard.qml:57,58,71`,
    `modules/widgets/FullPlayer.qml:202,254,269`).
  - `weather.unit` (read `modules/services/WeatherService.qml:459`,
    `widgets/WeatherWidget.qml:818`).
- **Readers:** all within `shell/dashboard/**`, e.g. theme generators
  (`modules/theme/{Discord,Gtk,Kitty,QtCt}Generator.qml`, `Styling.qml:13-75`),
  `components/{Shadow,SearchInput,StyledToolTip}.qml`, clipboard/calendar/media
  widgets. No dashboard `Config.*` reads leak outside `shell/dashboard/`.

**Duplication vs. the other two stores:**

| dashboard key(s) | duplicated by |
|---|---|
| `theme.font/fontSize/monoFont/monoFontSize/roundness/animDuration` | `GlobalConfig.appearance.font.*` + `appearance.rounding/anim` **and** `Settings.data.ui.fontDefault/fontFixed` + `Settings.data.general.*RadiusRatio/animationSpeed` |
| `theme.shadow*` | `Settings.data.general.enableShadows/shadowOffsetX/shadowOffsetY` |
| `theme.lightMode/oledMode` | `Settings.data.colorSchemes.darkMode` |
| `theme.sr*` styled-rect gradients | `Ryoku.Config` Tokens / `services/Colours.qml` palette (design-token axis) |
| `bar.position/frame*/use12hFormat` | `Settings.data.bar.position/frameThickness/...` **and** `GlobalConfig.bar` |
| `weather.unit` | `Settings.data.location.useFahrenheit` + `GlobalConfig.services.useFahrenheit` |
| `performance.*` | overlaps `GlobalConfig.dashboard.*` (`dashboardconfig.hpp`) |

→ The dashboard store is the **most redundant** of the three: its `theme.*` block
triple-overlaps appearance tokens, and `bar.*`/`weather.*` overlap both other stores.

---

## Recommendation: smallest-blast-radius domain to migrate first

**Migrate `clipboard` first.**

Rationale (matches the rubric: fewest write sites + a single clear live reader):
- **4 keys** total (`clipboard.enabled`, `clipboard.maxEntries`,
  `clipboard.autoCleanup`, + the bare-object read).
- **3 write sites, all in one file:**
  `shell/settingsgui/Modules/Panels/Settings/Tabs/Launcher/ClipboardSubTab.qml:31,45,69`.
- **Exactly one live reader outside settingsgui:**
  `shell/modules/ClipboardMaintenance.qml:12,17` (`readonly property var cfg:
  Settings.data.clipboard`). That single binding is the only cross-surface coupling -
  trivial to repoint at a new `GlobalConfig.clipboard` section.
- **No GlobalConfig overlap** to reconcile, so it is a clean *add-section + repoint
  one binding* migration with no schema-merge conflicts.

Runner-up: `performanceMode` (2 keys, 2 writes in one file, 0 outside readers), even
smaller, but it has a partial `gameMode` overlap to decide, so it is a *merge*
decision rather than a clean add. `idle` is a special case: it is already
**duplicated** by `GlobalConfig.general.idle` (the live `IdleMonitors.qml` reads the
typed config), so its `Settings.data.idle` copy can likely be *deleted* rather than
migrated, flag for the manager.

> Sequencing/cross-axis decisions (e.g. whether dashboard `theme.*` folds into
> appearance tokens vs. `Settings.data.ui`) are left to Main.
