pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
  id: root

  required property ShellScreen screen
  required property DrawerVisibilities visibilities

  readonly property bool needsKeyboard: root.shouldBeActive || root.offsetScale < 1
  readonly property bool shouldBeActive: root.visibilities.settings
  readonly property int barPadding: Math.max(Tokens.padding.smaller, Config.border.thickness)
  readonly property int frameLeft: Config.bar.persistent ? Tokens.sizes.bar.innerWidth + root.barPadding * 2 : Config.border.thickness
  readonly property int frameRight: Config.border.thickness
  readonly property int frameTop: Config.border.thickness
  readonly property int frameBottom: Config.border.thickness
  readonly property real availableWidth: Math.max(root.screen.width - root.frameLeft - root.frameRight, 0)
  readonly property real availableHeight: Math.max(root.screen.height - root.frameTop - root.frameBottom, 0)
  readonly property real radiusScale: Math.max(0, Math.min(1, Tokens.rounding.scale))
  readonly property real windowRadius: Math.max(10, Math.min(14, 16 * root.radiusScale))
  readonly property real groupRadius: Math.max(8, Math.min(12, 12 * root.radiusScale))
  readonly property real rowRadius: Math.max(6, Math.min(10, 10 * root.radiusScale))
  readonly property int sidebarWidth: 268
  readonly property int headerHeight: 48
  readonly property int contentMaxWidth: 800
  readonly property int hyprmodDefaultWidth: 900
  readonly property int hyprmodDefaultHeight: 650
  readonly property int hyprmodPageVerticalMargin: 24
  readonly property int hyprmodPageHorizontalMargin: 12
  readonly property int hyprmodPageSpacing: 24
  readonly property string ryokuBridge: Paths.ryokuBridge
  readonly property color brandAccent: "#ff4d1f"
  readonly property color accent: "#3584e4"
  readonly property color accentOn: "#ffffff"
  readonly property color warning: "#f7c566"
  readonly property var pages: [
    {
      pageIndex: 0,
      id: "about",
      icon: "info",
      title: "About",
      subtitle: "Built for the sake of power and beauty."
    },
    {
      pageIndex: 1,
      id: "appearance",
      icon: "palette",
      title: "Appearance",
      subtitle: "Theme, spacing, motion, and background."
    },
    {
      pageIndex: 2,
      id: "bar",
      icon: "dock_to_left",
      title: "Taskbar",
      subtitle: "Frame, workspaces, tray, clock, and status icons."
    },
    {
      pageIndex: 3,
      id: "launcher",
      icon: "search",
      title: "Launcher",
      subtitle: "Search behavior, results, wallpapers, and actions."
    },
    {
      pageIndex: 4,
      id: "dashboard",
      icon: "dashboard",
      title: "Dashboard",
      subtitle: "Top-frame overview modules and telemetry."
    },
    {
      pageIndex: 5,
      id: "notifications",
      icon: "notifications",
      title: "Notifications",
      subtitle: "Expiry, grouping, and click behavior."
    },
    {
      pageIndex: 6,
      id: "system",
      icon: "tune",
      title: "System",
      subtitle: "OSD, idle, audio, brightness, and shell actions."
    },
    {
      pageIndex: 7,
      id: "hyprland",
      icon: "window",
      title: "Hyprland",
      subtitle: "Open HyprMod for compositor configuration."
    },
    {
      pageIndex: 8,
      id: "profiles",
      icon: "folder_managed",
      title: "Profiles",
      subtitle: "Save, activate, and compare settings profiles."
    },
    {
      pageIndex: 9,
      id: "settings",
      icon: "settings",
      title: "Settings",
      subtitle: "Config file path, auto-save, and app preferences."
    }
  ]
  readonly property var searchIndex: [
    { pageIndex: 0, title: "Version", description: "About > Build", key: "about.version", text: "build channel release" },
    { pageIndex: 0, title: "Refresh Shell", description: "About > Tools", key: "about.refresh_shell", text: "restart service run" },
    { pageIndex: 0, title: "Doctor", description: "About > Tools", key: "about.doctor", text: "health check shell environment" },
    { pageIndex: 0, title: "Credits", description: "About > Credits", key: "about.credits", text: "quickshell hyprland hyprmod" },
    { pageIndex: 1, title: "Mode", description: "Appearance > Theme Mode", key: "appearance.mode", text: "dark light theme palette" },
    { pageIndex: 1, title: "Scheme", description: "Appearance > Theme Mode", key: "appearance.scheme", text: "colour color swatch default forest ocean amethyst rose graphite" },
    { pageIndex: 1, title: "Color variant", description: "Appearance > Theme Mode", key: "appearance.variant", text: "tonal expressive vibrant fidelity content fruitsalad rainbow neutral monochrome" },
    { pageIndex: 1, title: "Transparency", description: "Appearance > Visual Effects", key: "appearance.transparency.enabled", text: "translucent shell layers" },
    { pageIndex: 1, title: "Base opacity", description: "Appearance > Visual Effects", key: "appearance.transparency.base", text: "opacity alpha transparent" },
    { pageIndex: 1, title: "Rounding scale", description: "Appearance > Geometry", key: "appearance.rounding.scale", text: "corner radius" },
    { pageIndex: 1, title: "Padding scale", description: "Appearance > Geometry", key: "appearance.padding.scale", text: "spacing density" },
    { pageIndex: 1, title: "Font scale", description: "Appearance > Geometry", key: "appearance.font.scale", text: "typography size" },
    { pageIndex: 1, title: "Frame thickness", description: "Appearance > Geometry", key: "border.thickness", text: "top frame side frame border" },
    { pageIndex: 1, title: "Wallpaper", description: "Appearance > Desktop", key: "background.wallpaperEnabled", text: "desktop background" },
    { pageIndex: 1, title: "Desktop clock", description: "Appearance > Desktop", key: "background.clockEnabled", text: "large overlay clock" },
    { pageIndex: 1, title: "Audio visualiser", description: "Appearance > Desktop", key: "background.visualiserEnabled", text: "wallpaper cava visualizer" },
    { pageIndex: 2, title: "Taskbar enabled", description: "Taskbar > General", key: "bar.enabled", text: "bar frame dock" },
    { pageIndex: 2, title: "Persistent", description: "Taskbar > General", key: "bar.persistent", text: "always visible" },
    { pageIndex: 2, title: "Show on hover", description: "Taskbar > General", key: "bar.showOnHover", text: "reveal frame" },
    { pageIndex: 2, title: "Vertical alignment", description: "Taskbar > Layout", key: "bar.verticallyCenter", text: "center align" },
    { pageIndex: 2, title: "Workspaces", description: "Taskbar > Workspaces", key: "bar.workspaces.shown", text: "workspace buttons" },
    { pageIndex: 2, title: "Active indicator", description: "Taskbar > Workspaces", key: "bar.workspaces.activeIndicator", text: "current workspace" },
    { pageIndex: 2, title: "Magic lamp", description: "Taskbar > Workspaces", key: "bar.workspaces.magicLamp", text: "animation" },
    { pageIndex: 2, title: "System tray", description: "Taskbar > Tray", key: "bar.tray.enabled", text: "tray icons" },
    { pageIndex: 2, title: "Clock", description: "Taskbar > Status", key: "bar.status.showClock", text: "time date" },
    { pageIndex: 2, title: "Network", description: "Taskbar > Status", key: "bar.status.showNetwork", text: "lan wifi bluetooth battery status" },
    { pageIndex: 3, title: "Launcher enabled", description: "Launcher > General", key: "launcher.enabled", text: "app search drawer" },
    { pageIndex: 3, title: "Show on hover", description: "Launcher > General", key: "launcher.showOnHover", text: "lower frame reveal" },
    { pageIndex: 3, title: "Vim keybinds", description: "Launcher > General", key: "launcher.vimKeybinds", text: "keyboard navigation" },
    { pageIndex: 3, title: "Dangerous actions", description: "Launcher > General", key: "launcher.enableDangerousActions", text: "power results" },
    { pageIndex: 3, title: "Maximum results", description: "Launcher > Results", key: "launcher.maxShown", text: "shown item count" },
    { pageIndex: 3, title: "Maximum wallpapers", description: "Launcher > Results", key: "launcher.maxWallpapers", text: "wallpaper results" },
    { pageIndex: 3, title: "Item scale", description: "Launcher > Results", key: "launcher.itemScale", text: "result size density" },
    { pageIndex: 3, title: "Fuzzy matching", description: "Launcher > Fuzzy Matching", key: "launcher.useFuzzy", text: "apps actions wallpapers" },
    { pageIndex: 4, title: "Dashboard enabled", description: "Dashboard > General", key: "dashboard.enabled", text: "top frame overview" },
    { pageIndex: 4, title: "Show on hover", description: "Dashboard > General", key: "dashboard.showOnHover", text: "reveal dashboard" },
    { pageIndex: 4, title: "Home tab", description: "Dashboard > Tabs", key: "dashboard.showDashboard", text: "main dashboard" },
    { pageIndex: 4, title: "Media tab", description: "Dashboard > Tabs", key: "dashboard.showMedia", text: "music controls" },
    { pageIndex: 4, title: "Performance tab", description: "Dashboard > Tabs", key: "dashboard.showPerformance", text: "telemetry system monitor" },
    { pageIndex: 4, title: "Weather tab", description: "Dashboard > Tabs", key: "dashboard.showWeather", text: "forecast summary" },
    { pageIndex: 4, title: "Performance modules", description: "Dashboard > Performance", key: "dashboard.performance", text: "cpu gpu memory storage network" },
    { pageIndex: 5, title: "Auto expire", description: "Notifications > Behaviour", key: "notifs.expire", text: "dismiss notifications timeout" },
    { pageIndex: 5, title: "Click primary action", description: "Notifications > Behaviour", key: "notifs.actionOnClick", text: "notification click action" },
    { pageIndex: 5, title: "Open expanded", description: "Notifications > Behaviour", key: "notifs.openExpanded", text: "notification group expand" },
    { pageIndex: 5, title: "Expire timeout", description: "Notifications > Timing", key: "notifs.expireTimeout", text: "lifetime delay" },
    { pageIndex: 5, title: "Fullscreen timeout", description: "Notifications > Timing", key: "notifs.fullscreenExpireTimeout", text: "lifetime fullscreen delay" },
    { pageIndex: 5, title: "Group preview count", description: "Notifications > Timing", key: "notifs.groupPreviewNum", text: "collapse preview" },
    { pageIndex: 6, title: "OSD enabled", description: "System > OSD", key: "osd.enabled", text: "brightness volume overlay" },
    { pageIndex: 6, title: "Brightness OSD", description: "System > OSD", key: "osd.enableBrightness", text: "brightness overlay" },
    { pageIndex: 6, title: "Microphone OSD", description: "System > OSD", key: "osd.enableMicrophone", text: "mic overlay" },
    { pageIndex: 6, title: "OSD hide delay", description: "System > OSD", key: "osd.hideDelay", text: "timeout overlay" },
    { pageIndex: 6, title: "Smart scheme", description: "System > Services", key: "services.smartScheme", text: "wallpaper color theme" },
    { pageIndex: 6, title: "12-hour clock", description: "System > Services", key: "services.useTwelveHourClock", text: "am pm time format" },
    { pageIndex: 6, title: "Lyrics", description: "System > Services", key: "services.showLyrics", text: "music lyrics service" },
    { pageIndex: 6, title: "Audio step", description: "System > Services", key: "services.audioIncrement", text: "volume increment" },
    { pageIndex: 6, title: "Brightness step", description: "System > Services", key: "services.brightnessIncrement", text: "brightness increment" },
    { pageIndex: 6, title: "Lock before sleep", description: "System > Idle", key: "general.idle.lockBeforeSleep", text: "suspend lock" },
    { pageIndex: 6, title: "Inhibit during audio", description: "System > Idle", key: "general.idle.inhibitWhenAudio", text: "media idle" },
    { pageIndex: 7, title: "Open HyprMod", description: "Hyprland > HyprMod", key: "hyprland.hyprmod", text: "advanced compositor settings" },
    { pageIndex: 7, title: "Reload Hyprland", description: "Hyprland > HyprMod", key: "hyprland.reload", text: "apply compositor config" },
    { pageIndex: 7, title: "Shell edits", description: "Hyprland > Shell edits", key: "hyprland.shell_edits", text: "ryoku shell appearance taskbar dashboard settings" },
    { pageIndex: 8, title: "Profiles", description: "Profiles", key: "profiles", text: "save current active profile duplicate activate" },
    { pageIndex: 8, title: "Current shell profile", description: "Profiles > Active", key: "profiles.active", text: "active current shell profile" },
    { pageIndex: 9, title: "Config file path", description: "Settings > Configuration", key: "settings.configPath", text: "hyprmod managed config file path" },
    { pageIndex: 9, title: "Auto-save", description: "Settings > Behavior", key: "settings.autoSave", text: "automatically save changes after each modification" }
  ]
  readonly property var navigationSections: [
    {
      title: "Look & Feel",
      pages: [1]
    },
    {
      title: "Input",
      pages: [3]
    },
    {
      title: "Display",
      pages: [4, 5]
    },
    {
      title: "Window Management",
      pages: [2]
    },
    {
      title: "Startup",
      pages: [6]
    },
    {
      title: "Advanced",
      pages: [7]
    }
  ]
  readonly property var pinnedPages: [8, 9]
  readonly property int searchPageIndex: 10
  readonly property int pendingPageIndex: 11
  readonly property string searchQuery: root.normaliseText(root.searchText).trim()
  readonly property bool searchActive: root.searchQuery.length >= 2
  readonly property var searchResults: root.searchIndex.filter(entry => root.searchEntryMatches(entry))
  readonly property string activeSchemeName: root.currentSchemeName.length > 0 ? root.currentSchemeName : root.savedSchemeName.length > 0 ? root.savedSchemeName : Colours.scheme || "ryoku"
  readonly property string activeSchemeFlavour: root.currentSchemeFlavour.length > 0 ? root.currentSchemeFlavour : root.savedSchemeFlavour.length > 0 ? root.savedSchemeFlavour : Colours.flavour || "default"
  readonly property string activeSchemeMode: root.currentSchemeMode.length > 0 ? root.currentSchemeMode : root.savedSchemeMode.length > 0 ? root.savedSchemeMode : Colours.light ? "light" : "dark"
  readonly property string activeVariant: root.currentVariant.length > 0 ? root.currentVariant : root.savedVariant.length > 0 ? root.savedVariant : "tonalspot"
  readonly property bool schemeDirty: root.savedSchemeReady && (root.activeSchemeName !== root.savedSchemeName || root.activeSchemeFlavour !== root.savedSchemeFlavour || root.activeVariant !== root.savedVariant || root.activeSchemeMode !== root.savedSchemeMode)
  readonly property int contentPageIndex: root.searchActive ? root.searchPageIndex : root.currentPage
  readonly property var selectedPage: root.searchActive ? {
    pageIndex: root.searchPageIndex,
    id: "search",
    icon: "search",
    title: "Search Results",
    subtitle: root.searchResults.length > 0 ? `${root.searchResults.length} result${root.searchResults.length === 1 ? "" : "s"}` : "Try a different search term."
  } : root.currentPage === root.pendingPageIndex ? {
    pageIndex: root.pendingPageIndex,
    id: "pending",
    icon: "pending_actions",
    title: "Pending Changes",
    subtitle: root.pendingCount > 0 ? `${root.pendingCount} change${root.pendingCount === 1 ? "" : "s"}` : "No pending changes."
  } : root.pages[root.currentPage] || root.pages[0]
  readonly property var pendingChanges: Object.keys(root.pendingEntries).map(key => root.pendingEntries[key])
  readonly property int pendingCount: root.pendingChanges.length
  readonly property int configPendingCount: root.pendingChanges.filter(entry => entry && entry.configBacked).length

  property int currentPage: 1
  property real offsetScale: root.shouldBeActive ? 0 : 1
  property string searchText: ""
  property string currentSchemeName: ""
  property string currentSchemeFlavour: ""
  property string currentSchemeMode: ""
  property string currentVariant: ""
  property bool savedSchemeReady
  property string savedSchemeName: ""
  property string savedSchemeFlavour: ""
  property string savedSchemeMode: ""
  property string savedVariant: ""
  property bool schemePreviewActive
  property bool shellConfigEditActive
  property bool autoSavePendingEdits
  property var pendingEntries: ({})
  property var changeHistory: []
  property var redoHistory: []
  property bool historyReplayActive
  property bool searchOpen
  property bool savedBannerVisible
  property bool shortcutsOverlayOpen
  property string highlightedSettingKey: ""

  function normaliseText(text: string): string {
    return String(text || "").toLowerCase();
  }

  function formatBreadcrumb(text: string): string {
    return String(text || "").replace(/\s*>\s*/g, " \u203a ");
  }

  function pageMatches(page): bool {
    return true;
  }

  function sectionMatches(section): bool {
    return true;
  }

  function searchEntryMatches(entry): bool {
    if (root.searchQuery.length < 2)
      return false;
    const terms = root.searchQuery.split(/\s+/);
    const haystack = root.normaliseText(`${entry.title} ${entry.description} ${entry.key} ${entry.text || ""}`);
    for (let i = 0; i < terms.length; i++) {
      if (!haystack.includes(terms[i]))
        return false;
    }
    return true;
  }

  function selectPage(pageIndex: int): void {
    root.currentPage = pageIndex;
    root.searchText = "";
    root.searchOpen = false;
  }

  function openSearchResult(entry): void {
    root.navigateToSetting(entry.pageIndex, entry.key || "");
  }

  function focusSearch(): void {
    root.searchOpen = true;
  }

  function dismissSearch(): bool {
    if (!root.searchOpen && root.searchText.length === 0)
      return false;

    root.searchText = "";
    root.searchOpen = false;
    return true;
  }

  function openPendingChanges(): void {
    root.currentPage = root.pendingPageIndex;
    root.searchText = "";
    root.searchOpen = false;
  }

  function navigateToSetting(pageIndex: int, targetKey: string): void {
    root.selectPage(pageIndex);
    root.highlightSetting(targetKey);
  }

  function highlightSetting(targetKey: string): void {
    if (targetKey.length === 0)
      return;

    root.highlightedSettingKey = targetKey;
    highlightedSettingTimer.restart();
  }

  function keyForSetting(title: string, propertyName: string): string {
    for (let i = 0; i < root.searchIndex.length; i++) {
      const entry = root.searchIndex[i];
      if (entry.title !== title)
        continue;
      if (propertyName.length === 0 || entry.key === propertyName || entry.key.endsWith(`.${propertyName}`) || entry.key.includes(`.${propertyName}.`))
        return entry.key;
    }

    for (let i = 0; i < root.searchIndex.length; i++) {
      const entry = root.searchIndex[i];
      if (entry.title === title)
        return entry.key;
    }

    return "";
  }

  function pageIndexForSetting(title: string, propertyName: string): int {
    for (let i = 0; i < root.searchIndex.length; i++) {
      const entry = root.searchIndex[i];
      if (entry.title !== title)
        continue;
      if (propertyName.length === 0 || entry.key === propertyName || entry.key.endsWith(`.${propertyName}`) || entry.key.includes(`.${propertyName}.`))
        return entry.pageIndex;
    }

    for (let i = 0; i < root.searchIndex.length; i++) {
      const entry = root.searchIndex[i];
      if (entry.title === title)
        return entry.pageIndex;
    }

    return -1;
  }

  function pagePendingCount(pageIndex: int): int {
    let count = 0;
    for (let i = 0; i < root.pendingChanges.length; i++) {
      if (root.pendingChanges[i] && root.pendingChanges[i].pageIndex === pageIndex)
        count++;
    }
    return count;
  }

  function setPendingEntry(key: string, entry): void {
    const previous = root.pendingEntries[key] || null;
    const next = Object.assign({}, root.pendingEntries);
    if (entry)
      next[key] = entry;
    else
      delete next[key];
    root.recordPendingHistory(key, previous, entry);
    root.pendingEntries = next;
    root.scheduleAutoSaveIfEnabled();
  }

  function discardPendingEntry(key: string): void {
    const entry = root.pendingEntries[key];
    if (entry && typeof entry.revert === "function")
      entry.revert();
  }

  function isSchemePendingEntry(entry): bool {
    return entry && (entry.key === "appearance:mode" || entry.key === "appearance:scheme" || entry.key === "appearance:variant");
  }

  function historyValueKey(value): string {
    try {
      return JSON.stringify(value);
    } catch (error) {
      return String(value);
    }
  }

  function recordPendingHistory(key: string, previous, entry): void {
    if (root.historyReplayActive || !entry || typeof entry.apply !== "function" || entry.toValue === undefined)
      return;

    const previousValue = previous && previous.toValue !== undefined ? previous.toValue : entry.fromValue;
    if (previousValue === undefined || root.historyValueKey(previousValue) === root.historyValueKey(entry.toValue))
      return;

    const operation = {
      key,
      title: entry.title,
      previousValue,
      nextValue: entry.toValue,
      apply: entry.apply
    };
    root.changeHistory = root.changeHistory.concat([operation]).slice(-50);
    root.redoHistory = [];
  }

  function applyHistoryOperation(operation, value): void {
    if (!operation || typeof operation.apply !== "function")
      return;

    root.historyReplayActive = true;
    try {
      operation.apply(value);
    } finally {
      root.historyReplayActive = false;
    }
    root.finishShellConfigEditSessionIfClean();
    root.scheduleAutoSaveIfEnabled();
  }

  function undoLastChange(): void {
    if (root.changeHistory.length === 0)
      return;

    const history = root.changeHistory.slice();
    const operation = history.pop();
    root.changeHistory = history;
    root.applyHistoryOperation(operation, operation.previousValue);
    root.redoHistory = root.redoHistory.concat([operation]);
  }

  function redoLastChange(): void {
    if (root.redoHistory.length === 0)
      return;

    const redo = root.redoHistory.slice();
    const operation = redo.pop();
    root.redoHistory = redo;
    root.applyHistoryOperation(operation, operation.nextValue);
    root.changeHistory = root.changeHistory.concat([operation]).slice(-50);
  }

  function clearChangeHistory(): void {
    root.changeHistory = [];
    root.redoHistory = [];
  }

  function discardAllPending(): void {
    const entries = root.pendingChanges.slice();
    let restoreSavedScheme = root.schemeDirty;
    for (let i = 0; i < entries.length; i++) {
      if (root.isSchemePendingEntry(entries[i]))
        restoreSavedScheme = true;
      if (entries[i] && typeof entries[i].revert === "function")
        entries[i].revert();
    }
    if (restoreSavedScheme)
      root.restoreScheme();
    root.clearChangeHistory();
    root.finishShellConfigEditSessionIfClean();
  }

  function saveAllPending(): void {
    const entries = root.pendingChanges.slice();
    for (let i = 0; i < entries.length; i++) {
      if (entries[i] && typeof entries[i].accept === "function")
        entries[i].accept();
    }
    GlobalConfig.save();
    root.pendingEntries = ({});
    root.clearChangeHistory();
    root.setShellConfigAutoSaveSuspended(false);
    root.markSaved();
  }

  function toggleAutoSavePendingEdits(): void {
    root.autoSavePendingEdits = !root.autoSavePendingEdits;
    root.scheduleAutoSaveIfEnabled();
  }

  function scheduleAutoSaveIfEnabled(): void {
    if (root.autoSavePendingEdits && root.pendingCount > 0)
      autoSavePendingTimer.restart();
    else
      autoSavePendingTimer.stop();
  }

  function showKeyboardShortcuts(): void {
    root.shortcutsOverlayOpen = true;
  }

  function reportBug(): void {
    Quickshell.execDetached(["xdg-open", "https://github.com/neur0map/ryoku-arch/issues/new"]);
  }

  function configValue(target, propertyName: string, fallback): var {
    if (!target || !propertyName.length)
      return fallback;
    const value = target[propertyName];
    return value === undefined ? fallback : value;
  }

  function markSaved(): void {
    root.savedBannerVisible = true;
    savedBannerTimer.restart();
  }

  function writeConfig(target, propertyName: string, value): void {
    if (!target || !propertyName.length)
      return;
    root.beginShellConfigEditSession();
    if (typeof target.setProperty === "function")
      target.setProperty(propertyName, value);
    else
      target[propertyName] = value;
  }

  function setShellConfigAutoSaveSuspended(suspended: bool): void {
    root.shellConfigEditActive = suspended;
    if (typeof GlobalConfig.setAutoSaveSuspended === "function")
      GlobalConfig.setAutoSaveSuspended(suspended);
  }

  function beginShellConfigEditSession(): void {
    if (!root.shellConfigEditActive)
      root.setShellConfigAutoSaveSuspended(true);
  }

  function finishShellConfigEditSessionIfClean(): void {
    if (root.configPendingCount === 0 && root.shellConfigEditActive)
      root.setShellConfigAutoSaveSuspended(false);
  }

  function abandonPendingSession(): void {
    if (root.pendingCount > 0)
      root.discardAllPending();
    else {
      if (root.schemeDirty)
        root.restoreScheme();
      root.finishShellConfigEditSessionIfClean();
    }
    root.savedBannerVisible = false;
  }

  function schemeArg(args, flag: string, fallback: string): string {
    const index = args.indexOf(flag);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
  }

  function restartProcess(process): void {
    process.running = false;
    process.running = true;
  }

  function startProcess(process, command): void {
    process.running = false;
    process.command = command;
    process.running = true;
  }

  function refreshCurrentSchemeState(): void {
    root.restartProcess(schemeState);
  }

  function refreshSavedSchemeState(): void {
    root.restartProcess(schemeSavedState);
  }

  function refreshSchemeState(): void {
    root.refreshSavedSchemeState();
    root.refreshCurrentSchemeState();
  }

  function loadSchemeText(data: string): void {
    const trimmed = data.trim();
    if (!trimmed)
      return;

    try {
      const scheme = JSON.parse(trimmed);
      root.currentSchemeName = scheme.name || "";
      root.currentSchemeFlavour = scheme.flavour || "";
      root.currentSchemeMode = scheme.mode || "";
      root.currentVariant = scheme.variant || "";
      if (!root.savedSchemeReady && !root.schemePreviewActive) {
        root.savedSchemeName = root.currentSchemeName || "ryoku";
        root.savedSchemeFlavour = root.currentSchemeFlavour || "default";
        root.savedSchemeMode = root.currentSchemeMode || "dark";
        root.savedVariant = root.currentVariant || "tonalspot";
        root.savedSchemeReady = true;
      }
    } catch (error) {
      const lines = trimmed.split("\n");
      if (lines.length >= 3) {
        root.currentSchemeName = lines[0];
        root.currentSchemeFlavour = lines[1];
        root.currentVariant = lines[2];
      }
    }
  }

  function loadSavedSchemeFields(data: string): void {
    const lines = data.trim().split("\n");
    if (lines.length < 4)
      return;

    root.savedSchemeName = lines[0] || "ryoku";
    root.savedSchemeFlavour = lines[1] || "default";
    root.savedVariant = lines[2] || "tonalspot";
    root.savedSchemeMode = lines[3] || "dark";
    root.savedSchemeReady = true;

    if (root.currentSchemeName.length === 0)
      root.currentSchemeName = root.savedSchemeName;
    if (root.currentSchemeFlavour.length === 0)
      root.currentSchemeFlavour = root.savedSchemeFlavour;
    if (root.currentVariant.length === 0)
      root.currentVariant = root.savedVariant;
    if (root.currentSchemeMode.length === 0)
      root.currentSchemeMode = root.savedSchemeMode;
  }

  function previewScheme(args): void {
    const name = root.schemeArg(args, "-n", root.activeSchemeName);
    const flavour = root.schemeArg(args, "-f", root.activeSchemeFlavour);
    const variant = root.schemeArg(args, "-v", root.activeVariant);
    const mode = root.schemeArg(args, "-m", root.activeSchemeMode);

    root.currentSchemeName = name;
    root.currentSchemeFlavour = flavour;
    root.currentVariant = variant;
    root.currentSchemeMode = mode;
    root.schemePreviewActive = true;

    root.startProcess(schemeApply, [root.ryokuBridge, "scheme", "preview", "--notify", "-n", name, "-f", flavour, "-v", variant, "-m", mode]);
    schemeRefreshTimer.restart();
  }

  function saveScheme(): void {
    if (!root.savedSchemeReady)
      return;

    const name = root.activeSchemeName;
    const flavour = root.activeSchemeFlavour;
    const variant = root.activeVariant;
    const mode = root.activeSchemeMode;

    root.startProcess(schemePersist, [root.ryokuBridge, "scheme", "set", "--notify", "-n", name, "-f", flavour, "-v", variant, "-m", mode]);
    root.savedSchemeName = name;
    root.savedSchemeFlavour = flavour;
    root.savedVariant = variant;
    root.savedSchemeMode = mode;
    root.schemePreviewActive = false;
    schemeRefreshTimer.restart();
  }

  function restoreScheme(): void {
    if (!root.savedSchemeReady)
      return;

    root.previewScheme(["-n", root.savedSchemeName, "-f", root.savedSchemeFlavour, "-v", root.savedVariant, "-m", root.savedSchemeMode]);
    root.schemePreviewActive = false;
  }

  visible: true
  enabled: root.shouldBeActive || root.offsetScale < 1
  focus: root.shouldBeActive
  anchors.topMargin: (-implicitHeight - 5) * root.offsetScale
  implicitHeight: Math.min(root.availableHeight * 0.9, root.hyprmodDefaultHeight)
  implicitWidth: Math.min(root.availableWidth * 0.92, root.hyprmodDefaultWidth)
  opacity: 1 - root.offsetScale

  Behavior on offsetScale {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Component.onCompleted: {
    RyokuAbout.refreshStatus();
    root.refreshSchemeState();
  }

  Component.onDestruction: root.setShellConfigAutoSaveSuspended(false)

  onConfigPendingCountChanged: finishShellConfigEditSessionIfClean()
  onPendingCountChanged: scheduleAutoSaveIfEnabled()
  onShouldBeActiveChanged: {
    if (shouldBeActive) {
      root.refreshSchemeState();
      root.forceActiveFocus();
    } else {
      abandonPendingSession();
    }
  }

  Keys.onPressed: event => {
    const ctrlPressed = (event.modifiers & Qt.ControlModifier) !== 0;
    if (root.shortcutsOverlayOpen) {
      if (event.key === Qt.Key_Escape)
        root.shortcutsOverlayOpen = false;
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_F1 || ctrlPressed && event.key === Qt.Key_Question) {
      root.showKeyboardShortcuts();
      event.accepted = true;
      return;
    }

    if (ctrlPressed && event.key === Qt.Key_F) {
      root.focusSearch();
      event.accepted = true;
      return;
    }

    if (ctrlPressed && event.key === Qt.Key_S) {
      if (root.pendingCount > 0)
        root.saveAllPending();
      event.accepted = true;
      return;
    }

    if (ctrlPressed && event.key === Qt.Key_Z) {
      const shiftPressed = (event.modifiers & Qt.ShiftModifier) !== 0;
      if (shiftPressed)
        root.redoLastChange();
      else
        root.undoLastChange();
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_Escape) {
      if (!root.dismissSearch())
        root.visibilities.settings = false;
      event.accepted = true;
    }
  }

  Timer {
    id: savedBannerTimer

    interval: 1800
    onTriggered: root.savedBannerVisible = false
  }

  Timer {
    id: autoSavePendingTimer

    interval: 800
    onTriggered: {
      if (root.autoSavePendingEdits && root.pendingCount > 0)
        root.saveAllPending();
    }
  }

  Timer {
    id: highlightedSettingTimer

    interval: 900
    onTriggered: root.highlightedSettingKey = ""
  }

  Timer {
    id: schemeRefreshTimer

    interval: 700
    onTriggered: root.refreshCurrentSchemeState()
  }

  FileView {
    path: `${Paths.state}/scheme.json`
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      root.loadSchemeText(text());
      if (root.shouldBeActive)
        root.refreshSavedSchemeState();
    }
  }

  Process {
    id: schemeApply

    command: []
    stdout: StdioCollector {
      onStreamFinished: root.loadSchemeText(text)
    }
    onExited: code => {
      if (code === 0)
        root.refreshCurrentSchemeState();
    }
  }

  Process {
    id: schemePersist

    command: []
    onExited: code => {
      if (code === 0)
        root.refreshSchemeState();
    }
  }

  Process {
    id: schemeState

    command: [root.ryokuBridge, "scheme", "get"]
    stdout: StdioCollector {
      onStreamFinished: root.loadSchemeText(text)
    }
  }

  Process {
    id: schemeSavedState

    command: [root.ryokuBridge, "scheme", "get", "-nfvm"]
    stdout: StdioCollector {
      onStreamFinished: root.loadSavedSchemeFields(text)
    }
  }

  StyledRect {
    id: chrome

    anchors.fill: parent
    radius: root.windowRadius
    color: Colours.palette.m3surface
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    clip: true

    RowLayout {
      anchors.fill: parent
      spacing: 0

      StyledRect {
        id: sidebar

        Layout.fillHeight: true
        Layout.preferredWidth: root.sidebarWidth
        color: Colours.palette.m3surfaceContainerLowest
        topLeftRadius: chrome.radius
        bottomLeftRadius: chrome.radius

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          HeaderBar {
            Layout.fillWidth: true
            title: "HyprMod"
            showBackButton: false
            searchButton: true
          }

          SearchBox {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.smaller
            Layout.rightMargin: Tokens.padding.smaller
            Layout.topMargin: visible ? Tokens.padding.small : 0
            Layout.bottomMargin: visible ? Tokens.padding.small : 0
            visible: root.searchOpen || root.searchText.length > 0
          }

          StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
          }

          StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: navColumn.implicitHeight + Tokens.padding.normal
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: navColumn

              width: parent.width
              anchors.top: parent.top
              anchors.topMargin: Tokens.padding.small
              spacing: 0

              Repeater {
                model: root.navigationSections

                SidebarCategory {
                  required property var modelData

                  Layout.fillWidth: true
                  section: modelData
                  visible: root.sectionMatches(modelData)
                }
              }
            }
          }

          StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.padding.small
            spacing: 2

            Repeater {
              model: root.pinnedPages

              SidebarRow {
                required property int modelData

                Layout.fillWidth: true
                pageIndex: modelData
                pageIcon: root.pages[modelData].icon
                pageTitle: root.pages[modelData].title
                visible: root.pageMatches(root.pages[modelData])
              }
            }
          }
        }
      }

      StyledRect {
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        color: Colours.palette.m3outlineVariant
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        HeaderBar {
          Layout.fillWidth: true
          title: root.selectedPage.title
          subtitle: root.selectedPage.subtitle
          centerTitle: true
          showMenuButton: true
          profileSaveButton: !root.searchActive && root.currentPage === 8
        }

        StackLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: root.contentPageIndex

          AboutPage {}
          AppearancePage {}
          BarPage {}
          LauncherPage {}
          DashboardPage {}
          NotificationsPage {}
          SystemPage {}
          HyprlandPage {}
          ProfilesPage {}
          AppSettingsPage {}
          SearchPage {}
          PendingChangesPage {}
        }

        DirtyBanner {
          Layout.fillWidth: true
          visible: root.pendingCount > 0 || root.savedBannerVisible
        }
      }
    }
  }

  ShortcutOverlay {
    visible: root.shortcutsOverlayOpen
    anchors.fill: chrome
    z: 20
  }

  component ShortcutOverlay: Item {
    id: shortcutOverlay

    StyledRect {
      anchors.fill: parent
      color: Qt.alpha(Colours.palette.m3scrim, 0.34)

      StateLayer {
        color: Colours.palette.m3onSurface
        onClicked: root.shortcutsOverlayOpen = false
      }
    }

    StyledRect {
      anchors.centerIn: parent
      implicitWidth: Math.min(parent.width - Tokens.padding.large * 2, 520)
      implicitHeight: shortcutsBody.implicitHeight + Tokens.padding.large * 2
      radius: root.groupRadius
      color: Colours.palette.m3surface
      border.width: 1
      border.color: Colours.palette.m3outlineVariant

      ColumnLayout {
        id: shortcutsBody

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.larger

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.normal

          StyledText {
            Layout.fillWidth: true
            text: "Keyboard Shortcuts"
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.normal
            font.weight: Font.Bold
            elide: Text.ElideRight
          }

          IconButton {
            icon: "close"
            type: IconButton.Text
            padding: Tokens.padding.smaller
            onClicked: root.shortcutsOverlayOpen = false
          }
        }

        ShortcutGroup {
          title: "General"

          ShortcutRow { action: "Save changes"; keys: ["Ctrl", "S"] }
          ShortcutRow { action: "Undo last change"; keys: ["Ctrl", "Z"] }
          ShortcutRow { action: "Redo change"; keys: ["Ctrl", "Shift", "Z"] }
        }

        ShortcutGroup {
          title: "Search"

          ShortcutRow { action: "Search options"; keys: ["Ctrl", "F"] }
          ShortcutRow { action: "Close search"; keys: ["Esc"] }
        }

        ShortcutGroup {
          title: "Help"

          ShortcutRow { action: "Show keyboard shortcuts"; keys: ["F1"] }
        }
      }
    }
  }

  component ShortcutGroup: ColumnLayout {
    id: shortcutGroup

    default property alias rows: shortcutRows.data
    required property string title

    Layout.fillWidth: true
    spacing: Tokens.spacing.small

    StyledText {
      Layout.fillWidth: true
      text: shortcutGroup.title
      color: Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.smaller
      font.weight: Font.Bold
      elide: Text.ElideRight
    }

    StyledRect {
      Layout.fillWidth: true
      implicitHeight: shortcutRows.implicitHeight
      radius: root.groupRadius
      color: Colours.palette.m3surfaceContainer
      border.width: 1
      border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.75)
      clip: true

      ColumnLayout {
        id: shortcutRows

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0
      }
    }
  }

  component ShortcutRow: StyledRect {
    id: shortcutRow

    required property string action
    required property var keys

    Layout.fillWidth: true
    implicitHeight: 42
    radius: 0
    color: "transparent"

    StyledRect {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: Tokens.padding.normal
      implicitHeight: 1
      color: Qt.alpha(Colours.palette.m3outlineVariant, 0.62)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.normal

      StyledText {
        Layout.fillWidth: true
        text: shortcutRow.action
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: Tokens.spacing.small / 2

        Repeater {
          model: shortcutRow.keys

          ShortcutKey {
            required property string modelData

            label: modelData
          }
        }
      }
    }
  }

  component ShortcutKey: StyledRect {
    id: shortcutKey

    required property string label

    implicitWidth: keyLabel.implicitWidth + Tokens.padding.small * 2
    implicitHeight: 24
    radius: root.rowRadius / 2
    color: Colours.palette.m3surfaceContainerHighest
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    StyledText {
      id: keyLabel

      anchors.centerIn: parent
      text: shortcutKey.label
      color: Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
    }
  }

  component HeaderBar: StyledRect {
    id: header

    property string title
    property string subtitle
    property bool showBackButton
    property bool searchButton
    property bool showMenuButton
    property bool centerTitle
    property bool profileSaveButton
    property bool menuOpen

    implicitHeight: root.headerHeight
    radius: 0
    color: Colours.palette.m3surface

    ColumnLayout {
      visible: header.centerTitle
      anchors.centerIn: parent
      width: Math.min(parent.width - 220, 360)
      spacing: 0

      StyledText {
        Layout.fillWidth: true
        text: header.title
        horizontalAlignment: Text.AlignHCenter
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.smaller
        font.weight: Font.Bold
        elide: Text.ElideRight
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.small

      IconButton {
        visible: header.showBackButton
        icon: "arrow_back"
        type: IconButton.Text
        padding: Tokens.padding.smaller
      }

      IconButton {
        id: profileSaveButton

        visible: header.profileSaveButton
        icon: "add"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: root.markSaved()

        Tooltip {
          target: profileSaveButton
          text: "Save current as new profile"
        }
      }

      ColumnLayout {
        visible: !header.centerTitle
        Layout.fillWidth: true
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: header.title
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.smaller
          font.weight: Font.Bold
          elide: Text.ElideRight
        }

        StyledText {
          visible: header.subtitle.length > 0
          Layout.fillWidth: true
          text: header.subtitle
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      Item {
        visible: header.centerTitle
        Layout.fillWidth: true
      }

      PendingChip {
        visible: header.showMenuButton && root.pendingCount > 0 && root.currentPage !== root.pendingPageIndex
      }

      IconButton {
        id: searchToggleButton

        visible: header.searchButton
        icon: "search"
        type: IconButton.Text
        toggle: true
        checked: root.searchOpen
        padding: Tokens.padding.smaller
        onClicked: {
          if (root.searchOpen)
            root.dismissSearch();
          else
            root.focusSearch();
        }

        Tooltip {
          target: searchToggleButton
          text: "Search options (Ctrl+F)"
        }
      }

      IconButton {
        id: menuButton

        visible: header.showMenuButton
        icon: "menu"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: settingsMenu.expanded = !settingsMenu.expanded

        Tooltip {
          target: menuButton
          text: "Settings menu"
        }
      }

      IconButton {
        id: closeButton

        icon: "close"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: root.visibilities.settings = false

        Tooltip {
          target: closeButton
          text: "Close"
        }
      }
    }

    Menu {
      id: settingsMenu

      visible: header.showMenuButton
      attachTo: menuButton
      attachSideX: Menu.Right
      attachSideY: Menu.Bottom
      thisSideX: Menu.Right
      thisSideY: Menu.Top
      marginY: Tokens.spacing.small
      active: null
      onExpandedChanged: {
        header.menuOpen = expanded;
        if (expanded)
          active = null;
      }
      items: [
        MenuItem {
          text: "Auto-save"
          trailingIcon: root.autoSavePendingEdits ? "check" : ""
          onClicked: root.toggleAutoSavePendingEdits()
        },
        MenuItem {
          text: "Migrate to Lua\u2026"
          separatorBefore: true
          enabled: false
        },
        MenuItem {
          text: "Review deprecated syntax\u2026"
          enabled: false
        },
        MenuItem {
          icon: "window"
          text: "Open HyprMod"
          separatorBefore: true
          onClicked: Quickshell.execDetached(["ryoku-launch-hyprmod"])
        },
        MenuItem {
          icon: "sync"
          text: "Reload Hyprland"
          onClicked: Quickshell.execDetached(["hyprctl", "reload"])
        },
        MenuItem {
          icon: "refresh"
          text: "Refresh Shell"
          onClicked: Quickshell.execDetached(["ryoku-shell", "service", "restart"])
        },
        MenuItem {
          icon: "keyboard"
          text: "Keyboard Shortcuts"
          separatorBefore: true
          onClicked: root.showKeyboardShortcuts()
        },
        MenuItem {
          icon: "bug_report"
          text: "Report a bug"
          onClicked: root.reportBug()
        },
        MenuItem {
          icon: "info"
          text: "About HyprMod"
          onClicked: root.selectPage(0)
        }
      ]
    }
  }

  component SearchBox: StyledRect {
    id: searchBox

    implicitHeight: 38
    radius: root.rowRadius
    color: Colours.palette.m3surface
    border.width: 1
    border.color: searchField.activeFocus ? root.accent : Colours.palette.m3outlineVariant

    onVisibleChanged: {
      if (visible && root.searchOpen)
        searchField.forceActiveFocus();
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.small
      anchors.rightMargin: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        text: "search"
        color: searchField.activeFocus ? root.accent : Colours.palette.m3outline
        font.pointSize: Tokens.font.size.smaller
      }

      StyledTextField {
        id: searchField

        Layout.fillWidth: true
        text: root.searchText
        placeholderText: "Search options\u2026"
        onTextEdited: root.searchText = text
      }

      MaterialIcon {
        visible: root.searchText.length > 0
        text: "close"
        color: Colours.palette.m3outline
        font.pointSize: Tokens.font.size.small

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Tokens.padding.small
          cursorShape: Qt.PointingHandCursor
          onClicked: root.searchText = ""
        }
      }
    }
  }

  component SidebarCategory: ColumnLayout {
    id: category

    required property var section

    spacing: 0

    StyledText {
      Layout.fillWidth: true
      Layout.leftMargin: Tokens.padding.normal
      Layout.rightMargin: Tokens.padding.normal
      Layout.topMargin: Tokens.padding.small
      Layout.bottomMargin: Tokens.padding.small / 2
      text: category.section.title.toUpperCase()
      color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.72)
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
      elide: Text.ElideRight
    }

    Repeater {
      model: category.section.pages

      SidebarRow {
        required property int modelData

        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.small
        Layout.rightMargin: Tokens.padding.small
        pageIndex: modelData
        pageIcon: root.pages[modelData].icon
        pageTitle: root.pages[modelData].title
        visible: root.pageMatches(root.pages[modelData])
      }
    }
  }

  component SidebarRow: StyledRect {
    id: row

    required property int pageIndex
    required property string pageIcon
    required property string pageTitle
    readonly property bool selected: !root.searchActive && root.currentPage === row.pageIndex
    readonly property int pendingCount: root.pagePendingCount(row.pageIndex)

    implicitHeight: 38
    radius: root.rowRadius
    color: selected ? Colours.palette.m3surfaceContainerHighest : "transparent"

    StateLayer {
      color: Colours.palette.m3onSurface
      onClicked: root.selectPage(row.pageIndex)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        text: row.pageIcon
        fill: row.selected ? 1 : 0
        color: row.selected ? Colours.palette.m3onSurface : Colours.palette.m3outline
        font.pointSize: Tokens.font.size.smaller
      }

      StyledText {
        Layout.fillWidth: true
        text: row.pageTitle
        color: row.selected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.smaller
        font.weight: row.selected ? Font.Bold : Font.Medium
        elide: Text.ElideRight
      }

      SidebarBadge {
        visible: row.pendingCount > 0
        count: row.pendingCount
      }
    }
  }

  component NavEntry: SidebarRow {}

  component SidebarBadge: StyledRect {
    id: sidebarBadge

    required property int count

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: Math.max(18, badgeLabel.implicitWidth + Tokens.padding.small)
    implicitHeight: 18
    radius: implicitHeight / 2
    color: Qt.alpha(root.warning, 0.25)

    StyledText {
      id: badgeLabel

      anchors.centerIn: parent
      text: sidebarBadge.count.toString()
      color: root.warning
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
    }
  }

  component PendingChip: StyledRect {
    id: pendingChip

    implicitHeight: 26
    implicitWidth: chipRow.implicitWidth + Tokens.padding.small * 2
    radius: implicitHeight / 2
    color: Qt.alpha(root.warning, 0.18)

    StateLayer {
      color: root.warning
      onClicked: root.openPendingChanges()
    }

    RowLayout {
      id: chipRow

      anchors.centerIn: parent
      spacing: Tokens.spacing.small / 2

      MaterialIcon {
        text: "pending_actions"
        color: root.warning
        font.pointSize: Tokens.font.size.small
      }

      StyledText {
        text: root.pendingCount.toString()
        color: root.warning
        font.pointSize: Tokens.font.size.small
        font.weight: Font.Bold
      }
    }

    Tooltip {
      target: pendingChip
      text: "View pending changes"
    }
  }

  component SettingsPage: StyledFlickable {
    id: page

    default property alias content: pageBody.data

    contentWidth: width
    contentHeight: pageBody.implicitHeight + root.hyprmodPageVerticalMargin * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    ColumnLayout {
      id: pageBody

      width: Math.min(page.width - root.hyprmodPageHorizontalMargin * 2, root.contentMaxWidth)
      anchors.top: parent.top
      anchors.topMargin: root.hyprmodPageVerticalMargin
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: root.hyprmodPageSpacing
    }
  }

  component PreferenceGroup: ColumnLayout {
    id: group

    default property alias content: rowColumn.data
    property string title
    property string description

    Layout.fillWidth: true
    spacing: Tokens.spacing.small

    ColumnLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Tokens.padding.small
      Layout.rightMargin: Tokens.padding.small
      spacing: 1

      StyledText {
        visible: group.title.length > 0
        Layout.fillWidth: true
        text: group.title
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.smaller
        font.weight: Font.Bold
        elide: Text.ElideRight
      }

      StyledText {
        visible: group.description.length > 0
        Layout.fillWidth: true
        text: group.description
        color: Colours.palette.m3outline
        font.pointSize: Tokens.font.size.small
        wrapMode: Text.WordWrap
      }
    }

    StyledRect {
      Layout.fillWidth: true
      implicitHeight: rowColumn.implicitHeight
      radius: root.groupRadius
      color: Colours.palette.m3surfaceContainer
      border.width: 1
      border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.75)
      clip: true

      ColumnLayout {
        id: rowColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0
      }
    }
  }

  component PreferenceRow: StyledRect {
    id: prefRow

    property string icon
    property string title
    property string description
    property bool managed
    property bool dirty
    property bool showPrefixIcon
    property string settingKey
    readonly property bool hovered: rowHover.hovered
    readonly property bool highlighted: prefRow.settingKey.length > 0 && root.highlightedSettingKey === prefRow.settingKey
    default property alias suffix: suffixBox.data
    signal activated

    Layout.fillWidth: true
    implicitHeight: Math.max(62, rowLayout.implicitHeight + Tokens.padding.normal * 2)
    radius: 0
    color: highlighted ? Qt.alpha(root.accent, 0.15) : "transparent"

    Behavior on color {
      CAnim {}
    }

    HoverHandler {
      id: rowHover
    }

    StyledRect {
      visible: prefRow.dirty || prefRow.managed
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 3
      color: prefRow.dirty ? root.warning : root.accent
    }

    StyledRect {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: Tokens.padding.normal
      implicitHeight: 1
      color: Qt.alpha(Colours.palette.m3outlineVariant, 0.62)
    }

    StateLayer {
      color: Colours.palette.m3onSurface
      onClicked: prefRow.activated()
    }

    RowLayout {
      id: rowLayout

      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.normal

      MaterialIcon {
        visible: prefRow.showPrefixIcon && prefRow.icon.length > 0
        text: prefRow.icon
        color: prefRow.dirty ? root.warning : prefRow.managed ? root.accent : Colours.palette.m3outline
        fill: prefRow.managed ? 1 : 0
        font.pointSize: Tokens.font.size.normal
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        StyledText {
          Layout.fillWidth: true
          text: prefRow.title
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.smaller
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        StyledText {
          visible: prefRow.description.length > 0
          Layout.fillWidth: true
          text: prefRow.description
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.small
          maximumLineCount: 2
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
        }
      }

      RowLayout {
        id: suffixBox

        spacing: Tokens.spacing.small
      }
    }
  }

  component EmptyState: Item {
    id: emptyState

    property string icon
    property string title
    property string description

    Layout.fillWidth: true
    implicitHeight: 320

    ColumnLayout {
      anchors.centerIn: parent
      width: Math.min(parent.width - Tokens.padding.large * 2, 360)
      spacing: Tokens.spacing.normal

      MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: emptyState.icon
        color: Colours.palette.m3outline
        font.pointSize: Tokens.font.size.extraLarge
      }

      StyledText {
        Layout.fillWidth: true
        text: emptyState.title
        horizontalAlignment: Text.AlignHCenter
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.normal
        font.weight: Font.Bold
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        text: emptyState.description
        horizontalAlignment: Text.AlignHCenter
        color: Colours.palette.m3outline
        font.pointSize: Tokens.font.size.small
        wrapMode: Text.WordWrap
      }
    }
  }

  component SearchResultRow: PreferenceRow {
    id: searchRow

    required property var entry

    settingKey: entry.key || ""
    title: entry.title
    description: root.formatBreadcrumb(entry.description)
    onActivated: root.openSearchResult(entry)

    StyledText {
      Layout.alignment: Qt.AlignVCenter
      text: searchRow.entry.key
      color: Colours.palette.m3outline
      font.pointSize: Tokens.font.size.small
      font.family: "monospace"
      elide: Text.ElideRight
    }

    MaterialIcon {
      Layout.alignment: Qt.AlignVCenter
      text: "chevron_right"
      color: Colours.palette.m3outline
      font.pointSize: Tokens.font.size.small
    }
  }

  component SearchPage: SettingsPage {
    id: searchPage

    readonly property int resultCount: root.searchResults.length

    EmptyState {
      visible: searchPage.resultCount === 0
      icon: "search_off"
      title: "No Results"
      description: "Try a different search term."
    }

    PreferenceGroup {
      visible: searchPage.resultCount > 0
      title: `${searchPage.resultCount} result${searchPage.resultCount === 1 ? "" : "s"}`

      Repeater {
        model: root.searchResults

        SearchResultRow {
          required property var modelData

          entry: modelData
        }
      }
    }
  }

  component PendingBadge: StyledRect {
    id: pendingBadge

    required property string text

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: badgeText.implicitWidth + Tokens.padding.small * 2
    implicitHeight: 24
    radius: implicitHeight / 2
    color: Qt.alpha(root.warning, 0.24)

    StyledText {
      id: badgeText

      anchors.centerIn: parent
      text: pendingBadge.text
      color: root.warning
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
    }
  }

  component PendingChangeRow: PreferenceRow {
    id: pendingRow

    required property var entry

    showPrefixIcon: true
    icon: entry.icon || "tune"
    title: entry.title
    description: (entry.valueText || "").length > 0 ? `${entry.description}  ${entry.valueText}` : entry.description
    onActivated: {
      if (entry.pageIndex >= 0)
        root.navigateToSetting(entry.pageIndex, entry.targetKey || "");
    }

    PendingBadge {
      text: "Modified"
    }

    RowActionButton {
      icon: "undo"
      active: true
      onActivated: root.discardPendingEntry(pendingRow.entry.key)
    }

    MaterialIcon {
      visible: pendingRow.entry.pageIndex >= 0
      Layout.alignment: Qt.AlignVCenter
      text: "chevron_right"
      color: Colours.palette.m3outline
      font.pointSize: Tokens.font.size.small
    }
  }

  component DiffStatPill: StyledRect {
    id: diffPill

    required property string text
    required property color foreground
    required property color pillBackground

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: statText.implicitWidth + Tokens.padding.small * 2
    implicitHeight: 24
    radius: implicitHeight / 2
    color: pillBackground

    StyledText {
      id: statText

      anchors.centerIn: parent
      text: diffPill.text
      color: diffPill.foreground
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
      font.family: "monospace"
    }
  }

  component ConfigDiffPreview: StyledRect {
    id: diffPreview

    required property var entries
    readonly property var lines: diffPreview.buildLines()
    readonly property int removedCount: (entries || []).length
    readonly property int addedCount: (entries || []).length

    function sourceKey(entry): string {
      if (entry && entry.targetKey && entry.targetKey.length > 0)
        return entry.targetKey;
      if (entry && entry.key)
        return entry.key;
      return "setting";
    }

    function splitValueText(text: string): var {
      const marker = String.fromCharCode(8594);
      const parts = String(text || "").split(marker);
      if (parts.length < 2)
        return ["saved", String(text || "changed")];
      return [parts[0].trim(), parts.slice(1).join(marker).trim()];
    }

    function buildLines(): var {
      const result = [];
      const sourceEntries = diffPreview.entries || [];
      for (let i = 0; i < sourceEntries.length; i++) {
        const entry = sourceEntries[i];
        const values = diffPreview.splitValueText(entry.valueText || "");
        const key = diffPreview.sourceKey(entry);
        result.push({
          kind: "removed",
          text: `- ${key}: ${values[0]}`
        });
        result.push({
          kind: "added",
          text: `+ ${key}: ${values[1]}`
        });
      }
      return result;
    }

    Layout.fillWidth: true
    implicitHeight: Math.min(280, Math.max(150, diffBody.implicitHeight + diffHeader.implicitHeight))
    radius: root.groupRadius
    color: Qt.alpha(Colours.palette.m3onSurface, 0.04)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
    clip: true

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      RowLayout {
        id: diffHeader

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        Layout.leftMargin: Tokens.padding.normal
        Layout.rightMargin: Tokens.padding.normal
        spacing: Tokens.spacing.small

        StyledText {
          Layout.fillWidth: true
          text: "shell.json"
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.small
          font.weight: Font.Bold
          font.family: "monospace"
          elide: Text.ElideRight
        }

        DiffStatPill {
          text: `+${diffPreview.addedCount}`
          foreground: "#2ec27e"
          pillBackground: Qt.alpha("#2ec27e", 0.18)
        }

        DiffStatPill {
          text: `-${diffPreview.removedCount}`
          foreground: "#e01b24"
          pillBackground: Qt.alpha("#e01b24", 0.16)
        }
      }

      StyledRect {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
      }

      StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: diffBody.implicitHeight + Tokens.padding.normal * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
          id: diffBody

          width: parent.width
          anchors.top: parent.top
          anchors.topMargin: Tokens.padding.small
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: 0

          Repeater {
            model: diffPreview.lines

            StyledText {
              required property var modelData

              Layout.fillWidth: true
              Layout.leftMargin: Tokens.padding.normal
              Layout.rightMargin: Tokens.padding.normal
              text: modelData.text
              color: modelData.kind === "added" ? "#2ec27e" : "#e01b24"
              font.pointSize: Tokens.font.size.small
              font.family: "monospace"
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }

  component PendingChangesPage: SettingsPage {
    id: pendingPage

    readonly property int changeCount: root.pendingCount

    StyledText {
      visible: pendingPage.changeCount > 0
      Layout.fillWidth: true
      text: `${pendingPage.changeCount} unsaved change${pendingPage.changeCount === 1 ? "" : "s"}`
      color: Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.large
      font.weight: Font.Bold
      elide: Text.ElideRight
    }

    EmptyState {
      visible: pendingPage.changeCount === 0
      icon: "check_circle"
      title: "No Pending Changes"
      description: "Edits made on any page will appear here for review."
    }

    PreferenceGroup {
      visible: pendingPage.changeCount > 0
      title: "Options"
      description: `${pendingPage.changeCount} change${pendingPage.changeCount === 1 ? "" : "s"}`

      Repeater {
        model: root.pendingChanges

        PendingChangeRow {
          required property var modelData

          entry: modelData
        }
      }
    }

    PreferenceGroup {
      visible: pendingPage.changeCount > 0
      title: "Config diff preview"
      description: "Comparison between the saved config and what the next save would write."

      ConfigDiffPreview {
        entries: root.pendingChanges
      }
    }

    PreferenceGroup {
      visible: pendingPage.changeCount > 0
      title: "Actions"

      PreferenceRow {
        icon: "undo"
        showPrefixIcon: true
        title: "Discard all"
        description: "Restore every changed row to the value it had when settings opened."
        onActivated: root.discardAllPending()

        FlatButton {
          text: "Discard"
          onClicked: root.discardAllPending()
        }
      }
    }
  }

  component RowActionButton: StyledRect {
    id: rowAction

    required property string icon
    property bool active
    property bool revealed: true
    property string tooltipText: "Discard changes"
    signal activated

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: 30
    implicitHeight: 30
    radius: root.rowRadius
    color: "transparent"
    opacity: active && revealed ? 1 : 0
    enabled: active && revealed

    Behavior on opacity {
      Anim {}
    }

    StateLayer {
      disabled: !rowAction.active
      color: Colours.palette.m3onSurface
      onClicked: rowAction.activated()
    }

    MaterialIcon {
      anchors.centerIn: parent
      text: rowAction.icon
      color: Colours.palette.m3outline
      font.pointSize: Tokens.font.size.small
    }

    Tooltip {
      target: rowAction
      text: rowAction.tooltipText
    }
  }

  component AdwSwitch: StyledRect {
    id: adwSwitch

    required property bool checked
    signal toggled(bool checked)

    implicitWidth: 46
    implicitHeight: 26
    radius: implicitHeight / 2
    color: checked ? root.accent : Colours.palette.m3surfaceContainerHighest
    border.width: checked ? 0 : 1
    border.color: Colours.palette.m3outlineVariant

    Behavior on color {
      CAnim {}
    }

    Behavior on border.color {
      CAnim {}
    }

    StateLayer {
      color: adwSwitch.checked ? root.accentOn : Colours.palette.m3onSurface
      onClicked: adwSwitch.toggled(!adwSwitch.checked)
    }

    StyledRect {
      implicitWidth: 22
      implicitHeight: 22
      radius: implicitHeight / 2
      anchors.verticalCenter: parent.verticalCenter
      x: adwSwitch.checked ? adwSwitch.width - width - 2 : 2
      color: adwSwitch.checked ? root.accentOn : Colours.palette.m3outline

      Behavior on x {
        Anim {
          type: Anim.DefaultSpatial
        }
      }

      Behavior on color {
        CAnim {}
      }
    }
  }

  component SwitchPreferenceRow: PreferenceRow {
    id: switchRow

    required property var target
    required property string propertyName
    readonly property bool checkedValue: !!root.configValue(switchRow.target, switchRow.propertyName, false)
    readonly property string settingKeyValue: root.keyForSetting(switchRow.title, switchRow.propertyName)
    readonly property string pendingKey: `switch:${switchRow.title}:${switchRow.propertyName}:${switchRow.description}`
    property bool baselineReady
    property bool baselineValue
    readonly property bool dirtyValue: baselineReady && checkedValue !== baselineValue

    function commit(value: bool): void {
      root.writeConfig(switchRow.target, switchRow.propertyName, value);
    }

    function updatePending(): void {
      if (!baselineReady)
        return;
      root.setPendingEntry(pendingKey, dirtyValue ? {
        key: pendingKey,
        title: switchRow.title,
        description: switchRow.description,
        valueText: `${baselineValue ? "On" : "Off"} \u2192 ${checkedValue ? "On" : "Off"}`,
        icon: switchRow.icon || "toggle_on",
        pageIndex: root.pageIndexForSetting(switchRow.title, switchRow.propertyName),
        targetKey: switchRow.settingKeyValue,
        configBacked: true,
        fromValue: baselineValue,
        toValue: checkedValue,
        apply: value => switchRow.commit(!!value),
        revert: () => switchRow.commit(switchRow.baselineValue),
        accept: () => {
          switchRow.baselineValue = switchRow.checkedValue;
          switchRow.updatePending();
        }
      } : null);
    }

    Component.onCompleted: {
      baselineValue = checkedValue;
      baselineReady = true;
      updatePending();
    }

    Component.onDestruction: root.setPendingEntry(pendingKey, null)
    onDirtyValueChanged: updatePending()

    dirty: dirtyValue
    managed: false
    settingKey: settingKeyValue
    onActivated: commit(!checkedValue)

    RowActionButton {
      icon: "undo"
      active: switchRow.dirtyValue
      revealed: switchRow.hovered
      onActivated: switchRow.commit(switchRow.baselineValue)
    }

    AdwSwitch {
      checked: switchRow.checkedValue
      onToggled: checked => switchRow.commit(checked)
    }
  }

  component SliderPreferenceRow: StyledRect {
    id: sliderRow

    required property var target
    required property string propertyName
    property string icon
    property string title
    property string description
    property bool showPrefixIcon
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property int decimals: 1
    property string suffix: ""
    readonly property real currentValue: Number(root.configValue(sliderRow.target, sliderRow.propertyName, sliderRow.from))
    readonly property bool atMinimum: sliderRow.currentValue <= sliderRow.from
    readonly property bool atMaximum: sliderRow.currentValue >= sliderRow.to
    property bool baselineReady
    property real baselineValue
    property bool editing
    property string editText: sliderRow.editableText(sliderRow.currentValue)
    readonly property bool hovered: rowHover.hovered
    readonly property string settingKey: root.keyForSetting(sliderRow.title, sliderRow.propertyName)
    readonly property bool highlighted: settingKey.length > 0 && root.highlightedSettingKey === settingKey
    readonly property string pendingKey: `number:${sliderRow.title}:${sliderRow.propertyName}:${sliderRow.description}`
    readonly property bool dirtyValue: baselineReady && Math.abs(currentValue - baselineValue) > Math.max(0.0001, stepSize / 1000)

    function commit(value: real): void {
      const rounded = sliderRow.stepSize > 0 ? Math.round(value / sliderRow.stepSize) * sliderRow.stepSize : value;
      root.writeConfig(sliderRow.target, sliderRow.propertyName, Math.max(sliderRow.from, Math.min(sliderRow.to, rounded)));
    }

    function updatePending(): void {
      if (!baselineReady)
        return;
      root.setPendingEntry(pendingKey, dirtyValue ? {
        key: pendingKey,
        title: sliderRow.title,
        description: sliderRow.description,
        valueText: `${sliderRow.formatted(baselineValue)} \u2192 ${sliderRow.formatted(currentValue)}`,
        icon: sliderRow.icon || "tag",
        pageIndex: root.pageIndexForSetting(sliderRow.title, sliderRow.propertyName),
        targetKey: sliderRow.settingKey,
        configBacked: true,
        fromValue: baselineValue,
        toValue: currentValue,
        apply: value => sliderRow.commit(Number(value)),
        revert: () => sliderRow.commit(sliderRow.baselineValue),
        accept: () => {
          sliderRow.baselineValue = sliderRow.currentValue;
          sliderRow.updatePending();
        }
      } : null);
    }

    function formatted(value: real): string {
      return value.toFixed(sliderRow.decimals) + sliderRow.suffix;
    }

    function editableText(value: real): string {
      return value.toFixed(sliderRow.decimals);
    }

    function beginEdit(): void {
      sliderRow.editText = sliderRow.editableText(sliderRow.currentValue);
      sliderRow.editing = true;
      numberEditor.forceActiveFocus();
      numberEditor.selectAll();
    }

    function cancelEdit(): void {
      sliderRow.editing = false;
      sliderRow.editText = sliderRow.editableText(sliderRow.currentValue);
    }

    function commitEdit(): void {
      if (!sliderRow.editing)
        return;

      const value = Number(numberEditor.text);
      sliderRow.editing = false;
      if (isNaN(value)) {
        sliderRow.editText = sliderRow.editableText(sliderRow.currentValue);
        return;
      }
      sliderRow.commit(value);
    }

    onCurrentValueChanged: {
      if (!editing)
        editText = editableText(currentValue);
    }

    Component.onCompleted: {
      baselineValue = currentValue;
      baselineReady = true;
      updatePending();
    }

    Component.onDestruction: root.setPendingEntry(pendingKey, null)
    onDirtyValueChanged: updatePending()

    Layout.fillWidth: true
    implicitHeight: Math.max(62, rowLayout.implicitHeight + Tokens.padding.normal * 2)
    radius: 0
    color: highlighted ? Qt.alpha(root.accent, 0.15) : "transparent"

    Behavior on color {
      CAnim {}
    }

    HoverHandler {
      id: rowHover
    }

    StyledRect {
      visible: sliderRow.dirtyValue
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      implicitWidth: 3
      color: root.warning
    }

    StyledRect {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: Tokens.padding.normal
      implicitHeight: 1
      color: Qt.alpha(Colours.palette.m3outlineVariant, 0.62)
    }

    RowLayout {
      id: rowLayout

      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.normal

      MaterialIcon {
        visible: sliderRow.showPrefixIcon && sliderRow.icon.length > 0
        text: sliderRow.icon
        color: root.accent
        font.pointSize: Tokens.font.size.normal
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        StyledText {
          Layout.fillWidth: true
          text: sliderRow.title
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.smaller
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: sliderRow.description
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.small
          maximumLineCount: 2
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        RowActionButton {
          icon: "undo"
          active: sliderRow.dirtyValue
          revealed: sliderRow.hovered || sliderRow.editing
          onActivated: sliderRow.commit(sliderRow.baselineValue)
        }

        StepperButton {
          icon: "remove"
          disabled: sliderRow.atMinimum
          leftButton: true
          onActivated: sliderRow.commit(sliderRow.currentValue - sliderRow.stepSize)
        }

        StyledRect {
          implicitWidth: Math.max(78, valueLabel.implicitWidth + Tokens.padding.normal * 2)
          implicitHeight: 34
          radius: 0
          color: Colours.palette.m3surface
          border.width: 1
          border.color: sliderRow.editing ? root.accent : Colours.palette.m3outlineVariant

          StateLayer {
            color: Colours.palette.m3onSurface
            onClicked: sliderRow.beginEdit()
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            onWheel: event => {
              const direction = event.angleDelta.y >= 0 ? 1 : -1;
              const multiplier = event.modifiers & Qt.ControlModifier ? 10 : 1;
              sliderRow.commit(sliderRow.currentValue + direction * sliderRow.stepSize * multiplier);
              event.accepted = true;
            }
          }

          StyledText {
            id: valueLabel

            visible: !sliderRow.editing
            anchors.centerIn: parent
            text: sliderRow.formatted(sliderRow.currentValue)
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.small
            font.weight: Font.DemiBold
          }

          StyledTextField {
            id: numberEditor

            visible: sliderRow.editing
            anchors.fill: parent
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            text: sliderRow.editText
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator {
              bottom: sliderRow.from
              top: sliderRow.to
              decimals: sliderRow.decimals
            }
            onTextEdited: sliderRow.editText = text
            onAccepted: sliderRow.commitEdit()
            Keys.onEscapePressed: sliderRow.cancelEdit()
            Keys.onUpPressed: sliderRow.commit(sliderRow.currentValue + sliderRow.stepSize)
            Keys.onDownPressed: sliderRow.commit(sliderRow.currentValue - sliderRow.stepSize)
            onActiveFocusChanged: {
              if (!activeFocus)
                sliderRow.commitEdit();
            }
          }
        }

        StepperButton {
          icon: "add"
          disabled: sliderRow.atMaximum
          rightButton: true
          onActivated: sliderRow.commit(sliderRow.currentValue + sliderRow.stepSize)
        }
      }
    }
  }

  component SettingSwitch: SwitchPreferenceRow {}

  component SettingSlider: SliderPreferenceRow {}

  component StepperButton: StyledRect {
    id: stepButton

    required property string icon
    property bool disabled
    property bool leftButton
    property bool rightButton
    signal activated

    implicitWidth: 34
    implicitHeight: 34
    radius: 0
    topLeftRadius: leftButton ? root.rowRadius : 0
    bottomLeftRadius: leftButton ? root.rowRadius : 0
    topRightRadius: rightButton ? root.rowRadius : 0
    bottomRightRadius: rightButton ? root.rowRadius : 0
    color: disabled ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.45) : Colours.palette.m3surfaceContainerHighest
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    opacity: disabled ? 0.55 : 1

    StateLayer {
      disabled: stepButton.disabled
      color: Colours.palette.m3onSurface
      onClicked: stepButton.activated()
    }

    MaterialIcon {
      anchors.centerIn: parent
      text: stepButton.icon
      color: stepButton.disabled ? Colours.palette.m3outline : Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
    }
  }

  component ActionPreferenceRow: PreferenceRow {
    id: actionRow

    required property string buttonText
    property var command: []

    showPrefixIcon: true
    onActivated: Quickshell.execDetached(actionRow.command)

    ActionButton {
      text: actionRow.buttonText
      command: actionRow.command
    }
  }

  component NavigationPreferenceRow: PreferenceRow {
    id: navigationRow

    required property string buttonText
    required property int pageIndex

    showPrefixIcon: true
    onActivated: root.selectPage(navigationRow.pageIndex)

    FlatButton {
      text: navigationRow.buttonText
      onClicked: root.selectPage(navigationRow.pageIndex)
    }
  }

  component EntryPreferenceRow: StyledRect {
    id: entryRow

    property string icon
    property string title
    property string text
    property string defaultText
    property string placeholderText
    property string settingKey
    readonly property bool dirtyText: editText !== text
    readonly property bool highlighted: settingKey.length > 0 && root.highlightedSettingKey === settingKey
    property string editText: text
    signal applied(string value)
    signal browseRequested

    function resetText(): void {
      editText = text;
    }

    function applyText(): void {
      const next = editText.trim().length > 0 ? editText.trim() : defaultText;
      text = next;
      editText = next;
      applied(next);
    }

    Layout.fillWidth: true
    implicitHeight: Math.max(62, rowLayout.implicitHeight + Tokens.padding.normal * 2)
    radius: 0
    color: highlighted ? Qt.alpha(root.accent, 0.15) : "transparent"

    Behavior on color {
      CAnim {}
    }

    StyledRect {
      visible: entryRow.dirtyText
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 3
      color: root.warning
    }

    StyledRect {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: Tokens.padding.normal
      implicitHeight: 1
      color: Qt.alpha(Colours.palette.m3outlineVariant, 0.62)
    }

    RowLayout {
      id: rowLayout

      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.normal

      MaterialIcon {
        visible: entryRow.icon.length > 0
        text: entryRow.icon
        color: entryRow.dirtyText ? root.warning : Colours.palette.m3outline
        font.pointSize: Tokens.font.size.normal
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        StyledText {
          Layout.fillWidth: true
          text: entryRow.title
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.smaller
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        StyledTextField {
          id: entryField

          Layout.fillWidth: true
          text: entryRow.editText
          placeholderText: entryRow.placeholderText
          inputMethodHints: Qt.ImhNoPredictiveText
          onTextEdited: entryRow.editText = text
          onAccepted: entryRow.applyText()
          Keys.onEscapePressed: entryRow.resetText()
        }
      }

      IconButton {
        id: applyEntryButton

        visible: entryRow.dirtyText
        icon: "check"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: entryRow.applyText()

        Tooltip {
          target: applyEntryButton
          text: "Apply"
        }
      }

      IconButton {
        id: browseEntryButton

        icon: "folder_open"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: entryRow.browseRequested()

        Tooltip {
          target: browseEntryButton
          text: "Browse\u2026"
        }
      }
    }
  }

  component ActionButton: StyledRect {
    id: button

    required property string text
    required property var command

    implicitWidth: label.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: implicitHeight / 2
    color: root.accent

    StateLayer {
      color: root.accentOn
      onClicked: Quickshell.execDetached(button.command)
    }

    StyledText {
      id: label

      anchors.centerIn: parent
      text: button.text
      color: root.accentOn
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
    }
  }

  component FlatButton: StyledRect {
    id: flatButton

    required property string text
    signal clicked

    implicitWidth: label.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: implicitHeight / 2
    color: Colours.palette.m3surfaceContainerHighest
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    StateLayer {
      color: Colours.palette.m3onSurface
      onClicked: flatButton.clicked()
    }

    StyledText {
      id: label

      anchors.centerIn: parent
      text: flatButton.text
      color: Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: Font.DemiBold
    }
  }

  component SuggestedButton: StyledRect {
    id: suggestedButton

    required property string text
    signal clicked

    implicitWidth: label.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: implicitHeight / 2
    color: root.accent

    StateLayer {
      color: root.accentOn
      onClicked: suggestedButton.clicked()
    }

    StyledText {
      id: label

      anchors.centerIn: parent
      text: suggestedButton.text
      color: root.accentOn
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
    }
  }

  component SaveSplitButton: Row {
    id: saveSplit

    signal saveRequested

    Layout.alignment: Qt.AlignVCenter
    spacing: Math.floor(Tokens.spacing.small / 2)

    StyledRect {
      implicitWidth: saveLabel.implicitWidth + Tokens.padding.normal * 2
      implicitHeight: 34
      radius: implicitHeight / 2
      topRightRadius: root.rowRadius / 2
      bottomRightRadius: root.rowRadius / 2
      color: root.accent

      StateLayer {
        color: root.accentOn
        rect.topRightRadius: parent.topRightRadius
        rect.bottomRightRadius: parent.bottomRightRadius
        onClicked: saveSplit.saveRequested()
      }

      StyledText {
        id: saveLabel

        anchors.centerIn: parent
        text: "Save now"
        color: root.accentOn
        font.pointSize: Tokens.font.size.small
        font.weight: Font.Bold
      }
    }

    StyledRect {
      id: saveMenuButton

      implicitWidth: implicitHeight
      implicitHeight: 34
      radius: implicitHeight / 2
      topLeftRadius: root.rowRadius / 2
      bottomLeftRadius: root.rowRadius / 2
      color: root.accent

      StateLayer {
        color: root.accentOn
        rect.topLeftRadius: parent.topLeftRadius
        rect.bottomLeftRadius: parent.bottomLeftRadius
        onClicked: saveMenu.expanded = !saveMenu.expanded
      }

      MaterialIcon {
        anchors.centerIn: parent
        text: "keyboard_arrow_down"
        color: root.accentOn
        font.pointSize: Tokens.font.size.small
        rotation: saveMenu.expanded ? 180 : 0

        Behavior on rotation {
          Anim {}
        }
      }
    }

    Menu {
      id: saveMenu

      attachTo: saveMenuButton
      attachSideX: Menu.Right
      attachSideY: Menu.Top
      thisSideX: Menu.Right
      thisSideY: Menu.Bottom
      marginY: -Tokens.spacing.small
      active: null
      items: [
        MenuItem {
          icon: "save"
          text: "Save without updating profile"
          onClicked: saveSplit.saveRequested()
        },
        MenuItem {
          icon: "add"
          text: "Save as new profile"
          onClicked: saveSplit.saveRequested()
        }
      ]
    }
  }

  component DirtyBanner: StyledRect {
    id: dirtyBanner

    readonly property bool hasPendingChanges: root.pendingCount > 0

    implicitHeight: 46
    radius: 0
    color: Colours.palette.m3surface

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        text: dirtyBanner.hasPendingChanges ? "warning" : "check_circle"
        color: dirtyBanner.hasPendingChanges ? root.warning : root.accent
        fill: dirtyBanner.hasPendingChanges ? 0 : 1
        font.pointSize: Tokens.font.size.normal
      }

      StyledText {
        Layout.fillWidth: true
        text: dirtyBanner.hasPendingChanges ? "Unsaved changes \u2014 applied live, not saved to disk" : "Changes saved to disk"
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        elide: Text.ElideRight
      }

      FlatButton {
        text: dirtyBanner.hasPendingChanges ? "Discard" : "Hide"
        onClicked: {
          if (dirtyBanner.hasPendingChanges)
            root.discardAllPending();
          else
            root.savedBannerVisible = false;
        }
      }

      SaveSplitButton {
        visible: dirtyBanner.hasPendingChanges
        onSaveRequested: root.saveAllPending()
      }
    }
  }

  component AboutTabButton: StyledRect {
    id: tab

    required property string title
    required property int index
    required property int currentIndex
    signal selected(int index)

    readonly property bool active: index === currentIndex

    Layout.fillWidth: true
    implicitHeight: 34
    radius: root.rowRadius
    color: active ? root.accent : Colours.palette.m3surfaceContainer
    border.width: active ? 0 : 1
    border.color: Colours.palette.m3outlineVariant

    StateLayer {
      color: tab.active ? root.accentOn : Colours.palette.m3onSurface
      onClicked: tab.selected(tab.index)
    }

    StyledText {
      anchors.centerIn: parent
      text: tab.title
      color: tab.active ? root.accentOn : Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: Font.Bold
    }
  }

  component InfoRow: PreferenceRow {
    required property string label
    required property string value

    title: label
    description: value
  }

  component CreditRow: PreferenceRow {
    required property string name
    required property string role

    icon: "person"
    title: name
    description: role
  }

  component ProfileDnaPreview: RowLayout {
    id: dnaPreview

    property var values: [0.74, 0.42, 0.58, 0.86, 0.35, 0.68, 0.51, 0.79, 0.46, 0.62, 0.83, 0.39, 0.71, 0.55, 0.91, 0.48]

    Layout.alignment: Qt.AlignVCenter
    spacing: 3

    Repeater {
      model: dnaPreview.values

      StyledRect {
        required property real modelData

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 8
        implicitHeight: 28
        radius: 4
        color: Qt.hsla(root.accent.hslHue, Math.max(0.22, root.accent.hslSaturation * modelData), Math.max(0.45, root.accent.hslLightness * (0.8 + modelData * 0.45)), 1)
      }
    }
  }

  component ProfileCard: StyledRect {
    id: profileCard

    required property string profileTitle
    required property string meta
    property bool activeProfile

    Layout.fillWidth: true
    implicitHeight: 74
    radius: root.groupRadius
    color: activeProfile ? Qt.alpha(root.accent, 0.06) : Colours.palette.m3surfaceContainer
    border.width: activeProfile ? 0 : 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.75)

    StyledRect {
      visible: profileCard.activeProfile
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      implicitWidth: 3
      radius: 2
      color: root.accent
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.small
      spacing: Tokens.spacing.normal

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.small

          StyledText {
            Layout.fillWidth: true
            text: profileCard.profileTitle
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.smaller
            font.weight: Font.Bold
            elide: Text.ElideRight
          }

          PendingBadge {
            visible: profileCard.activeProfile
            text: "Active"
          }
        }

        StyledText {
          Layout.fillWidth: true
          text: profileCard.meta
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      ProfileDnaPreview {}

      IconButton {
        icon: "more_vert"
        type: IconButton.Text
        padding: Tokens.padding.smaller
      }
    }
  }

  component ModePreferenceRow: PreferenceRow {
    id: modeRow

    readonly property string pendingKey: "appearance:mode"
    readonly property bool currentLight: root.activeSchemeMode === "light"
    readonly property bool savedLight: root.savedSchemeMode === "light"
    readonly property bool dirtyValue: root.savedSchemeReady && currentLight !== savedLight

    function restore(): void {
      root.previewScheme(["-m", root.savedSchemeMode]);
    }

    function updatePending(): void {
      if (!root.savedSchemeReady)
        return;
      root.setPendingEntry(pendingKey, dirtyValue ? {
        key: pendingKey,
        title: modeRow.title,
        description: modeRow.description,
        valueText: `${savedLight ? "Light" : "Dark"} \u2192 ${currentLight ? "Light" : "Dark"}`,
        icon: "dark_mode",
        pageIndex: 1,
        targetKey: "appearance.mode",
        fromValue: root.savedSchemeMode,
        toValue: root.activeSchemeMode,
        apply: value => root.previewScheme(["-m", String(value)]),
        revert: () => modeRow.restore(),
        accept: () => root.saveScheme()
      } : null);
    }

    Component.onCompleted: updatePending()
    Component.onDestruction: root.setPendingEntry(pendingKey, null)
    onDirtyValueChanged: updatePending()

    title: "Mode"
    description: "Switch the shell between light and dark palettes."
    dirty: dirtyValue
    settingKey: "appearance.mode"

    RowActionButton {
      icon: "undo"
      active: modeRow.dirtyValue
      revealed: modeRow.hovered
      onActivated: modeRow.restore()
    }

    RowLayout {
      spacing: 0

      ModeSegmentButton {
        mode: "dark"
        leftButton: true
      }

      ModeSegmentButton {
        mode: "light"
        rightButton: true
      }
    }

    Connections {
      target: root
      function onCurrentSchemeModeChanged(): void { modeRow.updatePending(); }
      function onSavedSchemeModeChanged(): void { modeRow.updatePending(); }
      function onSavedSchemeReadyChanged(): void { modeRow.updatePending(); }
    }
  }

  component ModeSegmentButton: StyledRect {
    id: segment

    required property string mode
    property bool leftButton
    property bool rightButton
    readonly property bool checked: root.activeSchemeMode === mode

    implicitWidth: Math.max(72, label.implicitWidth + Tokens.padding.normal * 2)
    implicitHeight: 34
    radius: 0
    topLeftRadius: leftButton ? root.rowRadius : 0
    bottomLeftRadius: leftButton ? root.rowRadius : 0
    topRightRadius: rightButton ? root.rowRadius : 0
    bottomRightRadius: rightButton ? root.rowRadius : 0
    color: checked ? root.accent : Colours.palette.m3surface
    border.width: 1
    border.color: checked ? root.accent : Colours.palette.m3outlineVariant

    StateLayer {
      color: segment.checked ? root.accentOn : Colours.palette.m3onSurface
      onClicked: root.previewScheme(["-m", segment.mode])
    }

    StyledText {
      id: label

      anchors.centerIn: parent
      text: segment.mode.charAt(0).toUpperCase() + segment.mode.slice(1)
      color: segment.checked ? root.accentOn : Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: Font.DemiBold
    }
  }

  component SchemePreferenceRow: PreferenceRow {
    id: schemeRow

    readonly property string pendingKey: "appearance:scheme"
    readonly property string currentLabel: `${root.activeSchemeName} / ${root.activeSchemeFlavour}`
    readonly property string savedLabel: `${root.savedSchemeName || "ryoku"} / ${root.savedSchemeFlavour || "default"}`
    readonly property bool dirtyValue: root.savedSchemeReady && (root.activeSchemeName !== root.savedSchemeName || root.activeSchemeFlavour !== root.savedSchemeFlavour)

    function restore(): void {
      root.previewScheme(["-n", root.savedSchemeName, "-f", root.savedSchemeFlavour]);
    }

    function updatePending(): void {
      if (!root.savedSchemeReady)
        return;
      root.setPendingEntry(pendingKey, dirtyValue ? {
        key: pendingKey,
        title: schemeRow.title,
        description: schemeRow.description,
        valueText: `${savedLabel} \u2192 ${currentLabel}`,
        icon: "palette",
        pageIndex: 1,
        targetKey: "appearance.scheme",
        fromValue: ({
          name: root.savedSchemeName,
          flavour: root.savedSchemeFlavour
        }),
        toValue: ({
          name: root.activeSchemeName,
          flavour: root.activeSchemeFlavour
        }),
        apply: value => root.previewScheme(["-n", value.name, "-f", value.flavour]),
        revert: () => schemeRow.restore(),
        accept: () => root.saveScheme()
      } : null);
    }

    Component.onCompleted: updatePending()
    Component.onDestruction: root.setPendingEntry(pendingKey, null)
    onDirtyValueChanged: updatePending()

    title: "Scheme"
    description: currentLabel
    dirty: dirtyValue
    settingKey: "appearance.scheme"

    RowActionButton {
      icon: "undo"
      active: schemeRow.dirtyValue
      revealed: schemeRow.hovered
      onActivated: schemeRow.restore()
    }

    RowLayout {
      spacing: Tokens.spacing.small / 2

      SchemeSwatchButton { flavour: "default"; swatch: "#f25623" }
      SchemeSwatchButton { flavour: "forest"; swatch: "#4d8b57" }
      SchemeSwatchButton { flavour: "ocean"; swatch: "#3584e4" }
      SchemeSwatchButton { flavour: "amethyst"; swatch: "#9b72d0" }
      SchemeSwatchButton { flavour: "rose"; swatch: "#d86f8d" }
      SchemeSwatchButton { flavour: "graphite"; swatch: "#8a8a8a" }
    }

    Connections {
      target: root
      function onCurrentSchemeNameChanged(): void { schemeRow.updatePending(); }
      function onCurrentSchemeFlavourChanged(): void { schemeRow.updatePending(); }
      function onSavedSchemeNameChanged(): void { schemeRow.updatePending(); }
      function onSavedSchemeFlavourChanged(): void { schemeRow.updatePending(); }
      function onSavedSchemeReadyChanged(): void { schemeRow.updatePending(); }
    }
  }

  component SchemeSwatchButton: StyledRect {
    id: swatchButton

    required property string flavour
    required property color swatch
    readonly property bool checked: root.activeSchemeFlavour === flavour

    implicitWidth: 28
    implicitHeight: 28
    radius: implicitHeight / 2
    color: "transparent"
    border.width: checked ? 2 : 1
    border.color: checked ? root.accent : Colours.palette.m3outlineVariant

    StateLayer {
      color: Colours.palette.m3onSurface
      onClicked: root.previewScheme(["-f", swatchButton.flavour])
    }

    StyledRect {
      anchors.centerIn: parent
      implicitWidth: parent.implicitWidth - 8
      implicitHeight: implicitWidth
      radius: implicitHeight / 2
      color: swatchButton.swatch
    }
  }

  component VariantPreferenceRow: PreferenceRow {
    id: variantRow

    readonly property string pendingKey: "appearance:variant"
    readonly property bool dirtyValue: root.savedSchemeReady && root.activeVariant !== root.savedVariant

    function displayVariant(variant: string): string {
      switch (variant) {
      case "tonalspot":
        return "Tonal";
      case "expressive":
        return "Expressive";
      case "vibrant":
        return "Vibrant";
      case "fidelity":
        return "Fidelity";
      case "content":
        return "Content";
      case "fruitsalad":
        return "Fruit Salad";
      case "rainbow":
        return "Rainbow";
      case "neutral":
        return "Neutral";
      case "monochrome":
        return "Monochrome";
      default:
        return variant.charAt(0).toUpperCase() + variant.slice(1);
      }
    }

    function restore(): void {
      root.previewScheme(["-v", root.savedVariant]);
    }

    function updatePending(): void {
      if (!root.savedSchemeReady)
        return;
      root.setPendingEntry(pendingKey, dirtyValue ? {
        key: pendingKey,
        title: variantRow.title,
        description: variantRow.description,
        valueText: `${displayVariant(root.savedVariant)} \u2192 ${displayVariant(root.activeVariant)}`,
        icon: "tonality",
        pageIndex: 1,
        targetKey: "appearance.variant",
        fromValue: root.savedVariant,
        toValue: root.activeVariant,
        apply: value => root.previewScheme(["-v", String(value)]),
        revert: () => variantRow.restore(),
        accept: () => root.saveScheme()
      } : null);
    }

    Component.onCompleted: updatePending()
    Component.onDestruction: root.setPendingEntry(pendingKey, null)
    onDirtyValueChanged: updatePending()

    title: "Color variant"
    description: displayVariant(root.activeVariant)
    dirty: dirtyValue
    settingKey: "appearance.variant"

    RowActionButton {
      icon: "undo"
      active: variantRow.dirtyValue
      revealed: variantRow.hovered
      onActivated: variantRow.restore()
    }

    Flow {
      id: variantFlow

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: 430
      spacing: Tokens.spacing.small / 2

      VariantPillButton { label: "Tonal"; variant: "tonalspot" }
      VariantPillButton { label: "Expressive"; variant: "expressive" }
      VariantPillButton { label: "Vibrant"; variant: "vibrant" }
      VariantPillButton { label: "Fidelity"; variant: "fidelity" }
      VariantPillButton { label: "Content"; variant: "content" }
      VariantPillButton { label: "Fruit"; variant: "fruitsalad" }
      VariantPillButton { label: "Rainbow"; variant: "rainbow" }
      VariantPillButton { label: "Neutral"; variant: "neutral" }
      VariantPillButton { label: "Mono"; variant: "monochrome" }
    }

    Connections {
      target: root
      function onCurrentVariantChanged(): void { variantRow.updatePending(); }
      function onSavedVariantChanged(): void { variantRow.updatePending(); }
      function onSavedSchemeReadyChanged(): void { variantRow.updatePending(); }
    }
  }

  component VariantPillButton: StyledRect {
    id: variantButton

    required property string label
    required property string variant
    readonly property bool checked: root.activeVariant === variant

    implicitWidth: labelText.implicitWidth + Tokens.padding.small * 2
    implicitHeight: 30
    radius: root.rowRadius
    color: checked ? root.accent : Colours.palette.m3surface
    border.width: 1
    border.color: checked ? root.accent : Colours.palette.m3outlineVariant

    StateLayer {
      color: variantButton.checked ? root.accentOn : Colours.palette.m3onSurface
      onClicked: root.previewScheme(["-v", variantButton.variant])
    }

    StyledText {
      id: labelText

      anchors.centerIn: parent
      text: variantButton.label
      color: variantButton.checked ? root.accentOn : Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: Font.DemiBold
    }
  }

  component AboutPage: SettingsPage {
    property int aboutTab: 0

    RowLayout {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      AboutTabButton {
        title: "Overview"
        index: 0
        currentIndex: aboutTab
        onSelected: index => aboutTab = index
      }

      AboutTabButton {
        title: "Credits"
        index: 1
        currentIndex: aboutTab
        onSelected: index => aboutTab = index
      }
    }

    ColumnLayout {
      visible: aboutTab === 0
      Layout.fillWidth: true
      spacing: Tokens.spacing.larger

      StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 280
        radius: root.groupRadius
        color: Colours.palette.m3surfaceContainer
        border.width: 1
        border.color: Qt.alpha(root.brandAccent, 0.45)

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Tokens.padding.large * 2, 360)
          spacing: Tokens.spacing.normal

          StyledRect {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 126
            Layout.preferredHeight: 126
            radius: root.groupRadius
            color: Qt.alpha(root.brandAccent, 0.18)

            Logo {
              anchors.centerIn: parent
              width: 96
              height: 96
            }
          }

          StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "RYOKU"
            font.pointSize: Tokens.font.size.extraLarge
            font.weight: Font.Black
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Built for the sake of power and beauty."
            wrapMode: Text.WordWrap
            font.pointSize: Tokens.font.size.smaller
            color: Colours.palette.m3outline
          }
        }
      }

      PreferenceGroup {
        title: "Build"

        InfoRow {
          icon: "tag"
          label: "Version"
          value: RyokuAbout.info.version || "unknown"
        }

        InfoRow {
          icon: "cloud_sync"
          label: "Channel"
          value: RyokuAbout.info.configuredChannelLabel || "unknown"
        }
      }

      PreferenceGroup {
        title: "Tools"
        description: "Common maintenance actions."

        ActionPreferenceRow {
          icon: "refresh"
          title: "Refresh Shell"
          description: "Restart the user shell service."
          buttonText: "Run"
          command: ["ryoku-shell", "service", "restart"]
        }

        ActionPreferenceRow {
          icon: "health_and_safety"
          title: "Doctor"
          description: "Check the live shell environment."
          buttonText: "Run"
          command: ["ryoku-doctor", "shell"]
        }

        ActionPreferenceRow {
          icon: "system_update_alt"
          title: "Check Updates"
          description: "Look for available Ryoku updates."
          buttonText: "Check"
          command: ["ryoku-settings-about", "check-updates"]
        }
      }
    }

    ColumnLayout {
      visible: aboutTab === 1
      Layout.fillWidth: true
      spacing: Tokens.spacing.larger

      PreferenceGroup {
        title: "Credits"

        CreditRow {
          name: "Ryoku"
          role: "Shell, installer, defaults, and update tooling"
        }

        CreditRow {
          name: "Quickshell"
          role: "Native QML shell runtime"
        }

        CreditRow {
          name: "Hyprland"
          role: "Wayland compositor and window management"
        }

        CreditRow {
          name: "HyprMod"
          role: "Frontend reference for the rebuilt settings surface"
        }
      }
    }
  }

  component ProfilesPage: SettingsPage {
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      ProfileCard {
        profileTitle: "Current shell profile"
        meta: `${root.pendingCount} pending change${root.pendingCount === 1 ? "" : "s"}`
        activeProfile: true
      }

      ProfileCard {
        profileTitle: "Ryoku defaults"
        meta: "Baseline shell layout and HyprMod-managed config"
      }
    }

    EmptyState {
      visible: false
      icon: "folder_managed"
      title: "No Profiles"
      description: "Save your current configuration to create one."
    }
  }

  component AppSettingsPage: SettingsPage {
    PreferenceGroup {
      title: "Configuration"
      description: "Manage where HyprMod reads and writes Hyprland settings."

      EntryPreferenceRow {
        icon: "description"
        title: "Config file path"
        text: "~/.config/hypr/hyprland-gui.conf"
        defaultText: "~/.config/hypr/hyprland-gui.conf"
        placeholderText: "~/.config/hypr/hyprland-gui.conf"
        settingKey: "settings.configPath"
        onApplied: root.markSaved()
        onBrowseRequested: Quickshell.execDetached(["xdg-open", `${Quickshell.env("HOME")}/.config/hypr`])
      }
    }

    PreferenceGroup {
      title: "Behavior"

      PreferenceRow {
        icon: "save"
        showPrefixIcon: true
        title: "Auto-save"
        description: "Automatically save changes after each modification."
        onActivated: root.toggleAutoSavePendingEdits()

        AdwSwitch {
          checked: root.autoSavePendingEdits
          onToggled: root.toggleAutoSavePendingEdits()
        }
      }
    }
  }

  component AppearancePage: SettingsPage {
    PreferenceGroup {
      title: "Theme Mode"

      ModePreferenceRow {}

      SchemePreferenceRow {}

      VariantPreferenceRow {}
    }

    PreferenceGroup {
      title: "Visual Effects"
      description: "Shared visual tokens consumed by the shell."

      SwitchPreferenceRow {
        target: GlobalConfig.appearance.transparency
        propertyName: "enabled"
        icon: "opacity"
        title: "Transparency"
        description: "Use translucent shell layers."
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.transparency
        propertyName: "base"
        icon: "layers"
        title: "Base opacity"
        description: "Controls the main layer opacity."
        from: 0.45
        to: 1
        stepSize: 0.05
        decimals: 2
      }
    }

    PreferenceGroup {
      title: "Geometry"

      SliderPreferenceRow {
        target: GlobalConfig.appearance.rounding
        propertyName: "scale"
        icon: "rounded_corner"
        title: "Rounding scale"
        description: "Adjusts shared corner radii."
        from: 0
        to: 1.6
        stepSize: 0.05
        decimals: 2
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.padding
        propertyName: "scale"
        icon: "padding"
        title: "Padding scale"
        description: "Adjusts internal control spacing."
        from: 0.7
        to: 1.5
        stepSize: 0.05
        decimals: 2
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.font.size
        propertyName: "scale"
        icon: "format_size"
        title: "Font scale"
        description: "Adjusts shell typography."
        from: 0.8
        to: 1.3
        stepSize: 0.05
        decimals: 2
      }

      SliderPreferenceRow {
        target: GlobalConfig.border
        propertyName: "thickness"
        icon: "border_outer"
        title: "Frame thickness"
        description: "Controls top-frame and side-frame thickness."
        from: 2
        to: 24
        stepSize: 1
        decimals: 0
      }
    }

    PreferenceGroup {
      title: "Desktop"

      SwitchPreferenceRow {
        target: GlobalConfig.background
        propertyName: "wallpaperEnabled"
        icon: "wallpaper"
        title: "Wallpaper"
        description: "Show the configured wallpaper behind the shell."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.background.desktopClock
        propertyName: "enabled"
        icon: "schedule"
        title: "Desktop clock"
        description: "Show the large desktop clock overlay."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.background.visualiser
        propertyName: "enabled"
        icon: "graphic_eq"
        title: "Audio visualiser"
        description: "Show the wallpaper visualiser."
      }
    }
  }

  component BarPage: SettingsPage {
    PreferenceGroup {
      title: "Taskbar"
      description: "Persistent frame bar and workspace controls."

      SwitchPreferenceRow {
        target: GlobalConfig.bar
        propertyName: "persistent"
        icon: "keep"
        title: "Persistent bar"
        description: "Reserve frame space for the bar."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.bar
        propertyName: "showOnHover"
        icon: "ads_click"
        title: "Show on hover"
        description: "Reveal the bar when the pointer reaches the frame."
      }

      SliderPreferenceRow {
        target: GlobalConfig.bar.workspaces
        propertyName: "shown"
        icon: "view_week"
        title: "Visible workspaces"
        description: "Workspace buttons shown in the bar."
        from: 1
        to: 10
        stepSize: 1
        decimals: 0
      }

      SwitchPreferenceRow {
        target: GlobalConfig.bar.workspaces
        propertyName: "activeIndicator"
        icon: "radio_button_checked"
        title: "Active indicator"
        description: "Show a filled marker for the active workspace."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.bar.workspaces
        propertyName: "occupiedBg"
        icon: "space_dashboard"
        title: "Occupied background"
        description: "Highlight workspaces with windows."
      }
    }

    PreferenceGroup {
      title: "Status Icons"

      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showNetwork"; icon: "lan"; title: "Network"; description: "Show network status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showWifi"; icon: "wifi"; title: "Wi-Fi"; description: "Show Wi-Fi status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showBluetooth"; icon: "bluetooth"; title: "Bluetooth"; description: "Show Bluetooth status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showBattery"; icon: "battery_full"; title: "Battery"; description: "Show battery status." }
    }
  }

  component LauncherPage: SettingsPage {
    PreferenceGroup {
      title: "Behavior"

      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "enabled"; icon: "toggle_on"; title: "Enabled"; description: "Allow the launcher drawer to open." }
      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "showOnHover"; icon: "ads_click"; title: "Show on hover"; description: "Reveal launcher from the lower frame." }
      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "vimKeybinds"; icon: "keyboard"; title: "Vim keybinds"; description: "Use vim-style movement in launcher lists." }
      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "enableDangerousActions"; icon: "warning"; title: "Dangerous actions"; description: "Show power actions in launcher results." }
    }

    PreferenceGroup {
      title: "Results"

      SliderPreferenceRow { target: GlobalConfig.launcher; propertyName: "maxShown"; icon: "format_list_numbered"; title: "Max results"; description: "Normal results shown at once."; from: 3; to: 14; stepSize: 1; decimals: 0 }
      SliderPreferenceRow { target: GlobalConfig.launcher; propertyName: "maxWallpapers"; icon: "image"; title: "Wallpaper results"; description: "Wallpaper previews shown."; from: 3; to: 18; stepSize: 1; decimals: 0 }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "apps"; icon: "apps"; title: "Apps"; description: "Use fuzzy matching for applications." }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "actions"; icon: "bolt"; title: "Actions"; description: "Use fuzzy matching for launcher actions." }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "wallpapers"; icon: "wallpaper"; title: "Wallpapers"; description: "Use fuzzy matching for wallpapers." }
    }
  }

  component DashboardPage: SettingsPage {
    PreferenceGroup {
      title: "Tabs"

      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "enabled"; icon: "toggle_on"; title: "Enabled"; description: "Allow dashboard to open." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showOnHover"; icon: "ads_click"; title: "Show on hover"; description: "Open dashboard from the top frame." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showDashboard"; icon: "home"; title: "Home tab"; description: "Show the main dashboard tab." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showMedia"; icon: "music_note"; title: "Media tab"; description: "Show media controls." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showPerformance"; icon: "monitoring"; title: "Performance tab"; description: "Show system telemetry." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showWeather"; icon: "partly_cloudy_day"; title: "Weather tab"; description: "Show weather summary." }
    }

    PreferenceGroup {
      title: "Performance"

      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showCpu"; icon: "memory"; title: "CPU"; description: "Show CPU usage." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showGpu"; icon: "developer_board"; title: "GPU"; description: "Show GPU usage when available." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showMemory"; icon: "memory_alt"; title: "Memory"; description: "Show memory usage." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showStorage"; icon: "hard_drive"; title: "Storage"; description: "Show storage usage." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showNetwork"; icon: "network_check"; title: "Network"; description: "Show network throughput." }
    }
  }

  component NotificationsPage: SettingsPage {
    PreferenceGroup {
      title: "Notification Behavior"

      SwitchPreferenceRow { target: GlobalConfig.notifs; propertyName: "expire"; icon: "timer"; title: "Auto expire"; description: "Automatically dismiss normal notifications." }
      SwitchPreferenceRow { target: GlobalConfig.notifs; propertyName: "actionOnClick"; icon: "touch_app"; title: "Click primary action"; description: "Trigger the primary action when clicking a notification." }
      SwitchPreferenceRow { target: GlobalConfig.notifs; propertyName: "openExpanded"; icon: "unfold_more"; title: "Open expanded"; description: "Show new notification groups expanded." }
    }

    PreferenceGroup {
      title: "Timing"

      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "defaultExpireTimeout"; icon: "timer"; title: "Default timeout"; description: "Normal notification lifetime."; from: 1000; to: 12000; stepSize: 500; decimals: 0; suffix: "ms" }
      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "fullscreenExpireTimeout"; icon: "fullscreen"; title: "Fullscreen timeout"; description: "Notification lifetime while fullscreen."; from: 500; to: 8000; stepSize: 500; decimals: 0; suffix: "ms" }
      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "groupPreviewNum"; icon: "stacks"; title: "Group preview count"; description: "Notifications shown before collapse."; from: 1; to: 8; stepSize: 1; decimals: 0 }
    }
  }

  component SystemPage: SettingsPage {
    PreferenceGroup {
      title: "OSD"

      SwitchPreferenceRow { target: GlobalConfig.osd; propertyName: "enabled"; icon: "display_settings"; title: "Enabled"; description: "Show brightness, volume, and status overlays." }
      SwitchPreferenceRow { target: GlobalConfig.osd; propertyName: "enableBrightness"; icon: "brightness_medium"; title: "Brightness"; description: "Show brightness changes in the OSD." }
      SwitchPreferenceRow { target: GlobalConfig.osd; propertyName: "enableMicrophone"; icon: "mic"; title: "Microphone"; description: "Show microphone changes in the OSD." }
      SliderPreferenceRow { target: GlobalConfig.osd; propertyName: "hideDelay"; icon: "hourglass"; title: "Hide delay"; description: "How long OSD remains visible."; from: 500; to: 6000; stepSize: 250; decimals: 0; suffix: "ms" }
    }

    PreferenceGroup {
      title: "Services"

      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "smartScheme"; icon: "auto_awesome"; title: "Smart scheme"; description: "Adjust schemes from wallpaper context." }
      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "useTwelveHourClock"; icon: "schedule"; title: "12-hour clock"; description: "Use AM/PM time format." }
      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "showLyrics"; icon: "lyrics"; title: "Lyrics"; description: "Enable lyrics service integration." }
      SliderPreferenceRow { target: GlobalConfig.services; propertyName: "audioIncrement"; icon: "volume_up"; title: "Audio step"; description: "Volume change amount per step."; from: 0.02; to: 0.25; stepSize: 0.01; decimals: 2 }
      SliderPreferenceRow { target: GlobalConfig.services; propertyName: "brightnessIncrement"; icon: "brightness_medium"; title: "Brightness step"; description: "Brightness change amount per step."; from: 0.02; to: 0.25; stepSize: 0.01; decimals: 2 }
    }

    PreferenceGroup {
      title: "Idle"

      SwitchPreferenceRow { target: GlobalConfig.general.idle; propertyName: "lockBeforeSleep"; icon: "lock"; title: "Lock before sleep"; description: "Lock the session before suspend actions." }
      SwitchPreferenceRow { target: GlobalConfig.general.idle; propertyName: "inhibitWhenAudio"; icon: "music_note"; title: "Inhibit during audio"; description: "Do not trigger idle actions while media is playing." }
    }
  }

  component HyprlandPage: SettingsPage {
    PreferenceGroup {
      title: "HyprMod"
      description: "Ryoku delegates compositor-specific editing to HyprMod and keeps shell controls here."

      ActionPreferenceRow {
        icon: "window"
        title: "Open HyprMod"
        description: "Configure Hyprland through the native HyprMod app."
        buttonText: "Open"
        command: ["ryoku-launch-hyprmod"]
      }

      ActionPreferenceRow {
        icon: "sync"
        title: "Reload Hyprland"
        description: "Apply compositor config changes."
        buttonText: "Reload"
        command: ["hyprctl", "reload"]
      }
    }

    PreferenceGroup {
      title: "Shell edits"
      description: "Ryoku shell settings stay in this HyprMod-style surface and live-preview through shared shell config."

      NavigationPreferenceRow {
        icon: "palette"
        title: "Appearance"
        description: "Theme, scheme, transparency, geometry, and desktop visuals."
        settingKey: "hyprland.shell_edits"
        buttonText: "Open"
        pageIndex: 1
      }

      NavigationPreferenceRow {
        icon: "dock_to_left"
        title: "Taskbar"
        description: "Frame, workspaces, tray, clock, and status indicators."
        buttonText: "Open"
        pageIndex: 2
      }

      NavigationPreferenceRow {
        icon: "dashboard"
        title: "Dashboard"
        description: "Top-frame tabs, media, weather, and performance modules."
        buttonText: "Open"
        pageIndex: 4
      }
    }
  }
}
