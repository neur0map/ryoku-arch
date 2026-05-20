# Bar Rework Map

This is the working inventory for a full Ryoku bar rework. It includes the
classic ii bar, ii vertical bar, Waffle taskbar, bar settings, config keys,
runtime installation paths, IPC, keybinds, services, tests, and documentation
that can affect bar behavior or user-facing bar settings.

Use this as the removal/rebuild checklist. If a file is removed or a setting is
renamed, update every connected file in the matching section so no old behavior
keeps writing stale config or expecting removed UI.

## Runtime Note

Repo files are not always the live shell files. Before testing visible changes,
identify the active Quickshell instance and config path:

```bash
qs list --all
```

Expected live/runtime locations that can matter during a bar rework:

- `~/.config/quickshell/ryoku-shell`
- `~/.local/share/ryoku`
- `~/.config/ryoku-shell/config.json`
- `~/.config/quickshell/ryoku-shell/version.json`

## Current Bar Families

- Classic ii horizontal bar: `shell/ShellIiPanels.qml` -> `shell/modules/bar/Bar.qml` -> `shell/modules/bar/BarContent.qml`
- Classic ii vertical bar: `shell/ShellIiPanels.qml` -> `shell/modules/verticalBar/VerticalBar.qml` -> `shell/modules/verticalBar/VerticalBarContent.qml`
- Waffle taskbar: `shell/ShellWafflePanels.qml` -> `shell/modules/waffle/bar/WaffleBar.qml` -> `shell/modules/waffle/bar/WaffleBarContent.qml`
- Tools mode: `shell/shell.qml` -> `shell/modules/bar/ToolsModePanel.qml` -> `shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml`

Direct renderer roots:

- `shell/modules/bar`
- `shell/modules/verticalBar`
- `shell/modules/waffle/bar`

## Entrypoints And Loaders

| File | Connection |
| --- | --- |
| `shell/shell.qml` | Main shell entry. Chooses `ShellIiPanels` or `ShellWafflePanels` from `panelFamily`, mounts `ToolsModePanel`, starts bar-related services, and exposes IPC for panel family changes. |
| `shell/ShellIiPanels.qml` | Loads `iiBar` when `bar.vertical` is false and `iiVerticalBar` when `bar.vertical` is true. Gates both through `enabledPanels`. |
| `shell/ShellWafflePanels.qml` | Loads `wBar` for the Waffle taskbar. |
| `shell/GlobalStates.qml` | Shared runtime state: `barOpen`, `toolsModeOpen`, sidebars, control center, overview, workspace numbers, and Waffle popup states. |
| `shell/FamilyTransitionOverlay.qml` | Panel-family transition overlay. It is not a bar renderer, but uses layer-shell/exclusive-zone behavior and is part of the ii/Waffle family switch path. |
| `shell/modules/common/Config.qml` | Config schema and defaults exposed to QML. The `bar` block is the central source for classic bar settings. |
| `shell/modules/common/Persistent.qml` | Persistent runtime state, including the old `bar.utilButtons.*` to `bar.dynamicIsland.tools.buttons.*` migration marker. |
| `shell/defaults/config.json` | Shipped config defaults. Contains `bar.*`, `waffles.bar.*`, `enabledPanels`, `panelFamily`, and adjacent settings. |
| `default/ryoku-shell/config-overrides.json` | Ryoku branding/default overlay. Currently bar-adjacent because it can override shipped shell defaults. |

## Config Keys

Primary classic bar keys in `shell/defaults/config.json` and
`shell/modules/common/Config.qml`:

- `bar.autoHide.enable`
- `bar.autoHide.hoverRegionWidth`
- `bar.autoHide.pushWindows`
- `bar.autoHide.showWhenPressingSuper.enable`
- `bar.autoHide.showWhenPressingSuper.delay`
- `bar.bottom`
- `bar.vertical`
- `bar.borderless`
- `bar.cornerStyle`
- `bar.customRounding`
- `bar.floatStyleShadow`
- `bar.showBackground`
- `bar.showScrollHints`
- `bar.leftScrollAction`
- `bar.rightScrollAction`
- `bar.topLeftIcon`
- `bar.verbose`
- `bar.screenList`
- `bar.modules.leftSidebarButton`
- `bar.modules.activeWindow`
- `bar.modules.resources`
- `bar.modules.media`
- `bar.modules.workspaces`
- `bar.modules.clock`
- `bar.modules.utilButtons`
- `bar.modules.battery`
- `bar.modules.rightSidebarButton`
- `bar.modules.sysTray`
- `bar.modules.secPulse`
- `bar.modules.weather`
- `bar.modules.taskbar`
- `bar.modules.kanjiClock`
- `bar.modules.dateLabel`
- `bar.modules.weatherIcon`
- `bar.modulesLayout.order`
- `bar.modulesPlacement.resources`
- `bar.modulesPlacement.media`
- `bar.modulesPlacement.workspaces`
- `bar.modulesPlacement.clock`
- `bar.modulesPlacement.utilButtons`
- `bar.modulesPlacement.battery`
- `bar.edgeModulesLayout.leftOrder`
- `bar.edgeModulesLayout.rightOrder`
- `bar.resources.showMemoryIndicator`
- `bar.resources.showSwapIndicator`
- `bar.resources.showTempIndicator`
- `bar.resources.showCpuIndicator`
- `bar.resources.showGpuIndicator`
- `bar.resources.alwaysShowCpu`
- `bar.resources.alwaysShowGpu`
- `bar.resources.alwaysShowSwap`
- `bar.resources.alwaysShowTemp`
- `bar.resources.tempCautionThreshold`
- `bar.resources.tempWarningThreshold`
- `bar.resources.cpuWarningThreshold`
- `bar.resources.gpuWarningThreshold`
- `bar.resources.memoryWarningThreshold`
- `bar.resources.swapWarningThreshold`
- `bar.dynamicIsland.enabled`
- `bar.dynamicIsland.musicPopupContinuous`
- `bar.dynamicIsland.tools.enabled`
- `bar.dynamicIsland.tools.keybind`
- `bar.dynamicIsland.tools.order`
- `bar.dynamicIsland.tools.buttons.screenshot`
- `bar.dynamicIsland.tools.buttons.record`
- `bar.dynamicIsland.tools.buttons.lens`
- `bar.dynamicIsland.tools.buttons.colorPicker`
- `bar.dynamicIsland.tools.buttons.musicRecognize`
- `bar.dynamicIsland.tools.buttons.micToggle`
- `bar.dynamicIsland.tools.buttons.osk`
- `bar.dynamicIsland.tools.buttons.caffeine`
- `bar.dynamicIsland.tools.buttons.notepad`
- `bar.dynamicIsland.tools.buttons.screenCast`
- `bar.dynamicIsland.tools.buttons.darkMode`
- `bar.dynamicIsland.tools.buttons.powerProfile`
- `bar.dynamicIsland.tools.autoCloseAfterAction`
- `bar.dynamicIsland.tools.closeOnEsc`
- `bar.utilButtons.showScreenSnip`
- `bar.utilButtons.showScreenRecord`
- `bar.utilButtons.showColorPicker`
- `bar.utilButtons.showMicToggle`
- `bar.utilButtons.showKeyboardToggle`
- `bar.utilButtons.showKeyboardLayoutSwitch`
- `bar.utilButtons.showDarkModeToggle`
- `bar.utilButtons.showPerformanceProfileToggle`
- `bar.utilButtons.showScreenCast`
- `bar.utilButtons.screenCastOutput`
- `bar.utilButtons.showNotepad`
- `bar.kanjiClock.showDate`
- `bar.kanjiClock.useKanjiDigits`
- `bar.tray.monochromeIcons`
- `bar.tray.showItemId`
- `bar.tray.invertPinnedItems`
- `bar.tray.pinnedItems`
- `bar.tray.filterPassive`
- `bar.workspaces.scrollBehavior`
- `bar.workspaces.invertScroll`
- `bar.workspaces.monochromeIcons`
- `bar.workspaces.dynamicCount`
- `bar.workspaces.shown`
- `bar.workspaces.wrapAround`
- `bar.workspaces.scrollSteps`
- `bar.workspaces.showAppIcons`
- `bar.workspaces.alwaysShowNumbers`
- `bar.workspaces.showNumberDelay`
- `bar.workspaces.numberMap`
- `bar.workspaces.useNerdFont`
- `bar.workspaces.perMonitor`
- `bar.weather.enable`
- `bar.weather.useUSCS`
- `bar.weather.enableGPS`
- `bar.weather.city`
- `bar.weather.manualLat`
- `bar.weather.manualLon`
- `bar.weather.fetchInterval`
- `bar.vignette.enabled`
- `bar.vignette.intensity`
- `bar.vignette.radius`
- `bar.blurBackground.enabled`
- `bar.blurBackground.overlayOpacity`
- `bar.indicators.notifications.showUnreadCount`

Waffle taskbar keys:

- `waffles.bar.bottom`
- `waffles.bar.leftAlignApps`
- `waffles.bar.monochromeIcons`
- `waffles.bar.tintTrayIcons`
- `waffles.bar.iconSize`
- `waffles.bar.searchIconSize`
- `waffles.bar.activationWatermark.enable`
- `waffles.bar.desktopPeek.hoverPeek`
- `waffles.bar.desktopPeek.hoverDelay`
- `waffles.bar.notifications.showUnreadCount`

Waffle taskbar-adjacent keys:

- `waffles.settings.useMaterialStyle`
- `waffles.modules.sidebarLeft`
- `waffles.modules.sidebarRight`
- `waffles.modules.dock`
- `waffles.modules.mediaControls`
- `waffles.modules.screenCorners`
- `waffles.modules.widgets`
- `waffles.notifications.showUnreadCount`
- `waffles.background.wallpaperPath`
- `waffles.background.thumbnailPath`
- `waffles.background.useMainWallpaper`
- `waffles.background.enableAnimation`
- `waffles.background.hideWhenFullscreen`
- `waffles.background.transition.*`
- `waffles.background.effects.*`
- `waffles.background.backdrop.*`
- `waffles.background.parallax.*`
- `waffles.background.widgets.clock.*`
- `waffles.actionCenter.toggles`
- `waffles.calendar.force2CharDayOfWeek`
- `waffles.calendar.locale`
- `waffles.theming.useMaterialColors`
- `waffles.theming.font.*`
- `waffles.behavior.allowMultiplePanels`
- `waffles.startMenu.sizePreset`
- `waffles.startMenu.scale`
- `waffles.widgetsPanel.showDateTime`
- `waffles.widgetsPanel.showWeather`
- `waffles.widgetsPanel.weatherHideLocation`
- `waffles.widgetsPanel.showSystem`
- `waffles.widgetsPanel.showMedia`
- `waffles.widgetsPanel.showQuickActions`
- `waffles.widgetsPanel.quickActions`
- `waffles.widgetsPanel.showFiles`
- `waffles.widgetsPanel.showTerminal`
- `waffles.widgetsPanel.showSettings`
- `waffles.widgetsPanel.showWallpaper`
- `waffles.widgetsPanel.showScreenshot`
- `waffles.widgetsPanel.showScreenRecord`
- `waffles.widgetsPanel.showSession`
- `waffles.widgetsPanel.showColorScheme`
- `waffles.workspaceNames`
- `waffles.taskView.mode`
- `waffles.taskView.closeOnSelect`

Panel family keys:

- `panelFamily`
- `enabledPanels`
- `knownPanels`
- `familyTransitionAnimation`

Bar-adjacent config groups:

- `appearance.globalStyle`
- `appearance.globalStyleCornerStyles.*`
- `appearance.transparency.*`
- `appearance.typography.*`
- `appearance.shellScale`
- `appearance.iconTheme`
- `dock.*`
- `sidebar.*`
- `controlPanel.*`
- `settingsUi.*`
- `overview.respectBar`
- `resources.updateInterval`
- `resources.monitorGpu`
- `media.popupMode`
- `battery.*`
- `time.*`
- `updates.*`
- `shellUpdates.*`
- `notifications.edgeMargin`
- `notifications.maxPopupLifetime`
- `notifications.position`
- `notifications.timeout`
- `notifications.timeoutCritical`
- `notifications.timeoutLow`
- `notifications.timeoutNormal`
- `notifications.silent`
- `notifications.scaleOnHover`
- `notifications.useLegacyCounter`
- `notifications.ignoreAppTimeout`
- `keyboardIndicators.showPopup`
- `keyboardIndicators.showPanel`
- `keyboardIndicators.popup.layout`
- `keyboardIndicators.popup.caps`
- `keyboardIndicators.popup.num`
- `keyboardIndicators.panel.layout`
- `keyboardIndicators.panel.caps`
- `keyboardIndicators.panel.num`

## Settings Surfaces

| File | Connection |
| --- | --- |
| `shell/ryokuSettings.qml` | Current official settings app. Bar and Dock page controls position, vertical mode, style, background, auto-hide, borderless, workspace numbers, and module toggles. Also controls weather, resources, global style, and panel enablement in other sections. |
| `shell/welcome.qml` | First-run/onboarding settings writes `bar.bottom`, `bar.cornerStyle`, `panelFamily`, `bar.showBackground`, `bar.autoHide.enable`, and `bar.weather.enable`. |
| `shell/waffleSettings.qml` | Waffle settings entrypoint. Its Taskbar page loads `modules/waffle/settings/pages/WBarPage.qml`. |
| `shell/settings.qml` | Older settings shell that still loads legacy config pages including `BarConfig.qml`. |
| `shell/modules/settings/BarConfig.qml` | Legacy detailed classic bar settings page. Has controls for position, style, auto-hide, scroll actions, vignette, modules, resources, workspace behavior, tray, util buttons, and notification count. |
| `shell/modules/settings/GeneralConfig.qml` | Multi-monitor bar visibility through `bar.screenList`. |
| `shell/modules/settings/BackgroundConfig.qml` | Desktop weather widget depends on `bar.weather.enable`. |
| `shell/modules/settings/DesktopWidgetsConfig.qml` | Desktop widget settings are panel-family aware and include unrelated bar-shaped visualizer settings. Check during a broad settings cleanup. |
| `shell/modules/settings/InterfaceConfig.qml` | Sidebar and overview settings. Includes `overview.respectBar` and many sidebar settings reached from bar-opened sidebars. |
| `shell/modules/settings/ModulesConfig.qml` | Panel toggles for `iiBar`, `iiVerticalBar`, and `wBar`. Helper keeps ii horizontal and vertical bar enablement aligned. |
| `shell/modules/settings/QuickConfig.qml` | Quick/global settings surface with direct or indirect panel controls. |
| `shell/modules/settings/ServicesConfig.qml` | Service toggles used by bar modules and indicators. |
| `shell/modules/settings/SettingsOverlay.qml` | Settings overlay search/index metadata for bar/taskbar, keyboard indicators, and Waffle Taskbar. Tracks `panelFamily`. |
| `shell/modules/settings/ThemesConfig.qml` | Global style and appearance settings that affect bar shape/color. |
| `shell/modules/settings/ToolsConfig.qml` | Tool/panel settings that mutate `enabledPanels`. |
| `shell/modules/settings/WaffleConfig.qml` | Waffle settings entrypoint. |
| `shell/modules/settings/AngelStyleEditor.qml` | Angel/global style editor. Static search hit through accent-bar styling; check if bar style is unified under Angel. |
| `shell/modules/waffle/settings/WSettingsContent.qml` | Waffle settings page loader. |
| `shell/modules/waffle/settings/WSettingsDropdown.qml` | Waffle settings control component. Static search hit via settings/taskbar UI. |
| `shell/modules/waffle/settings/WSettingsFontSelector.qml` | Waffle settings control component. Static search hit via settings/taskbar UI. |
| `shell/modules/waffle/settings/WSettingsInfoBar.qml` | Waffle settings info bar component. |
| `shell/modules/waffle/settings/WSettingsPage.qml` | Waffle settings page shell. |
| `shell/modules/waffle/settings/pages/WBarPage.qml` | Waffle taskbar page: position, layout, icon size, monochrome/tinted tray icons, desktop peek, notification count, and update thresholds. |
| `shell/modules/waffle/settings/pages/WAboutPage.qml` | Displays active `panelFamily` and Waffle/ii family details. |
| `shell/modules/waffle/settings/pages/WBackgroundPage.qml` | Waffle background page; check if taskbar/background ownership changes. |
| `shell/modules/waffle/settings/pages/WGeneralPage.qml` | Waffle keyboard/time settings; controls indicators shown in the bar/taskbar. |
| `shell/modules/waffle/settings/pages/WGowallPage.qml` | Waffle wallpaper/Gowall page; panel-family-aware wallpaper behavior can affect Waffle bar visuals. |
| `shell/modules/waffle/settings/pages/WInterfacePage.qml` | Waffle interface page; notification and lock notification settings affect taskbar-attached notification surfaces. |
| `shell/modules/waffle/settings/pages/WModulesPage.qml` | Waffle module toggles including `wBar`. |
| `shell/modules/waffle/settings/pages/WQuickPage.qml` | Waffle quick settings page. Static taskbar/settings search hit. |
| `shell/modules/waffle/settings/pages/WShortcutsPage.qml` | Waffle shortcuts settings. Check if bar/tool binds move. |
| `shell/modules/waffle/settings/pages/WThemesPage.qml` | Waffle theme/global style page. Can set/reset `bar.cornerStyle`. |
| `shell/modules/waffle/settings/pages/WWaffleStylePage.qml` | Waffle style page with weather settings shared through `bar.weather.*`. |
| `shell/modules/waffle/settings/pages/qmldir` | Waffle settings module registration. |
| `shell/modules/waffle/settings/qmldir` | Waffle settings module registration. |
| `docs/settings-migration-audit.md` | Existing audit of settings parity gaps. Use this before deleting old settings pages. |

## Classic Bar Rendering Files

Every file under `shell/modules/bar` is part of the classic bar surface or its
toolkit:

| File | Connection |
| --- | --- |
| `shell/modules/bar/Bar.qml` | Horizontal classic bar panel, layer-shell geometry, exclusive zone, auto-hide, IPC target `bar`, and global shortcuts. |
| `shell/modules/bar/BarContent.qml` | Main classic bar layout, click/scroll interactions, module placement, sidebar/control-panel toggles, weather gate, timer, updates indicator, and context menu. |
| `shell/modules/bar/BarGroup.qml` | Group container styling used by bar modules. |
| `shell/modules/bar/ActiveWindow.qml` | Active window title/module. |
| `shell/modules/bar/BarTaskbar.qml` | Optional classic taskbar module. |
| `shell/modules/bar/BarTaskbarButton.qml` | Classic taskbar button and launcher behavior. |
| `shell/modules/bar/BarTaskbarPreview.qml` | Classic taskbar preview surface. |
| `shell/modules/bar/BarTaskbarWindowPreview.qml` | Classic taskbar window preview item. |
| `shell/modules/bar/BarVignette.qml` | Legacy vignette component. Check before removing because current vignette behavior appears to live in `Backdrop.qml`. |
| `shell/modules/bar/BatteryIndicator.qml` | Battery bar module. |
| `shell/modules/bar/BatteryPopup.qml` | Battery popup. |
| `shell/modules/bar/CircleUtilButton.qml` | Utility button component used by bar tools. |
| `shell/modules/bar/ClockWidget.qml` | Clock module. |
| `shell/modules/bar/ClockWidgetTooltip.qml` | Clock tooltip/date details. |
| `shell/modules/bar/HyprlandXkbIndicator.qml` | Keyboard layout indicator. |
| `shell/modules/bar/LeftSidebarButton.qml` | Top-left icon/logo and left sidebar toggle. Reads `bar.topLeftIcon`. |
| `shell/modules/bar/Media.qml` | Bar media module and media popup trigger. |
| `shell/modules/bar/NotificationUnreadCount.qml` | Notification unread count badge. |
| `shell/modules/bar/Resource.qml` | Single resource indicator. |
| `shell/modules/bar/Resources.qml` | CPU/RAM/temp/GPU resource cluster. |
| `shell/modules/bar/ResourcesPopup.qml` | Resource details popup. |
| `shell/modules/bar/ScrollHint.qml` | Hover/scroll hints for brightness, volume, or workspace scrolling. |
| `shell/modules/bar/SecPulseIndicator.qml` | Ryoku SecPulse VPN/Tailscale status pill. |
| `shell/modules/bar/ShellUpdateIndicator.qml` | Shell update indicator shown in the bar. |
| `shell/modules/bar/StyledPopup.qml` | Bar popup wrapper. Future edits should follow `docs/ui-patterns.md`. |
| `shell/modules/bar/SysTray.qml` | Classic system tray cluster. |
| `shell/modules/bar/SysTrayItem.qml` | Classic tray item. |
| `shell/modules/bar/SysTrayMenu.qml` | Classic tray menu. |
| `shell/modules/bar/SysTrayMenuEntry.qml` | Classic tray menu entry. |
| `shell/modules/bar/TimerIndicator.qml` | Timer/pomodoro indicator. |
| `shell/modules/bar/TimerIndicatorTooltip.qml` | Timer tooltip. |
| `shell/modules/bar/ToolsModePanel.qml` | Mod+S tools overlay, positioned relative to bar. Uses `bar.bottom`, `bar.screenList`, `bar.showBackground`, and `GlobalStates.toolsModeOpen`. |
| `shell/modules/bar/UtilButtons.qml` | Classic utility buttons. Shares actions with tools mode via `ToolRegistry.qml` and legacy `bar.utilButtons.*` gates. |
| `shell/modules/bar/Workspaces.qml` | Workspace strip and workspace scrolling. |
| `shell/modules/bar/weather/WeatherBar.qml` | Weather pill/module. |
| `shell/modules/bar/weather/WeatherCard.qml` | Weather card content. |
| `shell/modules/bar/weather/WeatherPopup.qml` | Weather popup. |
| `shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml` | Toolkit row still under the old `threeIsland` path. Uses `bar.dynamicIsland.tools.*`. |
| `shell/modules/bar/threeIsland/dynamicIsland/tools/ToolButton.qml` | Toolkit button component. |
| `shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml` | Shared action registry for tools mode and utility buttons. |
| `shell/modules/bar/threeIsland/dynamicIsland/tools/qmldir` | Toolkit module registration. |

## Vertical Bar Rendering Files

| File | Connection |
| --- | --- |
| `shell/modules/verticalBar/VerticalBar.qml` | Vertical classic bar panel, layer-shell geometry, exclusive zone, IPC target `bar`, and global shortcuts. |
| `shell/modules/verticalBar/VerticalBarContent.qml` | Vertical bar content, sidebar toggles, workspace/media/resources/battery layout, and scroll behavior. |
| `shell/modules/verticalBar/VerticalClockWidget.qml` | Vertical clock. |
| `shell/modules/verticalBar/VerticalDateWidget.qml` | Vertical date. |
| `shell/modules/verticalBar/VerticalMedia.qml` | Vertical media module. |
| `shell/modules/verticalBar/BatteryIndicator.qml` | Vertical battery module. |
| `shell/modules/verticalBar/Resource.qml` | Vertical resource indicator. |
| `shell/modules/verticalBar/Resources.qml` | Vertical resource cluster. |

## Waffle Taskbar Rendering Files

| File | Connection |
| --- | --- |
| `shell/modules/waffle/bar/WaffleBar.qml` | Waffle taskbar panel, layer-shell geometry, auto-hide state through `GlobalStates.barOpen`, and IPC target `wbar`. |
| `shell/modules/waffle/bar/WaffleBarContent.qml` | Main Waffle taskbar layout. Uses `waffles.bar.*`, tasks, tray, weather, timer, updates, system, clock, desktop peek, and context menu. |
| `shell/modules/waffle/bar/AppButton.qml` | Waffle app/task button base. |
| `shell/modules/waffle/bar/BarButton.qml` | Waffle taskbar button base. |
| `shell/modules/waffle/bar/BarIconButton.qml` | Waffle icon button base. |
| `shell/modules/waffle/bar/BarMenu.qml` | Waffle taskbar menu. |
| `shell/modules/waffle/bar/BarPopup.qml` | Waffle taskbar popup. |
| `shell/modules/waffle/bar/BarToolTip.qml` | Waffle taskbar tooltip. |
| `shell/modules/waffle/bar/DesktopPeekButton.qml` | Desktop peek button and hover behavior. |
| `shell/modules/waffle/bar/SearchButton.qml` | Search/start-menu taskbar button. |
| `shell/modules/waffle/bar/StartButton.qml` | Start button and start menu trigger. |
| `shell/modules/waffle/bar/SystemButton.qml` | Action center/system button. |
| `shell/modules/waffle/bar/TaskViewButton.qml` | Task view/overview button. |
| `shell/modules/waffle/bar/TimeButton.qml` | Clock/calendar taskbar button. |
| `shell/modules/waffle/bar/TimerButton.qml` | Timer taskbar button. |
| `shell/modules/waffle/bar/UpdatesButton.qml` | Updates taskbar button and update state. |
| `shell/modules/waffle/bar/WeatherButton.qml` | Weather taskbar button. |
| `shell/modules/waffle/bar/WidgetsButton.qml` | Widgets taskbar button. |
| `shell/modules/waffle/bar/qmldir` | Waffle bar module registration. |
| `shell/modules/waffle/bar/tasks/Tasks.qml` | Running tasks cluster. |
| `shell/modules/waffle/bar/tasks/TaskAppButton.qml` | Task app button. |
| `shell/modules/waffle/bar/tasks/TaskPreview.qml` | Task preview popup. |
| `shell/modules/waffle/bar/tasks/WindowPreview.qml` | Window preview item. |
| `shell/modules/waffle/bar/tasks/qmldir` | Waffle tasks module registration. |
| `shell/modules/waffle/bar/tray/Tray.qml` | Waffle tray. |
| `shell/modules/waffle/bar/tray/TrayButton.qml` | Waffle tray button. |
| `shell/modules/waffle/bar/tray/TrayOverflowMenu.qml` | Waffle tray overflow menu. |
| `shell/modules/waffle/bar/tray/WaffleTrayMenu.qml` | Waffle tray item menu. |
| `shell/modules/waffle/bar/tray/WaffleTrayMenuEntry.qml` | Waffle tray menu entry. |
| `shell/modules/waffle/bar/tray/qmldir` | Waffle tray module registration. |

## Waffle Bar Adjacent Files

These are not the bar itself, but open from the Waffle taskbar, attach to it, or
read taskbar position/style.

| File | Connection |
| --- | --- |
| `shell/modules/waffle/actionCenter/WaffleActionCenter.qml` | Opens from Waffle system button. |
| `shell/modules/waffle/actionCenter/ActionCenterContent.qml` | Action center content opened from taskbar. |
| `shell/modules/waffle/actionCenter/ActionCenterContext.qml` | Action center context/state. |
| `shell/modules/waffle/actionCenter/ExpandableChoiceButton.qml` | Action center control. |
| `shell/modules/waffle/actionCenter/HeaderRow.qml` | Action center header row. |
| `shell/modules/waffle/actionCenter/MediaPaneContent.qml` | Action center media content. |
| `shell/modules/waffle/actionCenter/SectionText.qml` | Action center section text. |
| `shell/modules/waffle/actionCenter/ToggleItem.qml` | Action center toggle item. |
| `shell/modules/waffle/actionCenter/qmldir` | Action center module registration. |
| `shell/modules/waffle/notificationCenter/WaffleNotificationCenter.qml` | Opens from Waffle notification/clock area. |
| `shell/modules/waffle/notificationCenter/NotificationCenterContent.qml` | Notification center content. |
| `shell/modules/waffle/notificationCenter/CalendarWidget.qml` | Notification center calendar widget. |
| `shell/modules/waffle/notificationCenter/DateHeader.qml` | Notification center date header. |
| `shell/modules/waffle/notificationCenter/FocusFooter.qml` | Notification center focus/footer controls. |
| `shell/modules/waffle/notificationCenter/NotificationHeaderButton.qml` | Notification center header button. |
| `shell/modules/waffle/notificationCenter/NotificationPaneContent.qml` | Notification center notification pane. |
| `shell/modules/waffle/notificationCenter/SmallBorderedIconAndTextButton.qml` | Notification center button. |
| `shell/modules/waffle/notificationCenter/SmallBorderedIconButton.qml` | Notification center icon button. |
| `shell/modules/waffle/notificationCenter/WNotificationAppIcon.qml` | Waffle notification app icon. |
| `shell/modules/waffle/notificationCenter/WNotificationDismissAnim.qml` | Waffle notification dismissal animation. |
| `shell/modules/waffle/notificationCenter/WNotificationGroup.qml` | Waffle notification group. |
| `shell/modules/waffle/notificationCenter/WSingleNotification.qml` | Waffle single notification. |
| `shell/modules/waffle/notificationCenter/qmldir` | Notification center module registration. |
| `shell/modules/waffle/startMenu/WaffleStartMenu.qml` | Opens from Waffle start/search buttons. |
| `shell/modules/waffle/startMenu/AllAppsContent.qml` | Start menu all-apps content. |
| `shell/modules/waffle/startMenu/SearchBar.qml` | Start menu search bar. |
| `shell/modules/waffle/startMenu/SearchEntryIcon.qml` | Start/search menu icon. |
| `shell/modules/waffle/startMenu/SearchPageContent.qml` | Start menu search page content. |
| `shell/modules/waffle/startMenu/SearchResults.qml` | Start/search results. |
| `shell/modules/waffle/startMenu/StartMenuContent.qml` | Start menu content. |
| `shell/modules/waffle/startMenu/StartMenuContext.qml` | Start menu context/state. |
| `shell/modules/waffle/startMenu/StartPageContent.qml` | Start menu start page content. |
| `shell/modules/waffle/startMenu/TagStrip.qml` | Start menu tag strip. |
| `shell/modules/waffle/startMenu/WSearchResultButton.qml` | Start/search result button. |
| `shell/modules/waffle/startMenu/qmldir` | Start menu module registration. |
| `shell/modules/waffle/widgets/WaffleWidgets.qml` | Opens from Waffle widgets button. |
| `shell/modules/waffle/widgets/WidgetsContent.qml` | Waffle widgets content. |
| `shell/modules/waffle/widgets/qmldir` | Waffle widgets module registration. |
| `shell/modules/waffle/onScreenDisplay/WaffleOSD.qml` | Waffle OSD positioning. |
| `shell/modules/waffle/onScreenDisplay/KeyboardLayoutOSD.qml` | Waffle keyboard layout OSD. |
| `shell/modules/waffle/onScreenDisplay/MediaOSD.qml` | Waffle media OSD. |
| `shell/modules/waffle/onScreenDisplay/OSDValue.qml` | Waffle OSD value item. |
| `shell/modules/waffle/background/WaffleBackground.qml` | Waffle desktop/background behavior around taskbar mode. |
| `shell/modules/waffle/looks/WBarAttachedPanelContent.qml` | Shared attached-panel positioning for Waffle taskbar popups. |
| `shell/modules/waffle/looks/WAppIcon.qml` | Shared app icon rendering used by Waffle taskbar/start/task surfaces. |
| `shell/modules/waffle/looks/WTaskbarSeparator.qml` | Waffle taskbar separator. |
| `shell/modules/waffle/looks/WPanelIconButton.qml` | Shared Waffle panel button used by taskbar-attached surfaces. |
| `shell/modules/waffle/looks/WPanelPageColumn.qml` | Shared Waffle panel column layout. |
| `shell/modules/waffle/looks/WPanelSeparator.qml` | Shared Waffle panel separator. |
| `shell/modules/waffle/looks/WListView.qml` | Shared Waffle list view; static bar/settings hit through scrollbars. |
| `shell/modules/waffle/looks/WScrollBar.qml` | Shared Waffle scrollbar component. |
| `shell/modules/waffle/looks/WProgressBar.qml` | Shared Waffle progress bar component. |
| `shell/modules/waffle/looks/WIndeterminateProgressBar.qml` | Shared Waffle progress bar component. |
| `shell/modules/waffle/looks/qmldir` | Waffle look component registration. |
| `shell/modules/waffle/clipboard/WaffleClipboard.qml` | Waffle-family clipboard panel; active only when `panelFamily` is Waffle. |
| `shell/modules/waffle/notificationPopup/WaffleNotificationPopup.qml` | Waffle notification popup surface. |
| `shell/modules/waffle/notificationPopup/WNotificationGroup.qml` | Waffle notification popup group. |
| `shell/modules/waffle/notificationPopup/WNotificationItem.qml` | Waffle notification popup item. |
| `shell/modules/waffle/notificationPopup/WNotificationListView.qml` | Waffle notification popup list view. |
| `shell/modules/waffle/notificationPopup/qmldir` | Waffle notification popup module registration. |
| `shell/modules/waffle/sessionScreen/WaffleSessionScreen.qml` | Waffle-family session screen. |
| `shell/modules/waffle/taskview/WaffleTaskView.qml` | Waffle task view, enabled by `panelFamily === "waffle"`. |
| `shell/modules/waffle/taskview/WaffleTaskViewContent.qml` | Waffle task view content. |
| `shell/modules/waffle/taskview/WindowThumbnail.qml` | Waffle task view window thumbnail. |
| `shell/modules/waffle/taskview/WorkspaceThumbnail.qml` | Waffle task view workspace thumbnail. |
| `shell/modules/waffle/taskview/qmldir` | Waffle task view module registration. |
| `shell/modules/wallpaperSelector/WallpaperSelector.qml` | Bar-position-sensitive selector references found in static search. |
| `shell/modules/wallpaperSelector/WallpaperSelectorContent.qml` | Wallpaper selector content; inspect if bar-position-sensitive selector changes. |
| `shell/modules/wallpaperSelector/WallpaperCoverflow.qml` | Wallpaper coverflow; inspect if selector layout changes around bars. |
| `shell/modules/wallpaperSelector/WallpaperSkewView.qml` | Bar-position-sensitive selector references found in static search. |

## Shared Widgets And Helpers Used By Bar Files

Bar modules import these shared modules heavily. Reworking the visual style may
require touching these, even if they are not bar-owned.

| Path | Connection |
| --- | --- |
| `shell/modules/common/Appearance.qml` | Shared colors, typography scale, `barHeight`, `verticalBarWidth`, spacing, and bar sizing derived from `bar.cornerStyle`. |
| `shell/modules/common/Icons.qml` | Weather and symbolic icon lookup helpers. |
| `shell/modules/common/StylePresets.qml` | Global style definitions that can drive bar corner/style decisions. |
| `shell/modules/common/ThemePresets.qml` | Theme presets that change bar appearance through palette/global style. |
| `shell/modules/common/widgets/CustomIcon.qml` | Resolves bundled icons for `bar.topLeftIcon`, including Ryoku logo assets. |
| `shell/modules/common/widgets/RippleButton.qml` | Common interactive button component used by bar-adjacent controls. |
| `shell/modules/common/widgets/FocusedScrollMouseArea.qml` | Scroll interaction helper. |
| `shell/modules/common/widgets/ContextMenu.qml` | Context menus opened by bar right-click actions. |
| `shell/modules/common/widgets/MaterialSymbol.qml` | Icon rendering for bar buttons and indicators. |
| `shell/modules/common/widgets/PopupToolTip.qml` | Tooltips for bar and taskbar controls. |
| `shell/modules/common/widgets/StyledRectangularShadow.qml` | Shared shadow styling. |
| `shell/modules/common/widgets/RoundCorner.qml` | Rounded corner rendering used by shell chrome. |
| `shell/modules/common/widgets/GlassBackground.qml` | Shared translucent/glass backgrounds used by attached surfaces. |
| `shell/modules/common/widgets/AngelAccentBar.qml` | Angel style accent bar component. Relevant if global bar styling is consolidated. |
| `shell/modules/common/widgets/AddressBar.qml` | Generic address bar widget. Static bar UI hit; do not confuse with shell top bar. |
| `shell/modules/common/widgets/AddressBreadcrumb.qml` | Generic address breadcrumb. Static address-bar UI hit. |
| `shell/modules/common/widgets/CircularProgress.qml` | Generic circular progress indicator. Static bar/progress hit. |
| `shell/modules/common/widgets/ClippedFilledCircularProgress.qml` | Generic circular progress indicator. Static bar/progress hit. |
| `shell/modules/common/widgets/ClippedProgressBar.qml` | Generic progress bar. Static bar UI hit. |
| `shell/modules/common/widgets/IconToolbarButton.qml` | Generic toolbar button. Static toolbar hit. |
| `shell/modules/common/widgets/NavigationRailButton.qml` | Generic navigation rail button. Static tab/bar hit. |
| `shell/modules/common/widgets/NavigationRailTabArray.qml` | Generic tab array. Static tab/bar hit. |
| `shell/modules/common/widgets/ScrollEdgeFade.qml` | Generic scroll edge fade. Static scrollbar hit. |
| `shell/modules/common/widgets/SecondaryTabBar.qml` | Generic tab bar. Static tab/bar hit. |
| `shell/modules/common/widgets/SecondaryTabButton.qml` | Generic tab button. Static tab/bar hit. |
| `shell/modules/common/widgets/SettingsCardSection.qml` | Generic settings section; static settings/bar hit. |
| `shell/modules/common/widgets/SettingsMaterialPreset.qml` | Generic settings preset; static settings/bar hit. |
| `shell/modules/common/widgets/StyledComboBox.qml` | Generic settings widget; static bar/settings hit. |
| `shell/modules/common/widgets/StyledFlickable.qml` | Generic flickable with scrollbar behavior. |
| `shell/modules/common/widgets/StyledIndeterminateProgressBar.qml` | Generic progress bar. |
| `shell/modules/common/widgets/StyledListView.qml` | Generic list view with scrollbar behavior. |
| `shell/modules/common/widgets/StyledProgressBar.qml` | Generic progress bar. |
| `shell/modules/common/widgets/StyledScrollBar.qml` | Shared scrollbar component. |
| `shell/modules/common/widgets/Toolbar.qml` | Generic toolbar. |
| `shell/modules/common/widgets/ToolbarButton.qml` | Generic toolbar button. |
| `shell/modules/common/widgets/ToolbarTabBar.qml` | Generic toolbar tab bar. |
| `shell/modules/common/widgets/ToolbarTabButton.qml` | Generic toolbar tab button. |
| `shell/modules/common/widgets/ToolbarTextField.qml` | Generic toolbar text field. |
| `shell/modules/common/widgets/widgetCanvas/AbstractWidget.qml` | Generic widget canvas; static bar-shaped widget hit. |
| `shell/modules/common/widgets/qmldir` | Shared widget registration. |
| `shell/modules/common/functions/*` | Shared QML helper functions imported by bar modules. |
| `shell/modules/common/models/*` | Shared models imported by bar/taskbar modules. |

## Services And State Feeding The Bar

| File | Connection |
| --- | --- |
| `shell/services/ToolsModeService.qml` | IPC target `toolsMode`; toggles `GlobalStates.toolsModeOpen`. |
| `shell/services/GlobalActions.qml` | Contains global action `toggle-bar-autohide`, writes `bar.autoHide.enable`. |
| `shell/services/Ai.qml` | AI config-writing tool examples include `bar.borderless`; keep schema/docs accurate if bar keys are renamed. |
| `shell/services/Notifications.qml` | Feeds unread notification badges/counts shown in classic and Waffle bar surfaces. |
| `shell/services/Weather.qml` | Feeds classic and Waffle weather UI through `bar.weather.*`. |
| `shell/services/ShellUpdates.qml` | Feeds `ShellUpdateIndicator.qml` and Waffle updates button. |
| `shell/services/ResourceUsage.qml` | Feeds resources indicators and resource thresholds. |
| `shell/services/NiriService.qml` | Workspaces, active window, task/window state, and compositor actions. |
| `shell/services/MprisController.qml` | Media module and media popup data. |
| `shell/services/Audio.qml` | Volume/mic state and mic toggle tools. |
| `shell/services/RyokuOpenVpn.qml` | SecPulse/OpenVPN status. |
| `shell/services/RyokuTailscale.qml` | SecPulse/Tailscale status. |
| `shell/services/TrayService.qml` | Classic and Waffle tray data. |
| `shell/services/TimerService.qml` | Timer indicators/buttons. |
| `shell/services/TaskbarApps.qml` | Classic taskbar and Waffle task data. |
| `shell/services/Network.qml` | Network status used by shell status surfaces. |
| `shell/services/KeyboardIndicators.qml` | Keyboard layout/caps/num state. |
| `shell/services/DateTime.qml` | Clock/date modules. |
| `shell/services/Brightness.qml` | Brightness scroll action. |
| `shell/services/BluetoothStatus.qml` | System/status surfaces opened from bars. |
| `shell/services/Battery.qml` | Battery modules and battery popups. |
| `shell/services/GameMode.qml` | Utility/status actions. |
| `shell/services/CompositorService.qml` | Compositor abstraction used by bar actions. |
| `shell/services/AwwwBackend.qml` | Panel-family-aware wallpaper backend; Waffle can own a different wallpaper path. |
| `shell/services/GowallService.qml` | Panel-family-aware wallpaper/color pipeline. |
| `shell/services/ThemeService.qml` | Tracks `panelFamily` and re-runs theme/color pipeline on family changes. |
| `shell/services/Wallpapers.qml` | Panel-family-aware wallpaper state and Waffle wallpaper behavior. |
| `shell/services/AppSearch.qml` | Waffle start/search surface. |
| `shell/services/AppLauncher.qml` | Launches apps from taskbar/start/search surfaces. |
| `shell/services/WindowPreviewService.qml` | Taskbar previews. |
| `shell/services/RecorderStatus.qml` | Screen recording tool state. |
| `shell/services/SongRec.qml` | Music recognition tool. |
| `shell/services/Idle.qml` | Caffeine/idle inhibitor tool. |
| `shell/services/PowerProfilePersistence.qml` | Persists/restores the global `PowerProfiles` state used by the bar/tools power-profile action. |
| `shell/modules/common/models/quickToggles/PowerProfilesToggle.qml` | Shared power-profile toggle model used by Waffle action center and conceptually shared with the bar/tools power-profile action. |
| `shell/services/Privacy.qml` | Privacy/status indicators. |
| `shell/services/MaterialThemeLoader.qml` | Dark mode/theme toggle used by tools. |
| `shell/services/SystemInfo.qml` | Distro icon and system info used by top-left icon logic. |
| `shell/services/qmldir` | Service singleton registration, including `ToolsModeService` and `TaskbarApps`. |

## Bar-Adjacent Panels

These files position themselves relative to bar settings, open from bar
interactions, or reserve space around the bar.

| File | Connection |
| --- | --- |
| `shell/modules/background/Backdrop.qml` | Uses `bar.vertical`, `bar.bottom`, and `bar.vignette.*`. |
| `shell/modules/background/Background.qml` | Uses `bar.workspaces.shown` for per-workspace wallpaper behavior. |
| `shell/modules/dock/Dock.qml` | Tracks bar position in its position key and must be checked if the bar moves. |
| `shell/modules/controlPanel/ControlPanel.qml` | Offsets/reserves space based on `bar.bottom`; opened from bar interactions. |
| `shell/modules/mediaControls/MediaControls.qml` | Positions media overlay near the bar based on `bar.bottom`. |
| `shell/modules/mediaControls/BarMediaPopup.qml` | Media popup opened from bar media controls. |
| `shell/modules/mediaControls/BarMediaPlayerItem.qml` | Media popup player item. |
| `shell/modules/sidebarLeft/SidebarLeft.qml` | Left sidebar surface toggled by bar left section and top-left button. |
| `shell/modules/sidebarLeft/SidebarLeftContent.qml` | Left sidebar content reached from bar interactions. |
| `shell/modules/sidebarLeft/aiChat/MessageCodeBlock.qml` | Static scrollbar hit inside bar-opened left sidebar content. |
| `shell/modules/sidebarLeft/widgets/GlanceHeader.qml` | Waffle-family-aware sidebar widget header. |
| `shell/modules/sidebarLeft/widgets/WidgetSettingsMenu.qml` | Sidebar widget settings menu with layer-shell/exclusive-zone behavior. |
| `shell/modules/sidebarRight/SidebarRight.qml` | Right sidebar/control surface toggled by bar right section. |
| `shell/modules/sidebarRight/SidebarRightContent.qml` | Right sidebar content reached from bar interactions. |
| `shell/modules/sidebarRight/CompactSidebarRightContent.qml` | Compact right sidebar layout; bar tools and timer can select tabs here. |
| `shell/modules/sidebarRight/BottomWidgetGroup.qml` | Persistent bottom tab group. `ToolRegistry.qml` and Waffle timer select these tabs. |
| `shell/modules/sidebarRight/notepad/NotepadWidget.qml` | Notepad widget opened by the bar/tools notepad action. |
| `shell/modules/sidebarRight/pomodoro/PomodoroWidget.qml` | Timer widget opened by Waffle timer button. |
| `shell/modules/sidebarRight/events/EventsDialog.qml` | Static scrollbar hit inside bar-opened right sidebar content. |
| `shell/modules/sidebarRight/events/EventsWidget.qml` | Static scrollbar hit inside bar-opened right sidebar content. |
| `shell/modules/sidebarRight/quickToggles/AndroidQuickPanel.qml` | Static scrollbar hit inside bar-opened right sidebar quick toggles. |
| `shell/modules/sidebarRight/sysmon/SysMonWidget.qml` | Static scrollbar hit inside bar-opened right sidebar system monitor. |
| `shell/modules/onScreenDisplay/OnScreenDisplay.qml` | Positions OSD relative to top/bottom bar. |
| `shell/modules/overview/Overview.qml` | Uses `overview.respectBar` and `bar.bottom` for layout offsets. |
| `shell/modules/overview/OverviewWidget.qml` | Workspace scrolling respects `bar.workspaces.invertScroll`. |
| `shell/modules/overview/OverviewNiriWidget.qml` | Niri overview workspace scrolling respects `bar.workspaces.invertScroll`. |
| `shell/modules/overview/ActionModeView.qml` | Overview subview; bar can toggle overview through workspace interactions. |
| `shell/modules/overview/OverviewDashboard.qml` | Overview dashboard; static scrollbar/search hit. |
| `shell/modules/overview/OverviewWindow.qml` | Overview window item. |
| `shell/modules/overview/SearchBar.qml` | Overview search bar. |
| `shell/modules/overview/SearchItem.qml` | Overview search item. |
| `shell/modules/overview/SearchWidget.qml` | Overview search widget; static search-bar hit. |
| `shell/modules/waffle/actionCenter/*` | Waffle taskbar-attached action center. |
| `shell/modules/waffle/notificationCenter/*` | Waffle taskbar-attached notification center. |
| `shell/modules/waffle/startMenu/*` | Waffle start/search surfaces opened from taskbar. |
| `shell/modules/waffle/widgets/*` | Waffle widgets surface opened from taskbar. |
| `shell/modules/ii/overlay/OverlayTaskbar.qml` | Overlay taskbar widget; static taskbar hit outside the main bar modules. |
| `shell/modules/ii/overlay/Overlay.qml` | ii overlay root. Check if overlay/taskbar surfaces are redesigned. |
| `shell/modules/ii/overlay/OverlayBackground.qml` | ii overlay background. |
| `shell/modules/ii/overlay/OverlayContent.qml` | Overlay content that can include taskbar/resource widgets. |
| `shell/modules/ii/overlay/OverlayContext.qml` | ii overlay context/state. |
| `shell/modules/ii/overlay/OverlayWidgetDelegateChooser.qml` | Chooses overlay widgets including taskbar/resource widgets. |
| `shell/modules/ii/overlay/StyledOverlayWidget.qml` | Overlay widget styling used by ii overlay surfaces. |
| `shell/modules/ii/overlay/crosshair/Crosshair.qml` | Overlay crosshair widget. Static overlay inventory hit. |
| `shell/modules/ii/overlay/crosshair/CrosshairContent.qml` | Overlay crosshair content. |
| `shell/modules/ii/overlay/discord/Discord.qml` | Overlay Discord widget. |
| `shell/modules/ii/overlay/discord/qmldir` | Overlay Discord module registration. |
| `shell/modules/ii/overlay/floatingImage/FloatingImage.qml` | Overlay floating image widget. |
| `shell/modules/ii/overlay/fpsLimiter/FpsLimiter.qml` | Overlay FPS limiter widget. |
| `shell/modules/ii/overlay/fpsLimiter/FpsLimiterContent.qml` | Overlay FPS limiter content. |
| `shell/modules/ii/overlay/notes/Notes.qml` | Overlay notes widget. |
| `shell/modules/ii/overlay/notes/NotesContent.qml` | Overlay notes content; static search hit through taskbar/overlay surface. |
| `shell/modules/ii/overlay/notifications/Notifications.qml` | Overlay notifications widget. |
| `shell/modules/ii/overlay/recorder/Recorder.qml` | Overlay recorder widget. |
| `shell/modules/ii/overlay/resources/Resources.qml` | Overlay resources, adjacent to bar resource indicators. |
| `shell/modules/ii/overlay/volumeMixer/VolumeMixer.qml` | Overlay volume mixer, adjacent to bar volume/scroll interactions. |
| `shell/modules/altSwitcher/AltSwitcher.qml` | Panel-family-aware alt switcher. |
| `shell/modules/clipboard/ClipboardPanel.qml` | Disabled in Waffle family; check if panel family behavior changes. |
| `shell/modules/closeConfirm/CloseConfirm.qml` | Selects Waffle or ii content based on `panelFamily`. |
| `shell/modules/lock/Lock.qml` | Uses `panelFamily` to choose Waffle/ii lock behavior. |
| `shell/modules/notificationPopup/NotificationPopup.qml` | Layer-shell notification surface with exclusive-zone behavior. |
| `shell/modules/onScreenKeyboard/OnScreenKeyboard.qml` | Layer-shell keyboard surface with exclusive-zone behavior. |
| `shell/modules/recordingOsd/RecordingOsd.qml` | Layer-shell recording OSD with exclusive-zone behavior. |
| `shell/modules/regionSelector/RegionSelection.qml` | Panel-family-aware region selector. |
| `shell/modules/regionSelector/OptionsToolbar.qml` | Region selector toolbar used by toolkit screenshot/region actions. |
| `shell/modules/waffle/regionSelector/WOptionsToolbar.qml` | Waffle region selector toolbar. |
| `shell/modules/waffle/regionSelector/qmldir` | Waffle region selector module registration. |
| `shell/modules/sessionScreen/SessionScreen.qml` | Disabled in Waffle family; check if panel family behavior changes. |
| `shell/modules/tilingOverlay/TilingOverlay.qml` | Layer-shell overlay with exclusive-zone behavior. |
| `shell/modules/common/ToastManager.qml` | Layer-shell toast surface with exclusive-zone behavior. |
| `shell/modules/common/widgets/CavaVisualizer.qml` | Generic visualizer with top-bar/bottom-bar mode comments. |

## IPC, Keybinds, And CLI

| File | Connection |
| --- | --- |
| `shell/modules/bar/Bar.qml` | IPC target `bar`; actions `toggle`, `open`, `close`; global shortcuts `barToggle`, `barOpen`, `barClose`. |
| `shell/modules/verticalBar/VerticalBar.qml` | IPC target `bar`; same visible bar state as horizontal bar. |
| `shell/modules/waffle/bar/WaffleBar.qml` | IPC target `wbar`; toggles Waffle taskbar state. |
| `shell/modules/bar/ToolsModePanel.qml` | IPC-driven tools overlay; hides the normal bar while active. |
| `shell/services/ToolsModeService.qml` | IPC target `toolsMode`; actions `toggle`, `open`, `close`. |
| `shell/scripts/ryoku-shell` | User-facing CLI for shell actions, including toolkit actions called by `ToolRegistry.qml`. |
| `shell/scripts/lib/ipc-registry.sh` | IPC registry used by shell command generation/completions. |
| `shell/scripts/lib/generate-ipc-registry.py` | Generates IPC registry data. |
| `shell/scripts/completions/ryoku-shell.bash` | CLI completion for shell IPC/actions. |
| `shell/scripts/completions/ryoku-shell.fish` | CLI completion for shell IPC/actions. |
| `shell/scripts/completions/ryoku-shell.zsh` | CLI completion for shell IPC/actions. |
| `shell/scripts/niri-config.py` | Parses/generates Niri shell action metadata including `panelFamily` and `toolsMode`. |
| `shell/scripts/parse_niri_keybinds.py` | Parses Niri keybinds and labels `toolsMode` and `panelFamily` actions. |
| `shell/scripts/colors/switchwall.sh` | Wallpaper/color pipeline uses `panelFamily` to choose Waffle/main wallpaper behavior. |
| `shell/scripts/sddm/sync-pixel-sddm.py` | SDDM sync script reads `panelFamily`. |
| `shell/setup` | Shell setup script reads/writes `panelFamily` in the user config. |
| `shell/docs/IPC.md` | IPC documentation. |
| `config/niri/config.d/70-binds.kdl` | Runtime Niri binds for bar/tools actions. |
| `shell/defaults/niri/config.d/70-binds.kdl` | Shipped Niri binds for bar/tools actions. |
| `shell/dots/.config/niri/config.kdl` | Upstream/dotconfig-style Niri config with `panelFamily` cycle bind. |
| `config/niri/config.d/20-layout-and-overview.kdl` | Runtime layout/overview binds that interact with bar/overview behavior. |
| `shell/defaults/niri/config.d/20-layout-and-overview.kdl` | Shipped layout/overview binds. |
| `config/niri/config.d/80-layer-rules.kdl` | Runtime layer rules that may affect bar/popup chrome. |
| `shell/defaults/niri/config.d/80-layer-rules.kdl` | Shipped layer rules. |

## Install, Runtime Sync, And Branding

| File | Connection |
| --- | --- |
| `install/config/shell.sh` | Installs/syncs the shell payload. Any bar file move/removal must be reflected by payload sync behavior. |
| `install/config/ryoku-shell-branding.sh` | Applies Ryoku branding defaults and icon assets; currently writes bar-related defaults such as `bar.cornerStyle`, `bar.modules.*`, `bar.dynamicIsland.*`, and `bar.kanjiClock.*`. |
| `config/systemd/user/ryoku-shell.service` | User service running the shell. Needed for live validation. |
| `shell/sdata/subcmd-install/3.files.sh` | Shell install file copy logic. |
| `shell/sdata/runtime-payload-dirs.txt` | Runtime payload directory list. Include moved/renamed bar dirs here. |
| `shell/sdata/runtime-root-files.txt` | Runtime root file list. |
| `default/ryoku-shell/branding-replacements.tsv` | Branding replacement table. Check for bar/icon references if logo paths change. |
| `shell/assets/icons/ryoku-symbolic.svg` | Current top-left Ryoku symbolic logo used by `bar.topLeftIcon`. |
| `assets/brand/logo-mark.svg` | Source Ryoku logo used by branding install paths. The installer can write a runtime `ryoku.svg` icon under the shell assets directory. |
| `assets/brand/logo-mark.png` | Raster Ryoku logo source used by branding/assets. |
| `shell/assets/icons/arch-symbolic.svg` | Alternate top-left icon target. |
| `shell/assets/icons/desktop-symbolic.svg` | Alternate/default branding icon target. |

## Migrations

| File | Connection |
| --- | --- |
| `migrations/1778022724.sh` | Retired no-op for old Three-Island topbar propagation. Keep in mind if removing old compatibility behavior. |
| `migrations/1778256447.sh` | Migrates off removed Three-Island bar style, deletes stale dynamic island state keys, and preserves tools mode. |
| `migrations/1777852554.sh` | Re-runs branding to relocate workspaces/weather and unhide topbar indicators. |
| `migrations/1778252246.sh` | Static search hit around panel/bar migration context. Inspect before rewriting defaults/migrations. |
| `migrations/1778000000.sh` | Mentions unavailable desktop chrome in current environment; inspect if shell/bar setup changes. |
| `migrations/1778100000.sh` | Mentions unavailable desktop chrome in current environment; inspect if shell/bar setup changes. |
| `migrations/1778563633.sh` | Static search hit around panel/bar migration context. Inspect before rewriting defaults/migrations. |

## Tests

| File | Connection |
| --- | --- |
| `tests/topbar-removal-regression.sh` | Regression for removed Three-Island topbar and preserved tools mode. Must be updated if toolkit path or `bar.dynamicIsland.*` changes. |
| `tests/dynamic-island-ipc.sh` | Tests tools mode IPC, defaults, and Mod+S binds. |
| `tests/bar-secpulse.sh` | Tests SecPulse bar module, OpenVPN/Tailscale services, settings switch, and `BarContent` gate. |
| `tests/shell-layout-upstream-fixes.sh` | Covers shell layout/update indicator sizing. |
| `tests/upstream-audit-gap-static.sh` | Static audit checks including `ShellUpdateIndicator.qml`. |
| `tests/ryoku-shell-branding.sh` | Tests topbar/logo defaults, branding overlay behavior, and dynamic island button preservation. |
| `tests/ryoku-settings-official.sh` | Tests that official settings expose required bar settings. |
| `tests/niri-keybinds.sh` | Tests Niri keybind coverage; relevant for bar/tools/panel-family binds. |
| `tests/terminal-launchers.sh` | Includes taskbar launcher behavior through `BarTaskbarButton.qml`. |
| `tests/sidebar-requested-widget-notepad.sh` | Covers notepad action from `ToolRegistry.qml`. |
| `tests/sidebar-tailscale.sh` | Covers Tailscale sidebar/topbar service behavior. |
| `tests/google-lens-search.sh` | Covers Google Lens action from `ToolRegistry.qml`. |

## Documentation

| File | Connection |
| --- | --- |
| `docs/settings-migration-audit.md` | Existing settings parity audit with bar/Waffle gaps. |
| `docs/ui-patterns.md` | Popup/layout rules for bar popup rewrites, especially `StyledPopup`. |
| `README.md` | Product README mentions Quickshell topbar, sidebars, custom topbar layouts, and SecPulse/tray behavior. |
| `index.mdx` | Site/documentation entry mentions topbar islands and side panels. |
| `docs/tour.mdx` | User-facing description of topbar/islands/widgets. Likely stale if bar UX changes. |
| `docs/first-boot.mdx` | User-facing first-boot docs mention the top bar and update indicator. |
| `docs/updates.mdx` | Mentions update indicator in the bar. |
| `docs/security-tools.mdx` | Mentions SecPulse bar pill. |
| `docs/customize.mdx` | Customization docs; static search hit for bar/panel config. |
| `docs/customization-inventory.md` | Customization inventory; static search hit for bar/panel config. |
| `docs/branding.md` | Branding docs; static search hit for topbar/custom layout references. |
| `docs/omarchy-heritage.md` | Heritage docs; static search hit for legacy bar/panel references. |
| `docs/troubleshoot.mdx` | Troubleshooting docs; inspect if bar/runtime behavior changes. |
| `docs/install.mdx` | Install docs; inspect if shell/topbar setup changes. |
| `docs/superpowers/specs/2026-05-19-settings-migration-master.md` | Settings migration plan with bar/Waffle parity context. |
| `shell/README.md` | Shell README describes ii/Waffle bars and taskbar. |
| `shell/ARCHITECTURE.md` | Shell architecture references panels/bar behavior. |
| `shell/CONTRIBUTING.md` | Contributor docs with panel/bar references. |
| `shell/CHANGELOG.md` | Changelog documents bar/taskbar behavior, panel hiding, and regressions. |
| `shell/docs/CONFIG_SYSTEM.md` | Config docs with bar keys. |
| `shell/docs/ARCHITECTURE_OVERVIEW.md` | Shell architecture docs with panel/bar context. |
| `shell/docs/AUTOSTART.md` | Shell startup docs with panel/bar context. |
| `shell/docs/GLOBAL_ACTIONS.md` | Global action docs; includes topbar auto-hide action if generated/current. |
| `shell/docs/MODULES.md` | Module docs with bar modules/panels. |
| `shell/docs/IPC.md` | IPC docs for `bar`, `wbar`, `toolsMode`, and panel family commands. |
| `shell/docs/LIMITATIONS.md` | Shell limitations docs with panel/bar references. |
| `shell/docs/OPTIMIZATION.md` | Performance docs touching panels/modules. |
| `shell/docs/PANEL_FAMILIES.md` | Panel family docs for ii and Waffle bars. |
| `shell/docs/PROJECT_MAP.md` | Project map with bar/panel module references. |
| `shell/docs/RUNTIME.md` | Runtime docs for shell payload/install behavior. |
| `shell/docs/SERVICES.md` | Service docs for bar-fed services. |
| `shell/docs/index.md` | Shell docs index; static bar/panel hit. |
| `shell/modules/waffle/README.md` | Waffle notes; mentions current Waffle bar and panel-family switching. |
| `shell/.github/ISSUE_TEMPLATE/feature_request.yml` | Issue template example references a hypothetical `bar.autoHide.workspaces` key. |
| `shell/welcome.qml` | Welcome/onboarding references shell settings and may need copy/flow updates. |
| `shell/translations/ar_SA.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/de_DE.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/en_US.json` | Source translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/es_AR.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/fr_FR.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/he_HE.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/hi_IN.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/it_IT.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/ja_JP.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/ko_KR.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/pt_BR.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/ru_RU.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/uk_UA.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/vi_VN.json` | Translation strings for bar/taskbar/topbar/settings text. |
| `shell/translations/zh_CN.json` | Translation strings for bar/taskbar/topbar/settings text. |

## Dotconfig And Non-Shell Bar Hits

These were found by the broad second pass. Some are not the Ryoku shell topbar,
but they contain bar/statusbar/scrollbar/progressbar/toolbar/tabbar references
and should be consciously ignored or updated if the rework changes global style
language.

| File | Connection |
| --- | --- |
| `config/niri/config.d/10-input-and-cursor.kdl` | Broad dotconfig search hit. Inspect if panel/bar input behavior changes. |
| `config/niri/config.d/20-layout-and-overview.kdl` | Runtime layout comments mention Ryoku layer-shell bar behavior. |
| `config/niri/config.d/60-animations.kdl` | Broad dotconfig search hit. Inspect if panel animations change. |
| `config/niri/config.d/70-binds.kdl` | Runtime binds for panel family and shell actions. |
| `config/niri/config.d/80-layer-rules.kdl` | Runtime layer-shell rules for bars/panels/wallpaper renderers. |
| `shell/defaults/niri/config.d/20-layout-and-overview.kdl` | Shipped layout comments mention Ryoku layer-shell bar behavior. |
| `shell/defaults/niri/config.d/70-binds.kdl` | Shipped binds for panel family and shell actions. |
| `shell/defaults/niri/config.d/80-layer-rules.kdl` | Shipped layer-shell rules for bars/panels/wallpaper renderers. |
| `config/tmux/tmux.conf` | Non-shell terminal status bar config. |
| `config/Typora/themes/ia_typora.css` | Non-shell UI bar/static CSS hit. |
| `config/Typora/themes/ia_typora_night.css` | Non-shell UI bar/static CSS hit. |
| `config/fuzzel/fuzzel.ini` | Dotconfig search hit; inspect only if launcher styling is unified with bar. |
| `config/ghostty/config` | Non-shell status/tab bar config hit. |
| `config/gtk-3.0/gtk.css` | GTK scrollbar/style hit. |
| `config/gtk-3.0/settings.ini` | GTK toolbar/style hit. |
| `config/gtk-4.0/gtk.css` | GTK scrollbar/style hit. |
| `config/matugen/templates/gtk-3.0/gtk.css` | Themed GTK scrollbar/style template hit. |
| `config/matugen/templates/gtk-4.0/gtk.css` | Themed GTK scrollbar/style template hit. |
| `config/matugen/templates/terminals/alacritty.toml` | Terminal bar/static search hit. |
| `config/ryoku/themed/alacritty.toml.tpl.sample` | Terminal bar/static search hit. |
| `config/xournalpp/settings.xml` | Non-shell toolbar/statusbar config hit. |
| `default/plymouth/progress_bar.png` | Boot splash progress bar asset. Not shell topbar. |
| `default/plymouth/ryoku.script` | Boot splash progress bar script. Not shell topbar. |
| `themes/catppuccin/waybar.css` | Legacy Waybar theme CSS. |
| `themes/lumon/waybar.css` | Legacy Waybar theme CSS. |
| `themes/retro-82/waybar.css` | Legacy Waybar theme CSS. |
| `themes/lumon/swayosd.css` | OSD bar/progress styling hit. |

## Root Removal Tree

Use this section when removing the current bar from its roots. Every root has
branch files that either need to be replaced, explicitly preserved, or migrated
away before the old bar code is deleted.

```text
shell/shell.qml
├── panel-family root
│   ├── Config keys: panelFamily, enabledPanels, knownPanels, familyTransitionAnimation
│   ├── family defaults: shell.qml panelFamilies.ii and panelFamilies.waffle
│   ├── transition UI: shell/FamilyTransitionOverlay.qml
│   ├── settings writers: shell/ryokuSettings.qml, shell/settings.qml,
│   │   shell/waffleSettings.qml, shell/modules/settings/ModulesConfig.qml,
│   │   shell/modules/settings/ToolsConfig.qml,
│   │   shell/modules/waffle/settings/pages/WModulesPage.qml,
│   │   shell/modules/waffle/settings/WSettingsContent.qml
│   ├── onboarding writers: shell/welcome.qml, shell/setup
│   ├── CLI/IPC: shell/scripts/ryoku-shell,
│   │   shell/scripts/lib/ipc-registry.sh,
│   │   shell/scripts/lib/generate-ipc-registry.py,
│   │   shell/scripts/completions/ryoku-shell.{bash,fish,zsh}
│   ├── binds: config/niri/config.d/70-binds.kdl,
│   │   shell/defaults/niri/config.d/70-binds.kdl,
│   │   shell/dots/.config/niri/config.kdl,
│   │   shell/scripts/niri-config.py,
│   │   shell/scripts/parse_niri_keybinds.py
│   ├── panel-family-aware surfaces: ShellIiPanels.qml, ShellWafflePanels.qml,
│   │   lock, clipboard, session screen, alt switcher, close confirm,
│   │   region selector, wallpaper selector, Waffle background/backdrop,
│   │   Waffle task view, Waffle session screen, Waffle clipboard
│   └── panel-family-aware services/scripts: ThemeService.qml, Wallpapers.qml,
│       AwwwBackend.qml, GowallService.qml, switchwall.sh, sync-pixel-sddm.py
│
├── ii family root: shell/ShellIiPanels.qml
│   ├── horizontal bar branch: shell/modules/bar/Bar.qml
│   ├── vertical bar branch: shell/modules/verticalBar/VerticalBar.qml
│   ├── shared ii panels loaded beside the bar:
│   │   background, backdrop, dock, control panel, media controls,
│   │   notification popup, OSD, keyboard, recorder OSD, overview,
│   │   polkit, region selector, screen corners, session screen,
│   │   sidebars, tiling overlay, wallpaper selector, ii overlay,
│   │   shell update, clipboard
│   └── gating branch: enabledPanels plus bar.vertical
│
├── Waffle family root: shell/ShellWafflePanels.qml
│   ├── taskbar branch: shell/modules/waffle/bar/WaffleBar.qml
│   ├── attached panels: action center, notification center,
│   │   start menu, widgets, task view, clipboard, notification popup,
│   │   Waffle OSD, Waffle backdrop/background, Waffle alt switcher
│   └── gating branch: enabledPanels, waffles.modules.*, waffles.background.*,
│       waffles.behavior.*, waffles.taskView.*, waffles.widgetsPanel.*
│
└── tools mode root: shell/modules/bar/ToolsModePanel.qml
    ├── visibility state: GlobalStates.toolsModeOpen
    ├── IPC singleton: shell/services/ToolsModeService.qml
    ├── config schema: bar.dynamicIsland.tools.*
    ├── UI: shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml
    ├── buttons: ToolButton.qml, ToolRegistry.qml
    └── action branches: screenshot, recorder, Google Lens, color picker,
        music recognition, mic toggle, OSK, caffeine, notepad, screen cast,
        dark mode, power profile
```

### Classic Bar Tree

```text
shell/modules/bar/Bar.qml
├── render state
│   ├── GlobalStates.barOpen
│   ├── GlobalStates.screenLocked
│   ├── GlobalStates.widgetEditMode
│   ├── GlobalStates.coverflowSelectorOpen
│   ├── GlobalStates.toolsModeOpen
│   ├── GlobalStates.superDown
│   ├── GameMode.shouldHidePanels
│   └── Appearance.sizes.barHeight/baseBarHeight/hyprlandGapsOut
├── geometry/config
│   ├── bar.bottom
│   ├── bar.screenList
│   ├── bar.showBackground
│   ├── bar.cornerStyle
│   ├── bar.autoHide.enable
│   ├── bar.autoHide.hoverRegionWidth
│   ├── bar.autoHide.pushWindows
│   └── interactions.deadPixelWorkaround.*
├── IPC/keybinds
│   ├── IpcHandler target "bar": toggle/open/close
│   └── Hyprland GlobalShortcut names: barToggle, barOpen, barClose
├── content: shell/modules/bar/BarContent.qml
└── shell chrome
    ├── round decorators
    ├── shadows/backgrounds
    └── layer-shell exclusiveZone
```

```text
shell/modules/bar/BarContent.qml
├── left side
│   ├── bar.modules.leftSidebarButton -> LeftSidebarButton.qml
│   │   ├── bar.topLeftIcon
│   │   ├── SystemInfo.distroIcon
│   │   ├── CustomIcon.qml
│   │   └── assets/icons/*-symbolic.svg
│   ├── bar.modules.activeWindow -> ActiveWindow.qml -> NiriService/Hyprland
│   ├── click branch -> GlobalStates.sidebarLeftOpen -> SidebarLeft.qml
│   ├── scroll branch -> bar.leftScrollAction -> Brightness, Audio, NiriService
│   └── hint branch -> bar.showScrollHints -> ScrollHint.qml
├── center/start modules
│   ├── bar.modules.resources -> Resources.qml -> Resource.qml
│   │   ├── ResourceUsage.qml
│   │   ├── resources.updateInterval/resources.monitorGpu
│   │   └── bar.resources.*
│   ├── bar.modules.media -> Media.qml
│   │   ├── MprisController.qml
│   │   ├── MediaControls.qml
│   │   ├── BarMediaPopup.qml
│   │   └── BarMediaPlayerItem.qml
│   ├── bar.modules.taskbar -> BarTaskbar.qml
│   │   ├── BarTaskbarButton.qml
│   │   ├── BarTaskbarPreview.qml
│   │   ├── BarTaskbarWindowPreview.qml
│   │   ├── TaskbarApps.qml
│   │   ├── WindowPreviewService.qml
│   │   ├── AppLauncher.qml/AppSearch.qml
│   │   └── dock pinned/ignored app config
│   ├── bar.modules.workspaces -> Workspaces.qml
│   │   ├── NiriService.qml
│   │   ├── bar.workspaces.*
│   │   ├── Overview.qml, OverviewWidget.qml, OverviewNiriWidget.qml
│   │   └── Background.qml workspace wallpaper behavior
│   └── context menu -> Mission Center/settings launch paths
├── center/end modules
│   ├── bar.modules.clock -> ClockWidget.qml -> ClockWidgetTooltip.qml
│   │   ├── DateTime.qml
│   │   └── time.*
│   ├── bar.modules.utilButtons -> UtilButtons.qml
│   │   ├── CircleUtilButton.qml
│   │   ├── bar.utilButtons.*
│   │   └── ToolRegistry.qml shared action tree
│   ├── bar.modules.battery -> BatteryIndicator.qml -> BatteryPopup.qml
│   │   ├── Battery.qml
│   │   └── battery.*
│   ├── TimerIndicator.qml -> TimerIndicatorTooltip.qml -> TimerService.qml
│   └── ShellUpdateIndicator.qml -> ShellUpdates.qml -> shellUpdates.*
├── right side
│   ├── bar.modules.rightSidebarButton -> right-sidebar toggle
│   ├── click branch -> GlobalStates.sidebarRightOpen/controlPanelOpen
│   │   ├── SidebarRight.qml
│   │   ├── SidebarRightContent.qml
│   │   ├── CompactSidebarRightContent.qml
│   │   ├── BottomWidgetGroup.qml
│   │   └── ControlPanel.qml
│   ├── scroll branch -> bar.rightScrollAction -> Brightness, Audio, NiriService
│   ├── bar.modules.sysTray -> SysTray.qml
│   │   ├── SysTrayItem.qml
│   │   ├── SysTrayMenu.qml
│   │   ├── SysTrayMenuEntry.qml
│   │   ├── TrayService.qml
│   │   └── bar.tray.*
│   ├── bar.modules.secPulse -> SecPulseIndicator.qml
│   │   ├── RyokuOpenVpn.qml
│   │   ├── RyokuTailscale.qml
│   │   └── sidebar right OpenVPN/Tailscale cards
│   └── bar.modules.weather + bar.weather.enable -> weather/WeatherBar.qml
│       ├── WeatherCard.qml
│       ├── WeatherPopup.qml
│       ├── Weather.qml
│       ├── bar.weather.*
│       └── waffles.widgetsPanel.weatherHideLocation
└── shared style
    ├── BarGroup.qml
    ├── StyledPopup.qml
    ├── Appearance.qml
    ├── common widgets/functions/models
    └── docs/ui-patterns.md for popup anchoring/padding
```

### Vertical Bar Tree

```text
shell/modules/verticalBar/VerticalBar.qml
├── shares the same public IPC target "bar" and GlobalStates.barOpen
├── uses bar.screenList, bar.bottom, bar.showBackground, bar.cornerStyle,
│   bar.autoHide.*, GameMode.shouldHidePanels, Appearance.sizes.verticalBarWidth
├── content: VerticalBarContent.qml
│   ├── top click -> GlobalStates.sidebarLeftOpen
│   ├── bottom click -> GlobalStates.sidebarRightOpen
│   ├── scroll -> brightness/volume OSD branches
│   ├── bar.modules.taskbar -> imports classic bar taskbar branch
│   ├── workspaces -> classic Workspaces.qml/NiriService branch
│   ├── media -> VerticalMedia.qml -> MediaControls/MprisController
│   ├── resources -> Resources.qml/Resource.qml -> ResourceUsage/bar.resources
│   ├── clock/date -> VerticalClockWidget.qml/VerticalDateWidget.qml
│   └── battery -> BatteryIndicator.qml -> Battery.qml
└── removal must stay aligned with iiBar because ModulesConfig treats iiBar and
    iiVerticalBar as one user-facing "Bar" toggle
```

### Waffle Taskbar Tree

```text
shell/modules/waffle/bar/WaffleBar.qml
├── render state
│   ├── GlobalStates.barOpen
│   ├── GameMode.shouldHidePanels
│   ├── waffles.bar.bottom
│   └── layer-shell exclusiveZone
├── IPC
│   └── IpcHandler target "wbar": toggle/open/close
└── content: WaffleBarContent.qml
```

```text
shell/modules/waffle/bar/WaffleBarContent.qml
├── layout/config
│   ├── waffles.bar.bottom
│   ├── waffles.bar.leftAlignApps
│   ├── waffles.bar.iconSize
│   ├── waffles.bar.searchIconSize
│   ├── waffles.bar.monochromeIcons
│   ├── waffles.bar.tintTrayIcons
│   ├── waffles.bar.desktopPeek.*
│   ├── waffles.bar.notifications.showUnreadCount
│   └── waffles.bar.activationWatermark.enable
├── start/search branch
│   ├── StartButton.qml
│   ├── SearchButton.qml
│   ├── WaffleStartMenu.qml
│   ├── startMenu/*.qml
│   └── AppSearch.qml/AppLauncher.qml
├── task branch
│   ├── tasks/Tasks.qml
│   ├── tasks/TaskAppButton.qml
│   ├── tasks/TaskPreview.qml
│   ├── tasks/WindowPreview.qml
│   ├── TaskbarApps.qml
│   ├── WindowPreviewService.qml
│   └── pin/unpin strings in translations
├── tray branch
│   ├── tray/Tray.qml
│   ├── tray/TrayButton.qml
│   ├── tray/TrayOverflowMenu.qml
│   ├── tray/WaffleTrayMenu.qml
│   ├── tray/WaffleTrayMenuEntry.qml
│   └── TrayService.qml
├── attached panel branches
│   ├── SystemButton.qml -> WaffleActionCenter.qml/actionCenter/*.qml
│   ├── TimeButton.qml -> WaffleNotificationCenter.qml/notificationCenter/*.qml
│   ├── WidgetsButton.qml -> WaffleWidgets.qml/widgets/*.qml
│   ├── TaskViewButton.qml -> WaffleTaskView.qml/taskview/*.qml
│   ├── DesktopPeekButton.qml -> Niri desktop/overview behavior
│   └── BarPopup.qml, BarMenu.qml, BarToolTip.qml, WBarAttachedPanelContent.qml
├── status branches
│   ├── TimerButton.qml -> TimerService.qml and sidebar bottom tab
│   ├── UpdatesButton.qml -> Updates.qml/ShellUpdates.qml
│   ├── WeatherButton.qml -> Weather.qml/bar.weather.*
│   └── TimeButton.qml -> DateTime.qml/Notifications.qml
└── visual system
    ├── qs.modules.waffle.looks/*
    ├── WSettingsContent.qml/WBarPage.qml/WThemesPage.qml/WWaffleStylePage.qml
    ├── waffles.settings.*, waffles.theming.*, waffles.background.*
    └── Waffle translations and docs
```

### Tools Mode Action Tree

```text
ToolsModePanel.qml
├── GlobalStates.toolsModeOpen
├── ToolsModeService.qml IPC target "toolsMode"
├── Config/Persistent bridge
│   ├── bar.dynamicIsland.tools.*
│   ├── bar.utilButtons.*
│   └── Persistent.dynamicIslandMigrated
├── RyokuToolsMode.qml -> ToolButton.qml -> ToolRegistry.qml
└── ToolRegistry action branches
    ├── screenshot -> ryoku-shell region screenshot -> regionSelector
    ├── record -> Persistent.states.overlay.open + RecorderStatus/overlay recorder
    ├── lens -> ryoku-shell region googleLens -> tests/google-lens-search.sh
    ├── colorPicker -> hyprpicker and ColorPicker quick toggles
    ├── musicRecognize -> SongRec.qml
    ├── micToggle -> Audio.qml
    ├── osk -> GlobalStates.oskOpen -> OnScreenKeyboard.qml
    ├── caffeine -> Idle.qml
    ├── notepad -> GlobalStates.sidebarRightRequestedWidget,
    │   SidebarRight.qml, BottomWidgetGroup.qml, NotepadWidget.qml
    ├── screenCast -> niri dynamic cast target, Persistent.states.screenCast,
    │   bar.utilButtons.screenCastOutput
    ├── darkMode -> MaterialThemeLoader.qml
    └── powerProfile -> global PowerProfiles, PowerProfilePersistence.qml,
        PowerProfilesToggle.qml, powerprofiles helper commands
```

### Config And Settings Writer Tree

```text
bar.* / waffles.bar.* roots
├── schema/defaults
│   ├── shell/modules/common/Config.qml
│   ├── shell/defaults/config.json
│   ├── default/ryoku-shell/config-overrides.json
│   └── install/config/ryoku-shell-branding.sh
├── user config and live/runtime copies
│   ├── ~/.config/ryoku-shell/config.json
│   ├── ~/.config/quickshell/ryoku-shell
│   ├── ~/.local/share/ryoku
│   ├── shell/sdata/runtime-payload-dirs.txt
│   ├── shell/sdata/runtime-root-files.txt
│   ├── shell/sdata/subcmd-install/3.files.sh
│   └── install/config/shell.sh
├── settings writers
│   ├── shell/ryokuSettings.qml
│   ├── shell/settings.qml
│   ├── shell/modules/settings/BarConfig.qml
│   ├── shell/modules/settings/GeneralConfig.qml
│   ├── shell/modules/settings/QuickConfig.qml
│   ├── shell/modules/settings/ServicesConfig.qml
│   ├── shell/modules/settings/InterfaceConfig.qml
│   ├── shell/modules/settings/ModulesConfig.qml
│   ├── shell/modules/settings/ThemesConfig.qml
│   ├── shell/modules/settings/WaffleConfig.qml
│   ├── shell/modules/settings/SettingsOverlay.qml
│   ├── shell/modules/waffle/settings/pages/WBarPage.qml
│   ├── shell/modules/waffle/settings/pages/WGeneralPage.qml
│   ├── shell/modules/waffle/settings/pages/WModulesPage.qml
│   ├── shell/modules/waffle/settings/pages/WThemesPage.qml
│   ├── shell/modules/waffle/settings/pages/WWaffleStylePage.qml
│   └── shell/welcome.qml
├── other writers
│   ├── shell/setup
│   ├── shell/scripts/colors/switchwall.sh
│   ├── shell/scripts/sddm/sync-pixel-sddm.py
│   ├── shell/services/Ai.qml config write tool descriptions
│   ├── shell/services/ShellUpdates.qml enabledPanels writer
│   └── shell/modules/common/Persistent.qml migration marker
└── migrations/tests/docs
    ├── migrations/1777852554.sh
    ├── migrations/1778022724.sh
    ├── migrations/1778252246.sh
    ├── migrations/1778256447.sh
    ├── migrations/1778563633.sh
    ├── tests/topbar-removal-regression.sh
    ├── tests/dynamic-island-ipc.sh
    ├── tests/bar-secpulse.sh
    ├── tests/ryoku-shell-branding.sh
    ├── tests/ryoku-settings-official.sh
    ├── tests/niri-keybinds.sh
    ├── tests/terminal-launchers.sh
    ├── tests/sidebar-requested-widget-notepad.sh
    └── docs/translations/site/shell docs listed above
```

### Branches Not To Delete Blindly

- `panelFamily` is larger than the bar. It also selects lock/session/clipboard,
  Waffle background/backdrop, theme pipeline, wallpaper behavior, SDDM sync, and
  several generated keybind docs. Remove or replace it only with a full family
  migration.
- `GlobalStates.barOpen` is shared by classic, vertical, and Waffle bars. A new
  bar should either own a replacement state name or keep this one intentionally.
- `enabledPanels` is the public panel gating model. If `iiBar`, `iiVerticalBar`,
  or `wBar` disappear, every settings page, default, test, CLI path, and
  migration that names them must be updated.
- `bar.dynamicIsland.tools.*` is current tools-mode config despite the old path
  name. Do not delete it as "old island" without replacing Mod+S/toolkit config.
- `bar.utilButtons.*` still bridges into the same tools action registry. Remove
  only after a migration or explicit compatibility decision.
- `bar.weather.*` feeds both classic weather and Waffle weather/widget settings.
- `bar.workspaces.*` feeds bar workspaces, overview scroll behavior, and
  wallpaper per-workspace behavior.
- `bar.resources.*` and `resources.*` feed both bar indicators and sidebar/OSD
  resource views.
- `bar.topLeftIcon` reaches into `SystemInfo`, `CustomIcon`, bundled assets,
  branding install, and translations/docs around the Ryoku logo.
- Waffle `waffles.bar.*` is only the taskbar root; adjacent behavior also lives
  under `waffles.widgetsPanel.*`, `waffles.background.*`, `waffles.taskView.*`,
  `waffles.notifications.*`, and `waffles.actionCenter.*`.
- Removing visible bar modules without updating `shell/translations/*.json`
  leaves stale user-facing strings in settings/search.
- Removing files from the repo is not enough. The runtime sync path must delete
  old files from `~/.config/quickshell/ryoku-shell` and `~/.local/share/ryoku`.

## Live Mirror System Tree

This section records the repo plus live mirror scan from May 19, 2026. Re-run
these checks before removing bar code because the user config and runtime mirror
can drift independently of the source checkout.

### Active Live Roots

```text
repo source
└── /home/carlos/prowl/ryoku-arch
    └── shell/

installed Ryoku mirror
└── /home/carlos/.local/share/ryoku
    ├── shell/
    ├── VERSION
    └── .git

active Quickshell runtime
└── /home/carlos/.config/quickshell/ryoku-shell
    ├── shell.qml
    ├── modules/
    ├── services/
    ├── defaults/config.json
    ├── version.json
    └── .ryoku-manifest

user shell config/state
└── /home/carlos/.config/ryoku-shell
    ├── config.json
    ├── version
    ├── version.json
    ├── migrations.json
    ├── installed_listfile
    └── widgets/

service and launcher
├── /home/carlos/.config/systemd/user/ryoku-shell.service
└── /home/carlos/.local/bin/ryoku-shell
```

Active service state during the scan:

- `ryoku-shell.service` was active/running.
- `ExecStart=/home/carlos/.local/bin/ryoku-shell run --session`.
- `qs list --all` reported active config path `/home/carlos/.config/quickshell/ryoku-shell/shell.qml`.
- Latest live recheck reported instance `ml0c9ycbft`, process ID `560650`, launched `2026-05-19 22:15:45`.
- The runtime `version.json` reported `0.1.0-alpha-4`, commit `ce23bfde`, source `setup-install`, install mode `repo-copy`, repo path `/home/carlos/.local/share/ryoku`.
- The runtime `.ryoku-manifest` was generated at `2026-05-19T18:13:50-04:00` for commit `ce23bfde`.

### Live File Set Parity

The direct bar file sets existed in all three layers:

| Layer | Classic bar | Vertical bar | Waffle bar | Waffle settings | Legacy settings |
| --- | ---: | ---: | ---: | ---: | ---: |
| `/home/carlos/prowl/ryoku-arch/shell` | 41 | 8 | 30 | 29 | 26 |
| `/home/carlos/.local/share/ryoku/shell` | 41 | 8 | 30 | 29 | 26 |
| `/home/carlos/.config/quickshell/ryoku-shell` | 41 | 8 | 30 | 29 | 26 |

The active runtime intentionally does not carry every repo documentation/support
file:

- Runtime `docs/` is missing.
- Runtime `defaults/` has one fewer file than repo/mirror because `defaults/ai/README.md` is not copied.
- Runtime `sdata/` has fewer support files because README/gitignore files are not copied.
- Runtime `scripts/` has fewer support files than the repo because README and generated/cache files differ.

These are not bar renderer gaps by themselves, but the delete/sync path must
still be checked whenever directories are renamed or removed.

### Live Content Drift

Direct bar directories have matching filenames, but the current repo is ahead of
the installed mirror/runtime in several bar-connected files:

| Branch | Drift found |
| --- | --- |
| `shell/modules/bar/BarTaskbarButton.qml` | Repo removed/changed a live Spotify desktop-id special case. Live runtime still maps `spotify` and `spotify-launcher` to `spotify-launcher`. |
| `shell/modules/bar/Workspaces.qml` | Repo uses stricter `bool`/`real` properties and null-safe occupied checks. Live runtime still has older `var` properties. |
| `shell/services/GlobalActions.qml` | Repo schedules quick recorder status checks after start/stop. Live runtime does not. |
| `shell/services/MprisController.qml` | Repo adds `zen` browser-player filtering. Live runtime lacks part of that filter. |
| `shell/services/RecorderStatus.qml` | Repo splits idle and active recording polling and adds quick checks. Live runtime has older 1s polling behavior. |
| `shell/services/ResourceUsage.qml` | Repo prefers Ryzen `Tdie` and GPU `edge` temps. Live runtime takes the first temp input. This affects bar resources. |
| `shell/services/ShellUpdates.qml` | Repo points diagnostics to `ryoku-doctor`. Live runtime still references `./setup doctor`. This affects bar update warnings. |
| `shell/services/SystemInfo.qml` | Live runtime has a 15s identity refresh timer not present in repo. This can affect top-left distro/logo state. |
| `shell/services/TrayService.qml` | Repo uses `LaunchUtils.launchByDesktopId`; live runtime uses shell commands and has a Spotify launcher special case. This affects tray behavior. |
| `shell/services/Wallpapers.qml` | Repo has thumbnail-known tracking not present in live runtime. This is panel-family and Waffle-background adjacent. |
| `shell/ryokuSettings.qml` | Runtime matches repo, but installed mirror differs and has it as untracked in the mirror git status. Settings changes must be checked in both runtime and mirror. |
| `shell/defaults/config.json` | Repo and installed mirror defaults match, but active runtime defaults differ. Runtime defaults are not enough; user config is the real live state. |
| `shell/sdata/subcmd-install/3.files.sh` | Repo differs from mirror/runtime. This is a critical path for deleting old bar files from active runtime during a rework. |

Installed mirror git status also had unrelated dirty/untracked files during the
scan:

- Modified: `/home/carlos/.local/share/ryoku/config/niri/config.d/30-window-rules.kdl`
- Modified: `/home/carlos/.local/share/ryoku/shell/defaults/niri/config.d/30-window-rules.kdl`
- Modified: `/home/carlos/.local/share/ryoku/shell/modules/common/Config.qml`
- Modified: `/home/carlos/.local/share/ryoku/shell/modules/common/widgets/GlassBackground.qml`
- Modified: `/home/carlos/.local/share/ryoku/shell/modules/settings/DesktopWidgetsConfig.qml`
- Modified: `/home/carlos/.local/share/ryoku/shell/modules/settings/ExtrasConfig.qml`
- Modified: `/home/carlos/.local/share/ryoku/shell/scripts/ryoku-shell`
- Modified: `/home/carlos/.local/share/ryoku/shell/services/qmldir`
- Modified: `/home/carlos/.local/share/ryoku/shell/shell.qml`
- Untracked: `/home/carlos/.local/share/ryoku/shell/ryokuSettings.qml`
- Untracked: `/home/carlos/.local/share/ryoku/shell/services/CavaTheme.qml`
- Untracked: `/home/carlos/.local/share/ryoku/tests/noctalia-settings-prototype.sh`

Do not assume repo, mirror, and runtime are content-identical just because the
bar file names line up.

### Live User Config Root

The live user config at `/home/carlos/.config/ryoku-shell/config.json` is a
separate root and must be migrated explicitly. During the scan it contained:

```text
panelFamily=ii
enabledPanels includes both ii and Waffle panel IDs:
  iiBar, iiVerticalBar, iiBackground, iiBackdrop, iiDock, iiOverview,
  iiScreenCorners, iiClipboard, iiShellUpdate, wBar, wBackground, wBackdrop,
  wStartMenu, wActionCenter, wNotificationCenter, wNotificationPopup,
  wOnScreenDisplay, wWidgets, wTaskView, wLock, wPolkit, wSessionScreen

bar.bottom=false
bar.vertical=false
bar.cornerStyle=0
bar.borderless=true
bar.leftScrollAction=brightness
bar.rightScrollAction=workspace

bar.modules:
  activeWindow=true
  battery=true
  clock=true
  dateLabel=true
  kanjiClock=true
  leftSidebarButton=true
  media=true
  resources=false
  rightSidebarButton=true
  secPulse=false
  sysTray=false
  taskbar=false
  utilButtons=false
  weather=false
  weatherIcon=true
  workspaces=true

bar.dynamicIsland.tools.buttons:
  caffeine=true
  colorPicker=true
  darkMode=false
  lens=true
  micToggle=true
  musicRecognize=true
  notepad=true
  osk=false
  powerProfile=false
  record=true
  screenCast=false
  screenshot=true

waffles.bar:
  bottom=true
  iconSize=26
  searchIconSize=24
  leftAlignApps=false
  monochromeIcons=false
  tintTrayIcons=false
  desktopPeek.hoverDelay=500
  desktopPeek.hoverPeek=false
  notifications.showUnreadCount=true
  activationWatermark.enable=true
```

Every replacement must decide whether to preserve, migrate, or delete these user
keys. Do not only change `shell/defaults/config.json`.

### Live Removal Checklist

To remove the current bar without loose ends, handle all layers in this order:

```text
1. Repo source
   ├── remove/replace shell/modules/bar
   ├── remove/replace shell/modules/verticalBar
   ├── remove/replace shell/modules/waffle/bar if Waffle taskbar is affected
   ├── update shell/ShellIiPanels.qml and shell/ShellWafflePanels.qml
   ├── update shell/shell.qml panelFamilies, IPC, and ToolsModePanel ownership
   └── update services and adjacent panels listed in the root tree

2. Config schema and migrations
   ├── shell/modules/common/Config.qml
   ├── shell/defaults/config.json
   ├── default/ryoku-shell/config-overrides.json
   ├── install/config/ryoku-shell-branding.sh
   ├── migrations/*
   └── /home/carlos/.config/ryoku-shell/config.json migration behavior

3. Settings and user-facing text
   ├── shell/ryokuSettings.qml
   ├── shell/settings.qml and modules/settings/*
   ├── shell/waffleSettings.qml and modules/waffle/settings/*
   ├── shell/welcome.qml
   ├── shell/translations/*.json
   └── docs and README pages listed above

4. Runtime sync and delete behavior
   ├── install/config/shell.sh
   ├── shell/sdata/subcmd-install/3.files.sh
   ├── shell/sdata/runtime-payload-dirs.txt
   ├── shell/sdata/runtime-root-files.txt
   ├── /home/carlos/.local/share/ryoku/shell
   ├── /home/carlos/.config/quickshell/ryoku-shell
   └── /home/carlos/.config/quickshell/ryoku-shell/.ryoku-manifest

5. Service and launcher
   ├── /home/carlos/.local/bin/ryoku-shell
   ├── /home/carlos/.config/systemd/user/ryoku-shell.service
   ├── shell/scripts/ryoku-shell
   ├── shell/scripts/lib/ipc-registry.sh
   └── config/niri + shell/defaults/niri binds

6. Verification
   ├── qs list --all
   ├── systemctl --user is-active ryoku-shell.service
   ├── targeted search in repo, mirror, and runtime
   ├── check config keys in /home/carlos/.config/ryoku-shell/config.json
   ├── check stale files under /home/carlos/.config/quickshell/ryoku-shell
   └── run/update tests that mention bar, wbar, taskbar, topbar, toolsMode
```

Do not hot-copy only one layer and call the bar removed. The installed mirror,
runtime copy, user config, manifest, service, and docs/tests are separate
branches.

### Broad Bar-Term Scan Reviewed

A final broad scan across repo source, installed mirror, and active runtime used
bar/topbar/taskbar/statusbar/vertical-bar/panel/exclusive-zone terms. These hits
are not primary shell bar roots, but they were reviewed because they contain
generic bar wording, scroll/progress/media bars, Cava bars, status bars,
side-panel wording, or mirrored docs/config that could otherwise look like
missed loose ends.

Repo/install-system hits outside the main root tree:

- `install/config/hardware/network.sh`
- `install/profiles/music-rmpc/setup.sh`
- `migrations/1773599943.sh`
- `tests/cava-config-system.sh`
- `tests/desktop-widget-visualizer.sh`
- `tests/inir-post-v225-upstream-fixes.sh`
- `tests/recorder-widget-redesign.sh`

Shell docs, dotconfig, and issue-template hits:

- `shell/.github/ISSUE_TEMPLATE/bug_report.yml`
- `shell/.github/ISSUE_TEMPLATE/question.yml`
- `shell/defaults/kde/dolphinrc`
- `shell/docs/AUDIO_MEDIA.md`
- `shell/docs/INSTALL.md`
- `shell/docs/PACKAGES.md`
- `shell/docs/VESKTOP.md`
- `shell/docs/readme/README.de.md`
- `shell/docs/readme/README.es.md`
- `shell/docs/readme/README.fr.md`
- `shell/docs/readme/README.pt.md`
- `shell/docs/stylesheets/extra.css`
- `shell/dots/.config/dolphinrc`
- `shell/dots/.config/vesktop/themes/system24.theme.css`
- `shell/dots/sddm/pixel/VirtualKeyboard.qml`

Shell widget/module hits from generic bar wording:

- `shell/modules/background/widgets/AbstractBackgroundWidget.qml`
- `shell/modules/background/widgets/battery/BatteryWidget.qml`
- `shell/modules/background/widgets/systemMonitor/SystemMonitorWidget.qml`
- `shell/modules/background/widgets/visualizer/VisualizerWidget.qml`
- `shell/modules/common/functions/parallax.js`
- `shell/modules/common/widgets/CavaProcess.qml`
- `shell/modules/common/widgets/StyledSlider.qml`
- `shell/modules/common/widgets/ToastNotification.qml`
- `shell/modules/controlPanel/MediaSection.qml`
- `shell/modules/controlPanel/SystemSection.qml`
- `shell/modules/lock/LockMediaWidget.qml`
- `shell/modules/lock/LockSurface.qml`
- `shell/modules/mediaControls/PlayerControl.qml`
- `shell/modules/mediaControls/components/PlayerProgress.qml`
- `shell/modules/mediaControls/presets/AlbumArtPlayer.qml`
- `shell/modules/mediaControls/presets/ClassicPlayer.qml`
- `shell/modules/mediaControls/presets/CompactPlayer.qml`
- `shell/modules/mediaControls/presets/FullPlayer.qml`
- `shell/modules/mediaControls/presets/MinimalPlayer.qml`
- `shell/modules/mediaControls/presets/VisualizerPlayer.qml`
- `shell/modules/onScreenDisplay/indicators/BrightnessIndicator.qml`
- `shell/modules/settings/AdvancedConfig.qml`
- `shell/modules/settings/AuroraStyleEditor.qml`
- `shell/modules/settings/CheatsheetConfig.qml`
- `shell/modules/settings/CustomThemeEditor.qml`
- `shell/modules/settings/NiriConfig.qml`
- `shell/modules/shellUpdate/ShellUpdateOverlay.qml`
- `shell/modules/sidebarLeft/SoftwareView.qml`
- `shell/modules/sidebarLeft/WallhavenView.qml`
- `shell/modules/sidebarLeft/plugins/WebAppView.qml`
- `shell/modules/sidebarLeft/widgets/DraggableWidgetContainer.qml`
- `shell/modules/sidebarLeft/widgets/MediaPlayerWidget.qml`
- `shell/modules/sidebarRight/CompactMediaPlayer.qml`
- `shell/modules/sidebarRight/events/EventCard.qml`
- `shell/modules/waffle/clipboard/WaffleClipboardContent.qml`
- `shell/modules/waffle/looks/Looks.qml`

Shell script/service/support hits from generic bar wording:

- `shell/scripts/cava/generate_config.sh`
- `shell/scripts/cava/raw_output_config.txt`
- `shell/scripts/colors/apply-spicetify-theme.sh`
- `shell/scripts/colors/generate_terminal_configs.py`
- `shell/scripts/colors/modules/80-pear-desktop.sh`
- `shell/scripts/colors/modules/90-cava.sh`
- `shell/scripts/colors/system24_palette.py`
- `shell/scripts/colors/vscode/theme_generator.py`
- `shell/scripts/colors/vscode_themegen/main.go`
- `shell/scripts/emoji/emoji-data.sh`
- `shell/scripts/quickshell-webengine/build-quickshell-webengine.sh`
- `shell/scripts/thumbnails/thumbgen.py`
- `shell/sdata/dist-arch/ryoku-deps/PKGBUILD`
- `shell/sdata/lib/conflicts.sh`
- `shell/sdata/lib/package-installers.sh`
- `shell/sdata/lib/tui.sh`
- `shell/services/Cava.qml`
- `shell/services/RyokuHosts.qml`

## Loose Ends To Resolve During Rework

- `bar` and `wbar` IPC targets both operate on visible bar state but are separate targets. Decide whether the rework keeps separate targets or exposes one unified command surface.
- `GlobalStates.barOpen` is shared by classic and Waffle bars. Redesign this intentionally if both families stay.
- `bar.dynamicIsland.*` now primarily controls the tools mode, not the removed Three-Island bar. Rename or migrate this config if the rework removes the old concept.
- `shell/modules/bar/threeIsland/dynamicIsland/tools/*` is a confusing path for current tools mode. Moving it requires updating imports, tests, defaults, IPC docs, and runtime payload lists.
- `bar.utilButtons.*` and `bar.dynamicIsland.tools.*` are overlapping tool configuration models. Consolidate them or keep a migration bridge.
- `bar.modulesLayout`, `bar.modulesPlacement`, and `bar.edgeModulesLayout` are declared in config/defaults, but current `BarContent.qml` appears hard-coded. Verify whether these are dead settings before removing them.
- `bar.blurBackground.*` exists in `Config.qml`; verify whether any renderer still uses it.
- `bar.vignette.*` is controlled in legacy settings and used by `Backdrop.qml`, while `BarVignette.qml` appears legacy. Decide one ownership model.
- `bar.modules.kanjiClock`, `bar.modules.dateLabel`, `bar.modules.weatherIcon`, and `bar.kanjiClock.*` are set by defaults/branding, but the current visible classic bar path mainly uses `ClockWidget.qml` and `WeatherBar.qml`. Verify live usage before keeping them.
- `bar.topLeftIcon` defaults to `ryoku` in `Config.qml` and `shell/defaults/config.json`; branding installs several icon assets. Keep the source-of-truth default explicit.
- `bar.screenList` affects horizontal bar, vertical bar, and tools mode. Preserve or replace this multi-monitor model deliberately.
- Official `shell/ryokuSettings.qml` does not have parity with legacy `BarConfig.qml` or Waffle `WBarPage.qml`. A full settings rework should decide which pages survive.
- Classic bar click zones currently toggle left sidebar, right sidebar, control panel, and overview. Preserve or replace every interaction intentionally.
- Classic bar scroll zones control brightness, volume, or workspaces through `bar.leftScrollAction` and `bar.rightScrollAction`. Rework settings must not leave those keys orphaned.
- Waffle and ii bars share weather, timer, updates, notification count, tray, app/task, and workspace services. Removing one family should not break shared services used elsewhere.
- `install/config/shell.sh`, `shell/sdata/runtime-payload-dirs.txt`, and `shell/sdata/runtime-root-files.txt` must be checked after any file move so removed bar files do not survive in the installed runtime copy.
- Existing docs still mention topbar islands and user-customizable bar widgets. Rewrite docs when the new bar model lands.
- Tests encode removed Three-Island behavior and current SecPulse/tools assumptions. Update tests in the same change as any bar/settings rewrite.

## Static Search Notes

This map was built from direct path search for bar/taskbar/topbar/island/panel
names, direct config searches for `bar.*` and `waffles.bar.*`, and import scans
inside classic/vertical/Waffle bar modules. Files that only contain unrelated
third-party application theme keys such as editor `status_bar` colors were not
included, because they do not affect the Ryoku shell bar rework.
