//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env RYOKU_SHELL_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ApplicationWindow {
  id: app

  visible: true
  width: 860
  height: 660
  minimumWidth: 760
  minimumHeight: 560
  title: "Ryoku Settings"
  color: "transparent"
  flags: Qt.Window | Qt.FramelessWindowHint
  onClosing: Qt.quit()

  property int currentPage: 0
  property bool easyMode: Config.options?.settingsUi?.easyMode ?? false
  readonly property var visibleTabsModel: {
    const out = [];
    for (let i = 0; i < tabsModel.length; i++) {
      const tab = tabsModel[i];
      if (!app.easyMode || tab.essential === true) {
        out.push(Object.assign({}, tab, { realIndex: i }));
      }
    }
    return out;
  }

  function setEasyMode(enabled) {
    Config.setNestedValue("settingsUi.easyMode", enabled === true);
    app.easyMode = enabled === true;
    if (enabled && !(app.tabsModel[app.currentPage]?.essential)) {
      app.currentPage = 0;
    }
  }
  property string searchText: ""
  property string themeSearchText: ""
  property string themeFilter: "all"
  property string advancedPrefix: "appearance"
  property var subTabState: ({})
  property var activeDropdown: null
  property bool uiReady: Config.ready
  property var outputList: []
  property int selectedOutputIndex: 0
  property bool outputReady: false
  property string displayStatus: ""
  property string displayPendingOutput: ""
  property string displayPendingKey: ""
  property string displayPendingValue: ""
  property var layoutData: ({})
  property var windowRulesData: ({})
  property var inputData: ({})
  property var cursorThemes: []
  property string niriStatus: ""
  property string windowRulesStatus: ""
  property string inputStatus: ""
  property string lastSetSection: ""
  property var setRequestQueue: []

  readonly property bool centeredMode: (Quickshell.env("RYOKU_SETTINGS_MODE") || "centered") !== "window"
  readonly property int sidebarWidth: 216
  readonly property int scrollGutterWidth: 18
  readonly property int frameMargin: 8
  readonly property int panelRadius: 14
  readonly property int cardRadius: 12
  readonly property int rowHeight: 42
  readonly property int contentMaxWidth: 620
  readonly property int fastDuration: Appearance.calcEffectiveDuration(120)
  readonly property int normalDuration: Appearance.calcEffectiveDuration(180)

  readonly property bool auroraStyle: Appearance.auroraEverywhere && !Appearance.ryokuEverywhere
  readonly property bool auroraLightStyle: auroraStyle && !Appearance.m3colors.darkmode
  readonly property real auroraFrameTransparency: auroraLightStyle ? 0.04 : 0.05
  readonly property real auroraPaneTransparency: auroraLightStyle ? 0.07 : 0.08
  readonly property real auroraCardTransparency: auroraLightStyle ? 0.10 : 0.10
  readonly property real auroraFrameWallpaperOpacity: 0.0
  readonly property real auroraPaneWallpaperOpacity: 0.0
  readonly property real auroraCardWallpaperOpacity: 0.0
  readonly property color ryokuWindowColor: auroraLightStyle ? "#f5f2ec" : "#15181a"
  readonly property color ryokuSurfaceColor: auroraLightStyle ? "#ece9e3" : "#191d20"
  readonly property color ryokuSurfaceVariantColor: auroraLightStyle ? "#fbf8f2" : "#101315"
  readonly property color windowColor: auroraStyle ? ryokuWindowColor : Appearance.colors.colLayer0
  readonly property color surfaceColor: auroraStyle ? ryokuSurfaceColor : Appearance.colors.colLayer1
  readonly property color surfaceVariantColor: auroraStyle ? ryokuSurfaceVariantColor : Appearance.colors.colLayer2
  readonly property color popupSurfaceColor: auroraStyle ? surfaceVariantColor : Appearance.colors.colLayer2Base
  readonly property color hoverColor: auroraStyle ? (auroraLightStyle ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.07)) : Appearance.colors.colLayer2Hover
  readonly property color activeColor: auroraStyle ? (auroraLightStyle ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.10)) : Appearance.colors.colLayer2Active
  readonly property color borderColor: auroraStyle ? Qt.alpha(textColor, auroraLightStyle ? 0.18 : 0.16) : Appearance.colors.colLayer0Border
  readonly property color textColor: auroraLightStyle ? "#201c18" : Appearance.colors.colOnLayer0
  readonly property color subtextColor: auroraLightStyle ? "#4e463d" : Appearance.colors.colSubtext
  readonly property color primaryColor: Appearance.colors.colPrimary
  readonly property color onPrimaryColor: Appearance.colors.colOnPrimary
  readonly property color selectedTextColor: readableOn(primaryColor)
  readonly property color quietSelectedColor: auroraLightStyle ? "#050505" : primaryColor
  readonly property color quietSelectedTextColor: auroraLightStyle ? "#f7f4ef" : selectedTextColor
  readonly property color successColor: Appearance.colors.colSecondary
  readonly property string scriptPath: Quickshell.shellPath("scripts/niri-config.py")

  readonly property var currentOutput: outputList.length > selectedOutputIndex ? outputList[selectedOutputIndex] : null
  readonly property string currentOutputName: currentOutput?.name ?? ""
  readonly property string currentResolution: currentOutput?.current_resolution ?? ""
  readonly property real currentRate: currentOutput?.current_rate ?? 0
  readonly property string currentRateString: currentOutput?.current_rate_string ?? (currentRate > 0 ? currentRate.toFixed(3) : "")
  readonly property real currentScale: currentOutput?.scale ?? 1.0
  readonly property string currentTransform: currentOutput?.transform ?? "normal"
  readonly property bool vrrSupported: currentOutput?.vrr_supported ?? false
  readonly property bool vrrEnabled: currentOutput?.vrr_enabled ?? false
  readonly property var cursorData: inputData?.cursor ?? ({})
  readonly property var mouseData: inputData?.mouse ?? ({})
  readonly property var touchpadData: inputData?.touchpad ?? ({})
  readonly property var keyboardData: inputData?.keyboard ?? ({})
  readonly property var generalInputData: inputData?.general ?? ({})

  readonly property string themeModeSummary: "Light | Dark | Auto | Schedule"

  readonly property var globalStyleOptions: [
    { label: "Material", value: "material" },
    { label: "Cards", value: "cards" },
    { label: "Aurora", value: "aurora" },
    { label: "Ryoku", value: "ryoku-shell" },
    { label: "Angel", value: "angel" }
  ]

  readonly property var paletteVariantOptions: [
    { label: "Auto", value: "auto" },
    { label: "Content", value: "scheme-content" },
    { label: "Expressive", value: "scheme-expressive" },
    { label: "Fidelity", value: "scheme-fidelity" },
    { label: "Neutral", value: "scheme-neutral" },
    { label: "Monochrome", value: "scheme-monochrome" },
    { label: "Rainbow", value: "scheme-rainbow" },
    { label: "Tonal spot", value: "scheme-tonal-spot" }
  ]

  readonly property var themeModeOptions: [
    { label: "Light", value: "light", icon: "light_mode" },
    { label: "Dark", value: "dark", icon: "dark_mode" },
    { label: "Auto", value: "auto", icon: "auto_mode" },
    { label: "Schedule", value: "schedule", icon: "routine" }
  ]

  readonly property var aiProviderFormatOptions: [
    { label: "OpenAI compatible", value: "openai" },
    { label: "Gemini", value: "gemini" },
    { label: "Mistral", value: "mistral" },
    { label: "Anthropic", value: "anthropic" },
    { label: "Responses API", value: "openai-response" }
  ]

  readonly property var legacyMigrationLabels: [
    "Themes",
    "Panels",
    "Modules",
    "Services",
    "Advanced",
    "Shortcuts",
    "Tools",
    "Waffle Style",
    "Compositor",
    "Login screen",
    "Desktop Widgets",
    "Extras"
  ]

  readonly property var legacyCoveragePaths: [
    "appearance.typography.titleFont",
    "appearance.wallpaperTheming.enableAppsAndShell",
    "appearance.wallpaperTheming.terminals.kitty",
    "appearance.cava.sensitivity",
    "appearance.globalStyleCornerStyles.material",
    "appearance.transparency.backgroundTransparency",
    "background.backdrop.enable",
    "background.transition.duration",
    "background.parallax.enable",
    "background.enableAnimation",
    "background.effects.enableBlur",
    "background.widgets.clock.enable",
    "bar.modules.sysTray",
    "bar.modules.rightSidebarButton",
    "bar.resources.cpuWarningThreshold",
    "bar.tray.monochromeIcons",
    "bar.utilButtons.showScreenRecord",
    "bar.workspaces.alwaysShowNumbers",
    "dock.enable",
    "controlPanel.compactMode",
    "sidebar.leftWidth",
    "altSwitcher.preset",
    "notifications.timeoutNormal",
    "notifications.timeoutCritical",
    "osd.timeout",
    "lock.clock.style",
    "display.primaryMonitor",
    "screenRecord.qualityPreset",
    "screenRecord.videoCodec",
    "screenRecord.discordCompress.targetSizeMb",
    "regionSelector.screenshotNameFormat",
    "apps.terminal",
    "updates.checkInterval",
    "enabledPanels",
    "panelFamily",
    "resources.updateInterval",
    "gameMode.autoDetect",
    "gameMode.disableEffects",
    "waffles.modules.widgets"
  ]

  readonly property var advancedPrefixOptions: [
    { label: "Appearance", value: "appearance" },
    { label: "Wallpaper and desktop", value: "background" },
    { label: "Bar", value: "bar" },
    { label: "Dock", value: "dock" },
    { label: "Control center", value: "controlPanel" },
    { label: "Sidebar", value: "sidebar" },
    { label: "Launcher", value: "search" },
    { label: "Notifications", value: "notifications" },
    { label: "On-Screen Display", value: "osd" },
    { label: "Sounds", value: "sounds" },
    { label: "Audio", value: "audio" },
    { label: "Display", value: "display" },
    { label: "Screen recorder", value: "screenRecord" },
    { label: "Region capture", value: "regionSelector" },
    { label: "Apps", value: "apps" },
    { label: "Lock screen", value: "lock" },
    { label: "Idle and power", value: "idle" },
    { label: "Panels", value: "enabledPanels" },
    { label: "Modules", value: "modules" },
    { label: "Waffle", value: "waffles" },
    { label: "Compositor", value: "compositor" },
    { label: "Overview", value: "overview" },
    { label: "Updates", value: "updates" },
    { label: "Settings UI", value: "settingsUi" }
  ]

  readonly property var tabsModel: [
    { key: "general", name: "General", icon: "tune", desc: "Quick rice, window, fonts", essential: true, source: generalPage },
    { key: "appearance", name: "Appearance", icon: "palette", desc: "Color Scheme, themes, style", essential: true, source: appearancePage },
    { key: "wallpaper", name: "Wallpaper & Desktop", icon: "wallpaper", desc: "Wallpaper, widgets, effects", essential: false, source: wallpaperPage },
    { key: "barDock", name: "Bar & Dock", icon: "border_top", desc: "Bar, dock, tray, modules", essential: true, source: barDockPage },
    { key: "panels", name: "Panels & Modules", icon: "dashboard", desc: "Panels, Waffle, compositor", essential: true, source: panelsPage },
    { key: "control", name: "Control Center", icon: "instant_mix", desc: "Sidebar, quick cards", essential: true, source: controlCenterPage },
    { key: "launcher", name: "Launcher", icon: "search", desc: "Search, actions, shortcuts", essential: true, source: launcherPage },
    { key: "notifications", name: "Notifications", icon: "notifications", desc: "Popups, OSD, sounds", essential: true, source: notificationsPage },
    { key: "audioDisplay", name: "Audio & Display", icon: "monitor", desc: "Audio, screens, resources", essential: true, source: audioDisplayPage },
    { key: "lockPower", name: "Lock & Power", icon: "lock", desc: "Lock screen, session menu", essential: true, source: lockPowerPage },
    { key: "services", name: "Services", icon: "settings", desc: "AI, idle, networking, updates", essential: false, source: servicesPage },
    { key: "tools", name: "Tools & Capture", icon: "construction", desc: "Recording, region, apps", essential: false, source: toolsPage },
    { key: "advanced", name: "Advanced", icon: "manufacturing", desc: "Expert settings inspector", essential: false, source: advancedPage },
    { key: "extras", name: "Extras", icon: "extension", desc: "Optional feature profiles", essential: true, source: extrasPage },
    { key: "about", name: "About", icon: "info", desc: "Version and config paths", essential: true, source: aboutPage }
  ]

  readonly property var settingsSearchIndex: [
    { label: "Quick Rice", desc: "Favorite themes, wallpaper colors, transparency, focus ring, cursor, and packages", page: "General", subTab: 0 },
    { label: "Default font", desc: "Main interface font", page: "General", subTab: 2 },
    { label: "Settings window mode", desc: "Centered panel or normal window", page: "General", subTab: 1 },
    { label: "Color Scheme", desc: "Shell style and light/dark mode", page: "Appearance", subTab: 0 },
    { label: "Light mode", desc: "Theme mode: Light, Dark, Auto, Schedule", page: "Appearance", subTab: 0 },
    { label: "Full themes", desc: "Shell presets and compatibility themes", page: "Appearance", subTab: 1 },
    { label: "Application templates", desc: "UI, terminal, apps, and misc generated colors", page: "Appearance", subTab: 2 },
    { label: "Wallpaper effects", desc: "Blur, dim, parallax, transition", page: "Wallpaper & Desktop", subTab: 1 },
    { label: "Desktop widgets", desc: "Clock, weather, media, system monitor", page: "Wallpaper & Desktop", subTab: 2 },
    { label: "Bar modules", desc: "Bar visible widgets", page: "Bar & Dock", subTab: 1 },
    { label: "Dock", desc: "Dock placement, previews, icons", page: "Bar & Dock", subTab: 2 },
    { label: "Panels", desc: "Loaded shell panels and Waffle", page: "Panels & Modules", subTab: 0 },
    { label: "Control Center", desc: "Quick settings sections", page: "Control Center", subTab: 0 },
    { label: "Launcher", desc: "Search and global actions", page: "Launcher", subTab: 0 },
    { label: "Notifications", desc: "DND, timeout, position", page: "Notifications", subTab: 0 },
    { label: "Audio protection", desc: "Volume safety limits", page: "Audio & Display", subTab: 0 },
    { label: "Display", desc: "Primary monitor, overview, brightness", page: "Audio & Display", subTab: 1 },
    { label: "Lock screen", desc: "Qylock, clock, dim, blur", page: "Lock & Power", subTab: 0 },
    { label: "Screen recorder", desc: "Quality, FPS, codecs", page: "Tools & Capture", subTab: 0 },
    { label: "Advanced Inspector", desc: "Raw config paths and compatibility coverage", page: "Advanced", subTab: 0 }
  ]

  readonly property var sidebarModel: {
    const query = searchText.toLowerCase().trim();
    if (query.length > 0)
      return tabsModel;
    return tabsModel;
  }

  readonly property var searchResults: {
    const needle = searchText.toLowerCase().trim();
    if (needle.length === 0)
      return [];
    const out = [];
    const rows = searchIndexRows(Config.revision);
    for (let i = 0; i < rows.length; i++) {
      const item = rows[i];
      const haystack = (item.label + " " + item.desc + " " + item.page).toLowerCase();
      if (haystack.indexOf(needle) >= 0)
        out.push(item);
    }
    return out.slice(0, 9);
  }

  function searchIndexRows(revision) {
    revision;
    const out = settingsSearchIndex.slice();
    for (let i = 0; i < tabsModel.length; i++) {
      const tab = tabsModel[i];
      out.push({ label: tab.name, desc: tab.desc, page: tab.name, subTab: 0 });
    }
    const extra = [
      { label: "Focus ring", desc: "Niri focus ring width, color, gradient, active and inactive color", page: "Audio & Display", subTab: 1 },
      { label: "Focus ring active color", desc: "focus-ring.active-color", page: "Audio & Display", subTab: 1 },
      { label: "Focus ring inactive color", desc: "focus-ring.inactive-color", page: "Audio & Display", subTab: 1 },
      { label: "Refresh rate", desc: "Niri output refresh rate", page: "Audio & Display", subTab: 1 },
      { label: "Cursor theme", desc: "Niri cursor.xcursor-theme", page: "Audio & Display", subTab: 2 },
      { label: "Cursor size", desc: "Niri cursor.xcursor-size", page: "Audio & Display", subTab: 2 },
      { label: "Hide cursor while typing", desc: "Niri cursor.hide-when-typing", page: "Audio & Display", subTab: 2 },
      { label: "Touchpad", desc: "Tap, natural scroll, disable while typing", page: "Audio & Display", subTab: 2 },
      { label: "Theme color sets", desc: "ThemePresets swatches and favorites", page: "Appearance", subTab: 1 },
      { label: "Template targets", desc: "Terminal, apps, shell, browser color templates", page: "Appearance", subTab: 2 },
      { label: "Login screen", desc: "SDDM greeter provider and qylock theme path", page: "Advanced", subTab: 3 },
      { label: "Services", desc: "Idle, caffeine, AI, music recognition, networking, hotspot", page: "Services", subTab: 0 },
      { label: "AI settings", desc: "AI providers, system prompt, API formats, and keys", page: "Services", subTab: 0 },
      { label: "Extras", desc: "Package profiles and optional software", page: "Extras", subTab: 0 },
      { label: "Shortcuts", desc: "Keybind overlay and Niri binds", page: "Launcher", subTab: 2 }
    ];
    for (let i = 0; i < extra.length; i++)
      out.push(extra[i]);
    const rows = coverageRows(revision);
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      out.push({ label: row.label, desc: row.path, page: "Advanced", subTab: 0 });
    }
    return out;
  }

  function centerWindow() {
    if (!centeredMode)
      return;
    x = Math.round((Screen.width - width) / 2);
    y = Math.round((Screen.height - height) / 2);
  }

  function tabIndexByName(name) {
    for (let i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].name === name)
        return i;
    }
    return 0;
  }

  function subTabForPage(key, fallback) {
    const value = subTabState[key];
    return value === undefined ? fallback : value;
  }

  function setSubTabForPage(key, index) {
    const next = Object.assign({}, subTabState);
    next[key] = index;
    subTabState = next;
  }

  function navigateSearchResult(item) {
    currentPage = tabIndexByName(item.page);
    setSubTabForPage(tabsModel[currentPage].key, item.subTab ?? 0);
    searchText = "";
  }

  function closeActiveDropdown(owner) {
    if (activeDropdown && activeDropdown !== owner)
      activeDropdown.closeDropdown();
    activeDropdown = owner;
  }

  function readableOn(value) {
    const c = Qt.color(value);
    const luminance = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return luminance > 0.58 ? "#111318" : "#ffffff";
  }

  function cornerStyleForGlobalStyle(styleId) {
    const styles = Config.options?.appearance?.globalStyleCornerStyles;
    if (!styles)
      return 1;
    if (styleId === "cards")
      return styles.cards ?? 3;
    if (styleId === "aurora")
      return styles.aurora ?? 1;
    if (styleId === "ryoku-shell")
      return styles.ryoku ?? 1;
    if (styleId === "angel")
      return styles.angel ?? 1;
    return styles.material ?? 1;
  }

  function applyGlobalStyle(styleId) {
    const cornerStyle = cornerStyleForGlobalStyle(styleId);
    const updates = { "appearance.globalStyle": styleId };
    updates["dock.cardStyle"] = styleId === "cards";
    updates["sidebar.cardStyle"] = styleId === "cards";
    updates["bar.cornerStyle"] = styleId === "angel" && cornerStyle === 0 ? 1 : cornerStyle;
    updates["appearance.transparency.enable"] = styleId === "aurora" || styleId === "angel";
    Config.setNestedValues(updates);
  }

  function currentStyle() {
    const style = Config.options?.appearance?.globalStyle ?? "";
    return style.length > 0 ? style : "material";
  }

  function currentThemeMode() {
    const saved = Config.getNestedValue("appearance.themeMode", "");
    if (saved === "light" || saved === "dark" || saved === "auto" || saved === "schedule")
      return saved;
    if (Config.options?.appearance?.themeSchedule?.enabled ?? false)
      return "schedule";
    return Appearance.m3colors.darkmode ? "dark" : "light";
  }

  function setThemeMode(mode) {
    Config.setNestedValue("appearance.themeMode", mode);
    if (mode === "schedule") {
      Config.setNestedValue("appearance.themeSchedule.enabled", true);
      return;
    }
    Config.setNestedValue("appearance.themeSchedule.enabled", false);
    if (mode === "auto") {
      Config.setNestedValue("appearance.theme", "auto");
      return;
    }
    const dark = mode === "dark";
    Config.setNestedValue("appearance.customTheme.darkmode", dark);
    Appearance.m3colors.darkmode = dark;
    MaterialThemeLoader.setDarkMode(dark);
  }

  function applyPaletteVariant(variant) {
    Config.setNestedValue("appearance.palette.type", variant);
    if (!ThemeService.isAutoTheme) {
      const hex = MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary);
      const mode = currentThemeMode() === "light" ? "light" : "dark";
      MaterialThemeLoader.applySchemeVariant(hex, variant, mode);
    }
  }

  function themeSwatches() {
    return [
      { label: "Primary", value: MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary) },
      { label: "Secondary", value: MaterialThemeLoader.colorToHex(Appearance.m3colors.m3secondary) },
      { label: "Tertiary", value: MaterialThemeLoader.colorToHex(Appearance.m3colors.m3tertiary) },
      { label: "Outline", value: MaterialThemeLoader.colorToHex(Appearance.m3colors.m3outline) },
      { label: "Surface", value: MaterialThemeLoader.colorToHex(Appearance.m3colors.m3surface) },
      { label: "Error", value: MaterialThemeLoader.colorToHex(Appearance.m3colors.m3error) }
    ];
  }

  function focusRingThemeColor() {
    return MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary);
  }

  function focusRingThemeInactiveColor() {
    return MaterialThemeLoader.colorToHex(Appearance.m3colors.m3outline);
  }

  function syncThemeFocusRing() {
    app.niriSetConfig("layout", "focus-ring.active-color", focusRingThemeColor());
    app.niriSetConfig("layout", "focus-ring.inactive-color", focusRingThemeInactiveColor());
  }

  function appPresetOptions(slotId) {
    const options = AppLauncher.presetOptions(slotId);
    const out = [];
    for (let i = 0; i < options.length; i++)
      out.push({ label: options[i].displayName ?? options[i].label ?? options[i].value, value: options[i].value });
    return out;
  }

  function presetTags(preset) {
    return preset?.tags ?? [];
  }

  function presetHasTag(preset, tag) {
    const tags = presetTags(preset);
    for (let i = 0; i < tags.length; i++) {
      if (String(tags[i]) === tag)
        return true;
    }
    return false;
  }

  function isFavoriteTheme(themeId) {
    return configList("appearance.favoriteThemes").indexOf(themeId) >= 0;
  }

  function toggleFavoriteTheme(themeId) {
    setConfigListMember("appearance.favoriteThemes", themeId, !isFavoriteTheme(themeId));
  }

  function themePresetOptions() {
    const out = [];
    for (let i = 0; i < ThemePresets.presets.length; i++) {
      const preset = ThemePresets.presets[i];
      out.push({ label: preset.name ?? preset.id, value: preset.id });
    }
    return out;
  }

  function favoriteThemeOptions(revision) {
    revision;
    const favorites = configList("appearance.favoriteThemes");
    const out = [];
    for (let i = 0; i < ThemePresets.presets.length; i++) {
      const preset = ThemePresets.presets[i];
      if (favorites.indexOf(preset.id) >= 0)
        out.push({ label: "★ " + (preset.name ?? preset.id), value: preset.id });
    }
    if (out.length === 0)
      out.push({ label: "Mark themes with ★ first", value: "" });
    return out;
  }

  function currentFavoriteThemeSelection(revision) {
    revision;
    const current = Config.options?.appearance?.theme ?? "";
    if (current.length > 0 && isFavoriteTheme(current))
      return current;
    const favorites = configList("appearance.favoriteThemes");
    return favorites.length > 0 ? favorites[0] : "";
  }

  function favoriteThemePresets(revision) {
    revision;
    const favorites = configList("appearance.favoriteThemes");
    const out = [];
    for (let i = 0; i < ThemePresets.presets.length; i++) {
      const preset = ThemePresets.presets[i];
      if (favorites.indexOf(preset.id) >= 0)
        out.push(preset);
    }
    if (out.length === 0) {
      const current = ThemePresets.presets.find(p => p.id === staticThemeFallback(revision));
      if (current)
        out.push(current);
    }
    return out.slice(0, 6);
  }

  function staticThemeFallback(revision) {
    revision;
    const current = Config.options?.appearance?.theme ?? "";
    if (current.length > 0 && current !== "auto" && current !== "custom")
      return current;
    const favorites = configList("appearance.favoriteThemes");
    if (favorites.length > 0)
      return favorites[0];
    return "catppuccin-mocha";
  }

  function setWallpaperColorsEnabled(enabled) {
    if (enabled) {
      Config.setNestedValue("appearance.theme", "auto");
      return;
    }
    const fallback = staticThemeFallback(Config.revision);
    if (fallback.length > 0)
      applyThemePreset(fallback);
  }

  function setManualShellTransparency(path, value) {
    const updates = {
      "appearance.transparency.enable": true,
      "appearance.transparency.automatic": false
    };
    updates[path] = value;
    Config.setNestedValues(updates);
  }

  function aiProviderFormatLabel(format) {
    const options = aiProviderFormatOptions;
    for (let i = 0; i < options.length; i++) {
      if (options[i].value === format)
        return options[i].label;
    }
    return String(format ?? "OpenAI compatible");
  }

  function presetSwatches(preset) {
    const colors = preset?.colors;
    if (!colors || colors === "custom") {
      return [
        Appearance.m3colors.m3primary,
        Appearance.m3colors.m3secondary,
        Appearance.m3colors.m3tertiary,
        Appearance.m3colors.m3surfaceContainerHighest
      ];
    }
    return [
      colors.m3primary ?? primaryColor,
      colors.m3secondary ?? successColor,
      colors.m3tertiary ?? primaryColor,
      colors.m3surfaceContainerHighest ?? colors.m3surface ?? surfaceVariantColor
    ];
  }

  function filteredThemePresets(revision) {
    revision;
    const needle = themeSearchText.trim().toLowerCase();
    const favorites = configList("appearance.favoriteThemes");
    const out = [];
    for (let i = 0; i < ThemePresets.presets.length; i++) {
      const preset = ThemePresets.presets[i];
      const haystack = (preset.id + " " + (preset.name ?? "") + " " + (preset.description ?? "") + " " + presetTags(preset).join(" ")).toLowerCase();
      if (needle.length > 0 && haystack.indexOf(needle) < 0)
        continue;
      if (themeFilter === "dark" && !presetHasTag(preset, "dark"))
        continue;
      if (themeFilter === "light" && !presetHasTag(preset, "light"))
        continue;
      if (themeFilter === "favorites" && favorites.indexOf(preset.id) < 0)
        continue;
      out.push(preset);
    }
    return out.slice(0, 80);
  }

  function applyThemePreset(themeId) {
    ThemeService.setTheme(themeId);
    Config.setNestedValue("appearance.theme", themeId);
    const preset = ThemePresets.presets.find(p => p.id === themeId);
    if (presetHasTag(preset, "light"))
      Config.setNestedValue("appearance.themeMode", "light");
    else if (presetHasTag(preset, "dark"))
      Config.setNestedValue("appearance.themeMode", "dark");
  }

  function applyAuroraPreset(name) {
    const presets = {
      default: { overlay: 0.30, subSurface: 0.42, popup: 0.32, tooltip: 0.28, layer: 0.32 },
      frosted: { overlay: 0.25, subSurface: 0.35, popup: 0.30, tooltip: 0.25, layer: 0.28 },
      clear:   { overlay: 0.60, subSurface: 0.72, popup: 0.58, tooltip: 0.45, layer: 0.60 },
      subtle:  { overlay: 0.18, subSurface: 0.28, popup: 0.22, tooltip: 0.18, layer: 0.20 }
    };
    const preset = presets[name];
    if (!preset) return;
    Config.setNestedValue("appearance.aurora.transparency.overlay", preset.overlay);
    Config.setNestedValue("appearance.aurora.transparency.subSurface", preset.subSurface);
    Config.setNestedValue("appearance.aurora.transparency.popup", preset.popup);
    Config.setNestedValue("appearance.aurora.transparency.tooltip", preset.tooltip);
    Config.setNestedValue("appearance.aurora.transparency.layer", preset.layer);
  }

  function saveAuroraCustom() {
    const t = Config.options?.appearance?.aurora?.transparency ?? {};
    const snapshot = {
      overlay: t.overlay ?? 0.30,
      subSurface: t.subSurface ?? 0.42,
      popup: t.popup ?? 0.32,
      tooltip: t.tooltip ?? 0.28,
      layer: t.layer ?? 0.32
    };
    Config.setNestedValue("appearance.aurora.customPreset", JSON.stringify(snapshot));
  }

  function loadAuroraCustom() {
    const raw = Config.options?.appearance?.aurora?.customPreset ?? "";
    if (raw === "") return;
    try {
      const snap = JSON.parse(raw);
      if (snap?.overlay !== undefined) Config.setNestedValue("appearance.aurora.transparency.overlay", snap.overlay);
      if (snap?.subSurface !== undefined) Config.setNestedValue("appearance.aurora.transparency.subSurface", snap.subSurface);
      if (snap?.popup !== undefined) Config.setNestedValue("appearance.aurora.transparency.popup", snap.popup);
      if (snap?.tooltip !== undefined) Config.setNestedValue("appearance.aurora.transparency.tooltip", snap.tooltip);
      if (snap?.layer !== undefined) Config.setNestedValue("appearance.aurora.transparency.layer", snap.layer);
    } catch (e) {
      console.warn("[Aurora] Failed to load custom preset:", e);
    }
  }

  function applyAngelPreset(name) {
    const presets = {
      default: {
        blur: { intensity: 0.35, saturation: 0.20, overlayOpacity: 0.45, noiseOpacity: 0.20, vignetteStrength: 0.15 },
        transparency: { panel: 0.28, card: 0.40, popup: 0.28, tooltip: 0.25 },
        escalonado: { offsetX: 1, offsetY: 1, hoverOffsetX: 7, hoverOffsetY: 7, opacity: 0.50, borderOpacity: 0.17, hoverOpacity: 0.0 },
        escalonadoShadow: { offsetX: 3, offsetY: 2, hoverOffsetX: 7, hoverOffsetY: 7, opacity: 1.0, borderOpacity: 1.0, hoverOpacity: 0.60, glass: true, glassBlur: 0.70, glassOverlay: 0.50 },
        border: { width: 0.8, accentBarHeight: 10, accentBarWidth: 10, coverage: 0.60, opacity: 0.52, hoverOpacity: 0.50, activeOpacity: 0.50, insetGlowHeight: 1, insetGlowOpacity: 0.20 },
        surface: { panelBorderWidth: 1, cardBorderWidth: 1, panelBorderOpacity: 0.90, cardBorderOpacity: 0.0 },
        glow: { opacity: 0.0, strongOpacity: 0.0 },
        rounding: { small: 0, normal: 0, large: 0 },
        colorStrength: 0.6
      },
      ethereal: {
        blur: { intensity: 0.65, saturation: 0.25, overlayOpacity: 0.45, noiseOpacity: 0.10, vignetteStrength: 0.25 },
        transparency: { panel: 0.75, card: 0.85, popup: 0.70, tooltip: 0.40 },
        escalonado: { offsetX: 2, offsetY: 2, hoverOffsetX: 6, hoverOffsetY: 6, opacity: 0.30, borderOpacity: 0.25, hoverOpacity: 0.15 },
        escalonadoShadow: { offsetX: 4, offsetY: 3, hoverOffsetX: 8, hoverOffsetY: 8, opacity: 0.60, borderOpacity: 0.50, hoverOpacity: 0.40, glass: true, glassBlur: 0.55, glassOverlay: 0.40 },
        border: { width: 0.5, accentBarHeight: 4, accentBarWidth: 4, coverage: 0.40, opacity: 0.30, hoverOpacity: 0.45, activeOpacity: 0.55, insetGlowHeight: 2, insetGlowOpacity: 0.30 },
        surface: { panelBorderWidth: 1, cardBorderWidth: 1, panelBorderOpacity: 0.40, cardBorderOpacity: 0.15 },
        glow: { opacity: 0.50, strongOpacity: 0.35 },
        rounding: { small: 8, normal: 12, large: 20 },
        colorStrength: 0.9
      },
      monolith: {
        blur: { intensity: 0.20, saturation: 0.05, overlayOpacity: 0.20, noiseOpacity: 0.05, vignetteStrength: 0.0 },
        transparency: { panel: 0.20, card: 0.30, popup: 0.20, tooltip: 0.15 },
        escalonado: { offsetX: 2, offsetY: 2, hoverOffsetX: 5, hoverOffsetY: 5, opacity: 0.80, borderOpacity: 0.60, hoverOpacity: 0.30 },
        escalonadoShadow: { offsetX: 3, offsetY: 3, hoverOffsetX: 6, hoverOffsetY: 6, opacity: 1.0, borderOpacity: 1.0, hoverOpacity: 0.80, glass: false, glassBlur: 0.10, glassOverlay: 0.80 },
        border: { width: 1.0, accentBarHeight: 2, accentBarWidth: 2, coverage: 0.80, opacity: 0.70, hoverOpacity: 0.80, activeOpacity: 0.90, insetGlowHeight: 0, insetGlowOpacity: 0.0 },
        surface: { panelBorderWidth: 1, cardBorderWidth: 1, panelBorderOpacity: 1.0, cardBorderOpacity: 0.30 },
        glow: { opacity: 0.0, strongOpacity: 0.0 },
        rounding: { small: 0, normal: 0, large: 0 },
        colorStrength: 0.3
      },
      crystalline: {
        blur: { intensity: 0.80, saturation: 0.30, overlayOpacity: 0.50, noiseOpacity: 0.15, vignetteStrength: 0.20 },
        transparency: { panel: 0.60, card: 0.70, popup: 0.55, tooltip: 0.30 },
        escalonado: { offsetX: 1, offsetY: 1, hoverOffsetX: 4, hoverOffsetY: 4, opacity: 0.40, borderOpacity: 0.30, hoverOpacity: 0.10 },
        escalonadoShadow: { offsetX: 2, offsetY: 2, hoverOffsetX: 5, hoverOffsetY: 5, opacity: 0.70, borderOpacity: 0.80, hoverOpacity: 0.50, glass: true, glassBlur: 0.85, glassOverlay: 0.30 },
        border: { width: 0.6, accentBarHeight: 6, accentBarWidth: 6, coverage: 0.50, opacity: 0.40, hoverOpacity: 0.55, activeOpacity: 0.65, insetGlowHeight: 1, insetGlowOpacity: 0.25 },
        surface: { panelBorderWidth: 1, cardBorderWidth: 1, panelBorderOpacity: 0.60, cardBorderOpacity: 0.20 },
        glow: { opacity: 0.40, strongOpacity: 0.25 },
        rounding: { small: 4, normal: 6, large: 10 },
        colorStrength: 1.2
      }
    };
    const preset = presets[name];
    if (!preset) return;
    for (const section of ["blur", "transparency", "escalonado", "escalonadoShadow", "border", "surface", "glow", "rounding"]) {
      const data = preset[section];
      if (data) for (const key of Object.keys(data)) {
        Config.setNestedValue("appearance.angel." + section + "." + key, data[key]);
      }
    }
    Config.setNestedValue("appearance.angel.colorStrength", preset.colorStrength);
  }

  function _angelSnapshot() {
    const current = Config.options?.appearance?.angel ?? {};
    const clean = {};
    for (const key of ["blur", "transparency", "escalonado", "escalonadoShadow", "border", "surface", "glow", "rounding"]) {
      if (current[key] !== undefined) clean[key] = JSON.parse(JSON.stringify(current[key]));
    }
    if (current.colorStrength !== undefined) clean.colorStrength = current.colorStrength;
    return clean;
  }

  function _applyAngelSnapshot(snap) {
    if (!snap) return;
    for (const section of ["blur", "transparency", "escalonado", "escalonadoShadow", "border", "surface", "glow", "rounding"]) {
      const data = snap[section];
      if (data) for (const key of Object.keys(data)) {
        Config.setNestedValue("appearance.angel." + section + "." + key, data[key]);
      }
    }
    if (snap.colorStrength !== undefined) Config.setNestedValue("appearance.angel.colorStrength", snap.colorStrength);
  }

  function saveAngelCustom() {
    Config.setNestedValue("appearance.angel.customPreset", JSON.stringify(app._angelSnapshot()));
  }

  function loadAngelCustom() {
    const raw = Config.options?.appearance?.angel?.customPreset ?? "";
    if (raw === "") return;
    try { app._applyAngelSnapshot(JSON.parse(raw)); }
    catch (e) { console.warn("[Angel] Failed to load custom preset:", e); }
  }

  function angelProfiles() {
    const raw = Config.options?.appearance?.angel?.profiles ?? "";
    if (raw === "") return {};
    try { return JSON.parse(raw); }
    catch (e) { return {}; }
  }

  function angelProfileNames(revision) {
    return Object.keys(app.angelProfiles());
  }

  function saveAngelProfile(name) {
    if (!name || name.length === 0) return;
    const profiles = app.angelProfiles();
    profiles[name] = app._angelSnapshot();
    Config.setNestedValue("appearance.angel.profiles", JSON.stringify(profiles));
  }

  function loadAngelProfile(name) {
    const profiles = app.angelProfiles();
    if (profiles[name]) app._applyAngelSnapshot(profiles[name]);
  }

  function deleteAngelProfile(name) {
    const profiles = app.angelProfiles();
    delete profiles[name];
    Config.setNestedValue("appearance.angel.profiles", JSON.stringify(profiles));
  }

  function applyCustomThemePreset(presetKey) {
    const presetMap = {
      "angel-dark":         ThemePresets.angelColors,
      "angel-light":        ThemePresets.angelLightColors,
      "gruvbox-material":   ThemePresets.gruvboxMaterialColors,
      "catppuccin-mocha":   ThemePresets.catppuccinMochaColors,
      "catppuccin-latte":   ThemePresets.catppuccinLatteColors,
      "nord":               ThemePresets.nordColors,
      "material-black":     ThemePresets.materialBlackColors,
      "kanagawa":           ThemePresets.kanagawaColors,
      "kanagawa-dragon":    ThemePresets.kanagawaDragonColors,
      "samurai":            ThemePresets.samuraiColors,
      "tokyo-night":        ThemePresets.tokyoNightColors,
      "sakura":             ThemePresets.sakuraColors,
      "zen-garden":         ThemePresets.zenGardenColors
    };
    const colors = presetMap[presetKey];
    if (!colors) return;
    const updates = {};
    for (const key in colors) {
      updates["appearance.customTheme." + key] = colors[key];
    }
    Config.setNestedValues(updates);
    customThemeApplyTimer.restart();
  }

  function setCustomThemeColor(key, value) {
    Config.setNestedValue("appearance.customTheme." + key, value);
    customThemeApplyTimer.restart();
  }

  function setCustomThemeDarkMode(isDark) {
    Config.setNestedValues({
      "appearance.themeMode": isDark ? "dark" : "light",
      "appearance.customTheme.darkmode": isDark
    });
    customThemeApplyTimer.restart();
  }

  function normalizeTransform(value) {
    const raw = String(value ?? "normal").toLowerCase();
    if (raw === "normal")
      return "normal";
    return raw;
  }

  function displayOutputOptions() {
    const out = [];
    for (let i = 0; i < outputList.length; i++) {
      const output = outputList[i];
      const name = output?.name ?? "";
      if (name.length > 0)
        out.push({ label: name + ((output?.make || output?.model) ? " - " + [output.make, output.model].filter(v => v && String(v).length > 0).join(" ") : ""), value: name });
    }
    return out;
  }

  function displayResolutionOptions() {
    const out = [];
    if (!currentOutput?.resolutions)
      return out;
    for (let i = 0; i < currentOutput.resolutions.length; i++) {
      const res = currentOutput.resolutions[i];
      out.push({
        label: `${res.width}x${res.height}` + (res.preferred ? " preferred" : ""),
        value: `${res.width}x${res.height}`,
        rates: res.rates ?? []
      });
    }
    return out;
  }

  function displayRefreshOptions() {
    if (!currentOutput?.resolutions || currentResolution.length === 0)
      return [];
    const match = currentOutput.resolutions.find(r => `${r.width}x${r.height}` === currentResolution);
    if (!match?.rates)
      return [];
    const out = [];
    for (let i = 0; i < match.rates.length; i++) {
      const rate = match.rates[i];
      const value = rate.rate_string ?? Number(rate.rate).toFixed(3);
      out.push({ label: value + " Hz" + (rate.preferred ? " preferred" : ""), value: value, numeric: Number(rate.rate) });
    }
    out.sort((a, b) => b.numeric - a.numeric);
    return out;
  }

  function bestRateForResolution(resolution) {
    if (!currentOutput?.resolutions)
      return currentRateString;
    const match = currentOutput.resolutions.find(r => `${r.width}x${r.height}` === resolution);
    if (!match?.rates || match.rates.length === 0)
      return currentRateString;
    const preferred = match.rates.find(r => r.preferred) ?? match.rates[0];
    return preferred.rate_string ?? Number(preferred.rate).toFixed(3);
  }

  function displayScaleOptions() {
    return [
      { label: "0.75x", value: "0.75" },
      { label: "1x", value: "1" },
      { label: "1.25x", value: "1.25" },
      { label: "1.5x", value: "1.5" },
      { label: "1.75x", value: "1.75" },
      { label: "2x", value: "2" },
      { label: "2.5x", value: "2.5" },
      { label: "3x", value: "3" }
    ];
  }

  function displayTransformOptions() {
    return [
      { label: "Normal", value: "normal" },
      { label: "90 degrees", value: "90" },
      { label: "180 degrees", value: "180" },
      { label: "270 degrees", value: "270" },
      { label: "Flipped", value: "flipped" },
      { label: "Flipped 90 degrees", value: "flipped-90" },
      { label: "Flipped 180 degrees", value: "flipped-180" },
      { label: "Flipped 270 degrees", value: "flipped-270" }
    ];
  }

  function currentCursorTheme() {
    return cursorData?.theme ?? "capitaine-cursors-light";
  }

  function cursorThemeOptions() {
    const active = currentCursorTheme();
    const seen = {};
    const out = [];
    if (active.length > 0) {
      out.push({ label: active, value: active });
      seen[active] = true;
    }
    const themes = Array.isArray(cursorThemes) ? cursorThemes : [];
    for (let i = 0; i < themes.length; i++) {
      const theme = String(themes[i]);
      if (theme.length === 0 || seen[theme])
        continue;
      seen[theme] = true;
      out.push({ label: theme, value: theme });
    }
    if (out.length === 0)
      out.push({ label: "capitaine-cursors-light", value: "capitaine-cursors-light" });
    return out;
  }

  function accelerationProfileOptions() {
    return [
      { label: "Flat", value: "flat" },
      { label: "Adaptive", value: "adaptive" }
    ];
  }

  function warpPointerOptions() {
    return [
      { label: "Off", value: "off" },
      { label: "Center focused window", value: "center-xy" },
      { label: "Always center focused window", value: "center-xy-always" }
    ];
  }

  function focusFollowsMouseOptions() {
    return [
      { label: "Off", value: "off" },
      { label: "On", value: "always" },
      { label: "Max scroll", value: "max-scroll-amount" }
    ];
  }

  function formatReal(value, fallback) {
    const number = Number(value ?? fallback);
    return Number.isFinite(number) ? number.toFixed(2) : String(fallback);
  }

  function setSelectedOutput(outputName) {
    for (let i = 0; i < outputList.length; i++) {
      if ((outputList[i]?.name ?? "") === outputName) {
        selectedOutputIndex = i;
        return;
      }
    }
  }

  function loadOutputs() {
    if (outputsProcess.running)
      return;
    displayStatus = "Refreshing displays...";
    outputsProcess.running = true;
  }

  function applyAndPersistDisplay(key, value) {
    if (!currentOutputName.length || displayApplyProcess.running || displayPersistProcess.running)
      return;
    displayPendingOutput = currentOutputName;
    displayPendingKey = key;
    displayPendingValue = String(value);
    displayStatus = "Applying " + configLabelForPath(key).toLowerCase() + "...";
    displayApplyProcess.command = ["python3", scriptPath, "apply-output", currentOutputName, key + "=" + String(value)];
    displayApplyProcess.running = true;
  }

  function loadLayout() {
    if (layoutProcess.running)
      return;
    layoutProcess.running = true;
  }

  function loadWindowRules() {
    if (windowRulesProcess.running)
      return;
    windowRulesStatus = "Refreshing window rules...";
    windowRulesProcess.running = true;
  }

  function loadInput() {
    if (inputProcess.running)
      return;
    inputStatus = "Refreshing input settings...";
    inputProcess.running = true;
  }

  function loadCursorThemes() {
    if (cursorThemesProcess.running)
      return;
    cursorThemesProcess.running = true;
  }

  function runNextSetRequest() {
    if (niriSetProcess.running || setRequestQueue.length === 0)
      return;
    const nextQueue = setRequestQueue.slice();
    const request = nextQueue.shift();
    setRequestQueue = nextQueue;
    lastSetSection = request.section;
    niriStatus = "Saving " + request.section + "." + request.key + "...";
    if (request.section === "input")
      inputStatus = "Saving " + request.key + "...";
    niriSetProcess.command = ["python3", scriptPath, "set", request.section, request.key, request.value];
    niriSetProcess.running = true;
  }

  function niriSetConfig(section, key, value) {
    const normalizedValue = String(value);
    const nextQueue = [];
    for (let i = 0; i < setRequestQueue.length; i++) {
      const request = setRequestQueue[i];
      if (request.section === section && request.key === key)
        continue;
      nextQueue.push(request);
    }
    nextQueue.push({ section: section, key: key, value: normalizedValue });
    setRequestQueue = nextQueue;
    runNextSetRequest();
  }

  function niriSetBooleanConfig(section, key, enabled) {
    niriSetConfig(section, key, enabled ? "on" : "off");
  }

  function setWarpMouseMode(mode) {
    if (mode === "off") {
      niriSetConfig("input", "warp-mouse-to-focus", "off");
      return;
    }
    niriSetConfig("input", "warp-mouse-to-focus", mode);
  }

  function setFocusFollowsMouse(enabled, percent) {
    if (!enabled) {
      niriSetConfig("input", "focus-follows-mouse", "off");
      return;
    }
    const currentPercent = generalInputData?.focus_follows_mouse_max_scroll ?? 0;
    const finalPercent = percent === undefined ? currentPercent : percent;
    niriSetConfig("input", "focus-follows-mouse", `max-scroll-amount="${finalPercent}%"`);
  }

  function writeFocusRingGradient(fromColor, toColor, angle) {
    const cur = layoutData?.focus_ring?.active_gradient ?? {};
    const f = fromColor !== null && fromColor !== undefined && String(fromColor).length > 0 ? fromColor : (cur.from_color ?? "#F25623");
    const t = toColor !== null && toColor !== undefined && String(toColor).length > 0 ? toColor : (cur.to_color ?? "#F56E0F");
    const a = angle !== null && angle !== undefined ? angle : (cur.angle ?? 45);
    const rel = cur.relative_to ?? "workspace-view";
    const cs = cur.color_space ?? "oklch";
    niriSetConfig("layout", "focus-ring.active-gradient", `from="${f}" to="${t}" angle=${a} relative-to="${rel}" in="${cs}"`);
  }

  function checkShellUpdates() {
    ShellUpdates.check();
    Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "check"]);
  }

  function openShellUpdateDetails() {
    Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "open"]);
  }

  function setShellUpdateChannel(channel) {
    ShellUpdates.setChannel(channel);
    Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "setChannel", channel]);
  }

  function humanizeConfigSegment(segment) {
    if (!segment)
      return "";
    let text = String(segment).replace(/[_-]+/g, " ");
    text = text.replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    text = text.replace(/\bm3\b/gi, "M3");
    text = text.replace(/\bui\b/gi, "UI");
    text = text.replace(/\bosd\b/gi, "OSD");
    text = text.replace(/\bgpu\b/gi, "GPU");
    text = text.replace(/\bcpu\b/gi, "CPU");
    text = text.replace(/\bfps\b/gi, "FPS");
    return text.charAt(0).toUpperCase() + text.slice(1);
  }

  function configLabelForPath(path) {
    const parts = String(path).split(".");
    return humanizeConfigSegment(parts[parts.length - 1]);
  }

  function configDescriptionForPath(path) {
    const parts = String(path).split(".");
    if (parts.length <= 1)
      return path;
    return parts.slice(0, parts.length - 1).map(humanizeConfigSegment).join(" / ") + "  -  " + path;
  }

  function configKindForValue(value) {
    if (Array.isArray(value))
      return "list";
    if (value && typeof value !== "string" && typeof value.length === "number" && typeof value !== "function")
      return "list";
    if (typeof value === "boolean")
      return "bool";
    if (typeof value === "number")
      return Math.round(value) === value ? "int" : "real";
    if (typeof value === "string")
      return "string";
    return "object";
  }

  function shouldSkipConfigKey(key, value) {
    if (!key || key.charAt(0) === "_")
      return true;
    if (key === "objectName")
      return true;
    return typeof value === "function";
  }

  function appendConfigRows(prefix, value, rows, seen, depth) {
    if (value === undefined || value === null || depth > 10)
      return;
    const kind = configKindForValue(value);
    if (kind !== "object") {
      if (!seen[prefix]) {
        seen[prefix] = true;
        rows.push({
          path: prefix,
          label: configLabelForPath(prefix),
          description: configDescriptionForPath(prefix),
          value: value,
          kind: kind
        });
      }
      return;
    }
    const keys = Object.keys(value).sort();
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (!shouldSkipConfigKey(key, value[key]))
        appendConfigRows(prefix.length > 0 ? prefix + "." + key : key, value[key], rows, seen, depth + 1);
    }
  }

  function flattenConfigRows(prefixes, revision) {
    revision;
    const rows = [];
    const seen = {};
    const list = prefixes && prefixes.length ? prefixes : [""];
    for (let i = 0; i < list.length; i++) {
      const prefix = list[i];
      const value = prefix.length > 0 ? Config.getNestedValue(prefix, undefined) : Config.options;
      appendConfigRows(prefix, value, rows, seen, 0);
    }
    rows.sort((left, right) => left.path.localeCompare(right.path));
    return rows;
  }

  function coverageRows(revision) {
    revision;
    const rows = [];
    for (let i = 0; i < legacyCoveragePaths.length; i++) {
      const path = legacyCoveragePaths[i];
      const value = Config.getNestedValue(path, "");
      rows.push({
        path: path,
        label: configLabelForPath(path),
        description: configDescriptionForPath(path),
        value: value,
        kind: configKindForValue(value)
      });
    }
    return rows;
  }

  function filterConfigRows(rows, query) {
    const needle = String(query || "").trim().toLowerCase();
    if (needle.length === 0)
      return rows;
    const out = [];
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const haystack = (row.path + " " + row.label + " " + row.description).toLowerCase();
      if (haystack.indexOf(needle) >= 0)
        out.push(row);
    }
    return out;
  }

  function configList(path) {
    const value = Config.getNestedValue(path, []);
    if (Array.isArray(value))
      return [...value];
    if (value && typeof value.length === "number" && typeof value !== "string") {
      const out = [];
      for (let i = 0; i < value.length; i++)
        out.push(value[i]);
      return out;
    }
    return [];
  }

  function configListContains(path, item) {
    return configList(path).indexOf(item) >= 0;
  }

  function setConfigListMember(path, item, enabled) {
    const values = configList(path);
    const idx = values.indexOf(item);
    if (enabled && idx < 0)
      values.push(item);
    if (!enabled && idx >= 0)
      values.splice(idx, 1);
    Config.setNestedValue(path, values);
  }

  function formatNumber(value, decimals) {
    const fixed = Number(value).toFixed(decimals);
    return decimals > 0 ? fixed.replace(/\.?0+$/, "") : fixed;
  }

  function configListToString(value) {
    if (Array.isArray(value))
      return value.join(", ");
    if (value && typeof value.length === "number" && typeof value !== "string") {
      const out = [];
      for (let i = 0; i < value.length; i++)
        out.push(String(value[i]));
      return out.join(", ");
    }
    return String(value ?? "");
  }

  function parseConfigList(text) {
    const out = [];
    const parts = String(text).split(",");
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i].trim();
      if (part.length > 0)
        out.push(part);
    }
    return out;
  }

  function intSpinFrom(rowData) {
    const value = Number(rowData.value ?? 0);
    return value < 0 ? Math.floor(value * 2 - 10) : 0;
  }

  function intSpinTo(rowData) {
    const value = Math.abs(Number(rowData.value ?? 0));
    if (rowData.path.indexOf("bitrate") >= 0)
      return Math.max(50000, Math.ceil(value * 2));
    if (rowData.path.indexOf("timeout") >= 0 || rowData.path.indexOf("duration") >= 0 || rowData.path.indexOf("interval") >= 0 || rowData.path.indexOf("delay") >= 0)
      return Math.max(60000, Math.ceil(value * 2 + 1000));
    return Math.max(100, Math.ceil(value * 2 + 20));
  }

  function realSliderTo(rowData) {
    const value = Math.abs(Number(rowData.value ?? 1));
    if (value <= 1)
      return 1;
    if (value <= 2)
      return 2;
    return Math.ceil(value * 2);
  }

  function ryokuHelperPath(name) {
    let ryokuPath = Quickshell.env("RYOKU_PATH") || "";
    if (ryokuPath.length === 0)
      ryokuPath = Quickshell.env("HOME") + "/.local/share/ryoku";
    return ryokuPath + "/bin/" + name;
  }

  function safeTerminal() {
    const configured = String(Config.options?.apps?.terminal ?? "").trim();
    if (configured.length === 0)
      return "kitty";
    return /^[A-Za-z0-9._+-]+$/.test(configured) ? configured : "kitty";
  }

  function safeEditor() {
    const configured = String(Config.options?.apps?.editor ?? "").trim();
    if (configured.length === 0)
      return "nvim";
    return /^[A-Za-z0-9._+-]+$/.test(configured) ? configured : "nvim";
  }

  function launchTerminalCommand(command) {
    const terminal = safeTerminal();
    if (terminal === "wezterm")
      Quickshell.execDetached([terminal, "start", "--always-new-process", "--", "bash", "-lc", command]);
    else
      Quickshell.execDetached([terminal, "-e", "bash", "-lc", command]);
  }

  function launchPackageManager() {
    launchTerminalCommand("gpk");
  }

  function launchGpkPrompt(action) {
    const actionLabels = ({
      install: "Package to install",
      remove: "Package to uninstall",
      upgrade: "Package to update"
    });
    const prompt = actionLabels[action] ?? "Package";
    launchTerminalCommand("printf 'GPK package manager - " + action + "\\n'; read -rp '" + prompt + ": ' pkg; if [[ -n $pkg ]]; then gpk " + action + " \"$pkg\"; fi; printf '\\nPress Enter to close...'; read -r _");
  }

  function launchGpkOutdated() {
    launchTerminalCommand("gpk outdated; printf '\\nPress Enter to close...'; read -r _");
  }

  function openFileInTerminal(path) {
    const terminal = safeTerminal();
    const editor = safeEditor();
    if (terminal === "wezterm")
      Quickshell.execDetached([terminal, "start", "--always-new-process", "--", editor, path]);
    else
      Quickshell.execDetached([terminal, "-e", editor, path]);
  }

  function applyInitialTabFromEnv() {
    const requestedPage = Quickshell.env("RYOKU_SETTINGS_PAGE") || "";
    if (requestedPage.length > 0) {
      const normalized = requestedPage.toLowerCase();
      for (let i = 0; i < tabsModel.length; i++) {
        if (String(tabsModel[i].key).toLowerCase() === normalized || String(tabsModel[i].name).toLowerCase() === normalized) {
          currentPage = i;
          break;
        }
      }
    }

    const requestedSubTab = Quickshell.env("RYOKU_SETTINGS_SUBTAB") || "";
    if (requestedSubTab.length > 0) {
      const pageKey = tabsModel[currentPage]?.key ?? "";
      const index = Number(requestedSubTab);
      if (pageKey.length > 0 && !isNaN(index))
        setSubTabForPage(pageKey, Math.max(0, Math.floor(index)));
    }
  }

  Shortcut {
    sequences: [StandardKey.Find]
    onActivated: {
      searchField.focusInput();
    }
  }

  Component.onCompleted: {
    Quickshell.watchFiles = false;
    Config.readWriteDelay = 0;
    applyInitialTabFromEnv();
    centerWindow();
    if (Config.ready)
      ThemeService.applyCurrentTheme();
    loadOutputs();
    loadLayout();
    loadWindowRules();
    loadInput();
    loadCursorThemes();
  }

  Connections {
    target: Config
    function onReadyChanged() {
      if (Config.ready)
        ThemeService.applyCurrentTheme();
    }
    function onConfigChanged() {
      app.easyMode = Config.options?.settingsUi?.easyMode ?? false;
      if (Config.options?.settingsUi?.focusRing?.followTheme ?? false)
        app.syncThemeFocusRing();
    }
  }

  Connections {
    target: app
    function onCurrentPageChanged() {
      if ((app.tabsModel[app.currentPage]?.key ?? "") === "audioDisplay")
        app.loadOutputs();
      if ((app.tabsModel[app.currentPage]?.key ?? "") === "audioDisplay" || (app.tabsModel[app.currentPage]?.key ?? "") === "advanced")
        app.loadLayout();
      if ((app.tabsModel[app.currentPage]?.key ?? "") === "general" || (app.tabsModel[app.currentPage]?.key ?? "") === "audioDisplay")
        app.loadWindowRules();
      if ((app.tabsModel[app.currentPage]?.key ?? "") === "audioDisplay") {
        app.loadInput();
        app.loadCursorThemes();
      }
    }
  }

  Timer {
    id: customThemeApplyTimer
    interval: 350
    repeat: false
    onTriggered: {
      // 1) Local apply in the settings-window process (instant settings-UI
      //    feedback). applyExternal=false so we do NOT run applycolor.sh
      //    twice -- the main shell does that.
      ThemeService.applyCurrentTheme(false);
      // 2) IPC into the main-shell process so its Appearance.m3colors
      //    singleton gets re-applied from the just-written customTheme,
      //    and applycolor.sh runs once to push GTK / terminals / Neovim /
      //    Vesktop / etc. config files.
      Quickshell.execDetached([
        Quickshell.shellPath("scripts/ryoku-shell"),
        "ipc",
        "settings",
        "applyTheme"
      ]);
    }
  }

  Process {
    id: outputsProcess
    command: ["python3", app.scriptPath, "outputs"]
    stdout: StdioCollector {
      id: outputsCollector
      onStreamFinished: {
        try {
          const parsed = JSON.parse(outputsCollector.text);
          if (Array.isArray(parsed)) {
            const selectedName = app.currentOutputName;
            app.outputList = parsed;
            app.outputReady = true;
            if (selectedName.length > 0)
              app.setSelectedOutput(selectedName);
            if (app.selectedOutputIndex >= app.outputList.length)
              app.selectedOutputIndex = 0;
            app.displayStatus = parsed.length > 0 ? "Display list refreshed." : "No connected displays were reported.";
          } else if (parsed && parsed.error) {
            app.displayStatus = String(parsed.error);
          }
        } catch (e) {
          app.displayStatus = "Could not parse display helper output.";
          console.warn("[RyokuSettings] display output parse failure:", e);
        }
      }
    }
    stderr: StdioCollector { id: outputsErrorCollector }
    onExited: exitCode => {
      if (exitCode !== 0)
        app.displayStatus = (outputsErrorCollector.text || outputsCollector.text || "Unable to query connected displays.").trim();
    }
  }

  Process {
    id: displayApplyProcess
    stdout: StdioCollector { id: displayApplyCollector }
    stderr: StdioCollector { id: displayApplyErrorCollector }
    onExited: exitCode => {
      if (exitCode !== 0) {
        app.displayStatus = (displayApplyErrorCollector.text || displayApplyCollector.text || "Display change failed.").trim();
        app.loadOutputs();
        return;
      }
      app.displayStatus = "Saving display change...";
      displayPersistProcess.command = ["python3", app.scriptPath, "persist-output", app.displayPendingOutput, app.displayPendingKey + "=" + app.displayPendingValue];
      displayPersistProcess.running = true;
    }
  }

  Process {
    id: displayPersistProcess
    stdout: StdioCollector { id: displayPersistCollector }
    stderr: StdioCollector { id: displayPersistErrorCollector }
    onExited: exitCode => {
      app.displayStatus = exitCode === 0
        ? "Display setting saved."
        : (displayPersistErrorCollector.text || displayPersistCollector.text || "Display changed, but saving failed.").trim();
      app.loadOutputs();
    }
  }

  Process {
    id: layoutProcess
    command: ["python3", app.scriptPath, "get-layout"]
    stdout: StdioCollector {
      id: layoutCollector
      onStreamFinished: {
        try {
          const parsed = JSON.parse(layoutCollector.text);
          if (parsed && parsed.error)
            app.niriStatus = String(parsed.error);
          else {
            app.layoutData = parsed ?? {};
            app.niriStatus = "Niri layout settings loaded.";
          }
        } catch (e) {
          app.niriStatus = "Could not parse Niri layout settings.";
          console.warn("[RyokuSettings] Niri layout parse failure:", e);
        }
      }
    }
    stderr: StdioCollector { id: layoutErrorCollector }
    onExited: exitCode => {
      if (exitCode !== 0)
        app.niriStatus = (layoutErrorCollector.text || layoutCollector.text || "Unable to read Niri layout settings.").trim();
    }
  }

  Process {
    id: windowRulesProcess
    command: ["python3", app.scriptPath, "get-window-rules"]
    stdout: StdioCollector {
      id: windowRulesCollector
      onStreamFinished: {
        try {
          const parsed = JSON.parse(windowRulesCollector.text);
          if (parsed && parsed.error)
            app.windowRulesStatus = String(parsed.error);
          else {
            app.windowRulesData = parsed ?? {};
            app.windowRulesStatus = "Niri window rules loaded.";
          }
        } catch (e) {
          app.windowRulesStatus = "Could not parse Niri window rules.";
          console.warn("[RyokuSettings] Niri window-rules parse failure:", e);
        }
      }
    }
    stderr: StdioCollector { id: windowRulesErrorCollector }
    onExited: exitCode => {
      if (exitCode !== 0)
        app.windowRulesStatus = (windowRulesErrorCollector.text || windowRulesCollector.text || "Unable to read Niri window rules.").trim();
    }
  }

  Process {
    id: inputProcess
    command: ["python3", app.scriptPath, "get-input"]
    stdout: StdioCollector {
      id: inputCollector
      onStreamFinished: {
        try {
          const parsed = JSON.parse(inputCollector.text);
          if (parsed && parsed.error) {
            app.inputStatus = String(parsed.error);
          } else {
            app.inputData = parsed ?? {};
            app.inputStatus = "Niri input settings loaded.";
          }
        } catch (e) {
          app.inputStatus = "Could not parse Niri input settings.";
          console.warn("[RyokuSettings] Niri input parse failure:", e);
        }
      }
    }
    stderr: StdioCollector { id: inputErrorCollector }
    onExited: exitCode => {
      if (exitCode !== 0)
        app.inputStatus = (inputErrorCollector.text || inputCollector.text || "Unable to read Niri input settings.").trim();
    }
  }

  Process {
    id: cursorThemesProcess
    command: ["python3", app.scriptPath, "list-cursor-themes"]
    stdout: StdioCollector {
      id: cursorThemesCollector
      onStreamFinished: {
        try {
          const parsed = JSON.parse(cursorThemesCollector.text);
          app.cursorThemes = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
          app.inputStatus = "Could not parse installed cursor themes.";
          console.warn("[RyokuSettings] cursor theme parse failure:", e);
        }
      }
    }
    stderr: StdioCollector { id: cursorThemesErrorCollector }
    onExited: exitCode => {
      if (exitCode !== 0)
        app.inputStatus = (cursorThemesErrorCollector.text || cursorThemesCollector.text || "Unable to enumerate cursor themes.").trim();
    }
  }

  Process {
    id: niriSetProcess
    stdout: StdioCollector { id: niriSetCollector }
    stderr: StdioCollector { id: niriSetErrorCollector }
    onExited: exitCode => {
      const statusText = exitCode === 0
        ? "Niri setting saved."
        : (niriSetErrorCollector.text || niriSetCollector.text || "Niri setting failed.").trim();
      if (app.lastSetSection === "input") {
        app.inputStatus = statusText;
        app.loadInput();
      } else if (app.lastSetSection === "window-rules") {
        app.windowRulesStatus = statusText;
        app.loadWindowRules();
      } else {
        app.niriStatus = statusText;
        app.loadLayout();
      }
      app.runNextSetRequest();
    }
  }

  Rectangle {
    anchors.fill: parent
    color: app.auroraStyle ? "transparent" : app.windowColor
  }

  GlassBackground {
    id: windowFrame
    anchors.fill: parent
    anchors.margins: 0
    radius: app.panelRadius
    fallbackColor: app.windowColor
    ryokuColor: Appearance.ryoku.colLayer0
    overlayColor: app.windowColor
    auroraTransparency: app.auroraFrameTransparency
    wallpaperOpacity: app.auroraStyle ? app.auroraFrameWallpaperOpacity : 1.0
    screenX: app.x + x
    screenY: app.y + y
    border.width: 1
    border.color: app.borderColor
    clip: false

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      height: 1
      visible: app.auroraStyle
      color: Qt.rgba(1, 1, 1, 0.18)
      z: 20
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: app.frameMargin
      spacing: 12

      SettingsPanelBox {
        id: sidebar
        Layout.preferredWidth: app.sidebarWidth
        Layout.fillHeight: true
        fallbackColor: app.surfaceColor
        auroraTransparency: app.auroraPaneTransparency

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 10

            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 10
              color: app.hoverColor

              MaterialSymbol {
                anchors.centerIn: parent
                text: "tune"
                iconSize: 20
                color: app.primaryColor
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                Layout.fillWidth: true
                text: "Ryoku Settings"
                color: app.textColor
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Curated shell controls"
                color: app.subtextColor
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
              }
            }
          }

          SettingsSearchField {
            id: searchField
            Layout.fillWidth: true
            text: app.searchText
            onEdited: value => app.searchText = value
          }

          ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.preferredHeight: app.searchText.length > 0 ? Math.min(238, Math.max(42, app.searchResults.length * 46)) : 0
            visible: app.searchText.length > 0
            clip: true
            model: app.searchResults
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds

            delegate: SettingsSearchResult {
              required property var modelData
              width: resultList.width
              title: modelData.label
              description: modelData.page + " / " + modelData.desc
              onClicked: app.navigateSearchResult(modelData)
            }
          }

          ListView {
            id: navList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: app.visibleTabsModel
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: {
              for (let i = 0; i < app.visibleTabsModel.length; i++) {
                if (app.visibleTabsModel[i].realIndex === app.currentPage)
                  return i;
              }
              return 0;
            }

            delegate: SettingsNavItem {
              required property int index
              required property var modelData
              width: navList.width
              tabName: modelData.name
              tabDescription: modelData.desc
              tabIcon: modelData.icon
              selected: modelData.realIndex === app.currentPage
              onClicked: {
                app.currentPage = modelData.realIndex;
                app.searchText = "";
              }
            }
          }

          SettingsConfigFileButton {
          }
        }
      }

      SettingsPanelBox {
        id: contentPane
        Layout.fillWidth: true
        Layout.fillHeight: true
        fallbackColor: app.surfaceColor
        auroraTransparency: app.auroraPaneTransparency

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
              Layout.preferredWidth: 44
              Layout.preferredHeight: 44
              radius: 12
              color: app.activeColor

              MaterialSymbol {
                anchors.centerIn: parent
                text: app.tabsModel[app.currentPage]?.icon ?? "settings"
                iconSize: 23
                color: app.primaryColor
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                Layout.fillWidth: true
                text: app.tabsModel[app.currentPage]?.name ?? ""
                color: app.textColor
                font.family: Appearance.font.family.title
                font.pixelSize: 25
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: app.tabsModel[app.currentPage]?.desc ?? ""
                color: app.subtextColor
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
              }
            }

            SettingsIconButton {
              iconName: app.easyMode ? "school" : "tune"
              tooltipText: app.easyMode
                ? "Easy mode - click to show all settings"
                : "Advanced mode - click to switch to Easy mode (essentials only)"
              onClicked: app.setEasyMode(!app.easyMode)
            }

            SettingsIconButton {
              iconName: "lock"
              tooltipText: "Lock screen"
              onClicked: Quickshell.execDetached([
                Quickshell.shellPath("scripts/ryoku-shell"),
                "lock",
                "activate"
              ])
            }

            SettingsIconButton {
              iconName: "close"
              tooltipText: "Close"
              onClicked: Qt.quit()
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: app.borderColor
          }

          Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: app.tabsModel[app.currentPage]?.source
          }
        }
      }
    }
  }

  component SettingsPanelBox: GlassBackground {
    fallbackColor: app.surfaceColor
    ryokuColor: Appearance.ryoku.colLayer1
    overlayColor: app.surfaceColor
    auroraTransparency: app.auroraPaneTransparency
    wallpaperOpacity: app.auroraStyle ? app.auroraPaneWallpaperOpacity : 1.0
    screenX: app.x + mapToItem(app.contentItem, 0, 0).x
    screenY: app.y + mapToItem(app.contentItem, 0, 0).y
    radius: 12
    border.width: 1
    border.color: app.borderColor

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      height: 1
      visible: app.auroraStyle
      color: Qt.rgba(1, 1, 1, 0.12)
      z: 20
    }
  }

  component SettingsIconButton: Rectangle {
    id: iconButton
    property string iconName: ""
    property string tooltipText: ""
    signal clicked

    Layout.preferredWidth: 34
    Layout.preferredHeight: 34
    radius: 17
    color: buttonMouse.containsMouse ? app.hoverColor : "transparent"

    Behavior on color {
      ColorAnimation { duration: app.fastDuration; easing.type: Easing.InOutQuad }
    }

    MaterialSymbol {
      anchors.centerIn: parent
      text: iconButton.iconName
      iconSize: 18
      color: app.subtextColor
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: iconButton.clicked()
    }
  }

  component SettingsConfigFileButton: Rectangle {
    id: configFileBtn
    property bool justCopied: false
    signal triggered

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    radius: 10
    color: configFileMouse.containsMouse ? app.hoverColor : "transparent"
    border.width: configFileMouse.containsMouse ? 0 : 1
    border.color: app.borderColor

    Behavior on color {
      ColorAnimation { duration: app.fastDuration; easing.type: Easing.InOutQuad }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      spacing: 8

      MaterialSymbol {
        text: configFileBtn.justCopied ? "check" : "edit"
        iconSize: 17
        color: configFileBtn.justCopied ? app.primaryColor : app.subtextColor
      }

      Text {
        Layout.fillWidth: true
        text: configFileBtn.justCopied ? "Path copied" : "Config file"
        color: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: configFileMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
          Quickshell.clipboardText = String(Directories.shellConfigPath).replace(/^file:\/\//, "");
          configFileBtn.justCopied = true;
          configFileRevertTimer.restart();
        } else {
          app.openFileInTerminal(String(Directories.shellConfigPath).replace(/^file:\/\//, ""));
        }
      }
    }

    Timer {
      id: configFileRevertTimer
      interval: 1500
      onTriggered: configFileBtn.justCopied = false;
    }
  }

  component SettingsSearchField: Rectangle {
    id: field
    property string text: ""
    signal edited(string value)

    function focusInput() { searchInput.forceActiveFocus(); }

    Layout.preferredHeight: 38
    radius: 10
    color: searchInput.activeFocus ? app.activeColor : app.windowColor
    border.width: searchInput.activeFocus ? 1 : 0
    border.color: app.primaryColor

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 11
      anchors.rightMargin: 10
      spacing: 8

      MaterialSymbol {
        text: "search"
        iconSize: 17
        color: app.subtextColor
      }

      TextInput {
        id: searchInput
        Layout.fillWidth: true
        text: field.text
        color: app.textColor
        selectionColor: Qt.alpha(app.primaryColor, 0.35)
        selectedTextColor: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        onTextChanged: field.edited(text)

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          text: "Search settings  (Ctrl+F)"
          color: app.subtextColor
          visible: searchInput.text.length === 0 && !searchInput.activeFocus
          font: searchInput.font
          elide: Text.ElideRight
        }
      }
    }
  }

  component SettingsSearchResult: Rectangle {
    id: result
    property string title: ""
    property string description: ""
    signal clicked

    height: 42
    radius: 9
    color: resultMouse.containsMouse ? app.hoverColor : app.windowColor

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      spacing: 8

      MaterialSymbol {
        text: "north_east"
        iconSize: 15
        color: app.primaryColor
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          Layout.fillWidth: true
          text: result.title
          color: app.textColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.small
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: result.description
          color: app.subtextColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.smaller
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      id: resultMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: result.clicked()
    }
  }

  component SettingsNavItem: Rectangle {
    id: nav
    property string tabName: ""
    property string tabDescription: ""
    property string tabIcon: ""
    property bool selected: false
    signal clicked

    height: 42
    radius: 10
    color: selected ? app.quietSelectedColor : navMouse.containsMouse ? app.hoverColor : "transparent"

    Behavior on color {
      ColorAnimation { duration: app.fastDuration; easing.type: Easing.InOutQuad }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 8
      spacing: 10

      MaterialSymbol {
        text: nav.tabIcon
        iconSize: 17
        color: nav.selected ? app.quietSelectedTextColor : navMouse.containsMouse ? app.textColor : app.subtextColor
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          Layout.fillWidth: true
          text: nav.tabName
          color: nav.selected ? app.quietSelectedTextColor : app.textColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.small
          font.weight: nav.selected ? Font.DemiBold : Font.Medium
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: nav.tabDescription
          color: nav.selected ? Qt.alpha(app.quietSelectedTextColor, 0.76) : app.subtextColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.smaller
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      id: navMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: nav.clicked()
    }
  }

  component SettingsPage: ColumnLayout {
    id: page
    default property alias pageItems: pageColumn.data
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 12

    ColumnLayout {
      id: pageColumn
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12
    }
  }

  component SettingsPageBody: ScrollView {
    id: body
    default property alias bodyItems: bodyColumn.data

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentWidth: availableWidth
    contentHeight: bodyColumn.implicitHeight + 4
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    ScrollBar.vertical.width: 6

    Item {
      width: body.availableWidth
      height: bodyColumn.implicitHeight + 4

      ColumnLayout {
        id: bodyColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: app.scrollGutterWidth
        spacing: 18
      }
    }
  }

  component SettingsEmbeddedSettingsPage: Item {
    id: embedded
    property string sourcePath: ""

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    Loader {
      id: embeddedLoader
      anchors.fill: parent
      source: embedded.sourcePath

      onLoaded: {
        if (!item)
          return;
        item.width = Qt.binding(() => embeddedLoader.width);
        item.height = Qt.binding(() => embeddedLoader.height);
      }
    }
  }

  component SettingsSubPage: ColumnLayout {
    id: subPage
    default property alias subPageItems: subPage.data
    Layout.fillWidth: true
    Layout.preferredHeight: StackLayout.isCurrentItem ? implicitHeight : 0
    spacing: 16
    visible: StackLayout.isCurrentItem
  }

  component SettingsStackLayout: StackLayout {
    id: stack
    readonly property Item activeStackItem: currentIndex >= 0 && currentIndex < children.length ? children[currentIndex] : null

    Layout.fillWidth: true
    Layout.preferredHeight: activeStackItem ? activeStackItem.implicitHeight : 0
    implicitHeight: activeStackItem ? activeStackItem.implicitHeight : 0
  }

  component SettingsSubTabs: Flow {
    id: tabs
    property string pageKey: ""
    property var options: []
    readonly property int selectedIndex: app.subTabForPage(tabs.pageKey, 0)

    Layout.fillWidth: true
    Layout.preferredHeight: childrenRect.height
    spacing: 7
    clip: false

    Repeater {
      model: tabs.options

      delegate: Rectangle {
        required property int index
        required property var modelData
        readonly property bool selected: tabs.selectedIndex === index

        width: Math.max(92, label.implicitWidth + 28)
        height: 34
        radius: 9
        color: selected ? app.quietSelectedColor : tabMouse.containsMouse ? app.hoverColor : app.windowColor
        border.width: selected ? 0 : 1
        border.color: app.borderColor

        Text {
          id: label
          anchors.centerIn: parent
          text: modelData
          color: parent.selected ? app.quietSelectedTextColor : app.textColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.small
          font.weight: Font.DemiBold
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: app.setSubTabForPage(tabs.pageKey, index)
        }
      }
    }
  }

  component SettingsSection: ColumnLayout {
    id: section
    property string title: ""
    property string description: ""
    default property alias sectionItems: sectionContent.data

    Layout.maximumWidth: app.contentMaxWidth
    Layout.fillWidth: true
    spacing: 9

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1

      Text {
        Layout.fillWidth: true
        text: section.title
        visible: section.title.length > 0
        color: app.textColor
        font.family: Appearance.font.family.title
        font.pixelSize: Appearance.font.pixelSize.large
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
      }

      Text {
        Layout.fillWidth: true
        text: section.description
        visible: section.description.length > 0
        color: app.subtextColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
      }
    }

    ColumnLayout {
      id: sectionContent
      Layout.fillWidth: true
      spacing: 9
    }
  }

  component SettingsSettingCard: Control {
    id: card
    property string title: ""
    property string description: ""
    property string iconName: ""
    default property alias cardItems: cardContent.data

    Layout.fillWidth: true
    implicitHeight: Math.max(78, contentItem.implicitHeight + topPadding + bottomPadding)
    leftPadding: 12
    rightPadding: 12
    topPadding: 12
    bottomPadding: 12

    background: Item {
      GlassBackground {
        anchors.fill: parent
        radius: app.cardRadius
        fallbackColor: app.surfaceVariantColor
        ryokuColor: Appearance.ryoku.colLayer1
        overlayColor: app.surfaceVariantColor
        auroraTransparency: app.auroraCardTransparency
        wallpaperOpacity: app.auroraStyle ? app.auroraCardWallpaperOpacity : 1.0
        screenX: app.x + card.mapToItem(app.contentItem, 0, 0).x
        screenY: app.y + card.mapToItem(app.contentItem, 0, 0).y
        border.width: 1
        border.color: app.borderColor
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        visible: app.auroraStyle
        color: Qt.rgba(1, 1, 1, 0.1)
        z: 20
      }
    }

    contentItem: Column {
      id: cardLayout
      spacing: 10

      RowLayout {
        width: parent.width
        visible: card.title.length > 0
        spacing: 10

        Rectangle {
          visible: card.iconName.length > 0
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          radius: 9
          color: app.activeColor

          MaterialSymbol {
            anchors.centerIn: parent
            text: card.iconName
            iconSize: 18
            color: app.primaryColor
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            Layout.fillWidth: true
            text: card.title
            color: app.textColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
          }

          Text {
            Layout.fillWidth: true
            text: card.description
            visible: card.description.length > 0
            color: app.subtextColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
          }
        }
      }

      Column {
        id: cardContent
        width: parent.width
        spacing: 8

        onChildrenChanged: {
          for (let i = 0; i < children.length; i++)
            children[i].width = Qt.binding(function() { return cardContent.width; });
        }
      }
    }
  }

  component SettingsLabel: ColumnLayout {
    id: labelRoot
    property string label: ""
    property string description: ""
    property string iconName: ""

    Layout.fillWidth: true
    spacing: 2

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      MaterialSymbol {
        visible: labelRoot.iconName.length > 0
        text: labelRoot.iconName
        iconSize: 16
        color: app.subtextColor
      }

      Text {
        Layout.fillWidth: true
        text: labelRoot.label
        color: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.leftMargin: labelRoot.iconName.length > 0 ? 24 : 0
      text: labelRoot.description
      visible: labelRoot.description.length > 0
      color: app.subtextColor
      font.family: Appearance.font.family.main
      font.pixelSize: Appearance.font.pixelSize.smaller
      wrapMode: Text.WordWrap
    }
  }

  component SettingsSwitch: RowLayout {
    id: row
    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled(bool checked)

    Layout.fillWidth: true
    spacing: 14

    SettingsLabel {
      label: row.label
      description: row.description
    }

    StyledSwitch {
      Layout.alignment: Qt.AlignTop
      scale: 0.62
      checked: row.checked
      onClicked: row.toggled(checked)
    }
  }

  component SettingsModeSegment: RowLayout {
    id: segment
    property var options: []
    property string selectedValue: ""
    signal selected(string value)

    Layout.fillWidth: true
    spacing: 6

    Repeater {
      model: segment.options

      delegate: Rectangle {
        required property int index
        required property var modelData
        readonly property bool selected: String(modelData.value) === String(segment.selectedValue)

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 11
        color: selected ? app.quietSelectedColor : modeMouse.containsMouse ? app.hoverColor : app.windowColor
        border.width: selected ? 0 : 1
        border.color: app.borderColor

        RowLayout {
          anchors.centerIn: parent
          spacing: 7

          MaterialSymbol {
            visible: modelData.icon !== undefined
            text: modelData.icon ?? ""
            iconSize: 17
            color: parent.parent.selected ? app.quietSelectedTextColor : app.subtextColor
          }

          Text {
            text: modelData.label
            color: parent.parent.selected ? app.quietSelectedTextColor : app.textColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
          }
        }

        MouseArea {
          id: modeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: segment.selected(String(modelData.value))
        }
      }
    }
  }

  component SettingsCombo: RowLayout {
    id: row
    property string label: ""
    property string description: ""
    property bool labelVisible: true
    property var options: []
    property var selectedValue: ""
    property string placeholderText: ""
    property bool expanded: false
    property int dropdownX: 0
    property int dropdownY: 0
    property bool openUpward: false
    signal selected(var value)

    function itemAt(index) {
      return options && index >= 0 && index < options.length ? options[index] : null;
    }

    function labelForIndex(index) {
      const item = itemAt(index);
      if (!item)
        return "";
      if (item.label !== undefined)
        return String(item.label);
      if (item.displayName !== undefined)
        return String(item.displayName);
      if (item.name !== undefined)
        return String(item.name);
      if (item.value !== undefined)
        return String(item.value);
      if (item.key !== undefined)
        return String(item.key);
      return "";
    }

    function valueForIndex(index) {
      const item = itemAt(index);
      if (!item)
        return "";
      if (item.value !== undefined)
        return item.value;
      if (item.key !== undefined)
        return item.key;
      if (item.label !== undefined)
        return item.label;
      return "";
    }

    function indexForValue(value) {
      if (row.placeholderText.length > 0 && (value === null || value === undefined || String(value).length === 0))
        return -1;
      for (let i = 0; i < options.length; i++) {
        if (valueForIndex(i) === value || String(valueForIndex(i)) === String(value))
          return i;
      }
      return 0;
    }

    function dropdownHeight() {
      return Math.min(180, ((row.options ? row.options.length : 0) * 32) + 12);
    }

    function syncToSelectedValue() {
      const nextIndex = indexForValue(selectedValue);
      combo.currentIndex = nextIndex;
      comboList.currentIndex = nextIndex;
    }

    function chooseIndex(index) {
      row.selected(row.valueForIndex(index));
      Qt.callLater(row.syncToSelectedValue);
    }

    function openDropdown() {
      app.closeActiveDropdown(row);
      combo.forceActiveFocus();
      const current = Math.max(0, combo.currentIndex);
      comboList.currentIndex = current;
      comboList.positionViewAtIndex(current, ListView.Contain);
      const down = combo.mapToItem(app.contentItem, 0, combo.height + 6);
      const up = combo.mapToItem(app.contentItem, 0, -dropdownHeight() - 6);
      openUpward = down.y + dropdownHeight() > app.height - 14;
      dropdownX = Math.round(down.x);
      dropdownY = Math.round(openUpward ? Math.max(14, up.y) : down.y);
      expanded = true;
    }

    function closeDropdown() {
      expanded = false;
      if (app.activeDropdown === row)
        app.activeDropdown = null;
    }

    function toggleDropdown() {
      if (expanded)
        closeDropdown();
      else
        openDropdown();
    }

    onSelectedValueChanged: syncToSelectedValue()
    onOptionsChanged: syncToSelectedValue()
    Component.onCompleted: syncToSelectedValue()

    Layout.fillWidth: true
    spacing: 14

    SettingsLabel {
      visible: row.labelVisible
      label: row.label
      description: row.description
    }

    ComboBox {
      id: combo
      Layout.fillWidth: !row.labelVisible
      Layout.preferredWidth: row.labelVisible ? 216 : -1
      Layout.alignment: Qt.AlignTop
      model: row.options
      textRole: "label"
      currentIndex: 0
      font.family: Appearance.font.family.main
      font.pixelSize: Appearance.font.pixelSize.small
      displayText: currentIndex >= 0 ? row.labelForIndex(currentIndex) : row.placeholderText
      onActivated: row.chooseIndex(currentIndex)

      Keys.onUpPressed: event => {
        if (!row.expanded) {
          row.openDropdown();
          event.accepted = true;
          return;
        }
        comboList.currentIndex = Math.max(0, comboList.currentIndex - 1);
        comboList.positionViewAtIndex(comboList.currentIndex, ListView.Contain);
        event.accepted = true;
      }

      Keys.onDownPressed: event => {
        if (!row.expanded) {
          row.openDropdown();
          event.accepted = true;
          return;
        }
        comboList.currentIndex = Math.min((row.options ? row.options.length : 1) - 1, comboList.currentIndex + 1);
        comboList.positionViewAtIndex(comboList.currentIndex, ListView.Contain);
        event.accepted = true;
      }

      Keys.onReturnPressed: event => {
        if (!row.expanded) {
          row.openDropdown();
          event.accepted = true;
          return;
        }
        row.chooseIndex(comboList.currentIndex);
        row.closeDropdown();
        event.accepted = true;
      }

      Keys.onEnterPressed: event => {
        combo.Keys.returnPressed(event);
      }

      Keys.onEscapePressed: event => {
        if (row.expanded) {
          row.closeDropdown();
          event.accepted = true;
        } else {
          event.accepted = false;
        }
      }

      background: Rectangle {
        implicitHeight: 34
        radius: 10
        color: row.expanded ? app.activeColor : comboMouse.containsMouse ? app.hoverColor : app.windowColor
        border.width: 1
        border.color: combo.activeFocus ? app.primaryColor : app.borderColor
      }

      contentItem: Text {
        leftPadding: 12
        rightPadding: 32
        text: combo.displayText
        color: app.textColor
        font: combo.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      indicator: MaterialSymbol {
        x: combo.width - width - 8
        y: Math.round((combo.height - height) / 2)
        text: row.expanded ? "expand_less" : "expand_more"
        iconSize: 18
        color: app.subtextColor
      }

      MouseArea {
        id: comboOutsideCatcher
        parent: app.contentItem
        anchors.fill: parent
        z: 999
        visible: row.expanded
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
          row.closeDropdown();
          mouse.accepted = false;
        }
        onWheel: wheel => { row.closeDropdown(); wheel.accepted = false; }
      }

      Rectangle {
        id: comboDropdown
        parent: app.contentItem
        x: row.dropdownX
        y: row.dropdownY
        z: 1000
        width: combo.width
        height: row.dropdownHeight()
        radius: 10
        color: app.popupSurfaceColor
        border.width: 1
        border.color: app.borderColor
        visible: row.expanded

        ListView {
          id: comboList
          anchors.fill: parent
          anchors.margins: 6
          clip: true
          model: row.options || []
          currentIndex: combo.currentIndex
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          WheelHandler {
            id: comboWheelGuard
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: wheel => {
              const rawDelta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
              const delta = rawDelta !== 0 ? rawDelta : wheel.angleDelta.x;
              const maxY = Math.max(0, comboList.contentHeight - comboList.height);
              if (maxY > 0)
                comboList.contentY = Math.max(0, Math.min(maxY, comboList.contentY - delta));
              wheel.accepted = true;
            }
          }

          delegate: Rectangle {
            id: comboDelegate
            required property int index

            width: comboList.width
            height: 32
            radius: 8
            color: comboList.currentIndex === index ? app.activeColor : app.popupSurfaceColor

            Text {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              text: row.labelForIndex(comboDelegate.index)
              color: app.textColor
              font: combo.font
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: {
                if (containsMouse)
                  comboList.currentIndex = comboDelegate.index;
              }
              onClicked: {
                row.chooseIndex(comboDelegate.index);
                row.closeDropdown();
              }
            }
          }
        }
      }

      MouseArea {
        id: comboMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggleDropdown()
      }
    }
  }

  component SettingsSpinBox: RowLayout {
    id: row
    property string label: ""
    property string description: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property int controlValue: value
    signal moved(int value)

    function clamp(nextValue) {
      return Math.max(row.from, Math.min(row.to, nextValue));
    }

    function setControlValue(nextValue) {
      const clamped = clamp(nextValue);
      if (clamped === controlValue)
        return;
      controlValue = clamped;
      row.moved(clamped);
    }

    onValueChanged: controlValue = value
    onControlValueChanged: {
      if (!valueInput.activeFocus)
        valueInput.text = String(controlValue);
    }

    Layout.fillWidth: true
    spacing: 14

    SettingsLabel {
      label: row.label
      description: row.description
    }

    Rectangle {
      id: spinBox
      Layout.preferredWidth: 122
      Layout.preferredHeight: 34
      Layout.alignment: Qt.AlignTop
      radius: 10
      color: app.windowColor
      border.width: 1
      border.color: spinHover.containsMouse || valueInput.activeFocus ? app.primaryColor : app.borderColor

      MouseArea {
        id: spinHover
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onWheel: wheel => row.setControlValue(row.controlValue + (wheel.angleDelta.y > 0 ? row.stepSize : -row.stepSize))
      }

      Rectangle {
        id: decrementButton
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.height
        radius: spinBox.radius
        color: decrementMouse.containsMouse ? app.hoverColor : "transparent"
        opacity: row.controlValue > row.from ? 1 : 0.45

        MaterialSymbol {
          anchors.centerIn: parent
          text: "remove"
          iconSize: 18
          color: app.textColor
        }

        MouseArea {
          id: decrementMouse
          anchors.fill: parent
          enabled: row.controlValue > row.from
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: row.setControlValue(row.controlValue - row.stepSize)
        }
      }

      TextInput {
        id: valueInput
        anchors.left: decrementButton.right
        anchors.right: incrementButton.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        text: String(row.controlValue)
        color: app.textColor
        selectionColor: Qt.alpha(app.primaryColor, 0.35)
        selectedTextColor: app.textColor
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        validator: IntValidator { bottom: row.from; top: row.to }

        function applyValue() {
          const next = parseInt(text);
          if (!isNaN(next))
            row.setControlValue(next);
          text = String(row.controlValue);
        }

        onAccepted: {
          applyValue();
          focus = false;
        }
        onEditingFinished: applyValue()
        Keys.onEscapePressed: {
          text = String(row.controlValue);
          focus = false;
        }
      }

      Rectangle {
        id: incrementButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.height
        radius: spinBox.radius
        color: incrementMouse.containsMouse ? app.hoverColor : "transparent"
        opacity: row.controlValue < row.to ? 1 : 0.45

        MaterialSymbol {
          anchors.centerIn: parent
          text: "add"
          iconSize: 18
          color: app.textColor
        }

        MouseArea {
          id: incrementMouse
          anchors.fill: parent
          enabled: row.controlValue < row.to
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: row.setControlValue(row.controlValue + row.stepSize)
        }
      }
    }
  }

  component SettingsTextField: RowLayout {
    id: row
    property string label: ""
    property string description: ""
    property string value: ""
    property string placeholder: ""
    signal edited(string value)

    Layout.fillWidth: true
    spacing: 14

    SettingsLabel {
      label: row.label
      description: row.description
    }

    Rectangle {
      id: fieldBox
      Layout.preferredWidth: 250
      Layout.preferredHeight: 34
      Layout.alignment: Qt.AlignTop
      radius: 10
      color: textField.activeFocus ? app.activeColor : app.windowColor
      border.width: 1
      border.color: textField.activeFocus ? app.primaryColor : app.borderColor

      TextInput {
        id: textField
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        text: row.value
        color: app.textColor
        selectionColor: Qt.alpha(app.primaryColor, 0.35)
        selectedTextColor: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        verticalAlignment: TextInput.AlignVCenter
        selectByMouse: true
        clip: true
        onEditingFinished: row.edited(text)

        Text {
          anchors.fill: parent
          verticalAlignment: Text.AlignVCenter
          text: row.placeholder
          color: app.subtextColor
          visible: textField.text.length === 0 && !textField.activeFocus
          font: textField.font
          elide: Text.ElideRight
        }
      }

      Connections {
        target: row
        function onValueChanged() {
          if (!textField.activeFocus)
            textField.text = row.value;
        }
      }
    }
  }

  component SettingsTextArea: ColumnLayout {
    id: row
    property string label: ""
    property string description: ""
    property string value: ""
    property string placeholder: ""
    property int preferredHeight: 96
    signal edited(string value)

    Layout.fillWidth: true
    spacing: 8

    SettingsLabel {
      label: row.label
      description: row.description
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: row.preferredHeight
      radius: 10
      color: textArea.activeFocus ? app.activeColor : app.windowColor
      border.width: 1
      border.color: textArea.activeFocus ? app.primaryColor : app.borderColor

      ScrollView {
        anchors.fill: parent
        anchors.margins: 9
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        TextArea {
          id: textArea
          text: row.value
          placeholderText: row.placeholder
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          color: app.textColor
          selectedTextColor: app.textColor
          selectionColor: Qt.alpha(app.primaryColor, 0.35)
          placeholderTextColor: app.subtextColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.small
          background: null
          onActiveFocusChanged: {
            if (!activeFocus)
              row.edited(text);
          }
        }
      }

      Connections {
        target: row
        function onValueChanged() {
          if (!textArea.activeFocus)
            textArea.text = row.value;
        }
      }
    }
  }

  component SettingsColorField: Column {
    id: row
    property string label: ""
    property string description: ""
    property string value: ""
    property string placeholder: "#808080"
    property var swatches: []
    signal edited(string value)

    Layout.fillWidth: true
    width: parent ? parent.width : implicitWidth
    spacing: 8

    RowLayout {
      width: parent.width
      spacing: 14

      SettingsLabel {
        label: row.label
        description: row.description
      }

      Rectangle {
        Layout.preferredWidth: 250
        Layout.preferredHeight: 36
        Layout.alignment: Qt.AlignTop
        radius: 10
        color: colorText.activeFocus ? app.activeColor : app.windowColor
        border.width: 1
        border.color: colorText.activeFocus ? app.primaryColor : app.borderColor

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 8

          Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: 9
            color: row.value.length > 0 ? row.value : row.placeholder
            border.width: 1
            border.color: app.borderColor
          }

          TextInput {
            id: colorText
            Layout.fillWidth: true
            text: row.value
            color: app.textColor
            selectionColor: Qt.alpha(app.primaryColor, 0.35)
            selectedTextColor: app.textColor
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true
            onEditingFinished: row.edited(text.trim())
          }

          MaterialSymbol {
            text: "palette"
            iconSize: 17
            color: app.subtextColor

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: colorDialog.open()
            }
          }
        }

        Connections {
          target: row
          function onValueChanged() {
            if (!colorText.activeFocus)
              colorText.text = row.value;
          }
        }
      }
    }

    Flow {
      width: Math.min(250, parent.width)
      x: Math.max(0, parent.width - width)
      spacing: 6

      Repeater {
        model: row.swatches

        delegate: Rectangle {
          required property var modelData
          width: 30
          height: 22
          radius: 8
          color: modelData.value
          border.width: 1
          border.color: Qt.alpha(app.textColor, 0.18)

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.edited(String(modelData.value))
          }

          StyledToolTip {
            text: modelData.label + " " + modelData.value
          }
        }
      }
    }

    ColorDialog {
      id: colorDialog
      selectedColor: row.value.length > 0 ? row.value : row.placeholder
      onAccepted: row.edited(MaterialThemeLoader.colorToHex(selectedColor))
    }
  }

  component SettingsCopyPathRow: RowLayout {
    id: row
    property string label: ""
    property string path: ""
    property string iconName: "content_copy"
    property bool copied: false

    Layout.fillWidth: true
    spacing: 12

    SettingsLabel {
      label: row.label
      description: "Select, highlight, or copy this path."
      iconName: row.iconName
    }

    Rectangle {
      Layout.preferredWidth: 360
      Layout.preferredHeight: 34
      radius: 10
      color: app.windowColor
      border.width: 1
      border.color: pathText.activeFocus ? app.primaryColor : app.borderColor

      TextInput {
        id: pathText
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 42
        text: row.path
        readOnly: true
        selectByMouse: true
        color: app.textColor
        selectionColor: Qt.alpha(app.primaryColor, 0.35)
        selectedTextColor: app.textColor
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smaller
        verticalAlignment: TextInput.AlignVCenter
        clip: true
      }

      MaterialSymbol {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: row.copied ? "check" : "content_copy"
        iconSize: 17
        color: row.copied ? app.primaryColor : app.subtextColor
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Quickshell.clipboardText = row.path;
          row.copied = true;
          copyReset.restart();
        }
      }

      Timer {
        id: copyReset
        interval: 1400
        onTriggered: row.copied = false
      }
    }
  }

  component SettingsAppSlotRow: ColumnLayout {
    id: row
    property string slotId: ""
    readonly property var definition: AppLauncher.slotDefinition(slotId)

    Layout.fillWidth: true
    spacing: 8

    SettingsCombo {
      label: definition?.label ?? slotId
      description: definition?.description ?? "Preferred launch command."
      options: app.appPresetOptions(slotId)
      selectedValue: AppLauncher.presetIdFor(slotId)
      onSelected: value => {
        if (value !== "__custom__")
          AppLauncher.applyPreset(slotId, value);
      }
    }

    SettingsTextField {
      label: "Command"
      description: "Custom command for " + (definition?.label ?? slotId) + "."
      value: AppLauncher.commandFor(slotId)
      placeholder: definition?.placeholder ?? ""
      onEdited: value => Config.setNestedValue("apps." + slotId, value)
    }
  }

  component SettingsValueSlider: ColumnLayout {
    id: row
    property string label: ""
    property string description: ""
    property real value: 1
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real displayScale: 100
    property int displayDecimals: 0
    property string suffix: ""
    signal moved(real value)

    Layout.fillWidth: true
    spacing: 8

    SettingsLabel {
      label: row.label
      description: row.description
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      StyledSlider {
        id: slider
        Layout.fillWidth: true
        from: row.from
        to: row.to
        stepSize: row.stepSize
        value: row.value
        onMoved: row.moved(value)
      }

      Text {
        Layout.preferredWidth: 70
        text: app.formatNumber(slider.value * row.displayScale, row.displayDecimals) + row.suffix
        color: app.textColor
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  component SettingsButton: Rectangle {
    id: button
    property string text: ""
    property string iconName: ""
    signal clicked

    implicitWidth: Math.max(152, buttonContent.implicitWidth + 30)
    implicitHeight: 36
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    radius: 10
    color: buttonMouse.containsMouse ? app.hoverColor : app.windowColor
    border.width: 1
    border.color: app.borderColor

    RowLayout {
      id: buttonContent
      anchors.centerIn: parent
      spacing: 8

      MaterialSymbol {
        visible: button.iconName.length > 0
        text: button.iconName
        iconSize: 16
        color: app.primaryColor
      }

      Text {
        text: button.text
        color: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
      }
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  component SettingsTemplateRow: Rectangle {
    id: row
    property string label: ""
    property string description: ""
    property string iconName: "chevron_right"
    property bool checked: false
    property bool showCheck: false
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 42
    radius: 12
    color: rowMouse.containsMouse ? app.hoverColor : app.windowColor
    border.width: 1
    border.color: row.showCheck && row.checked ? app.primaryColor : app.borderColor

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 10

      MaterialSymbol {
        text: row.showCheck ? (row.checked ? "check_circle" : "radio_button_unchecked") : row.iconName
        iconSize: 17
        color: row.showCheck && row.checked ? app.primaryColor : app.subtextColor
      }

      Text {
        text: row.label
        color: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
      }

      Text {
        Layout.fillWidth: true
        text: row.description
        color: app.subtextColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }
  }

  component SettingsThemePresetCard: Rectangle {
    id: card
    property var preset: ({})
    readonly property bool active: (preset?.id ?? "") === ThemeService.currentTheme
    readonly property bool favorite: app.isFavoriteTheme(preset?.id ?? "")
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 112
    radius: app.cardRadius
    color: active ? Qt.alpha(app.primaryColor, 0.16) : cardMouse.containsMouse ? app.hoverColor : app.windowColor
    border.width: 1
    border.color: active ? app.primaryColor : app.borderColor

    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.clicked()
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        spacing: 9

        MaterialSymbol {
          text: card.preset?.icon ?? "palette"
          iconSize: 19
          color: card.active ? app.primaryColor : app.subtextColor
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            Layout.fillWidth: true
            text: card.preset?.name ?? ""
            color: app.textColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            text: card.preset?.description ?? ""
            color: app.subtextColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            elide: Text.ElideRight
          }
        }

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 14
          color: favMouse.containsMouse ? app.activeColor : "transparent"
          z: 2

          MaterialSymbol {
            anchors.centerIn: parent
            text: card.favorite ? "star" : "star_border"
            iconSize: 17
            color: card.favorite ? app.primaryColor : app.subtextColor
          }

          MouseArea {
            id: favMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              mouse.accepted = true;
              app.toggleFavoriteTheme(card.preset.id);
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 5

        Repeater {
          model: app.presetSwatches(card.preset)

          delegate: Rectangle {
            required property color modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            radius: 7
            color: modelData
            border.width: 1
            border.color: Qt.alpha(app.textColor, 0.12)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: app.presetTags(card.preset).slice(0, 3)

          delegate: Rectangle {
            required property string modelData
            implicitWidth: tagLabel.implicitWidth + 12
            implicitHeight: 22
            radius: 11
            color: app.activeColor

            Text {
              id: tagLabel
              anchors.centerIn: parent
              text: modelData
              color: app.subtextColor
              font.family: Appearance.font.family.main
              font.pixelSize: Appearance.font.pixelSize.smallest
              font.weight: Font.DemiBold
            }
          }
        }

        Item { Layout.fillWidth: true }
      }
    }
  }

  component SettingsFavoriteThemeCard: Rectangle {
    id: card
    property var preset: ({})
    readonly property bool active: (preset?.id ?? "") === ThemeService.currentTheme
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 54
    radius: 11
    color: active ? Qt.alpha(app.primaryColor, 0.16) : cardMouse.containsMouse ? app.hoverColor : app.windowColor
    border.width: 1
    border.color: active ? app.primaryColor : app.borderColor

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 10
      spacing: 10

      Text {
        Layout.fillWidth: true
        text: card.preset?.name ?? card.preset?.id ?? ""
        color: app.textColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Row {
        spacing: 6
        Layout.alignment: Qt.AlignVCenter

        Repeater {
          model: app.presetSwatches(card.preset)

          delegate: Rectangle {
            required property color modelData
            width: 18
            height: 18
            radius: 9
            color: modelData
            border.width: 1
            border.color: Qt.alpha(app.textColor, 0.16)
          }
        }
      }

      MaterialSymbol {
        visible: card.active
        text: "check_circle"
        iconSize: 18
        color: app.primaryColor
      }
    }

    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.clicked()
    }
  }

  component SettingsCreditCard: Rectangle {
    id: credit
    property string title: ""
    property string description: ""
    property string url: ""

    Layout.fillWidth: true
    implicitHeight: 116
    radius: app.cardRadius
    color: creditMouse.containsMouse ? app.hoverColor : app.windowColor
    border.width: 1
    border.color: app.borderColor

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 6

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          Layout.fillWidth: true
          text: credit.title
          color: app.textColor
          font.family: Appearance.font.family.main
          font.pixelSize: Appearance.font.pixelSize.normal
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        MaterialSymbol {
          text: "open_in_new"
          iconSize: 16
          color: app.primaryColor
        }
      }

      Text {
        Layout.fillWidth: true
        text: credit.description
        color: app.subtextColor
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
      }

      Text {
        Layout.fillWidth: true
        text: credit.url.replace("https://", "")
        color: app.primaryColor
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smallest
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: creditMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Qt.openUrlExternally(credit.url)
    }
  }

  component SettingsToggleGrid: GridLayout {
    id: grid
    property var options: []
    property int cardColumns: width > 620 ? 3 : 2

    Layout.fillWidth: true
    columns: grid.cardColumns
    rowSpacing: 8
    columnSpacing: 8

    Repeater {
      model: grid.options

      delegate: SettingsTemplateRow {
        required property var modelData
        Layout.fillWidth: true
        label: modelData.label
        description: modelData.description ?? ""
        showCheck: true
        checked: modelData.listPath !== undefined
          ? app.configListContains(modelData.listPath, modelData.id)
          : Config.getNestedValue(modelData.path, modelData.fallback ?? false)
        onClicked: {
          if (modelData.listPath !== undefined)
            app.setConfigListMember(modelData.listPath, modelData.id, !checked);
          else
            Config.setNestedValue(modelData.path, !checked);
        }
      }
    }
  }

  component SettingsConfigBoolRow: SettingsSwitch {
    id: boolRow
    property var rowData: ({})
    label: rowData.label ?? app.configLabelForPath(rowData.path ?? "")
    description: rowData.description ?? app.configDescriptionForPath(rowData.path ?? "")
    checked: Config.getNestedValue(rowData.path, rowData.value ?? false)
    onToggled: checked => Config.setNestedValue(rowData.path, checked)
  }

  component SettingsConfigIntRow: SettingsSpinBox {
    id: intRow
    property var rowData: ({})
    label: rowData.label ?? app.configLabelForPath(rowData.path ?? "")
    description: rowData.description ?? app.configDescriptionForPath(rowData.path ?? "")
    from: rowData.from ?? app.intSpinFrom(rowData)
    to: rowData.to ?? app.intSpinTo(rowData)
    stepSize: rowData.stepSize ?? 1
    value: Math.round(Number(Config.getNestedValue(rowData.path, rowData.value ?? 0)))
    onMoved: value => Config.setNestedValue(rowData.path, value)
  }

  component SettingsConfigRealRow: SettingsValueSlider {
    id: realRow
    property var rowData: ({})
    label: rowData.label ?? app.configLabelForPath(rowData.path ?? "")
    description: rowData.description ?? app.configDescriptionForPath(rowData.path ?? "")
    from: rowData.from ?? (Number(rowData.value ?? 0) < 0 ? Math.floor(Number(rowData.value ?? 0) * 2 - 1) : 0)
    to: rowData.to ?? app.realSliderTo(rowData)
    stepSize: rowData.stepSize ?? 0.01
    value: Number(Config.getNestedValue(rowData.path, rowData.value ?? 0))
    displayScale: rowData.displayScale ?? 1
    displayDecimals: rowData.displayDecimals ?? 2
    suffix: rowData.suffix ?? ""
    onMoved: value => Config.setNestedValue(rowData.path, Math.round(value * 100) / 100)
  }

  component SettingsConfigTextRow: SettingsTextField {
    id: textRow
    property var rowData: ({})
    label: rowData.label ?? app.configLabelForPath(rowData.path ?? "")
    description: rowData.description ?? app.configDescriptionForPath(rowData.path ?? "")
    value: String(Config.getNestedValue(rowData.path, rowData.value ?? ""))
    onEdited: value => Config.setNestedValue(rowData.path, value)
  }

  component SettingsConfigListRow: SettingsTextField {
    id: listRow
    property var rowData: ({})
    label: rowData.label ?? app.configLabelForPath(rowData.path ?? "")
    description: rowData.description ?? app.configDescriptionForPath(rowData.path ?? "")
    value: app.configListToString(Config.getNestedValue(rowData.path, rowData.value ?? []))
    onEdited: value => Config.setNestedValue(rowData.path, app.parseConfigList(value))
  }

  component SettingsConfigRow: Loader {
    id: row
    property var rowData: ({})

    Layout.fillWidth: true
    sourceComponent: rowData.kind === "bool" ? boolComponent
      : rowData.kind === "int" ? intComponent
      : rowData.kind === "real" ? realComponent
      : rowData.kind === "list" ? listComponent
      : textComponent

    onLoaded: item.rowData = row.rowData
    onRowDataChanged: {
      if (item)
        item.rowData = rowData;
    }

    Component { id: boolComponent; SettingsConfigBoolRow {} }
    Component { id: intComponent; SettingsConfigIntRow {} }
    Component { id: realComponent; SettingsConfigRealRow {} }
    Component { id: listComponent; SettingsConfigListRow {} }
    Component { id: textComponent; SettingsConfigTextRow {} }
  }

  component SettingsConfigBrowser: ColumnLayout {
    id: browser
    property var prefixes: []
    property var rows: app.flattenConfigRows(prefixes, Config.revision)
    property string query: ""
    property var filteredRows: app.filterConfigRows(rows, query)
    property int maxRows: 260

    Layout.fillWidth: true
    spacing: 10

    SettingsSearchField {
      Layout.fillWidth: true
      text: browser.query
      onEdited: value => browser.query = value
    }

    Repeater {
      model: browser.filteredRows.slice(0, browser.maxRows)

      delegate: SettingsConfigRow {
        required property var modelData
        rowData: modelData
      }
    }

    SettingsLabel {
      visible: browser.filteredRows.length > browser.maxRows
      label: "Refine search to show more"
      description: "Showing " + browser.maxRows + " of " + browser.filteredRows.length + " matching settings."
      iconName: "filter_list"
    }
  }

  Component {
    id: generalPage
    SettingsPage {
      SettingsSubTabs { pageKey: "general"; options: ["Quick Rice", "Waffle", "Fonts", "Language"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("general", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Quick Rice"
            description: "Fast visual controls for theme, glass, focus, cursor, and package maintenance."

            SettingsSettingCard {
              iconName: "palette"
              title: "Look"
              description: "Switch the main visual identity without hunting through the Appearance page."

              SettingsSwitch {
                label: "Use wallpaper colors"
                description: "Generate shell and application colors from the current wallpaper."
                checked: (Config.options?.appearance?.theme ?? "auto") === "auto"
                onToggled: checked => app.setWallpaperColorsEnabled(checked)
              }

              SettingsLabel {
                label: "Favorite theme"
                description: "Apply starred color sets with a real palette preview."
                iconName: "star"
              }

              GridLayout {
                width: parent ? parent.width : implicitWidth
                columns: width > 520 ? 2 : 1
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                  model: app.favoriteThemePresets(Config.revision)

                  delegate: SettingsFavoriteThemeCard {
                    required property var modelData
                    preset: modelData
                    onClicked: app.applyThemePreset(modelData.id)
                  }
                }
              }

              SettingsCombo {
                label: "Palette style"
                description: "How wallpaper colors are shaped into a Material palette."
                options: app.paletteVariantOptions
                selectedValue: Config.options?.appearance?.palette?.type ?? "auto"
                onSelected: value => app.applyPaletteVariant(value)
              }
            }

            SettingsSettingCard {
              iconName: "opacity"
              title: "Glass and windows"
              description: "Aurora-style glass, shell surface opacity, and unfocused window dimming."

              SettingsSwitch {
                label: "Enable shell transparency"
                description: "Allow panels and popups to use transparent glass surfaces."
                checked: Config.options?.appearance?.transparency?.enable ?? false
                onToggled: checked => Config.setNestedValue("appearance.transparency.enable", checked)
              }

              SettingsSwitch {
                label: "Automatic transparency"
                description: "Let Ryoku derive glass strength from the current style. Turn this off when using the manual sliders below."
                checked: Config.options?.appearance?.transparency?.automatic ?? true
                onToggled: checked => Config.setNestedValues({
                  "appearance.transparency.enable": true,
                  "appearance.transparency.automatic": checked
                })
              }

              SettingsValueSlider {
                label: "Shell surface transparency"
                description: "How much panel background glass shows through."
                from: 0
                to: 0.75
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                value: Config.options?.appearance?.transparency?.backgroundTransparency ?? 0.11
                onMoved: value => app.setManualShellTransparency("appearance.transparency.backgroundTransparency", value)
              }

              SettingsValueSlider {
                label: "Content transparency"
                description: "How transparent inner content layers are."
                from: 0
                to: 0.9
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                value: Config.options?.appearance?.transparency?.contentTransparency ?? 0.57
                onMoved: value => app.setManualShellTransparency("appearance.transparency.contentTransparency", value)
              }

              SettingsValueSlider {
                label: "Inactive window opacity"
                description: "Focused windows stay fully opaque; unfocused windows dim to this value."
                from: 0.45
                to: 1.0
                stepSize: 0.05
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                value: app.windowRulesData?.inactive_opacity ?? 0.9
                onMoved: value => app.niriSetConfig("window-rules", "inactive-opacity", app.formatReal(value, 0.9))
              }

              SettingsLabel {
                label: "Active window opacity"
                description: "Niri keeps the focused window fully opaque. The slider above changes unfocused windows; this settings panel is pinned opaque so controls stay readable."
                iconName: "info"
              }

              SettingsLabel {
                label: app.windowRulesStatus.length > 0 ? app.windowRulesStatus : "Niri window rules ready"
                description: app.scriptPath
                iconName: "data_object"
              }
            }

            SettingsSettingCard {
              iconName: "center_focus_strong"
              title: "Focus and cursor"
              description: "Common compositor feel controls from the detailed Audio & Display page."

              SettingsSwitch {
                label: "Enable focus ring"
                description: "Draw a ring around the focused window."
                checked: app.layoutData?.focus_ring?.enabled ?? false
                onToggled: checked => app.niriSetBooleanConfig("layout", "focus-ring.enabled", checked)
              }

              SettingsSpinBox {
                label: "Focus ring width"
                description: "Border width in pixels."
                from: 1
                to: 16
                stepSize: 1
                value: app.layoutData?.focus_ring?.width ?? 1
                onMoved: value => app.niriSetConfig("layout", "focus-ring.width", value)
              }

              SettingsSwitch {
                label: "Follow theme focus ring"
                description: "Use the active Ryoku preset color for active and inactive focus rings."
                checked: Config.options?.settingsUi?.focusRing?.followTheme ?? false
                onToggled: checked => {
                  Config.setNestedValue("settingsUi.focusRing.followTheme", checked);
                  if (checked)
                    app.syncThemeFocusRing();
                }
              }

              SettingsCombo {
                label: "Cursor theme"
                description: "Installed XCursor theme used by Niri and new applications."
                options: app.cursorThemeOptions()
                selectedValue: app.currentCursorTheme()
                onSelected: value => app.niriSetConfig("input", "cursor.xcursor-theme", value)
              }

              SettingsSpinBox {
                label: "Cursor size"
                description: "Cursor size in pixels."
                from: 16
                to: 64
                stepSize: 2
                value: app.cursorData?.size ?? 24
                onMoved: value => app.niriSetConfig("input", "cursor.xcursor-size", value)
              }
            }

            SettingsSettingCard {
              iconName: "deployed_code"
              title: "Package manager"
              description: "GPK handles install, uninstall, and update actions across available package managers."

              Flow {
                width: parent.width
                spacing: 8

                SettingsButton { text: "Open GPK"; iconName: "terminal"; onClicked: app.launchPackageManager() }
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Waffle"
            description: "Windows-style panel family. Toggle Waffle on in Panels and Modules first."

            SettingsSettingCard {
              iconName: "grid_on"
              title: "Waffle launcher"
              description: "Real Waffle panels and options from the active shell config."

              SettingsToggleGrid {
                options: [
                  { label: "Start menu", description: "Waffle launcher surface.", listPath: "enabledPanels", id: "wStartMenu" },
                  { label: "Action center", description: "Waffle quick settings.", listPath: "enabledPanels", id: "wActionCenter" },
                  { label: "Notifications", description: "Waffle notification center.", listPath: "enabledPanels", id: "wNotificationCenter" },
                  { label: "Widgets", description: "Waffle desktop widgets.", listPath: "enabledPanels", id: "wWidgets" },
                  { label: "Task view", description: "Waffle task/workspace view.", listPath: "enabledPanels", id: "wTaskView" },
                  { label: "Waffle bar", description: "Waffle bar surface.", listPath: "enabledPanels", id: "wBar" }
                ]
              }

              SettingsToggleGrid {
                options: [
                  { label: "Material style", description: "Use Material controls in Waffle settings.", path: "waffles.settings.useMaterialStyle", fallback: false },
                  { label: "Smoother menu animations", description: "Enable Waffle animation tweak.", path: "waffles.tweaks.smootherMenuAnimations", fallback: true },
                  { label: "Switch handle fix", description: "Keep Waffle switch handle aligned.", path: "waffles.tweaks.switchHandlePositionFix", fallback: true },
                  { label: "Alt switcher animation", description: "Animate Waffle alt switcher.", path: "waffles.altSwitcher.enableAnimation", fallback: true },
                  { label: "Most recent first", description: "Sort Waffle alt switcher by recent windows.", path: "waffles.altSwitcher.useMostRecentFirst", fallback: true },
                  { label: "Close on focus", description: "Close Waffle switcher after selecting a window.", path: "waffles.altSwitcher.closeOnFocus", fallback: true }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Fonts"
            description: "Choose the fonts used throughout the interface."

            SettingsSettingCard {
              iconName: "format_size"
              title: "Typefaces"
              description: "Use familiar names instead of editing font keys by hand."

              SettingsCombo {
                label: "Default font"
                description: "Main font used throughout the interface."
                options: [
                  { label: "Roboto Flex", value: "Roboto Flex" },
                  { label: "Fira Sans", value: "Fira Sans" },
                  { label: "Inter", value: "Inter" },
                  { label: "Space Grotesk", value: "Space Grotesk" }
                ]
                selectedValue: Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex"
                onSelected: value => Config.setNestedValue("appearance.typography.mainFont", value)
              }

              SettingsCombo {
                label: "Title font"
                description: "Font used for headings and section titles."
                options: [
                  { label: "Roboto Flex", value: "Roboto Flex" },
                  { label: "Fira Sans", value: "Fira Sans" },
                  { label: "Inter", value: "Inter" },
                  { label: "Space Grotesk", value: "Space Grotesk" }
                ]
                selectedValue: Config.options?.appearance?.typography?.titleFont ?? "Roboto Flex"
                onSelected: value => Config.setNestedValue("appearance.typography.titleFont", value)
              }

              SettingsCombo {
                label: "Monospaced font"
                description: "Monospace font used for numbers and stats."
                options: [
                  { label: "JetBrainsMono Nerd Font", value: "JetBrainsMono Nerd Font" },
                  { label: "CaskaydiaCove Nerd Font Mono", value: "CaskaydiaCove Nerd Font Mono" },
                  { label: "Cascadia Mono", value: "Cascadia Mono" }
                ]
                selectedValue: Config.options?.appearance?.typography?.monospaceFont ?? "JetBrainsMono Nerd Font"
                onSelected: value => Config.setNestedValue("appearance.typography.monospaceFont", value)
              }
            }

            SettingsSettingCard {
              iconName: "text_increase"
              title: "Text scale"
              description: "Adjust standard text size without touching the raw theme file."

              SettingsValueSlider {
                label: "Default font size"
                description: "Increase or decrease standard text."
                from: 0.75
                to: 1.35
                stepSize: 0.01
                value: Config.options?.appearance?.typography?.sizeScale ?? 1
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.typography.sizeScale", value)
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Language"
            description: "Choose your preferred language and launch first-run setup."

            SettingsSettingCard {
              iconName: "language"
              title: "Application language"
              description: "Automatic follows the current system locale where supported."

              SettingsCombo {
                label: "Language"
                description: "Language used in the settings interface."
                options: [
                  { label: "Automatic (en)", value: "auto" },
                  { label: "English", value: "en_US" },
                  { label: "Spanish", value: "es_ES" }
                ]
                selectedValue: Config.options?.language?.ui ?? "auto"
                onSelected: value => Config.setNestedValue("language.ui", value)
              }

              SettingsButton {
                text: "Launch the setup wizard"
                iconName: "rocket_launch"
                onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "welcome"])
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: appearancePage
    SettingsPage {
      SettingsSubTabs { pageKey: "appearance"; options: ["Colors", "Themes", "Templates", "Motion", "Style"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("appearance", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Color source"
            description: "Main settings for Ryoku's colors."

            SettingsSettingCard {
              iconName: "routine"
              title: "Theme mode"
              description: "Light, dark, wallpaper-driven, or scheduled. " + app.themeModeSummary

              SettingsModeSegment {
                options: app.themeModeOptions
                selectedValue: app.currentThemeMode()
                onSelected: value => app.setThemeMode(value)
              }
            }

            SettingsSettingCard {
              iconName: "auto_awesome"
              title: "Wallpaper colors"
              description: "Generate shell and app color schemes from your wallpaper using Matugen."

              SettingsModeSegment {
                options: [
                  { label: "Wallpaper", value: "auto", icon: "wallpaper" },
                  { label: "Preset", value: "catppuccin-mocha", icon: "style" },
                  { label: "Custom", value: "custom", icon: "edit" }
                ]
                selectedValue: Config.options?.appearance?.theme ?? "auto"
                onSelected: value => Config.setNestedValue("appearance.theme", value)
              }

              SettingsCombo {
                label: "Matugen scheme type"
                description: "Derives colors that closely match the underlying image."
                options: app.paletteVariantOptions
                selectedValue: Config.options?.appearance?.palette?.type ?? "auto"
                onSelected: value => app.applyPaletteVariant(value)
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Themes"
            description: "Color sets from Ryoku's theme registry with swatches, favorites, and schedule choices."

            SettingsSettingCard {
              iconName: "color_lens"
              title: "Color sets"
              description: "Pick a preset by looking at the palette instead of typing a theme id."

              SettingsSearchField {
                Layout.fillWidth: true
                text: app.themeSearchText
                onEdited: value => app.themeSearchText = value
              }

              SettingsModeSegment {
                options: [
                  { label: "All", value: "all", icon: "palette" },
                  { label: "Dark", value: "dark", icon: "dark_mode" },
                  { label: "Light", value: "light", icon: "light_mode" },
                  { label: "Saved", value: "favorites", icon: "star" }
                ]
                selectedValue: app.themeFilter
                onSelected: value => app.themeFilter = value
              }

              GridLayout {
                Layout.fillWidth: true
                columns: width > 800 ? 3 : width > 480 ? 2 : 1
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                  model: app.filteredThemePresets(Config.revision)

                  delegate: SettingsFavoriteThemeCard {
                    required property var modelData
                    preset: modelData
                    onClicked: app.applyThemePreset(modelData.id)
                  }
                }
              }
            }

            SettingsSettingCard {
              iconName: "routine"
              title: "Theme schedule"
              description: "Use schedule when you want different day and night presets."

              SettingsCombo {
                label: "Schedule"
                description: "Automatic switching between day and night presets."
                options: [
                  { label: "Off", value: "off" },
                  { label: "Day / night", value: "schedule" }
                ]
                selectedValue: (Config.options?.appearance?.themeSchedule?.enabled ?? false) ? "schedule" : "off"
                onSelected: value => {
                  Config.setNestedValue("appearance.themeSchedule.enabled", value === "schedule");
                  Config.setNestedValue("appearance.themeMode", value === "schedule" ? "schedule" : app.currentThemeMode());
                }
              }

              SettingsCombo {
                label: "Day theme"
                description: "Theme used during daytime."
                options: app.themePresetOptions()
                selectedValue: Config.options?.appearance?.themeSchedule?.dayTheme ?? "auto"
                onSelected: value => Config.setNestedValue("appearance.themeSchedule.dayTheme", value)
              }

              SettingsCombo {
                label: "Night theme"
                description: "Theme used at night."
                options: app.themePresetOptions()
                selectedValue: Config.options?.appearance?.themeSchedule?.nightTheme ?? "auto"
                onSelected: value => Config.setNestedValue("appearance.themeSchedule.nightTheme", value)
              }
            }

          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Templates"
            description: "Apply generated colors to external applications without flooding this page with switches."

            SettingsSettingCard {
              iconName: "brush"
              title: "Template scopes"
              description: "Control where generated colors are written."

              SettingsToggleGrid {
                options: [
                  { label: "Apps and shell", description: "Desktop apps and shell surfaces.", path: "appearance.wallpaperTheming.enableAppsAndShell", fallback: true },
                  { label: "Qt apps", description: "Qt application colors.", path: "appearance.wallpaperTheming.enableQtApps", fallback: true },
                  { label: "Terminal", description: "Terminal emulator themes.", path: "appearance.wallpaperTheming.enableTerminal", fallback: true },
                  { label: "VS Code", description: "VS Code family themes.", path: "appearance.wallpaperTheming.enableVSCode", fallback: true },
                  { label: "Chrome", description: "Chrome browser theme.", path: "appearance.wallpaperTheming.enableChrome", fallback: true },
                  { label: "Vesktop", description: "Discord/Vesktop colors.", path: "appearance.wallpaperTheming.enableVesktop", fallback: true },
                  { label: "Neovim", description: "Neovim colors.", path: "appearance.wallpaperTheming.enableNeovim", fallback: true },
                  { label: "Cava", description: "Cava visualizer.", path: "appearance.wallpaperTheming.enableCava", fallback: false },
                  { label: "Steam", description: "Steam styling.", path: "appearance.wallpaperTheming.enableSteam", fallback: false }
                ]
              }
            }

            SettingsSettingCard {
              iconName: "terminal"
              title: "Terminal templates"
              description: "Generate colors for installed terminal tools and command-line apps."

              SettingsToggleGrid {
                options: [
                  { label: "Kitty", description: "Kitty terminal.", path: "appearance.wallpaperTheming.terminals.kitty", fallback: true },
                  { label: "Alacritty", description: "Alacritty terminal.", path: "appearance.wallpaperTheming.terminals.alacritty", fallback: true },
                  { label: "Foot", description: "Foot terminal.", path: "appearance.wallpaperTheming.terminals.foot", fallback: true },
                  { label: "WezTerm", description: "WezTerm terminal.", path: "appearance.wallpaperTheming.terminals.wezterm", fallback: true },
                  { label: "Ghostty", description: "Ghostty terminal.", path: "appearance.wallpaperTheming.terminals.ghostty", fallback: true },
                  { label: "Konsole", description: "Konsole terminal.", path: "appearance.wallpaperTheming.terminals.konsole", fallback: true },
                  { label: "Starship", description: "Prompt palette.", path: "appearance.wallpaperTheming.terminals.starship", fallback: true },
                  { label: "btop", description: "System monitor theme.", path: "appearance.wallpaperTheming.terminals.btop", fallback: true },
                  { label: "lazygit", description: "Terminal git UI.", path: "appearance.wallpaperTheming.terminals.lazygit", fallback: true },
                  { label: "yazi", description: "File manager flavor.", path: "appearance.wallpaperTheming.terminals.yazi", fallback: true }
                ]
              }
            }

            SettingsSettingCard {
              iconName: "tune"
              title: "Terminal color shaping"
              description: "Adjust generated terminal palettes without editing template files."

              SettingsSpinBox { label: "Color saturation"; description: "Terminal color saturation percentage."; from: 10; to: 80; stepSize: 5; value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.saturation ?? 0.65) * 100); onMoved: value => Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.saturation", value / 100) }
              SettingsSpinBox { label: "Color brightness"; description: "Terminal color brightness percentage."; from: 35; to: 75; stepSize: 5; value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.brightness ?? 0.60) * 100); onMoved: value => Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.brightness", value / 100) }
              SettingsSpinBox { label: "Theme harmony"; description: "Shift terminal hues toward the active theme."; from: 0; to: 100; stepSize: 5; value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.harmony ?? 0.40) * 100); onMoved: value => Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.harmony", value / 100) }
              SettingsSpinBox { label: "Background brightness"; description: "Terminal background brightness percentage."; from: 10; to: 90; stepSize: 5; value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.backgroundBrightness ?? 0.50) * 100); onMoved: value => Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.backgroundBrightness", value / 100) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Motion and transparency"
            description: "Visual feel shared across Material, Aurora, Ryoku, and Angel."

            SettingsSettingCard {
              iconName: "animation"
              title: "Animation"
              description: "Use these controls for shell motion, not compositor keyframes."

              SettingsValueSlider {
                label: "Animation scale"
                description: "Global shell animation speed."
                from: 0
                to: 1.5
                stepSize: 0.05
                value: Config.options?.animations?.scale ?? 1
                suffix: "%"
                onMoved: value => Config.setNestedValue("animations.scale", value)
              }

              SettingsSwitch {
                label: "Reduce motion"
                description: "Prefer shorter transitions and simpler motion."
                checked: Config.options?.animations?.reduceMotion ?? false
                onToggled: checked => Config.setNestedValue("animations.reduceMotion", checked)
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Style"
            description: "Pick the shell style, then tune its style-specific editor below."

            SettingsSettingCard {
              iconName: "palette"
              title: "Shell style"
              description: "Switch between Material, Cards, Aurora, Ryoku, and Angel. The matching editor card appears below once selected."

              SettingsCombo {
                label: "Style"
                description: "Active shell style. Some style-specific cards are gated on this value."
                options: app.globalStyleOptions
                selectedValue: app.currentStyle()
                onSelected: value => app.applyGlobalStyle(value)
              }

              SettingsModeSegment {
                options: [
                  { label: "Wallpaper", value: "auto", icon: "wallpaper" },
                  { label: "Preset", value: "catppuccin-mocha", icon: "style" },
                  { label: "Custom", value: "custom", icon: "edit" }
                ]
                selectedValue: Config.options?.appearance?.theme ?? "auto"
                onSelected: value => Config.setNestedValue("appearance.theme", value)
              }
            }

            SettingsSettingCard {
              iconName: "blur_on"
              title: "Aurora glass"
              description: "Transparency for panels, cards, popups, tooltips, and surface layers. Active while the Aurora style is on."
              visible: Appearance.auroraEverywhere && !Appearance.angelEverywhere

              Flow {
                width: parent.width
                spacing: 8
                SettingsButton { text: "Default"; iconName: "blur_on"; onClicked: app.applyAuroraPreset("default") }
                SettingsButton { text: "Frosted"; iconName: "ac_unit"; onClicked: app.applyAuroraPreset("frosted") }
                SettingsButton { text: "Clear"; iconName: "visibility"; onClicked: app.applyAuroraPreset("clear") }
                SettingsButton { text: "Subtle"; iconName: "blur_off"; onClicked: app.applyAuroraPreset("subtle") }
              }

              Flow {
                width: parent.width
                spacing: 8
                SettingsButton { text: "Save"; iconName: "save"; onClicked: app.saveAuroraCustom() }
                SettingsButton { text: "Load"; iconName: "restore"; enabled: (Config.options?.appearance?.aurora?.customPreset ?? "") !== ""; onClicked: app.loadAuroraCustom() }
                SettingsButton { text: "Reset"; iconName: "restart_alt"; onClicked: app.applyAuroraPreset("default") }
              }

              SettingsValueSlider {
                label: "Panels"
                description: "Transparency of bar and sidebar surfaces."
                value: Config.options?.appearance?.aurora?.transparency?.overlay ?? 0.30
                from: 0
                to: 1
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.aurora.transparency.overlay", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Cards"
                description: "Transparency of card surfaces."
                value: Config.options?.appearance?.aurora?.transparency?.subSurface ?? 0.42
                from: 0
                to: 1
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.aurora.transparency.subSurface", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Popups"
                description: "Transparency of popup menus and dropdowns."
                value: Config.options?.appearance?.aurora?.transparency?.popup ?? 0.32
                from: 0
                to: 1
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.aurora.transparency.popup", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Tooltips"
                description: "Transparency of hover tooltips."
                value: Config.options?.appearance?.aurora?.transparency?.tooltip ?? 0.28
                from: 0
                to: 1
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.aurora.transparency.tooltip", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Surface layers"
                description: "Transparency of stacked surface layers (cards on cards)."
                value: Config.options?.appearance?.aurora?.transparency?.layer ?? 0.32
                from: 0
                to: 1
                stepSize: 0.01
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.aurora.transparency.layer", Math.round(value * 100) / 100)
              }
            }

            SettingsSettingCard {
              iconName: "auto_awesome"
              title: "Angel presets"
              description: "Apply a ready-made Angel look, or save the current tuning as a named profile."
              visible: Appearance.angelEverywhere

              Flow {
                width: parent.width
                spacing: 8
                SettingsButton { text: "Default"; iconName: "auto_awesome"; onClicked: app.applyAngelPreset("default") }
                SettingsButton { text: "Ethereal"; iconName: "cloud"; onClicked: app.applyAngelPreset("ethereal") }
                SettingsButton { text: "Monolith"; iconName: "square"; onClicked: app.applyAngelPreset("monolith") }
                SettingsButton { text: "Crystalline"; iconName: "diamond"; onClicked: app.applyAngelPreset("crystalline") }
              }

              Flow {
                width: parent.width
                spacing: 8
                SettingsButton { text: "Save"; iconName: "save"; onClicked: app.saveAngelCustom() }
                SettingsButton { text: "Load"; iconName: "restore"; enabled: (Config.options?.appearance?.angel?.customPreset ?? "") !== ""; onClicked: app.loadAngelCustom() }
                SettingsButton { text: "Reset"; iconName: "restart_alt"; onClicked: app.applyAngelPreset("default") }
              }

              SettingsTextField {
                id: angelProfileNameField
                label: "Named profile"
                description: "Save the current Angel tuning under a name to recall it later."
                value: ""
                placeholder: "profile name"
                onEdited: value => angelProfileNameField.value = value
              }

              SettingsButton {
                text: "Save profile"
                iconName: "bookmark_add"
                enabled: angelProfileNameField.value.length > 0
                onClicked: { app.saveAngelProfile(angelProfileNameField.value); angelProfileNameField.value = ""; }
              }

              Repeater {
                model: app.angelProfileNames(Config.revision)
                delegate: RowLayout {
                  required property string modelData
                  Layout.fillWidth: true
                  spacing: 8
                  Text {
                    Layout.fillWidth: true
                    text: modelData
                    color: app.textColor
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                  }
                  SettingsButton { text: "Load"; iconName: "restore"; onClicked: app.loadAngelProfile(modelData) }
                  SettingsButton { text: "Delete"; iconName: "delete"; onClicked: app.deleteAngelProfile(modelData) }
                }
              }
            }

            SettingsSettingCard {
              iconName: "blur_on"
              title: "Angel blur and tint"
              description: "Glass intensity, color saturation, and the four transparency channels."
              visible: Appearance.angelEverywhere

              SettingsValueSlider {
                label: "Color strength"
                description: "How saturated the Angel tint is. 0 is neutral, 2 is maximum."
                value: Config.options?.appearance?.angel?.colorStrength ?? 0.6
                from: 0
                to: 2
                stepSize: 0.05
                displayScale: 100
                displayDecimals: 0
                suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.angel.colorStrength", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Blur intensity"
                description: "Background blur strength."
                value: Config.options?.appearance?.angel?.blur?.intensity ?? 0.35
                from: 0; to: 1; stepSize: 0.01
                displayScale: 100; displayDecimals: 0; suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.angel.blur.intensity", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Blur saturation"
                description: "Color punch behind the glass."
                value: Config.options?.appearance?.angel?.blur?.saturation ?? 0.20
                from: 0; to: 1; stepSize: 0.01
                displayScale: 100; displayDecimals: 0; suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.angel.blur.saturation", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Overlay opacity"
                description: "Tint overlay on top of the blur."
                value: Config.options?.appearance?.angel?.blur?.overlayOpacity ?? 0.45
                from: 0; to: 1; stepSize: 0.01
                displayScale: 100; displayDecimals: 0; suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.angel.blur.overlayOpacity", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Noise opacity"
                description: "Film-grain texture above the overlay."
                value: Config.options?.appearance?.angel?.blur?.noiseOpacity ?? 0.20
                from: 0; to: 1; stepSize: 0.01
                displayScale: 100; displayDecimals: 0; suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.angel.blur.noiseOpacity", Math.round(value * 100) / 100)
              }

              SettingsValueSlider {
                label: "Vignette strength"
                description: "Edge darkening to focus the eye."
                value: Config.options?.appearance?.angel?.blur?.vignetteStrength ?? 0.15
                from: 0; to: 1; stepSize: 0.01
                displayScale: 100; displayDecimals: 0; suffix: "%"
                onMoved: value => Config.setNestedValue("appearance.angel.blur.vignetteStrength", Math.round(value * 100) / 100)
              }

              SettingsValueSlider { label: "Panels"; description: "Bar and sidebar transparency."; value: Config.options?.appearance?.angel?.transparency?.panel ?? 0.28; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.transparency.panel", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Cards"; description: "Card surface transparency."; value: Config.options?.appearance?.angel?.transparency?.card ?? 0.40; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.transparency.card", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Popups"; description: "Popup menu transparency."; value: Config.options?.appearance?.angel?.transparency?.popup ?? 0.28; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.transparency.popup", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Tooltips"; description: "Tooltip transparency."; value: Config.options?.appearance?.angel?.transparency?.tooltip ?? 0.25; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.transparency.tooltip", Math.round(value * 100) / 100) }
            }

            SettingsSettingCard {
              iconName: "layers"
              title: "Angel escalonado"
              description: "Staircase card offsets, hover lift, and shadow glass."
              visible: Appearance.angelEverywhere

              SettingsSpinBox { label: "Offset X"; description: "Resting card X offset."; from: 0; to: 20; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonado?.offsetX ?? 1); onMoved: value => Config.setNestedValue("appearance.angel.escalonado.offsetX", value) }
              SettingsSpinBox { label: "Offset Y"; description: "Resting card Y offset."; from: 0; to: 20; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonado?.offsetY ?? 1); onMoved: value => Config.setNestedValue("appearance.angel.escalonado.offsetY", value) }
              SettingsSpinBox { label: "Hover offset X"; description: "X offset when hovered."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonado?.hoverOffsetX ?? 7); onMoved: value => Config.setNestedValue("appearance.angel.escalonado.hoverOffsetX", value) }
              SettingsSpinBox { label: "Hover offset Y"; description: "Y offset when hovered."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonado?.hoverOffsetY ?? 7); onMoved: value => Config.setNestedValue("appearance.angel.escalonado.hoverOffsetY", value) }
              SettingsValueSlider { label: "Fill opacity"; description: "Resting card fill."; value: Config.options?.appearance?.angel?.escalonado?.opacity ?? 0.50; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonado.opacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Border opacity"; description: "Card border opacity."; value: Config.options?.appearance?.angel?.escalonado?.borderOpacity ?? 0.17; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonado.borderOpacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Hover opacity"; description: "Fill when hovered."; value: Config.options?.appearance?.angel?.escalonado?.hoverOpacity ?? 0.0; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonado.hoverOpacity", Math.round(value * 100) / 100) }

              SettingsSpinBox { label: "Shadow X"; description: "Drop-shadow X offset."; from: 0; to: 20; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonadoShadow?.offsetX ?? 3); onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.offsetX", value) }
              SettingsSpinBox { label: "Shadow Y"; description: "Drop-shadow Y offset."; from: 0; to: 20; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonadoShadow?.offsetY ?? 2); onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.offsetY", value) }
              SettingsSpinBox { label: "Shadow hover X"; description: "Shadow X on hover."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonadoShadow?.hoverOffsetX ?? 7); onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.hoverOffsetX", value) }
              SettingsSpinBox { label: "Shadow hover Y"; description: "Shadow Y on hover."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.escalonadoShadow?.hoverOffsetY ?? 7); onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.hoverOffsetY", value) }
              SettingsValueSlider { label: "Shadow opacity"; description: "Drop-shadow strength."; value: Config.options?.appearance?.angel?.escalonadoShadow?.opacity ?? 1.0; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.opacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Shadow border opacity"; description: "Shadow border strength."; value: Config.options?.appearance?.angel?.escalonadoShadow?.borderOpacity ?? 1.0; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.borderOpacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Shadow hover opacity"; description: "Shadow strength on hover."; value: Config.options?.appearance?.angel?.escalonadoShadow?.hoverOpacity ?? 0.60; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.hoverOpacity", Math.round(value * 100) / 100) }

              SettingsSwitch { label: "Glass on shadow"; description: "Render the drop-shadow with the Angel glass material."; checked: Config.options?.appearance?.angel?.escalonadoShadow?.glass ?? true; onToggled: checked => Config.setNestedValue("appearance.angel.escalonadoShadow.glass", checked) }
              SettingsValueSlider { label: "Shadow blur"; description: "Glass blur amount on the shadow."; value: Config.options?.appearance?.angel?.escalonadoShadow?.glassBlur ?? 0.70; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.glassBlur", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Shadow overlay"; description: "Tint overlay on the glass shadow."; value: Config.options?.appearance?.angel?.escalonadoShadow?.glassOverlay ?? 0.50; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.escalonadoShadow.glassOverlay", Math.round(value * 100) / 100) }
            }

            SettingsSettingCard {
              iconName: "border_style"
              title: "Angel borders"
              description: "Card and panel border width, opacity, accent bars, and inset glow."
              visible: Appearance.angelEverywhere

              SettingsValueSlider { label: "Border width"; description: "Stroke width for card borders."; value: Config.options?.appearance?.angel?.border?.width ?? 0.8; from: 0; to: 5; stepSize: 0.1; displayScale: 10; displayDecimals: 0; suffix: ""; onMoved: value => Config.setNestedValue("appearance.angel.border.width", Math.round(value * 10) / 10) }
              SettingsValueSlider { label: "Border coverage"; description: "How much of the perimeter is drawn."; value: Config.options?.appearance?.angel?.border?.coverage ?? 0.60; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.border.coverage", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Border opacity"; description: "Resting border strength."; value: Config.options?.appearance?.angel?.border?.opacity ?? 0.52; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.border.opacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Hover border opacity"; description: "Border strength on hover."; value: Config.options?.appearance?.angel?.border?.hoverOpacity ?? 0.50; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.border.hoverOpacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Active border opacity"; description: "Border strength on the active card."; value: Config.options?.appearance?.angel?.border?.activeOpacity ?? 0.50; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.border.activeOpacity", Math.round(value * 100) / 100) }

              SettingsSpinBox { label: "Accent bar height"; description: "Top accent bar in pixels."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.border?.accentBarHeight ?? 10); onMoved: value => Config.setNestedValue("appearance.angel.border.accentBarHeight", value) }
              SettingsSpinBox { label: "Accent bar width"; description: "Left accent bar in pixels."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.border?.accentBarWidth ?? 10); onMoved: value => Config.setNestedValue("appearance.angel.border.accentBarWidth", value) }

              SettingsSpinBox { label: "Inset glow height"; description: "Glow lip thickness in pixels."; from: 0; to: 10; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.border?.insetGlowHeight ?? 1); onMoved: value => Config.setNestedValue("appearance.angel.border.insetGlowHeight", value) }
              SettingsValueSlider { label: "Inset glow opacity"; description: "Brightness of the inset glow."; value: Config.options?.appearance?.angel?.border?.insetGlowOpacity ?? 0.20; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.border.insetGlowOpacity", Math.round(value * 100) / 100) }

              SettingsSpinBox { label: "Panel border width"; description: "Pixel width for panel surfaces."; from: 0; to: 5; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.surface?.panelBorderWidth ?? 1); onMoved: value => Config.setNestedValue("appearance.angel.surface.panelBorderWidth", value) }
              SettingsValueSlider { label: "Panel border opacity"; description: "Panel border strength."; value: Config.options?.appearance?.angel?.surface?.panelBorderOpacity ?? 0.90; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.surface.panelBorderOpacity", Math.round(value * 100) / 100) }
              SettingsSpinBox { label: "Card border width"; description: "Pixel width for card surfaces."; from: 0; to: 5; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.surface?.cardBorderWidth ?? 1); onMoved: value => Config.setNestedValue("appearance.angel.surface.cardBorderWidth", value) }
              SettingsValueSlider { label: "Card border opacity"; description: "Card border strength."; value: Config.options?.appearance?.angel?.surface?.cardBorderOpacity ?? 0.0; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.surface.cardBorderOpacity", Math.round(value * 100) / 100) }
            }

            SettingsSettingCard {
              iconName: "auto_fix_high"
              title: "Angel glow and rounding"
              description: "Outer glow strength and corner radii."
              visible: Appearance.angelEverywhere

              SettingsValueSlider { label: "Glow opacity"; description: "Soft outer glow."; value: Config.options?.appearance?.angel?.glow?.opacity ?? 0.0; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.glow.opacity", Math.round(value * 100) / 100) }
              SettingsValueSlider { label: "Strong glow opacity"; description: "Glow on the active card."; value: Config.options?.appearance?.angel?.glow?.strongOpacity ?? 0.0; from: 0; to: 1; stepSize: 0.01; displayScale: 100; displayDecimals: 0; suffix: "%"; onMoved: value => Config.setNestedValue("appearance.angel.glow.strongOpacity", Math.round(value * 100) / 100) }

              SettingsSpinBox { label: "Rounding small"; description: "Corner radius for small surfaces."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.rounding?.small ?? 0); onMoved: value => Config.setNestedValue("appearance.angel.rounding.small", value) }
              SettingsSpinBox { label: "Rounding normal"; description: "Corner radius for cards."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.rounding?.normal ?? 0); onMoved: value => Config.setNestedValue("appearance.angel.rounding.normal", value) }
              SettingsSpinBox { label: "Rounding large"; description: "Corner radius for panels."; from: 0; to: 30; stepSize: 1; value: Math.round(Config.options?.appearance?.angel?.rounding?.large ?? 0); onMoved: value => Config.setNestedValue("appearance.angel.rounding.large", value) }
            }

            SettingsSettingCard {
              iconName: "edit"
              title: "Custom theme"
              description: "Hand-tuned color palette. Active when the Wallpaper colors source is set to Custom."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsModeSegment {
                options: [
                  { label: "Light", value: "light", icon: "light_mode" },
                  { label: "Dark", value: "dark", icon: "dark_mode" }
                ]
                selectedValue: (Config.options?.appearance?.customTheme?.darkmode ?? true) ? "dark" : "light"
                onSelected: value => app.setCustomThemeDarkMode(value === "dark")
              }

              SettingsCombo {
                label: "Preset"
                description: "Apply a curated palette as the starting point. You can fine-tune the individual colors below."
                options: [
                  { label: "Angel (Dark)", value: "angel-dark" },
                  { label: "Angel (Light)", value: "angel-light" },
                  { label: "Gruvbox Material", value: "gruvbox-material" },
                  { label: "Catppuccin Mocha", value: "catppuccin-mocha" },
                  { label: "Catppuccin Latte", value: "catppuccin-latte" },
                  { label: "Nord", value: "nord" },
                  { label: "Material Black", value: "material-black" },
                  { label: "Kanagawa", value: "kanagawa" },
                  { label: "Kanagawa Dragon", value: "kanagawa-dragon" },
                  { label: "Samurai", value: "samurai" },
                  { label: "Tokyo Night", value: "tokyo-night" },
                  { label: "Sakura", value: "sakura" },
                  { label: "Zen Garden", value: "zen-garden" }
                ]
                selectedValue: ""
                onSelected: value => app.applyCustomThemePreset(value)
              }
            }

            SettingsSettingCard {
              iconName: "palette"
              title: "Accent"
              description: "Primary brand color and matching text + container colors."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsColorField { label: "Primary"; description: "Main accent color."; value: Config.options?.appearance?.customTheme?.m3primary ?? ""; placeholder: "#7c4dff"; onEdited: v => app.setCustomThemeColor("m3primary", v) }
              SettingsColorField { label: "On primary"; description: "Text rendered on top of primary."; value: Config.options?.appearance?.customTheme?.m3onPrimary ?? ""; placeholder: "#ffffff"; onEdited: v => app.setCustomThemeColor("m3onPrimary", v) }
              SettingsColorField { label: "Primary container"; description: "Subtle accent surface."; value: Config.options?.appearance?.customTheme?.m3primaryContainer ?? ""; placeholder: "#5e35b1"; onEdited: v => app.setCustomThemeColor("m3primaryContainer", v) }
              SettingsColorField { label: "On primary container"; description: "Text on subtle accent surface."; value: Config.options?.appearance?.customTheme?.m3onPrimaryContainer ?? ""; placeholder: "#eadeff"; onEdited: v => app.setCustomThemeColor("m3onPrimaryContainer", v) }
            }

            SettingsSettingCard {
              iconName: "filter_2"
              title: "Secondary"
              description: "Supporting color pair for secondary actions."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsColorField { label: "Secondary"; value: Config.options?.appearance?.customTheme?.m3secondary ?? ""; placeholder: "#5b6b8c"; onEdited: v => app.setCustomThemeColor("m3secondary", v) }
              SettingsColorField { label: "On secondary"; value: Config.options?.appearance?.customTheme?.m3onSecondary ?? ""; placeholder: "#ffffff"; onEdited: v => app.setCustomThemeColor("m3onSecondary", v) }
              SettingsColorField { label: "Secondary container"; value: Config.options?.appearance?.customTheme?.m3secondaryContainer ?? ""; placeholder: "#3f4d6e"; onEdited: v => app.setCustomThemeColor("m3secondaryContainer", v) }
              SettingsColorField { label: "On secondary container"; value: Config.options?.appearance?.customTheme?.m3onSecondaryContainer ?? ""; placeholder: "#dee4f0"; onEdited: v => app.setCustomThemeColor("m3onSecondaryContainer", v) }
            }

            SettingsSettingCard {
              iconName: "filter_3"
              title: "Tertiary"
              description: "Third accent for chips, highlights, and special UI."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsColorField { label: "Tertiary"; value: Config.options?.appearance?.customTheme?.m3tertiary ?? ""; placeholder: "#8c5b6b"; onEdited: v => app.setCustomThemeColor("m3tertiary", v) }
              SettingsColorField { label: "On tertiary"; value: Config.options?.appearance?.customTheme?.m3onTertiary ?? ""; placeholder: "#ffffff"; onEdited: v => app.setCustomThemeColor("m3onTertiary", v) }
              SettingsColorField { label: "Tertiary container"; value: Config.options?.appearance?.customTheme?.m3tertiaryContainer ?? ""; placeholder: "#6e3f4d"; onEdited: v => app.setCustomThemeColor("m3tertiaryContainer", v) }
              SettingsColorField { label: "On tertiary container"; value: Config.options?.appearance?.customTheme?.m3onTertiaryContainer ?? ""; placeholder: "#f0dee4"; onEdited: v => app.setCustomThemeColor("m3onTertiaryContainer", v) }
            }

            SettingsSettingCard {
              iconName: "layers"
              title: "Backgrounds"
              description: "Main background and surface colors plus their foregrounds."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsColorField { label: "Background"; value: Config.options?.appearance?.customTheme?.m3background ?? ""; placeholder: "#1a1a1a"; onEdited: v => app.setCustomThemeColor("m3background", v) }
              SettingsColorField { label: "Surface"; value: Config.options?.appearance?.customTheme?.m3surface ?? ""; placeholder: "#1a1a1a"; onEdited: v => app.setCustomThemeColor("m3surface", v) }
              SettingsColorField { label: "On surface"; value: Config.options?.appearance?.customTheme?.m3onSurface ?? ""; placeholder: "#e6e1e5"; onEdited: v => app.setCustomThemeColor("m3onSurface", v) }
              SettingsColorField { label: "On background"; value: Config.options?.appearance?.customTheme?.m3onBackground ?? ""; placeholder: "#e6e1e5"; onEdited: v => app.setCustomThemeColor("m3onBackground", v) }
            }

            SettingsSettingCard {
              iconName: "border_style"
              title: "Borders and shadows"
              description: "Outlines and shadow scrim used by panels and overlays."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsColorField { label: "Outline"; value: Config.options?.appearance?.customTheme?.m3outline ?? ""; placeholder: "#938f99"; onEdited: v => app.setCustomThemeColor("m3outline", v) }
              SettingsColorField { label: "Outline variant"; value: Config.options?.appearance?.customTheme?.m3outlineVariant ?? ""; placeholder: "#49454f"; onEdited: v => app.setCustomThemeColor("m3outlineVariant", v) }
              SettingsColorField { label: "Shadow"; value: Config.options?.appearance?.customTheme?.m3shadow ?? ""; placeholder: "#000000"; onEdited: v => app.setCustomThemeColor("m3shadow", v) }
              SettingsColorField { label: "Scrim"; value: Config.options?.appearance?.customTheme?.m3scrim ?? ""; placeholder: "#000000"; onEdited: v => app.setCustomThemeColor("m3scrim", v) }
            }

            SettingsSettingCard {
              iconName: "info"
              title: "Status"
              description: "Error and success state colors."
              visible: (Config.options?.appearance?.theme ?? "auto") === "custom"

              SettingsColorField { label: "Error"; value: Config.options?.appearance?.customTheme?.m3error ?? ""; placeholder: "#f2b8b5"; onEdited: v => app.setCustomThemeColor("m3error", v) }
              SettingsColorField { label: "On error"; value: Config.options?.appearance?.customTheme?.m3onError ?? ""; placeholder: "#601410"; onEdited: v => app.setCustomThemeColor("m3onError", v) }
              SettingsColorField { label: "Success"; value: Config.options?.appearance?.customTheme?.m3success ?? ""; placeholder: "#7ac582"; onEdited: v => app.setCustomThemeColor("m3success", v) }
              SettingsColorField { label: "On success"; value: Config.options?.appearance?.customTheme?.m3onSuccess ?? ""; placeholder: "#00390a"; onEdited: v => app.setCustomThemeColor("m3onSuccess", v) }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: wallpaperPage
    SettingsPage {
      SettingsSubTabs { pageKey: "wallpaper"; options: ["Wallpaper", "Effects", "Widgets", "Background Controls", "Widget Controls"] }

      StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: app.subTabForPage("wallpaper", 0)

        SettingsPageBody {
          SettingsSection {
            title: "Wallpaper"
            description: "Picker, directory, selection target, and common source controls."

            SettingsSettingCard {
              iconName: "wallpaper"
              title: "Source"
              description: "Common wallpaper controls stay compact; the full background editor is in Background Controls."

              SettingsTextField { label: "Wallpaper directory"; description: "Folder used by the wallpaper selector."; value: Config.options?.wallpapers?.directory ?? ""; placeholder: "~/Pictures/Wallpapers"; onEdited: value => Config.setNestedValue("wallpapers.directory", value) }
              SettingsCombo {
                label: "Selector style"
                description: "Wallpaper picker presentation."
                options: [{ label: "Grid", value: "grid" }, { label: "Coverflow", value: "coverflow" }]
                selectedValue: Config.options?.wallpaperSelector?.style ?? "grid"
                onSelected: value => Config.setNestedValue("wallpaperSelector.style", value)
              }
              SettingsCombo {
                label: "Selection target"
                description: "Wallpaper target for new selections."
                options: [{ label: "Main wallpaper", value: "main" }, { label: "Backdrop", value: "backdrop" }, { label: "Both", value: "both" }]
                selectedValue: Config.options?.wallpaperSelector?.selectionTarget ?? "main"
                onSelected: value => Config.setNestedValue("wallpaperSelector.selectionTarget", value)
              }
            }
          }
        }

        SettingsPageBody {
          SettingsSection {
            title: "Effects"
            description: "Readable visual controls for backdrop, transitions, blur, dim, and parallax."

            SettingsSettingCard {
              iconName: "blur_on"
              title: "Wallpaper treatment"
              description: "These are the effects most people expect to find."

              SettingsSwitch { label: "Animated wallpapers"; description: "Play video or GIF wallpapers when available."; checked: Config.options?.background?.enableAnimation ?? true; onToggled: checked => Config.setNestedValue("background.enableAnimation", checked) }
              SettingsSwitch { label: "Wallpaper blur"; description: "Blur the current wallpaper."; checked: Config.options?.background?.effects?.enableBlur ?? false; onToggled: checked => Config.setNestedValue("background.effects.enableBlur", checked) }
              SettingsSpinBox { label: "Blur radius"; description: "Wallpaper blur radius."; from: 0; to: 120; stepSize: 1; value: Config.options?.background?.effects?.blurRadius ?? 32; onMoved: value => Config.setNestedValue("background.effects.blurRadius", value) }
              SettingsSpinBox { label: "Dim"; description: "Base wallpaper dim percentage."; from: 0; to: 100; stepSize: 1; value: Config.options?.background?.effects?.dim ?? 0; onMoved: value => Config.setNestedValue("background.effects.dim", value) }
            }

            SettingsSettingCard {
              iconName: "motion_photos_on"
              title: "Movement"
              description: "Polish effects that can be disabled for performance."

              SettingsToggleGrid {
                options: [
                  { label: "Backdrop", description: "Secondary backdrop surface.", path: "background.backdrop.enable", fallback: false },
                  { label: "Parallax", description: "Pointer or workspace parallax.", path: "background.parallax.enable", fallback: false },
                  { label: "Ripple", description: "Wallpaper ripple effects.", path: "background.effects.ripple.enable", fallback: false }
                ]
              }
            }
          }
        }

        SettingsPageBody {
          SettingsSection {
            title: "Desktop widgets"
            description: "Enable desktop widgets. Placement, style, presets, and custom widget details are in Widget Controls."

            SettingsSettingCard {
              iconName: "widgets"
              title: "Desktop widget gallery"
              description: "Quick enable switches for the desktop widget family."

              SettingsToggleGrid {
                options: [
                  { label: "Clock", description: "Desktop clock widget.", path: "background.widgets.clock.enable", fallback: false },
                  { label: "Weather", description: "Desktop weather widget.", path: "background.widgets.weather.enable", fallback: false },
                  { label: "Media", description: "Desktop media widget.", path: "background.widgets.mediaControls.enable", fallback: false },
                  { label: "Visualizer", description: "Audio visualizer widget.", path: "background.widgets.visualizer.enable", fallback: false },
                  { label: "System monitor", description: "Desktop system stats.", path: "background.widgets.systemMonitor.enable", fallback: false },
                  { label: "Battery", description: "Desktop battery widget.", path: "background.widgets.battery.enable", fallback: false },
                  { label: "Notes", description: "Desktop notes widget.", path: "background.widgets.notes.enable", fallback: false },
                  { label: "Upcoming Events", description: "Calendar events on the desktop.", path: "background.widgets.calendarUpcoming.enable", fallback: false }
                ]
              }
            }
          }
        }

        SettingsEmbeddedSettingsPage {
          sourcePath: Quickshell.shellPath("modules/settings/BackgroundConfig.qml")
        }

        SettingsEmbeddedSettingsPage {
          sourcePath: Quickshell.shellPath("modules/settings/DesktopWidgetsConfig.qml")
        }
      }
    }
  }

  Component {
    id: barDockPage
    SettingsPage {
      SettingsSubTabs { pageKey: "barDock"; options: ["Bar", "Modules", "Dock"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("barDock", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Bar"
            description: "Placement, frame shape, and workspace behavior."

            SettingsSettingCard {
              iconName: "border_top"
              title: "Presentation"
              description: "The common bar shape decisions."

              SettingsModeSegment {
                options: [
                  { label: "Top", value: "top", icon: "vertical_align_top" },
                  { label: "Bottom", value: "bottom", icon: "vertical_align_bottom" },
                  { label: "Vertical", value: "vertical", icon: "view_sidebar" }
                ]
                selectedValue: Config.options?.bar?.vertical ? "vertical" : Config.options?.bar?.bottom ? "bottom" : "top"
                onSelected: value => {
                  Config.setNestedValue("bar.vertical", value === "vertical");
                  Config.setNestedValue("bar.bottom", value === "bottom");
                }
              }

              SettingsCombo {
                label: "Corner style"
                description: "Controls how bar corners attach to the screen."
                options: [{ label: "Hug", value: "0" }, { label: "Float", value: "1" }, { label: "Rect", value: "2" }, { label: "Card", value: "3" }]
                selectedValue: String(Config.options?.bar?.cornerStyle ?? 1)
                onSelected: value => Config.setNestedValue("bar.cornerStyle", Number(value))
              }

              SettingsToggleGrid {
                options: [
                  { label: "Background", description: "Draw bar surface.", path: "bar.showBackground", fallback: true },
                  { label: "Auto hide", description: "Reveal on edge hover.", path: "bar.autoHide.enable", fallback: false },
                  { label: "Borderless", description: "Flatter grouped items.", path: "bar.borderless", fallback: false },
                  { label: "Numbers", description: "Always show workspace numbers.", path: "bar.workspaces.alwaysShowNumbers", fallback: false }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Modules"
            description: "Use cards for bar modules instead of a long switch wall."

            SettingsSettingCard {
              iconName: "widgets"
              title: "Visible bar modules"
              description: "Each card updates the existing bar module config key."

              SettingsToggleGrid {
                options: [
                  { label: "Left sidebar", description: "Open side panel.", path: "bar.modules.leftSidebarButton", fallback: true },
                  { label: "Right sidebar", description: "Open control panel.", path: "bar.modules.rightSidebarButton", fallback: true },
                  { label: "Active window", description: "Focused app title.", path: "bar.modules.activeWindow", fallback: true },
                  { label: "Resources", description: "CPU and memory.", path: "bar.modules.resources", fallback: true },
                  { label: "Media", description: "Playing media.", path: "bar.modules.media", fallback: true },
                  { label: "Workspaces", description: "Workspace status.", path: "bar.modules.workspaces", fallback: true },
                  { label: "Clock", description: "Date and time.", path: "bar.modules.clock", fallback: true },
                  { label: "Utility buttons", description: "Quick actions.", path: "bar.modules.utilButtons", fallback: true },
                  { label: "Battery", description: "Power status.", path: "bar.modules.battery", fallback: true },
                  { label: "System tray", description: "Tray icons.", path: "bar.modules.sysTray", fallback: true },
                  { label: "Weather", description: "Forecast chip.", path: "bar.modules.weather", fallback: true },
                  { label: "SecPulse", description: "Security status.", path: "bar.modules.secPulse", fallback: true }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Dock"
            description: "Dock visibility, placement, icon sizing, and previews."

            SettingsSettingCard {
              iconName: "space_bar"
              title: "Dock"
              description: "Common dock controls grouped into one readable card."

              SettingsSwitch { label: "Enable dock"; description: "Show the desktop dock."; checked: Config.options?.dock?.enable ?? false; onToggled: checked => Config.setNestedValue("dock.enable", checked) }
              SettingsCombo {
                label: "Position"
                description: "Screen edge used by the dock."
                options: [{ label: "Bottom", value: "bottom" }, { label: "Top", value: "top" }, { label: "Left", value: "left" }, { label: "Right", value: "right" }]
                selectedValue: Config.options?.dock?.position ?? "bottom"
                onSelected: value => Config.setNestedValue("dock.position", value)
              }
              SettingsSpinBox { label: "Dock height"; description: "Main dock height in pixels."; from: 36; to: 120; stepSize: 2; value: Math.round(Config.options?.dock?.height ?? 60); onMoved: value => Config.setNestedValue("dock.height", value) }
              SettingsSpinBox { label: "Icon size"; description: "Dock icon size in pixels."; from: 20; to: 96; stepSize: 1; value: Math.round(Config.options?.dock?.iconSize ?? 35); onMoved: value => Config.setNestedValue("dock.iconSize", value) }
              SettingsToggleGrid {
                options: [
                  { label: "Hover reveal", description: "Reveal on edge hover.", path: "dock.hoverToReveal", fallback: true },
                  { label: "Background", description: "Draw dock surface.", path: "dock.showBackground", fallback: true },
                  { label: "Smart indicator", description: "Focused app owner.", path: "dock.smartIndicator", fallback: true },
                  { label: "Hover previews", description: "Window thumbnails.", path: "dock.hoverPreview", fallback: true }
                ]
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: panelsPage
    SettingsPage {
      SettingsSubTabs { pageKey: "panels"; options: ["Panels", "Compositor"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("panels", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Panel family"
            description: "Choose the shell panel family and loaded surfaces."

            SettingsSettingCard {
              iconName: "dashboard"
              title: "Panel set"
              description: "This replaces the old list of raw panel IDs with friendly surface names."

              SettingsCombo {
                label: "Panel family"
                description: "Switch between ii panels and Waffle panels."
                options: [{ label: "ii", value: "ii" }, { label: "Waffle", value: "waffle" }]
                selectedValue: Config.options?.panelFamily ?? "ii"
                onSelected: value => Config.setNestedValue("panelFamily", value)
              }

              SettingsToggleGrid {
                options: [
                  { label: "Bar", description: "Top or bottom bar.", listPath: "enabledPanels", id: "iiBar" },
                  { label: "Background", description: "Wallpaper layer.", listPath: "enabledPanels", id: "iiBackground" },
                  { label: "Control panel", description: "Quick settings.", listPath: "enabledPanels", id: "iiControlPanel" },
                  { label: "Dock", description: "Desktop dock.", listPath: "enabledPanels", id: "iiDock" },
                  { label: "Notifications", description: "Popup notifications.", listPath: "enabledPanels", id: "iiNotificationPopup" },
                  { label: "Overview", description: "Workspace overview.", listPath: "enabledPanels", id: "iiOverview" },
                  { label: "Screen corners", description: "Corner overlays.", listPath: "enabledPanels", id: "iiScreenCorners" },
                  { label: "Session screen", description: "Power menu.", listPath: "enabledPanels", id: "iiSessionScreen" },
                  { label: "Clipboard", description: "Clipboard UI.", listPath: "enabledPanels", id: "iiClipboard" }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Compositor"
            description: "Shell-side compositor behavior that is stored in Ryoku config."

            SettingsSettingCard {
              iconName: "grid_view"
              title: "Window behavior"
              description: "Niri-adjacent shell settings, not raw compositor syntax."

              SettingsSwitch { label: "Auto-expand single tiling window"; description: "Expand one tiled window when it is the only tiled window."; checked: Config.options?.compositor?.autoExpandSingleTilingWindow ?? true; onToggled: checked => Config.setNestedValue("compositor.autoExpandSingleTilingWindow", checked) }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: controlCenterPage
    SettingsPage {
      SettingsSubTabs { pageKey: "control"; options: ["Control Center", "Sidebar"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("control", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Control Center"
            description: "Sections shown in quick settings."

            SettingsSettingCard {
              iconName: "instant_mix"
              title: "Layout"
              description: "Quick cards users can understand without knowing config names."

              SettingsToggleGrid {
                options: [
                  { label: "Compact mode", description: "Denser layout.", path: "controlPanel.compactMode", fallback: true },
                  { label: "Media", description: "Media controls.", path: "controlPanel.showMediaSection", fallback: true },
                  { label: "Weather", description: "Weather card.", path: "controlPanel.showWeatherSection", fallback: true },
                  { label: "System", description: "System status.", path: "controlPanel.showSystemSection", fallback: true },
                  { label: "Sliders", description: "Audio and brightness.", path: "controlPanel.showSlidersSection", fallback: true },
                  { label: "Quick actions", description: "Screenshot, lock, tools.", path: "controlPanel.showQuickActionsSection", fallback: true }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Sidebar"
            description: "Left and right panel dimensions."

            SettingsSettingCard {
              iconName: "view_sidebar"
              title: "Panel sizing"
              description: "Readable controls for common sidebar dimensions."

              SettingsSpinBox { label: "Left width"; description: "Left sidebar width in pixels."; from: 260; to: 720; stepSize: 10; value: Config.options?.sidebar?.leftWidth ?? 360; onMoved: value => Config.setNestedValue("sidebar.leftWidth", value) }
              SettingsToggleGrid {
                options: [
                  { label: "Card style", description: "Use card surfaces.", path: "sidebar.cardStyle", fallback: false },
                  { label: "Keep loaded", description: "Keep sidebar warm.", path: "sidebar.keepLoaded", fallback: false }
                ]
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: launcherPage
    SettingsPage {
      SettingsSubTabs { pageKey: "launcher"; options: ["Search", "Actions", "Shortcuts"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("launcher", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Search"
            description: "Launcher scoring, global actions, and web search."

            SettingsSettingCard {
              iconName: "search"
              title: "Launcher search"
              description: "Common behavior without exposing prefixes and internal API fields."

              SettingsSwitch { label: "Sloppy matching"; description: "Use relaxed matching instead of strict fuzzy search."; checked: Config.options?.search?.sloppy ?? false; onToggled: checked => Config.setNestedValue("search.sloppy", checked) }
              SettingsSpinBox { label: "Non-app delay"; description: "Delay before non-app results render, in milliseconds."; from: 0; to: 300; stepSize: 5; value: Config.options?.search?.nonAppResultDelay ?? 30; onMoved: value => Config.setNestedValue("search.nonAppResultDelay", value) }
              SettingsTextField { label: "Search engine"; description: "Base URL used for web searches."; value: Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q="; placeholder: "https://www.google.com/search?q="; onEdited: value => Config.setNestedValue("search.engineBaseUrl", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Global actions"
            description: "Launcher categories shown as cards."

            SettingsSettingCard {
              iconName: "bolt"
              title: "Categories"
              description: "Turn whole categories on or off."

              SettingsToggleGrid {
                options: [
                  { label: "System", description: "Power and system actions.", path: "search.globalActions.enableSystem", fallback: true },
                  { label: "Appearance", description: "Theme and wallpaper actions.", path: "search.globalActions.enableAppearance", fallback: true },
                  { label: "Tools", description: "Screenshot and utilities.", path: "search.globalActions.enableTools", fallback: true },
                  { label: "Media", description: "Music and media actions.", path: "search.globalActions.enableMedia", fallback: true },
                  { label: "Settings", description: "Settings shortcuts.", path: "search.globalActions.enableSettings", fallback: true }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Shortcuts"
            description: "Useful keybind actions."

            SettingsSettingCard {
              iconName: "keyboard"
              title: "Keyboard shortcuts"
              description: "Niri owns keybind syntax; Settings provides safe entry points."

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsButton { text: "Open overlay"; iconName: "keyboard"; onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "cheatsheet", "open"]) }
                SettingsButton { text: "Edit Niri keybinds"; iconName: "edit"; onClicked: app.openFileInTerminal(Quickshell.env("HOME") + "/.config/niri/config.d/70-binds.kdl") }
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: notificationsPage
    SettingsPage {
      SettingsSubTabs { pageKey: "notifications"; options: ["Notifications", "OSD", "Sounds"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("notifications", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Notifications"
            description: "Popup placement, timeout, and interaction behavior."

            SettingsSettingCard {
              iconName: "notifications"
              title: "Popup behavior"
              description: "Common notification choices."

              SettingsSwitch { label: "Do Not Disturb"; description: "Suppress notification popups."; checked: Config.options?.notifications?.silent ?? false; onToggled: checked => Config.setNestedValue("notifications.silent", checked) }
              SettingsCombo {
                label: "Popup position"
                description: "Screen corner used for notification popups."
                options: [{ label: "Top right", value: "topRight" }, { label: "Bottom right", value: "bottomRight" }, { label: "Top left", value: "topLeft" }, { label: "Bottom left", value: "bottomLeft" }]
                selectedValue: Config.options?.notifications?.position ?? "topRight"
                onSelected: value => Config.setNestedValue("notifications.position", value)
              }
              SettingsSpinBox { label: "Normal timeout"; description: "Normal notification lifetime in milliseconds."; from: 1000; to: 30000; stepSize: 500; value: Config.options?.notifications?.timeoutNormal ?? 7000; onMoved: value => Config.setNestedValue("notifications.timeoutNormal", value) }
              SettingsSpinBox { label: "Critical timeout"; description: "Critical notification lifetime in milliseconds."; from: 1000; to: 60000; stepSize: 500; value: Config.options?.notifications?.timeoutCritical ?? 0; onMoved: value => Config.setNestedValue("notifications.timeoutCritical", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "On-Screen Display"
            description: "Volume, brightness, and media status overlays."

            SettingsSettingCard {
              iconName: "vertical_align_center"
              title: "OSD"
              description: "Small overlays that appear after hardware actions."

              SettingsSwitch { label: "Media OSD"; description: "Show media info in the OSD."; checked: Config.options?.osd?.mediaEnabled ?? true; onToggled: checked => Config.setNestedValue("osd.mediaEnabled", checked) }
              SettingsSpinBox { label: "Timeout"; description: "OSD visible time in milliseconds."; from: 250; to: 5000; stepSize: 50; value: Config.options?.osd?.timeout ?? 1000; onMoved: value => Config.setNestedValue("osd.timeout", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Sounds"
            description: "Notification and shell sound preferences."

            SettingsSettingCard {
              iconName: "notifications_active"
              title: "Sound"
              description: "Keep the simple controls here; exact sound files stay in Advanced."

              SettingsToggleGrid {
                options: [
                  { label: "Notification sound", description: "Play notification sounds.", path: "sounds.notifications.enable", fallback: true },
                  { label: "Critical sound", description: "Play critical alert sounds.", path: "sounds.critical.enable", fallback: true }
                ]
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: audioDisplayPage
    SettingsPage {
      SettingsSubTabs { pageKey: "audioDisplay"; options: ["Audio", "Display", "Input", "Monitor"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("audioDisplay", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Volume protection"
            description: "Prevent sudden volume spikes and cap maximum volume."

            SettingsSettingCard {
              iconName: "volume_up"
              title: "Ear protection"
              description: "Common-sense volume safety controls."

              SettingsSwitch { label: "Earbang protection"; description: "Prevents abrupt increments and restricts the volume limit."; checked: Config.options?.audio?.protection?.enable ?? false; onToggled: checked => Config.setNestedValue("audio.protection.enable", checked) }
              SettingsSpinBox { label: "Max allowed increase"; description: "Maximum volume increase per key press."; from: 0; to: 100; stepSize: 2; value: Config.options?.audio?.protection?.maxAllowedIncrease ?? 10; onMoved: value => Config.setNestedValue("audio.protection.maxAllowedIncrease", value) }
              SettingsSpinBox { label: "Volume limit"; description: "Maximum volume percentage."; from: 0; to: 154; stepSize: 2; value: Config.options?.audio?.protection?.maxAllowed ?? 100; onMoved: value => Config.setNestedValue("audio.protection.maxAllowed", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Display"
            description: "Monitor defaults and overlay targeting."

            SettingsSettingCard {
              iconName: "monitor"
              title: "Screens"
              description: "Shell targeting and overview behavior."

              SettingsCombo {
                label: "Primary monitor"
                description: "Default monitor for popups when focus cannot be detected."
                options: (function() {
                  const opts = [{ label: "Auto", value: "" }];
                  for (let i = 0; i < Quickshell.screens.length; i++) {
                    const name = Quickshell.screens[i].name ?? "";
                    if (name.length > 0)
                      opts.push({ label: name, value: name });
                  }
                  return opts;
                })()
                selectedValue: Config.options?.display?.primaryMonitor ?? ""
                onSelected: value => Config.setNestedValue("display.primaryMonitor", value)
              }

              SettingsCombo {
                label: "Monitor"
                description: "Connected Niri output to edit."
                options: app.displayOutputOptions()
                selectedValue: app.currentOutputName
                onSelected: value => app.setSelectedOutput(value)
              }

              SettingsCombo {
                label: "Resolution"
                description: "Apply and save the output resolution."
                options: app.displayResolutionOptions()
                selectedValue: app.currentResolution
                onSelected: value => app.applyAndPersistDisplay("mode", value + "@" + app.bestRateForResolution(value))
              }

              SettingsCombo {
                label: "Refresh rate"
                description: "Apply and save the output refresh rate."
                options: app.displayRefreshOptions()
                selectedValue: app.currentRateString
                onSelected: value => app.applyAndPersistDisplay("mode", app.currentResolution + "@" + value)
              }

              SettingsCombo {
                label: "Scale"
                description: "Apply and save the output scale."
                options: app.displayScaleOptions()
                selectedValue: String(app.currentScale)
                onSelected: value => app.applyAndPersistDisplay("scale", value)
              }

              SettingsCombo {
                label: "Rotation"
                description: "Apply and save the output rotation."
                options: app.displayTransformOptions()
                selectedValue: app.normalizeTransform(app.currentTransform)
                onSelected: value => app.applyAndPersistDisplay("transform", value)
              }

              SettingsSwitch {
                visible: app.vrrSupported
                label: "Variable refresh rate"
                description: "Enable VRR for this output when supported."
                checked: app.vrrEnabled
                onToggled: checked => app.applyAndPersistDisplay("vrr", checked ? "on" : "off")
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsButton {
                  text: "Refresh displays"
                  iconName: "refresh"
                  onClicked: app.loadOutputs()
                }

                SettingsLabel {
                  label: app.displayStatus.length > 0 ? app.displayStatus : "Display helper ready"
                  description: app.scriptPath
                  iconName: app.outputReady ? "check_circle" : "sync"
                }
              }

              SettingsToggleGrid {
                options: [
                  { label: "Screen corners", description: "Rounded screen corners.", listPath: "enabledPanels", id: "iiScreenCorners" },
                  { label: "Overview", description: "Workspace overview.", path: "overview.enable", fallback: true },
                  { label: "Overview icons", description: "Center app icons.", path: "overview.centerIcons", fallback: true },
                  { label: "Window previews", description: "Overview thumbnails.", path: "overview.showPreviews", fallback: false }
                ]
              }
            }

            SettingsSettingCard {
              iconName: "center_focus_strong"
              title: "Focus ring"
              description: "Niri focus-ring.enabled, width, active color or gradient, and inactive color."

              SettingsSwitch {
                label: "Enable focus ring"
                description: "Draw a ring around the focused window."
                checked: app.layoutData?.focus_ring?.enabled ?? false
                onToggled: checked => app.niriSetBooleanConfig("layout", "focus-ring.enabled", checked)
              }

              SettingsSpinBox {
                visible: app.layoutData?.focus_ring?.enabled ?? false
                label: "Focus ring width"
                description: "Border width in pixels."
                from: 1
                to: 16
                stepSize: 1
                value: app.layoutData?.focus_ring?.width ?? 1
                onMoved: value => app.niriSetConfig("layout", "focus-ring.width", value)
              }

              SettingsSwitch {
                visible: app.layoutData?.focus_ring?.enabled ?? false
                label: "Follow Ryoku theme colors"
                description: "Use the active color preset for the focused ring and update it when presets change."
                checked: Config.options?.settingsUi?.focusRing?.followTheme ?? false
                onToggled: checked => {
                  Config.setNestedValue("settingsUi.focusRing.followTheme", checked);
                  if (checked)
                    app.syncThemeFocusRing();
                }
              }

              SettingsSwitch {
                visible: (app.layoutData?.focus_ring?.enabled ?? false) && !(Config.options?.settingsUi?.focusRing?.followTheme ?? false)
                label: "Use active gradient"
                description: "Use a two-color gradient instead of one active color."
                checked: !!app.layoutData?.focus_ring?.active_gradient
                onToggled: checked => {
                  if (checked)
                    app.writeFocusRingGradient(null, null, null);
                  else
                    app.niriSetConfig("layout", "focus-ring.active-color", app.layoutData?.focus_ring?.active_gradient?.from_color ?? app.layoutData?.focus_ring?.active_color ?? "#808080");
                }
              }

              SettingsColorField {
                visible: (app.layoutData?.focus_ring?.enabled ?? false) && !(Config.options?.settingsUi?.focusRing?.followTheme ?? false) && !app.layoutData?.focus_ring?.active_gradient
                label: "Focus ring active color"
                description: "Hex color, color picker, or theme swatch for the focused window ring."
                value: app.layoutData?.focus_ring?.active_color ?? "#808080"
                placeholder: "#808080"
                swatches: app.themeSwatches()
                onEdited: value => app.niriSetConfig("layout", "focus-ring.active-color", value.trim())
              }

              SettingsColorField {
                visible: (app.layoutData?.focus_ring?.enabled ?? false) && !(Config.options?.settingsUi?.focusRing?.followTheme ?? false) && !!app.layoutData?.focus_ring?.active_gradient
                label: "Gradient from"
                description: "First active gradient color."
                value: app.layoutData?.focus_ring?.active_gradient?.from_color ?? "#F25623"
                placeholder: "#F25623"
                swatches: app.themeSwatches()
                onEdited: value => app.writeFocusRingGradient(value.trim(), null, null)
              }

              SettingsColorField {
                visible: (app.layoutData?.focus_ring?.enabled ?? false) && !(Config.options?.settingsUi?.focusRing?.followTheme ?? false) && !!app.layoutData?.focus_ring?.active_gradient
                label: "Gradient to"
                description: "Second active gradient color."
                value: app.layoutData?.focus_ring?.active_gradient?.to_color ?? "#F56E0F"
                placeholder: "#F56E0F"
                swatches: app.themeSwatches()
                onEdited: value => app.writeFocusRingGradient(null, value.trim(), null)
              }

              SettingsSpinBox {
                visible: (app.layoutData?.focus_ring?.enabled ?? false) && !(Config.options?.settingsUi?.focusRing?.followTheme ?? false) && !!app.layoutData?.focus_ring?.active_gradient
                label: "Gradient angle"
                description: "Active gradient angle in degrees."
                from: 0
                to: 360
                stepSize: 5
                value: Math.round(app.layoutData?.focus_ring?.active_gradient?.angle ?? 45)
                onMoved: value => app.writeFocusRingGradient(null, null, value)
              }

              SettingsColorField {
                visible: app.layoutData?.focus_ring?.enabled ?? false
                label: "Focus ring inactive color"
                description: (Config.options?.settingsUi?.focusRing?.followTheme ?? false) ? "Using the current theme outline color." : "Hex color, color picker, or theme swatch for inactive focus rings."
                value: (Config.options?.settingsUi?.focusRing?.followTheme ?? false) ? app.focusRingThemeInactiveColor() : (app.layoutData?.focus_ring?.inactive_color ?? "#505050")
                placeholder: app.focusRingThemeInactiveColor()
                swatches: app.themeSwatches()
                onEdited: value => app.niriSetConfig("layout", "focus-ring.inactive-color", value.trim())
              }

              SettingsLabel {
                label: app.niriStatus.length > 0 ? app.niriStatus : "Niri layout helper ready"
                description: app.scriptPath
                iconName: "data_object"
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Input and cursor"
            description: "Cursor theme, pointer behavior, touchpad, and keyboard defaults from Niri."

            SettingsSettingCard {
              iconName: "mouse"
              title: "Cursor"
              description: "Legacy cursor theme, size, and hide-while-typing controls."

              SettingsCombo {
                label: "Cursor theme"
                description: "Installed XCursor theme used by Niri and new applications."
                options: app.cursorThemeOptions()
                selectedValue: app.currentCursorTheme()
                onSelected: value => app.niriSetConfig("input", "cursor.xcursor-theme", value)
              }

              SettingsSpinBox {
                label: "Cursor size"
                description: "Cursor size in pixels."
                from: 16
                to: 64
                stepSize: 2
                value: app.cursorData?.size ?? 24
                onMoved: value => app.niriSetConfig("input", "cursor.xcursor-size", value)
              }

              SettingsSwitch {
                label: "Hide cursor while typing"
                description: "Hide the pointer while keyboard input is active."
                checked: app.cursorData?.hide_when_typing ?? true
                onToggled: checked => app.niriSetBooleanConfig("input", "cursor.hide-when-typing", checked)
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsButton {
                  text: "Refresh input"
                  iconName: "refresh"
                  onClicked: {
                    app.loadInput();
                    app.loadCursorThemes();
                  }
                }

                SettingsLabel {
                  label: app.inputStatus.length > 0 ? app.inputStatus : "Niri input helper ready"
                  description: app.scriptPath
                  iconName: "data_object"
                }
              }
            }

            SettingsSettingCard {
              iconName: "ads_click"
              title: "Pointer"
              description: "Mouse acceleration and common pointer behavior."

              SettingsCombo {
                label: "Mouse acceleration"
                description: "Niri mouse acceleration profile."
                options: app.accelerationProfileOptions()
                selectedValue: app.mouseData?.accel_profile ?? "flat"
                onSelected: value => app.niriSetConfig("input", "mouse.accel-profile", value)
              }

              SettingsValueSlider {
                label: "Pointer speed"
                description: "Mouse acceleration speed from -1.00 to 1.00."
                from: -1
                to: 1
                stepSize: 0.05
                displayScale: 1
                displayDecimals: 2
                value: app.mouseData?.accel_speed ?? 0
                suffix: ""
                onMoved: value => app.niriSetConfig("input", "mouse.accel-speed", app.formatReal(value, 0))
              }

              SettingsSwitch { label: "Natural mouse scroll"; description: "Invert wheel direction for mouse scrolling."; checked: app.mouseData?.natural_scroll ?? false; onToggled: checked => app.niriSetBooleanConfig("input", "mouse.natural-scroll", checked) }
              SettingsSwitch { label: "Left-handed mouse"; description: "Swap primary and secondary mouse buttons."; checked: app.mouseData?.left_handed ?? false; onToggled: checked => app.niriSetBooleanConfig("input", "mouse.left-handed", checked) }
              SettingsSwitch { label: "Middle emulation"; description: "Allow middle-click emulation when supported."; checked: app.mouseData?.middle_emulation ?? false; onToggled: checked => app.niriSetBooleanConfig("input", "mouse.middle-emulation", checked) }
            }

            SettingsSettingCard {
              iconName: "touch_app"
              title: "Touchpad"
              description: "Tap, scroll, and accidental input behavior."

              SettingsCombo {
                label: "Touchpad acceleration"
                description: "Niri touchpad acceleration profile."
                options: app.accelerationProfileOptions()
                selectedValue: app.touchpadData?.accel_profile ?? "adaptive"
                onSelected: value => app.niriSetConfig("input", "touchpad.accel-profile", value)
              }

              SettingsSwitch { label: "Tap to click"; description: "Use taps as clicks."; checked: app.touchpadData?.tap ?? true; onToggled: checked => app.niriSetBooleanConfig("input", "touchpad.tap", checked) }
              SettingsSwitch { label: "Natural touchpad scroll"; description: "Invert touchpad scroll direction."; checked: app.touchpadData?.natural_scroll ?? true; onToggled: checked => app.niriSetBooleanConfig("input", "touchpad.natural-scroll", checked) }
              SettingsSwitch { label: "Disable while typing"; description: "Ignore touchpad movement while typing."; checked: app.touchpadData?.dwt ?? true; onToggled: checked => app.niriSetBooleanConfig("input", "touchpad.dwt", checked) }
              SettingsSwitch { label: "Disable with external mouse"; description: "Turn off touchpad while a mouse is connected."; checked: app.touchpadData?.disabled_on_external_mouse ?? false; onToggled: checked => app.niriSetBooleanConfig("input", "touchpad.disabled-on-external-mouse", checked) }
            }

            SettingsSettingCard {
              iconName: "keyboard"
              title: "Keyboard"
              description: "Layout, repeat, numlock, and compositor key behavior."

              SettingsTextField {
                label: "Keyboard layout"
                description: "XKB layout code, for example us."
                value: app.keyboardData?.layout ?? "us"
                placeholder: "us"
                onEdited: value => app.niriSetConfig("input", "keyboard.layout", value.trim())
              }

              SettingsTextField {
                label: "Keyboard options"
                description: "XKB options string."
                value: app.keyboardData?.options ?? ""
                placeholder: "caps:escape"
                onEdited: value => app.niriSetConfig("input", "keyboard.options", value.trim())
              }

              SettingsSpinBox { label: "Repeat delay"; description: "Milliseconds before key repeat starts."; from: 150; to: 1200; stepSize: 25; value: app.keyboardData?.repeat_delay ?? 600; onMoved: value => app.niriSetConfig("input", "keyboard.repeat-delay", value) }
              SettingsSpinBox { label: "Repeat rate"; description: "Key repeat rate per second."; from: 10; to: 80; stepSize: 1; value: app.keyboardData?.repeat_rate ?? 25; onMoved: value => app.niriSetConfig("input", "keyboard.repeat-rate", value) }
              SettingsSwitch { label: "Numlock on startup"; description: "Enable numlock when the compositor starts."; checked: app.keyboardData?.numlock ?? true; onToggled: checked => app.niriSetBooleanConfig("input", "keyboard.numlock", checked) }
            }

            SettingsSettingCard {
              iconName: "settings_input_composite"
              title: "Focus behavior"
              description: "Pointer warp, focus follows mouse, workspace history, and power key handling."

              SettingsSwitch {
                label: "Warp pointer to focus"
                description: "Move the pointer when focus changes."
                checked: app.generalInputData?.warp_mouse_to_focus ?? false
                onToggled: checked => app.setWarpMouseMode(checked ? (app.generalInputData?.warp_mouse_to_focus_mode ?? "center-xy") : "off")
              }

              SettingsCombo {
                visible: app.generalInputData?.warp_mouse_to_focus ?? false
                label: "Warp mode"
                description: "How Niri places the pointer on the focused window."
                options: app.warpPointerOptions().slice(1)
                selectedValue: app.generalInputData?.warp_mouse_to_focus_mode ?? "center-xy"
                onSelected: value => app.setWarpMouseMode(value)
              }

              SettingsSwitch {
                label: "Focus follows mouse"
                description: "Focus windows when the pointer hovers over them."
                checked: app.generalInputData?.focus_follows_mouse ?? false
                onToggled: checked => app.setFocusFollowsMouse(checked)
              }

              SettingsSpinBox {
                visible: app.generalInputData?.focus_follows_mouse ?? false
                label: "Hover focus scroll limit"
                description: "Maximum visible scroll amount allowed for hover focus."
                from: 0
                to: 100
                stepSize: 5
                value: app.generalInputData?.focus_follows_mouse_max_scroll ?? 0
                onMoved: value => app.setFocusFollowsMouse(true, value)
              }

              SettingsSwitch { label: "Workspace back-and-forth"; description: "Jump back to the previous workspace when switching to the current one."; checked: app.generalInputData?.workspace_auto_back_and_forth ?? false; onToggled: checked => app.niriSetBooleanConfig("input", "workspace-auto-back-and-forth", checked) }
              SettingsSwitch { label: "Disable power key handling"; description: "Let the system handle power key behavior instead of Niri."; checked: app.generalInputData?.disable_power_key_handling ?? false; onToggled: checked => app.niriSetBooleanConfig("input", "disable-power-key-handling", checked) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "System Monitor"
            description: "Resource polling and bar indicators."

            SettingsSettingCard {
              iconName: "monitoring"
              title: "Resources"
              description: "Stats and thresholds."

              SettingsSpinBox { label: "Update interval"; description: "Resource polling interval in milliseconds."; from: 500; to: 15000; stepSize: 250; value: Config.options?.resources?.updateInterval ?? 3000; onMoved: value => Config.setNestedValue("resources.updateInterval", value) }
              SettingsSpinBox { label: "CPU warning"; description: "CPU warning threshold percentage."; from: 1; to: 100; stepSize: 1; value: Config.options?.bar?.resources?.cpuWarningThreshold ?? 80; onMoved: value => Config.setNestedValue("bar.resources.cpuWarningThreshold", value) }
              SettingsToggleGrid {
                options: [
                  { label: "GPU monitor", description: "Collect GPU stats.", path: "resources.monitorGpu", fallback: true },
                  { label: "CPU indicator", description: "Show CPU in bar.", path: "bar.resources.showCpuIndicator", fallback: true },
                  { label: "Memory indicator", description: "Show memory in bar.", path: "bar.resources.showMemoryIndicator", fallback: true },
                  { label: "Temperature", description: "Show temperature.", path: "bar.resources.showTempIndicator", fallback: true }
                ]
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: lockPowerPage
    SettingsPage {
      SettingsSubTabs { pageKey: "lockPower"; options: ["Lock", "Session", "Power"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("lockPower", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Lock screen"
            description: "Qylock behavior, security, and lock-screen widgets."

            SettingsSettingCard {
              iconName: "lock"
              title: "Lock behavior"
              description: "Security choices with plain labels."

              SettingsToggleGrid {
                options: [
                  { label: "Use Hyprlock", description: "Use Hyprlock instead.", path: "lock.useHyprlock", fallback: false },
                  { label: "Start helper", description: "Launch lock helper at startup.", path: "lock.launchOnStartup", fallback: false },
                  { label: "Secure power", description: "Require password for power actions.", path: "lock.security.requirePasswordToPower", fallback: false },
                  { label: "Unlock keyring", description: "Unlock user keyring after login.", path: "lock.security.unlockKeyring", fallback: true },
                  { label: "Dim background", description: "Darken lock wallpaper.", path: "lock.dim.enable", fallback: false },
                  { label: "Blur background", description: "Blur lock wallpaper.", path: "lock.blur.enable", fallback: true }
                ]
              }

              SettingsCombo {
                label: "Clock style"
                description: "Visual style for the lock clock."
                options: [{ label: "Default", value: "default" }, { label: "Minimal", value: "minimal" }, { label: "Analog", value: "analog" }]
                selectedValue: Config.options?.lock?.clock?.style ?? "default"
                onSelected: value => Config.setNestedValue("lock.clock.style", value)
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Session Menu"
            description: "Power menu and close confirmation behavior."

            SettingsSettingCard {
              iconName: "power_settings_new"
              title: "Session actions"
              description: "Keep shutdown and close-confirm behavior easy to find."

              SettingsToggleGrid {
                options: [
                  { label: "Session screen", description: "Enable power menu overlay.", listPath: "enabledPanels", id: "iiSessionScreen" },
                  { label: "Confirm closes", description: "Ask before closing windows.", path: "closeConfirm.enabled", fallback: false }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Power"
            description: "Power profiles and brightness-adjacent settings."

            SettingsSettingCard {
              iconName: "battery_charging_full"
              title: "Power state"
              description: "Detailed policy remains in Advanced."

              SettingsCombo {
                label: "Power profile"
                description: "Default performance profile."
                options: [{ label: "Balanced", value: "balanced" }, { label: "Performance", value: "performance" }, { label: "Power saver", value: "power-saver" }]
                selectedValue: Config.options?.powerProfiles?.defaultProfile ?? "balanced"
                onSelected: value => Config.setNestedValue("powerProfiles.defaultProfile", value)
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: servicesPage
    SettingsPage {
      SettingsSubTabs { pageKey: "services"; options: ["Power", "AI", "Network", "Updates", "Weather", "Calendar"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("services", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Idle and sleep"
            description: "Screen idle policy, lock timing, and temporary keep-awake control."

            SettingsSettingCard {
              iconName: "bedtime"
              title: "Power behavior"
              description: "Use 0 to disable a timeout."

              SettingsSpinBox { label: "Screen off"; description: "Seconds before displays turn off."; from: 0; to: 3600; stepSize: 30; value: Config.options?.idle?.screenOffTimeout ?? 300; onMoved: value => Config.setNestedValue("idle.screenOffTimeout", value) }
              SettingsSpinBox { label: "Lock screen"; description: "Seconds before Ryoku locks the session."; from: 0; to: 3600; stepSize: 60; value: Config.options?.idle?.lockTimeout ?? 600; onMoved: value => Config.setNestedValue("idle.lockTimeout", value) }
              SettingsSpinBox { label: "Suspend"; description: "Seconds before suspend. 0 keeps suspend manual."; from: 0; to: 7200; stepSize: 60; value: Config.options?.idle?.suspendTimeout ?? 0; onMoved: value => Config.setNestedValue("idle.suspendTimeout", value) }
              SettingsSwitch { label: "Lock before sleep"; description: "Lock the screen before the system goes to sleep."; checked: Config.options?.idle?.lockBeforeSleep ?? true; onToggled: checked => Config.setNestedValue("idle.lockBeforeSleep", checked) }
              SettingsSwitch {
                label: "Keep awake"
                description: "Temporarily prevents display sleep and suspend."
                checked: Idle.inhibit
                onToggled: checked => {
                  if (checked !== Idle.inhibit)
                    Idle.toggleInhibit();
                }
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "AI providers"
            description: "Assistant policy, prompt, model endpoints, and key storage."

            SettingsSettingCard {
              iconName: "neurology"
              title: "Assistant policy"
              description: "Choose whether AI features are available and how much network access they can use."

              SettingsModeSegment {
                options: [
                  { label: "Off", value: "0", icon: "block" },
                  { label: "Enabled", value: "1", icon: "bolt" },
                  { label: "Local only", value: "2", icon: "home" }
                ]
                selectedValue: String(Config.options?.policies?.ai ?? 1)
                onSelected: value => Config.setNestedValue("policies.ai", Number(value))
              }

              SettingsCombo {
                label: "Tool access"
                description: "Search and function-call mode for assistant responses."
                options: [
                  { label: "Functions", value: "functions" },
                  { label: "Search", value: "search" },
                  { label: "None", value: "none" }
                ]
                selectedValue: Config.options?.ai?.tool ?? "functions"
                onSelected: value => Config.setNestedValue("ai.tool", value)
              }

              SettingsTextArea {
                label: "System prompt"
                description: "Base instructions injected into sidebar assistant sessions."
                value: Config.options?.ai?.systemPrompt ?? ""
                preferredHeight: 150
                onEdited: value => Config.setNestedValue("ai.systemPrompt", value)
              }
            }

            SettingsSettingCard {
              iconName: "hub"
              title: "Model providers"
              description: "Add compatible endpoints without editing JSON. API keys are stored through the keyring service."

              Repeater {
                model: Config.options?.ai?.extraModels ?? []

                delegate: Rectangle {
                  required property var modelData
                  required property int index

                  width: parent ? parent.width : implicitWidth
                  implicitHeight: providerRow.implicitHeight + 18
                  radius: 11
                  color: providerMouse.containsMouse ? app.hoverColor : app.windowColor
                  border.width: 1
                  border.color: app.borderColor

                  RowLayout {
                    id: providerRow
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

                    Rectangle {
                      Layout.preferredWidth: 34
                      Layout.preferredHeight: 34
                      radius: 10
                      color: app.activeColor

                      MaterialSymbol {
                        anchors.centerIn: parent
                        text: "smart_toy"
                        iconSize: 18
                        color: app.primaryColor
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 1

                      Text {
                        Layout.fillWidth: true
                        text: modelData?.name ?? modelData?.model ?? "Unnamed provider"
                        color: app.textColor
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                      }

                      Text {
                        Layout.fillWidth: true
                        text: (modelData?.model ?? "") + " - " + app.aiProviderFormatLabel(modelData?.api_format ?? "openai")
                        color: app.subtextColor
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideMiddle
                      }
                    }

                    SettingsIconButton {
                      iconName: "edit"
                      tooltipText: "Edit provider"
                      onClicked: {
                        providerForm.editingIndex = index;
                        providerForm.providerName = modelData?.name ?? "";
                        providerForm.endpoint = modelData?.endpoint ?? "";
                        providerForm.modelCode = modelData?.model ?? "";
                        providerForm.selectedFormat = modelData?.api_format ?? "openai";
                        providerForm.apiKey = "";
                        providerForm.expanded = true;
                      }
                    }

                    SettingsIconButton {
                      iconName: "close"
                      tooltipText: "Remove provider"
                      onClicked: {
                        const models = [...(Config.options?.ai?.extraModels ?? [])];
                        models.splice(index, 1);
                        Config.setNestedValue("ai.extraModels", models);
                      }
                    }
                  }

                  MouseArea {
                    id: providerMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                  }
                }
              }

              SettingsLabel {
                visible: (Config.options?.ai?.extraModels ?? []).length === 0
                label: "No extra providers"
                description: "Ryoku can still use built-in local and discovered providers. Add an endpoint here for custom hosted models."
                iconName: "info"
              }

              SettingsButton {
                text: providerForm.expanded ? "Close provider form" : "Add provider"
                iconName: providerForm.expanded ? "close" : "add"
                onClicked: {
                  if (providerForm.expanded) {
                    providerForm.expanded = false;
                    providerForm.editingIndex = -1;
                    return;
                  }
                  providerForm.editingIndex = -1;
                  providerForm.providerName = "";
                  providerForm.endpoint = "";
                  providerForm.modelCode = "";
                  providerForm.selectedFormat = "openai";
                  providerForm.apiKey = "";
                  providerForm.expanded = true;
                }
              }

              Rectangle {
                id: providerForm
                property bool expanded: false
                property int editingIndex: -1
                property string providerName: ""
                property string endpoint: ""
                property string modelCode: ""
                property string selectedFormat: "openai"
                property string apiKey: ""

                width: parent ? parent.width : implicitWidth
                visible: expanded
                implicitHeight: expanded ? providerFormColumn.implicitHeight + 24 : 0
                radius: 12
                color: app.windowColor
                border.width: 1
                border.color: app.borderColor
                clip: true

                ColumnLayout {
                  id: providerFormColumn
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 10

                  SettingsTextField { label: "Provider name"; description: "Friendly name shown in the assistant."; value: providerForm.providerName; placeholder: "My model"; onEdited: value => providerForm.providerName = value }
                  SettingsTextField { label: "Endpoint URL"; description: "Chat, responses, Gemini, or compatible API endpoint."; value: providerForm.endpoint; placeholder: "https://api.openai.com/v1/chat/completions"; onEdited: value => providerForm.endpoint = value }
                  SettingsCombo { label: "API format"; description: "Protocol used by this endpoint."; options: app.aiProviderFormatOptions; selectedValue: providerForm.selectedFormat; onSelected: value => providerForm.selectedFormat = value }
                  SettingsTextField { label: "Model code"; description: "Exact model id sent to the endpoint."; value: providerForm.modelCode; placeholder: "gpt-4.1"; onEdited: value => providerForm.modelCode = value }
                  SettingsTextField { label: "API key"; description: "Optional. Saved under this model id in the keyring."; value: providerForm.apiKey; placeholder: "sk-..."; onEdited: value => providerForm.apiKey = value }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    SettingsButton {
                      text: providerForm.editingIndex >= 0 ? "Save provider" : "Create provider"
                      iconName: "check"
                      onClicked: {
                        const endpoint = providerForm.endpoint.trim();
                        const modelCode = providerForm.modelCode.trim();
                        if (endpoint.length === 0 || modelCode.length === 0)
                          return;
                        const models = [...(Config.options?.ai?.extraModels ?? [])];
                        const original = providerForm.editingIndex >= 0 ? models[providerForm.editingIndex] : null;
                        const keyId = modelCode.toLowerCase().replace(/[:\/ ]/g, "-");
                        const entry = {
                          name: providerForm.providerName.trim() || modelCode,
                          endpoint: endpoint,
                          model: modelCode,
                          api_format: providerForm.selectedFormat,
                          requires_key: providerForm.apiKey.trim().length > 0 ? true : (original?.requires_key ?? false),
                          key_id: providerForm.apiKey.trim().length > 0 ? keyId : (original?.key_id ?? keyId)
                        };
                        if (providerForm.editingIndex >= 0)
                          models[providerForm.editingIndex] = entry;
                        else
                          models.push(entry);
                        Config.setNestedValue("ai.extraModels", models);
                        if (providerForm.apiKey.trim().length > 0)
                          KeyringStorage.setNestedField(["apiKeys", entry.key_id], providerForm.apiKey.trim());
                        providerForm.expanded = false;
                        providerForm.editingIndex = -1;
                      }
                    }
                  }
                }
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Music recognition"
            description: "Recognition timing plus user-agent, hotspot, and search service defaults."

            SettingsSettingCard {
              iconName: "music_note"
              title: "Recognition timing"
              description: "How long Ryoku waits for audio recognition results."

              SettingsSpinBox { label: "Timeout"; description: "Maximum recognition time in seconds."; from: 10; to: 100; stepSize: 2; value: Config.options?.musicRecognition?.timeout ?? 16; onMoved: value => Config.setNestedValue("musicRecognition.timeout", value) }
              SettingsSpinBox { label: "Polling interval"; description: "Seconds between recognition result checks."; from: 2; to: 10; stepSize: 1; value: Config.options?.musicRecognition?.interval ?? 4; onMoved: value => Config.setNestedValue("musicRecognition.interval", value) }
            }

            SettingsSettingCard {
              iconName: "wifi_tethering"
              title: "Hotspot"
              description: "Simple hotspot defaults used by networking helpers."

              SettingsTextField { label: "Network name"; description: "SSID broadcast by the hotspot."; value: Config.options?.hotspot?.ssid ?? "Ryoku Hotspot"; placeholder: "Ryoku Hotspot"; onEdited: value => Config.setNestedValue("hotspot.ssid", value) }
              SettingsTextField { label: "Password"; description: "WPA2 passphrase for the hotspot."; value: Config.options?.hotspot?.password ?? "ryoku-shell-hotspot"; placeholder: "ryoku-shell-hotspot"; onEdited: value => Config.setNestedValue("hotspot.password", value) }
              SettingsSwitch { label: "Use 5 GHz band"; description: "Use 5 GHz instead of 2.4 GHz when the adapter supports it."; checked: (Config.options?.hotspot?.band ?? "bg") === "a"; onToggled: checked => Config.setNestedValue("hotspot.band", checked ? "a" : "bg") }
            }

            SettingsSettingCard {
              iconName: "travel_explore"
              title: "Search and networking"
              description: "Service request identity and launcher search behavior."

              SettingsSwitch { label: "Typo-tolerant search"; description: "Use Levenshtein scoring instead of fuzzy sorting."; checked: Config.options?.search?.sloppy ?? false; onToggled: checked => Config.setNestedValue("search.sloppy", checked) }
              SettingsTextField { label: "Search engine"; description: "Base URL for web searches."; value: Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q="; placeholder: "https://www.google.com/search?q="; onEdited: value => Config.setNestedValue("search.engineBaseUrl", value) }
              SettingsTextArea { label: "User agent"; description: "Browser user-agent string for services that require one."; value: Config.options?.networking?.userAgent ?? ""; preferredHeight: 78; onEdited: value => Config.setNestedValue("networking.userAgent", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Updates"
            description: "Resource polling, system update hints, and Ryoku shell update checks."

            SettingsSettingCard {
              iconName: "memory"
              title: "Resources"
              description: "Polling cadence for CPU, memory, disk, and GPU stats."

              SettingsSpinBox { label: "Polling interval"; description: "Milliseconds between resource updates."; from: 100; to: 10000; stepSize: 100; value: Config.options?.resources?.updateInterval ?? 3000; onMoved: value => Config.setNestedValue("resources.updateInterval", value) }
              SettingsSwitch { label: "Monitor GPU"; description: "Include GPU usage when supported."; checked: Config.options?.resources?.monitorGpu ?? true; onToggled: checked => Config.setNestedValue("resources.monitorGpu", checked) }
            }

            SettingsSettingCard {
              iconName: "system_update"
              title: "System updates"
              description: "How often the update indicator checks and when it becomes urgent."

              SettingsSpinBox { label: "Check interval"; description: "Minutes between system package checks."; from: 15; to: 1440; stepSize: 15; value: Config.options?.updates?.checkInterval ?? 120; onMoved: value => Config.setNestedValue("updates.checkInterval", value) }
              SettingsSpinBox { label: "Show icon threshold"; description: "Show update icon after this many available updates."; from: 1; to: 200; stepSize: 5; value: Config.options?.updates?.adviseUpdateThreshold ?? 75; onMoved: value => Config.setNestedValue("updates.adviseUpdateThreshold", value) }
              SettingsSpinBox { label: "Warning threshold"; description: "Use warning color after this many updates."; from: 10; to: 500; stepSize: 10; value: Config.options?.updates?.stronglyAdviseUpdateThreshold ?? 200; onMoved: value => Config.setNestedValue("updates.stronglyAdviseUpdateThreshold", value) }
              SettingsTextField { label: "Update command"; description: "Command used when launching system updates."; value: Config.options?.apps?.update ?? ""; placeholder: "kitty -e sudo pacman -Syu"; onEdited: value => Config.setNestedValue("apps.update", value) }
            }

            SettingsSettingCard {
              iconName: "deployed_code_update"
              title: "Ryoku shell updates"
              description: "Shell git update checks and detail overlay controls."

              SettingsSwitch { label: "Enable shell update checker"; description: "Show shell update notifications in the bar."; checked: Config.options?.shellUpdates?.enabled ?? true; onToggled: checked => Config.setNestedValue("shellUpdates.enabled", checked) }
              SettingsCombo {
                label: "Update channel"
                description: !ShellUpdates.channelKnown ? "Detecting channel" : ShellUpdates.requiresChannelSwitch ? "Next update switches to " + ShellUpdates.configuredChannel : "Receive Ryoku shell updates from " + ShellUpdates.configuredChannel
                selectedValue: ShellUpdates.channelKnown ? ShellUpdates.configuredChannel : ""
                placeholderText: "Detecting channel"
                options: [
                  { label: "Stable (main)", value: "main" },
                  { label: "Unstable dev", value: "unstable-dev" }
                ]
                onSelected: value => {
                  app.setShellUpdateChannel(value);
                }
              }
              SettingsSpinBox { label: "Check interval"; description: "Minutes between Ryoku shell update checks."; from: 30; to: 1440; stepSize: 30; value: Config.options?.shellUpdates?.checkIntervalMinutes ?? 360; onMoved: value => Config.setNestedValue("shellUpdates.checkIntervalMinutes", value) }
              SettingsSwitch { label: "Open terminal during update"; description: "Show full setup output when applying shell updates."; checked: Config.options?.shellUpdates?.openTerminalOnUpdate ?? true; onToggled: checked => Config.setNestedValue("shellUpdates.openTerminalOnUpdate", checked) }
              SettingsLabel {
                label: ShellUpdates.requiresChannelSwitch ? "Channel switch ready" : ShellUpdates.hasUpdate ? "Update available" : ShellUpdates.lastError.length > 0 ? "Update check error" : ShellUpdates.available ? "Up to date" : "Shell updater unavailable"
                description: ShellUpdates.requiresChannelSwitch ? "Current branch " + ShellUpdates.currentBranch + ", update channel " + ShellUpdates.configuredChannel : ShellUpdates.hasUpdate ? ShellUpdates.commitsBehind + " commit(s) behind on " + (ShellUpdates.configuredChannel || "main") : (ShellUpdates.lastError || ShellUpdates.unavailableHint || "Branch: " + (ShellUpdates.currentBranch || "unknown"))
                iconName: ShellUpdates.canApplyUpdate ? "upgrade" : ShellUpdates.lastError.length > 0 ? "error" : "check_circle"
              }
              RowLayout {
                width: parent ? parent.width : implicitWidth
                spacing: 8
                SettingsButton { text: ShellUpdates.isChecking ? "Checking" : "Check now"; iconName: "refresh"; onClicked: app.checkShellUpdates() }
                SettingsButton { text: "Open details"; iconName: "open_in_new"; onClicked: app.openShellUpdateDetails() }
                SettingsButton { visible: ShellUpdates.canApplyUpdate && ShellUpdates.selfUpdateSupported; text: ShellUpdates.isUpdating ? "Updating" : ShellUpdates.requiresChannelSwitch ? "Switch channel" : "Update now"; iconName: "upgrade"; onClicked: ShellUpdates.requiresChannelSwitch ? app.openShellUpdateDetails() : ShellUpdates.performUpdate(false) }
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Weather service"
            description: "Bar weather, desktop widgets, privacy, location, and units."

            SettingsSettingCard {
              iconName: "cloud"
              title: "Weather"
              description: "Configure weather data used by the bar and desktop widgets."

              SettingsSwitch { label: "Enable weather service"; description: "Fetch weather data for bar and widget surfaces."; checked: Config.options?.bar?.weather?.enable ?? false; onToggled: checked => Config.setNestedValue("bar.weather.enable", checked) }
              SettingsSwitch { label: "Show in top bar"; description: "Enable the weather bar module."; checked: Config.options?.bar?.modules?.weather ?? false; onToggled: checked => Config.setNestedValue("bar.modules.weather", checked) }
              SettingsSwitch { label: "Hide location name"; description: "Hide the city name in weather widgets."; checked: Config.options?.waffles?.widgetsPanel?.weatherHideLocation ?? false; onToggled: checked => Config.setNestedValue("waffles.widgetsPanel.weatherHideLocation", checked) }
              SettingsTextField { label: "City"; description: "Leave blank to auto-detect from IP."; value: Config.options?.bar?.weather?.city ?? ""; placeholder: "Buenos Aires, London, Tokyo"; onEdited: value => Config.setNestedValue("bar.weather.city", value) }
              SettingsTextField { label: "Latitude"; description: "Optional manual coordinate override."; value: String(Config.options?.bar?.weather?.manualLat ?? 0); placeholder: "-34.6037"; onEdited: value => Config.setNestedValue("bar.weather.manualLat", Number(value) || 0) }
              SettingsTextField { label: "Longitude"; description: "Optional manual coordinate override."; value: String(Config.options?.bar?.weather?.manualLon ?? 0); placeholder: "-58.3816"; onEdited: value => Config.setNestedValue("bar.weather.manualLon", Number(value) || 0) }
              SettingsSwitch { label: "Use GPS location"; description: "Use Geoclue GPS when no manual location is set."; checked: Config.options?.bar?.weather?.enableGPS ?? false; onToggled: checked => Config.setNestedValue("bar.weather.enableGPS", checked) }
              SettingsSwitch { label: "Use Fahrenheit"; description: "Use US customary units instead of metric."; checked: Config.options?.bar?.weather?.useUSCS ?? false; onToggled: checked => Config.setNestedValue("bar.weather.useUSCS", checked) }
              SettingsSpinBox { label: "Update interval"; description: "Minutes between weather fetches."; from: 5; to: 60; stepSize: 5; value: Config.options?.bar?.weather?.fetchInterval ?? 10; onMoved: value => Config.setNestedValue("bar.weather.fetchInterval", value) }
              SettingsLabel {
                visible: Weather.location.valid
                label: "Current location"
                description: Weather.location.name || (Weather.location.lat + ", " + Weather.location.lon)
                iconName: "my_location"
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Calendar sync"
            description: "ICS/iCal sources for the desktop calendar and upcoming events."

            SettingsSettingCard {
              iconName: "calendar_month"
              title: "External calendars"
              description: "Paste public or private ICS URLs from calendar providers."

              SettingsSwitch { label: "Enable external calendar sync"; description: "Fetch events from configured ICS sources."; checked: Config.options?.calendar?.externalSync?.enable ?? false; onToggled: checked => Config.setNestedValue("calendar.externalSync.enable", checked) }
              SettingsSpinBox { label: "Refresh interval"; description: "Minutes between calendar refreshes."; from: 5; to: 120; stepSize: 5; value: Config.options?.calendar?.externalSync?.refreshMinutes ?? 15; onMoved: value => Config.setNestedValue("calendar.externalSync.refreshMinutes", value) }
              SettingsSwitch { label: "Show upcoming events"; description: "Show upcoming events below the calendar."; checked: Config.options?.calendar?.showUpcoming ?? true; onToggled: checked => Config.setNestedValue("calendar.showUpcoming", checked) }
              SettingsSpinBox { label: "Upcoming days"; description: "Number of days shown in the upcoming view."; from: 1; to: 14; stepSize: 1; value: Config.options?.calendar?.upcomingDays ?? 3; onMoved: value => Config.setNestedValue("calendar.upcomingDays", value) }

              Repeater {
                model: Config.options?.calendar?.externalSync?.sources ?? []

                delegate: Rectangle {
                  required property var modelData
                  width: parent ? parent.width : implicitWidth
                  implicitHeight: sourceRow.implicitHeight + 18
                  radius: 11
                  color: app.windowColor
                  border.width: 1
                  border.color: app.borderColor

                  RowLayout {
                    id: sourceRow
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 10

                    Rectangle { Layout.preferredWidth: 14; Layout.preferredHeight: 14; radius: 7; color: modelData?.color ?? app.primaryColor }
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 1
                      Text { Layout.fillWidth: true; text: modelData?.name ?? "Calendar"; color: app.textColor; font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold; elide: Text.ElideRight }
                      Text { Layout.fillWidth: true; text: modelData?.url ?? ""; color: app.subtextColor; font.family: Appearance.font.family.monospace; font.pixelSize: Appearance.font.pixelSize.smaller; elide: Text.ElideMiddle }
                    }
                    SettingsIconButton { iconName: modelData?.enabled ?? true ? "toggle_on" : "toggle_off"; tooltipText: "Toggle source"; onClicked: CalendarSync.toggleSource(modelData.id, !(modelData?.enabled ?? true)) }
                    SettingsIconButton { iconName: "close"; tooltipText: "Remove source"; onClicked: CalendarSync.removeSource(modelData.id) }
                  }
                }
              }

              SettingsLabel { visible: (Config.options?.calendar?.externalSync?.sources ?? []).length === 0; label: "No calendar sources"; description: "Add an ICS URL to show external events in Ryoku."; iconName: "info" }

              Rectangle {
                id: calendarForm
                property string sourceName: ""
                property string sourceUrl: ""
                property string sourceColor: CalendarSync.presetColors[0] ?? app.primaryColor

                width: parent ? parent.width : implicitWidth
                implicitHeight: calendarFormColumn.implicitHeight + 24
                radius: 12
                color: app.windowColor
                border.width: 1
                border.color: app.borderColor

                ColumnLayout {
                  id: calendarFormColumn
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 10

                  SettingsTextField { label: "Calendar name"; description: "Friendly label for this source."; value: calendarForm.sourceName; placeholder: "Work"; onEdited: value => calendarForm.sourceName = value }
                  SettingsTextField { label: "ICS URL"; description: "Calendar feed URL."; value: calendarForm.sourceUrl; placeholder: "https://calendar.google.com/calendar/ical/..."; onEdited: value => calendarForm.sourceUrl = value }

                  Flow {
                    width: parent ? parent.width : implicitWidth
                    spacing: 7
                    Repeater {
                      model: CalendarSync.presetColors
                      delegate: Rectangle {
                        required property string modelData
                        width: 24
                        height: 24
                        radius: 12
                        color: modelData
                        border.width: calendarForm.sourceColor === modelData ? 2 : 1
                        border.color: calendarForm.sourceColor === modelData ? app.primaryColor : app.borderColor
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarForm.sourceColor = modelData }
                      }
                    }
                  }

                  RowLayout {
                    width: parent ? parent.width : implicitWidth
                    Item { Layout.fillWidth: true }
                    SettingsButton {
                      text: "Add calendar"
                      iconName: "add"
                      onClicked: {
                        if (calendarForm.sourceName.trim().length === 0 || calendarForm.sourceUrl.trim().length === 0)
                          return;
                        CalendarSync.addSource(calendarForm.sourceName.trim(), calendarForm.sourceUrl.trim(), calendarForm.sourceColor);
                        calendarForm.sourceName = "";
                        calendarForm.sourceUrl = "";
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: toolsPage
    SettingsPage {
      SettingsSubTabs { pageKey: "tools"; options: ["Recorder", "Capture", "Apps"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("tools", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Screen recorder"
            description: "Recording quality, OSD, and compression defaults."

            SettingsSettingCard {
              iconName: "videocam"
              title: "Recording"
              description: "Simple controls first, codec details in Advanced."

              SettingsCombo {
                label: "Quality preset"
                description: "Default recording quality profile."
                options: [{ label: "Compact", value: "compact" }, { label: "Balanced", value: "balanced" }, { label: "Quality", value: "quality" }, { label: "Master", value: "master" }, { label: "Custom", value: "custom" }]
                selectedValue: Config.options?.screenRecord?.qualityPreset ?? "balanced"
                onSelected: value => Config.setNestedValue("screenRecord.qualityPreset", value)
              }
              SettingsSpinBox { label: "FPS"; description: "Frames per second."; from: 24; to: 144; stepSize: 1; value: Config.options?.screenRecord?.fps ?? 60; onMoved: value => Config.setNestedValue("screenRecord.fps", value) }
              SettingsCombo {
                label: "Video codec"
                description: "Recording video codec."
                options: [{ label: "Auto", value: "auto" }, { label: "H.264", value: "h264" }, { label: "HEVC", value: "hevc" }, { label: "VP9", value: "vp9" }]
                selectedValue: Config.options?.screenRecord?.videoCodec ?? "auto"
                onSelected: value => Config.setNestedValue("screenRecord.videoCodec", value)
              }
              SettingsSpinBox { label: "Discord target"; description: "Target size for Discord compression in MB."; from: 1; to: 100; stepSize: 1; value: Math.round(Config.options?.screenRecord?.discordCompress?.targetSizeMb ?? 10); onMoved: value => Config.setNestedValue("screenRecord.discordCompress.targetSizeMb", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Capture"
            description: "Region selector, screenshot naming, and overlay behavior."

            SettingsSettingCard {
              iconName: "screenshot_region"
              title: "Capture tools"
              description: "User-friendly capture options."

              SettingsTextField { label: "Screenshot name"; description: "Filename format for region captures."; value: Config.options?.regionSelector?.screenshotNameFormat ?? ""; placeholder: "Screenshot_%Y-%m-%d_%H-%M-%S"; onEdited: value => Config.setNestedValue("regionSelector.screenshotNameFormat", value) }
              SettingsSwitch { label: "Darken screen for tools"; description: "Dim the screen behind modal tool overlays."; checked: Config.options?.overlay?.darkenScreen ?? true; onToggled: checked => Config.setNestedValue("overlay.darkenScreen", checked) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Applications"
            description: "External commands and connectivity launchers."

            SettingsSettingCard {
              iconName: "apps"
              title: "Preferred apps"
              description: "All launch slots from the old settings, with presets and custom commands."

              Repeater {
                model: AppLauncher.slotDefinitions()

                delegate: SettingsAppSlotRow {
                  required property var modelData
                  slotId: modelData.id
                }
              }

              SettingsTextField { label: "Discord"; description: "Discord or Vesktop launch command."; value: Config.options?.apps?.discord ?? "discord"; placeholder: "discord"; onEdited: value => Config.setNestedValue("apps.discord", value) }
              SettingsTextField { label: "Update command"; description: "System update command used by update actions."; value: Config.options?.apps?.update ?? "kitty -e sudo pacman -Syu"; placeholder: "kitty -e sudo pacman -Syu"; onEdited: value => Config.setNestedValue("apps.update", value) }
              SettingsTextField { label: "Music directory"; description: "Music library folder for MPD/rmpc profiles."; value: Config.options?.apps?.musicDir ?? ""; placeholder: "~/Music"; onEdited: value => Config.setNestedValue("apps.musicDir", value) }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: advancedPage
    SettingsPage {
      SettingsSubTabs { pageKey: "advanced"; options: ["Inspector", "Theme Targets", "Automation", "Login"] }

      SettingsPageBody {
        SettingsStackLayout {
        Layout.fillWidth: true
        currentIndex: app.subTabForPage("advanced", 0)

        SettingsSubPage {
          SettingsSection {
            title: "Advanced Inspector"
            description: "Raw keys, compatibility coverage, and settings that should not clutter normal pages."

            SettingsSettingCard {
              id: advancedInspector
              iconName: "manufacturing"
              title: "Featured migrated settings"
              description: "These are existing settings kept reachable while the friendly pages evolve."

              Repeater {
                model: app.coverageRows(Config.revision)

                delegate: SettingsConfigRow {
                  required property var modelData
                  rowData: modelData
                }
              }
            }

            SettingsSettingCard {
              iconName: "data_object"
              title: "Category inspector"
              description: "Search one config category at a time so Advanced opens instantly. Paths are intentionally visible here only."

              SettingsCombo {
                label: "Category"
                description: "Choose which part of the Ryoku config tree to inspect."
                options: app.advancedPrefixOptions
                selectedValue: app.advancedPrefix
                onSelected: value => app.advancedPrefix = value
              }

              SettingsConfigBrowser {
                prefixes: [app.advancedPrefix]
                maxRows: 100
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Application color templates"
            description: "Exact generated theme output for desktop, terminal, editor, browser, and media applications."

            SettingsSettingCard {
              iconName: "brush"
              title: "Theme targets"
              description: "This is the proper place for the large target matrix."

              SettingsToggleGrid {
                options: [
                  { label: "Apps and shell", description: "Shell and desktop apps.", path: "appearance.wallpaperTheming.enableAppsAndShell", fallback: true },
                  { label: "Qt apps", description: "Qt application colors.", path: "appearance.wallpaperTheming.enableQtApps", fallback: true },
                  { label: "Kitty", description: "Kitty terminal.", path: "appearance.wallpaperTheming.terminals.kitty", fallback: true },
                  { label: "Alacritty", description: "Alacritty terminal.", path: "appearance.wallpaperTheming.terminals.alacritty", fallback: true },
                  { label: "Foot", description: "Foot terminal.", path: "appearance.wallpaperTheming.terminals.foot", fallback: true },
                  { label: "WezTerm", description: "WezTerm terminal.", path: "appearance.wallpaperTheming.terminals.wezterm", fallback: true },
                  { label: "Ghostty", description: "Ghostty terminal.", path: "appearance.wallpaperTheming.terminals.ghostty", fallback: true },
                  { label: "VS Code", description: "VS Code family.", path: "appearance.wallpaperTheming.enableVSCode", fallback: true },
                  { label: "Chrome", description: "Chrome browser.", path: "appearance.wallpaperTheming.enableChrome", fallback: true },
                  { label: "Neovim", description: "Neovim colors.", path: "appearance.wallpaperTheming.enableNeovim", fallback: true },
                  { label: "Cava", description: "Cava visualizer.", path: "appearance.wallpaperTheming.enableCava", fallback: false },
                  { label: "Steam", description: "Steam colors.", path: "appearance.wallpaperTheming.enableSteam", fallback: false }
                ]
              }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Automation"
            description: "Game Mode, reload toasts, update checks, work safety, and helper services."

            SettingsSettingCard {
              iconName: "sports_esports"
              title: "Game Mode"
              description: "Grouped because the old layout made this a wall of toggles."

              SettingsToggleGrid {
                options: [
                  { label: "Auto detect", description: "Detect games.", path: "gameMode.autoDetect", fallback: true },
                  { label: "Disable animations", description: "Reduce shell motion.", path: "gameMode.disableAnimations", fallback: true },
                  { label: "Disable effects", description: "Turn off expensive effects.", path: "gameMode.disableEffects", fallback: true },
                  { label: "Suppress notifications", description: "Hide popups while gaming.", path: "gameMode.suppressNotifications", fallback: true },
                  { label: "Minimal mode", description: "Use minimal panels.", path: "gameMode.minimalMode", fallback: true },
                  { label: "Reload toasts", description: "Show shell reload notices.", path: "reloadToasts.enable", fallback: true }
                ]
              }
            }

            SettingsSettingCard {
              iconName: "system_update_alt"
              title: "Updates"
              description: "Update checks and setup state."

              SettingsSpinBox { label: "Check interval"; description: "Update check interval in minutes."; from: 1; to: 1440; stepSize: 1; value: Config.options?.updates?.checkInterval ?? 60; onMoved: value => Config.setNestedValue("updates.checkInterval", value) }
            }
          }
        }

        SettingsSubPage {
          SettingsSection {
            title: "Login screen"
            description: "SDDM greeter and qylock theme workflows."

            SettingsSettingCard {
              iconName: "login"
              title: "Login provider actions"
              description: "Actions use the same Ryoku helpers as the legacy page."

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsButton { text: "Apply ii-pixel"; iconName: "verified"; onClicked: Quickshell.execDetached(["pkexec", app.ryokuHelperPath("ryoku-set-sddm-theme"), "ii-pixel"]) }
                SettingsButton { text: "Open qylock folder"; iconName: "folder_open"; onClicked: Qt.openUrlExternally("file://" + Quickshell.env("HOME") + "/.local/share/qylock") }
              }

              SettingsLabel { label: "Built-in provider"; description: Quickshell.shellPath("assets/sddm-providers/ii-pixel"); iconName: "folder" }
              SettingsLabel { label: "qylock provider"; description: Quickshell.env("HOME") + "/.local/share/qylock"; iconName: "folder" }
            }
          }
        }
      }
      }
    }
  }

  Component {
    id: extrasPage
    SettingsPage {
      SettingsEmbeddedSettingsPage {
        sourcePath: Quickshell.shellPath("modules/settings/ExtrasConfig.qml")
      }
    }
  }

  Component {
    id: aboutPage
    SettingsPage {
      Component.onCompleted: ShellUpdates.refresh()

      SettingsPageBody {
        SettingsSection {
        title: "About Ryoku"
        description: "Version, system details, update actions, and project credits."

        SettingsSettingCard {
          iconName: "psychiatry"
          title: "Ryoku"
          description: "An opinionated Arch Linux environment for security work, built around Niri and a cohesive visual system."

          SettingsLabel {
            label: ShellUpdates.localVersion.length > 0 ? "Version v" + ShellUpdates.localVersion : "Version unknown"
            description: ShellUpdates.currentBranch.length > 0 ? "Branch: " + ShellUpdates.currentBranch : "Branch information unavailable"
            iconName: ShellUpdates.isNonMainBranch ? "warning" : "verified"
          }

          SettingsLabel {
            label: "Current branch"
            description: ShellUpdates.currentBranch.length > 0 ? ShellUpdates.currentBranch : "Checking branch information"
            iconName: ShellUpdates.isNonMainBranch ? "warning" : "account_tree"
          }

          SettingsLabel {
            label: "Repository"
            description: "github.com/neur0map/ryoku-arch"
            iconName: "code"
          }

          SettingsCombo {
            label: "Selected channel"
            description: !ShellUpdates.channelKnown ? "Detecting channel" : ShellUpdates.requiresChannelSwitch ? "Selected channel " + ShellUpdates.configuredChannel + " differs from current branch " + ShellUpdates.currentBranch : "Receive Ryoku updates from " + ShellUpdates.configuredChannel
            selectedValue: ShellUpdates.channelKnown ? ShellUpdates.configuredChannel : ""
            placeholderText: "Detecting channel"
            options: [
              { label: "Stable (main)", value: "main" },
              { label: "Unstable dev", value: "unstable-dev" }
            ]
            onSelected: value => {
              app.setShellUpdateChannel(value);
            }
          }

          SettingsLabel {
            label: "Selected channel"
            description: !ShellUpdates.channelKnown ? "Detecting channel" : ShellUpdates.requiresChannelSwitch ? "Switch confirmation is required before moving from " + ShellUpdates.currentBranch + " to " + ShellUpdates.configuredChannel : "Already following " + ShellUpdates.configuredChannel
            iconName: ShellUpdates.requiresChannelSwitch ? "account_tree" : "verified"
          }

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 3 : 2
            rowSpacing: 8
            columnSpacing: 8

            SettingsButton {
              text: "Documentation"
              iconName: "auto_stories"
              onClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch")
            }

            SettingsButton {
              text: "Issues"
              iconName: "bug_report"
              onClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch/issues")
            }

            SettingsButton {
              text: ShellUpdates.isChecking ? "Checking" : "Check updates"
              iconName: ShellUpdates.isChecking ? "sync" : "refresh"
              onClicked: app.checkShellUpdates()
            }

            SettingsButton {
              visible: ShellUpdates.requiresChannelSwitch && ShellUpdates.selfUpdateSupported
              text: "Switch channel"
              iconName: "account_tree"
              onClicked: app.openShellUpdateDetails()
            }

            SettingsButton {
              visible: ShellUpdates.hasUpdate && !ShellUpdates.requiresChannelSwitch
              text: "Update details"
              iconName: "upgrade"
              onClicked: app.openShellUpdateDetails()
            }
          }
        }

        SettingsSettingCard {
          iconName: "computer"
          title: "System"
          description: "Detected system information from the shell service."

          SettingsLabel { label: SystemInfo.distroName || "Linux"; description: SystemInfo.homeUrl || "Distribution home URL unavailable"; iconName: "terminal" }
          SettingsLabel { label: "Migrated legacy groups"; description: app.legacyMigrationLabels.join(", "); iconName: "checklist" }
          SettingsCopyPathRow { label: "Runtime config"; path: Quickshell.env("HOME") + "/.config/ryoku-shell/config.json"; iconName: "data_object" }
          SettingsCopyPathRow { label: "Shell runtime"; path: Quickshell.env("HOME") + "/.config/quickshell/ryoku-shell"; iconName: "folder" }
          SettingsCopyPathRow { label: "Niri config"; path: Quickshell.env("HOME") + "/.config/niri/config.kdl"; iconName: "view_quilt" }
          SettingsCopyPathRow { label: "Ryoku dotfiles"; path: Quickshell.env("HOME") + "/.local/share/ryoku"; iconName: "settings_applications" }
        }

        SettingsSettingCard {
          iconName: "handshake"
          title: "Credits"
          description: "Project and integration credits kept from the previous settings About page."

          GridLayout {
            Layout.fillWidth: true
            columns: width > 560 ? 2 : 1
            rowSpacing: 8
            columnSpacing: 8

            SettingsCreditCard {
              title: "iNiR"
              description: "Upstream Quickshell desktop shell"
              url: "https://github.com/snowarch/inir"
            }

            SettingsCreditCard {
              title: "illogical-impulse"
              description: "Original Hyprland configuration"
              url: "https://github.com/end-4/dots-hyprland"
            }

            SettingsCreditCard {
              title: "Omarchy"
              description: "Opinionated Arch baseline"
              url: "https://github.com/basecamp/omarchy"
            }

            SettingsCreditCard {
              title: "qylock"
              description: "Optional SDDM greeter themes by Darkkal44"
              url: "https://github.com/Darkkal44/qylock"
            }
          }
        }
        }
      }
    }
  }
}
