pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.images
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
  readonly property real radiusScale: Math.max(0, Math.min(1.6, Tokens.rounding.scale))
  readonly property real windowRadius: Math.max(0, Math.min(26, 16 * root.radiusScale))
  readonly property real groupRadius: Math.max(0, Math.min(20, 12 * root.radiusScale))
  readonly property real rowRadius: Math.max(0, Math.min(16, 10 * root.radiusScale))
  readonly property int sidebarWidth: 268
  readonly property int headerHeight: 48
  readonly property int contentMaxWidth: 800
  readonly property int rowActionSize: 24
  readonly property int spinControlHeight: 34
  readonly property int hyprmodDefaultWidth: 900
  readonly property int hyprmodDefaultHeight: 650
  readonly property int hyprmodPageVerticalMargin: 24
  readonly property int hyprmodPageHorizontalMargin: 12
  readonly property int hyprmodPageSpacing: 24
  readonly property string ryokuBridge: Paths.ryokuBridge
  readonly property string profileCommand: Paths.toLocalFile(Quickshell.shellPath("scripts/ryoku-shell-profile"))
  readonly property string reloadHyprlandCommand: Paths.toLocalFile(Quickshell.shellPath("scripts/ryoku-reload-hyprland"))
  readonly property string ryokuConfigDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`}/ryoku`
  readonly property string hyprConfigDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`}/hypr`
  readonly property string shellConfigPath: `${root.ryokuConfigDir}/shell.json`

  function openPath(path: string): void {
    Quickshell.execDetached(["xdg-open", path]);
  }
  readonly property color brandAccent: "#F25623"
  readonly property color accent: Colours.palette.m3primary
  readonly property color accentOn: Colours.palette.m3onPrimary
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
      id: "island",
      icon: "graphic_eq",
      title: "Island",
      subtitle: "Top-frame media island, hover, gesture, and audio bars."
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
    { pageIndex: 0, title: "Check for updates", description: "About > Updates", key: "about.updates", text: "update channel stable unstable incoming commits version upgrade" },
    { pageIndex: 0, title: "Release channel", description: "About > Updates", key: "about.channel", text: "stable main unstable dev channel switch" },
    { pageIndex: 0, title: "Credits", description: "About > Credits", key: "about.credits", text: "omarchy caelestia activspot hyprmod qylock quickshell hyprland repository" },
    { pageIndex: 1, title: "Mode", description: "Appearance > Theme Mode", key: "appearance.mode", text: "dark light theme palette" },
    { pageIndex: 1, title: "Scheme", description: "Appearance > Theme Mode", key: "appearance.scheme", text: "colour color swatch default forest ocean amethyst rose graphite" },
    { pageIndex: 1, title: "Color variant", description: "Appearance > Theme Mode", key: "appearance.variant", text: "tonal expressive vibrant fidelity content fruitsalad rainbow neutral monochrome" },
    { pageIndex: 1, title: "Transparency", description: "Appearance > Visual Effects", key: "appearance.transparency.enabled", text: "translucent shell layers" },
    { pageIndex: 1, title: "Base opacity", description: "Appearance > Visual Effects", key: "appearance.transparency.base", text: "opacity alpha transparent" },
    { pageIndex: 1, title: "Rounding scale", description: "Appearance > Geometry", key: "appearance.rounding.scale", text: "corner radius" },
    { pageIndex: 1, title: "Padding scale", description: "Appearance > Geometry", key: "appearance.padding.scale", text: "spacing density" },
    { pageIndex: 1, title: "Font scale", description: "Appearance > Geometry", key: "appearance.font.size.scale", text: "typography size" },
    { pageIndex: 1, title: "Frame thickness", description: "Appearance > Geometry", key: "border.thickness", text: "top frame side frame border" },
    { pageIndex: 1, title: "Wallpaper", description: "Appearance > Desktop", key: "background.wallpaperEnabled", text: "desktop background" },
    { pageIndex: 1, title: "Wallpaper folder", description: "Appearance > Wallpapers", key: "paths.wallpaperDir", text: "wallpaper path directory previews images" },
    { pageIndex: 1, title: "Wallpaper previews", description: "Appearance > Wallpapers", key: "wallpapers.preview", text: "wallpaper thumbnails apply preview" },
    { pageIndex: 1, title: "Desktop clock", description: "Appearance > Desktop", key: "background.desktopClock.enabled", text: "large overlay clock" },
    { pageIndex: 1, title: "Audio visualiser", description: "Appearance > Desktop", key: "background.visualiser.enabled", text: "wallpaper cava visualizer" },
    { pageIndex: 2, title: "Persistent bar", description: "Taskbar > General", key: "bar.persistent", text: "always visible frame dock" },
    { pageIndex: 2, title: "Show on hover", description: "Taskbar > General", key: "bar.showOnHover", text: "reveal frame" },
    { pageIndex: 2, title: "Visible workspaces", description: "Taskbar > Workspaces", key: "bar.workspaces.shown", text: "workspace buttons" },
    { pageIndex: 2, title: "Active indicator", description: "Taskbar > Workspaces", key: "bar.workspaces.activeIndicator", text: "current workspace" },
    { pageIndex: 2, title: "Occupied background", description: "Taskbar > Workspaces", key: "bar.workspaces.occupiedBg", text: "workspace highlight windows" },
    { pageIndex: 2, title: "Workspace windows", description: "Taskbar > Workspaces", key: "bar.workspaces.showWindows", text: "window icons" },
    { pageIndex: 2, title: "Max window icons", description: "Taskbar > Workspaces", key: "bar.workspaces.maxWindowIcons", text: "workspace window icon count" },
    { pageIndex: 2, title: "Popout on hover", description: "Taskbar > Active Window", key: "bar.activeWindow.showOnHover", text: "active window details hover" },
    { pageIndex: 2, title: "Compact title", description: "Taskbar > Active Window", key: "bar.activeWindow.compact", text: "active window compact label" },
    { pageIndex: 2, title: "Invert title", description: "Taskbar > Active Window", key: "bar.activeWindow.inverted", text: "active window vertical text" },
    { pageIndex: 2, title: "Tray compact", description: "Taskbar > Tray", key: "bar.tray.compact", text: "system tray icons collapse" },
    { pageIndex: 2, title: "Tray background", description: "Taskbar > Tray", key: "bar.tray.background", text: "system tray background" },
    { pageIndex: 2, title: "Recolour tray", description: "Taskbar > Tray", key: "bar.tray.recolour", text: "system tray icons tint" },
    { pageIndex: 2, title: "Clock date", description: "Taskbar > Clock", key: "bar.clock.showDate", text: "time date" },
    { pageIndex: 2, title: "Clock icon", description: "Taskbar > Clock", key: "bar.clock.showIcon", text: "time icon" },
    { pageIndex: 2, title: "Clock background", description: "Taskbar > Clock", key: "bar.clock.background", text: "time date background" },
    { pageIndex: 2, title: "Audio", description: "Taskbar > Status", key: "bar.status.showAudio", text: "volume status" },
    { pageIndex: 2, title: "Microphone", description: "Taskbar > Status", key: "bar.status.showMicrophone", text: "mic status" },
    { pageIndex: 2, title: "Keyboard layout", description: "Taskbar > Status", key: "bar.status.showKbLayout", text: "keyboard layout status" },
    { pageIndex: 2, title: "Network", description: "Taskbar > Status", key: "bar.status.showNetwork", text: "lan wifi bluetooth battery status" },
    { pageIndex: 2, title: "Lock status", description: "Taskbar > Status", key: "bar.status.showLockStatus", text: "caps lock num lock" },
    { pageIndex: 3, title: "Launcher enabled", description: "Launcher > General", key: "launcher.enabled", text: "app search drawer" },
    { pageIndex: 3, title: "Show on hover", description: "Launcher > General", key: "launcher.showOnHover", text: "lower frame reveal" },
    { pageIndex: 3, title: "Vim keybinds", description: "Launcher > General", key: "launcher.vimKeybinds", text: "keyboard navigation" },
    { pageIndex: 3, title: "Dangerous actions", description: "Launcher > General", key: "launcher.enableDangerousActions", text: "power results" },
    { pageIndex: 3, title: "Maximum results", description: "Launcher > Results", key: "launcher.maxShown", text: "shown item count" },
    { pageIndex: 3, title: "Maximum wallpapers", description: "Launcher > Results", key: "launcher.maxWallpapers", text: "wallpaper results" },
    { pageIndex: 3, title: "Fuzzy apps", description: "Launcher > Fuzzy Matching", key: "launcher.useFuzzy.apps", text: "apps search matching" },
    { pageIndex: 3, title: "Fuzzy actions", description: "Launcher > Fuzzy Matching", key: "launcher.useFuzzy.actions", text: "actions search matching" },
    { pageIndex: 3, title: "Fuzzy schemes", description: "Launcher > Fuzzy Matching", key: "launcher.useFuzzy.schemes", text: "scheme search matching" },
    { pageIndex: 3, title: "Fuzzy variants", description: "Launcher > Fuzzy Matching", key: "launcher.useFuzzy.variants", text: "variant color search matching" },
    { pageIndex: 3, title: "Fuzzy wallpapers", description: "Launcher > Fuzzy Matching", key: "launcher.useFuzzy.wallpapers", text: "wallpaper search matching" },
    { pageIndex: 4, title: "Island enabled", description: "Island > General", key: "dashboard.enabled", text: "top frame media island" },
    { pageIndex: 4, title: "Show on hover", description: "Island > General", key: "dashboard.showOnHover", text: "reveal island hover top frame" },
    { pageIndex: 4, title: "Drag threshold", description: "Island > Gesture", key: "dashboard.dragThreshold", text: "touchscreen drag gesture distance" },
    { pageIndex: 4, title: "Audio bars", description: "Island > Visuals", key: "island.audioBars", text: "cava visualizer media audio bars" },
    { pageIndex: 5, title: "Auto expire", description: "Notifications > Behaviour", key: "notifs.expire", text: "dismiss notifications timeout" },
    { pageIndex: 5, title: "Click primary action", description: "Notifications > Behaviour", key: "notifs.actionOnClick", text: "notification click action" },
    { pageIndex: 5, title: "Open expanded", description: "Notifications > Behaviour", key: "notifs.openExpanded", text: "notification group expand" },
    { pageIndex: 5, title: "Default timeout", description: "Notifications > Timing", key: "notifs.defaultExpireTimeout", text: "lifetime delay" },
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
    { pageIndex: 1, title: "Spacing scale", description: "Appearance > Geometry", key: "appearance.spacing.scale", text: "gaps density spacing" },
    { pageIndex: 1, title: "Frame corner radius", description: "Appearance > Geometry", key: "border.rounding", text: "inner corner roundness frame radius" },
    { pageIndex: 1, title: "Corner smoothing", description: "Appearance > Geometry", key: "border.smoothing", text: "squircle smoothing corners" },
    { pageIndex: 1, title: "Squircle deform", description: "Appearance > Geometry", key: "appearance.deformScale", text: "squircle deform rounded" },
    { pageIndex: 1, title: "Animation duration", description: "Appearance > Motion", key: "appearance.anim.durations.scale", text: "animation speed motion timing snappy" },
    { pageIndex: 1, title: "Layer tint", description: "Appearance > Visual Effects", key: "appearance.transparency.layers", text: "translucent overlay tint opacity" },
    { pageIndex: 1, title: "Clock scale", description: "Appearance > Desktop", key: "background.desktopClock.scale", text: "desktop clock size" },
    { pageIndex: 1, title: "Clock shadow", description: "Appearance > Desktop", key: "background.desktopClock.shadow.enabled", text: "desktop clock shadow" },
    { pageIndex: 2, title: "Per-monitor workspaces", description: "Taskbar > Workspaces", key: "bar.workspaces.perMonitorWorkspaces", text: "per monitor workspaces" },
    { pageIndex: 4, title: "Dashboard", description: "Island > Modules", key: "dashboard.showDashboard", text: "dashboard panel" },
    { pageIndex: 4, title: "Resource poll", description: "Island > Refresh rates", key: "dashboard.resourceUpdateInterval", text: "performance refresh interval" },
    { pageIndex: 5, title: "Toasts", description: "Notifications > Toasts", key: "utilities.enabled", text: "toast popups status events now playing game mode" },
    { pageIndex: 6, title: "Weather location", description: "System > Weather", key: "services.weatherLocation", text: "weather city location fahrenheit celsius" },
    { pageIndex: 6, title: "Maximum volume", description: "System > Audio & Media", key: "services.maxVolume", text: "volume ceiling overamplify" },
    { pageIndex: 6, title: "Default media player", description: "System > Audio & Media", key: "services.defaultPlayer", text: "mpris player spotify media" },
    { pageIndex: 6, title: "Session menu", description: "System > Session", key: "session.enabled", text: "power menu logout shutdown session" },
    { pageIndex: 6, title: "Fingerprint unlock", description: "System > Lock screen", key: "lock.enableFprint", text: "lock screen fingerprint unlock notifications" },
    { pageIndex: 6, title: "Show over fullscreen", description: "System > General", key: "general.showOverFullscreen", text: "fullscreen shell overlay" },
    { pageIndex: 6, title: "Critical battery", description: "System > General", key: "general.battery.criticalLevel", text: "battery critical warning percent" },
    { pageIndex: 7, title: "Open HyprMod", description: "Hyprland > HyprMod", key: "hyprland.hyprmod", text: "advanced compositor settings" },
    { pageIndex: 7, title: "Reload Hyprland", description: "Hyprland > HyprMod", key: "hyprland.reload", text: "apply compositor config" },
    { pageIndex: 7, title: "Shell edits", description: "Hyprland > Shell edits", key: "hyprland.shell_edits", text: "ryoku shell appearance taskbar island settings" },
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
  property var profileEntries: []
  property string profileActionKind: ""
  property string pendingProfileName: ""

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

  function profileSnapshotName(): string {
    const now = new Date();
    const pad = value => value < 10 ? `0${value}` : String(value);
    return `Shell ${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
  }

  function loadProfilesText(data: string): void {
    const trimmed = data.trim();
    if (!trimmed) {
      root.profileEntries = [];
      return;
    }

    try {
      root.profileEntries = JSON.parse(trimmed);
    } catch (error) {
      console.warn("Failed to parse shell profiles: " + error);
      root.profileEntries = [];
    }
  }

  function refreshProfiles(): void {
    root.startProcess(profileListProcess, [root.profileCommand, "list", "--json"]);
  }

  function runProfileAction(kind: string, args): void {
    root.profileActionKind = kind;
    root.startProcess(profileActionProcess, [root.profileCommand, ...args]);
  }

  function saveCurrentShellProfile(name: string): void {
    root.pendingProfileName = name.length > 0 ? name : root.profileSnapshotName();
    if (root.pendingCount > 0)
      root.saveAllPending();
    else
      GlobalConfig.save();
    profileSaveTimer.restart();
  }

  function applyShellProfile(id: string): void {
    if (id.length > 0)
      root.runProfileAction("apply", ["apply", id]);
  }

  function deleteShellProfile(id: string): void {
    if (id.length > 0)
      root.runProfileAction("delete", ["delete", id]);
  }

  function renameShellProfile(id: string, name: string): void {
    const trimmed = name.trim();
    if (id.length > 0 && trimmed.length > 0)
      root.runProfileAction("rename", ["rename", id, trimmed]);
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
    root.refreshProfiles();
  }

  Component.onDestruction: root.setShellConfigAutoSaveSuspended(false)

  onConfigPendingCountChanged: finishShellConfigEditSessionIfClean()
  onCurrentPageChanged: {
    if (currentPage === 8)
      root.refreshProfiles();
  }
  onPendingCountChanged: scheduleAutoSaveIfEnabled()
  onContentPageIndexChanged: pageStackFade.restart()
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

  Timer {
    id: profileSaveTimer

    interval: 650
    onTriggered: root.runProfileAction("save", ["save", root.pendingProfileName])
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

  Process {
    id: profileListProcess

    command: [root.profileCommand, "list", "--json"]
    stdout: StdioCollector {
      onStreamFinished: root.loadProfilesText(text)
    }
  }

  Process {
    id: profileActionProcess

    command: []
    onExited: code => {
      if (code !== 0)
        return;
      if (root.profileActionKind === "apply") {
        GlobalConfig.reload();
        root.refreshSchemeState();
      }
      root.refreshProfiles();
      root.markSaved();
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
            title: "Ryoku"
            brandMark: true
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
          id: pageStack

          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: root.contentPageIndex
          opacity: 1

          AboutPage {}
          AppearancePage {}
          BarPage {}
          LauncherPage {}
          IslandPage {}
          NotificationsPage {}
          SystemPage {}
          HyprlandPage {}
          ProfilesPage {}
          AppSettingsPage {}
          SearchPage {}
          PendingChangesPage {}
        }

        NumberAnimation {
          id: pageStackFade

          target: pageStack
          property: "opacity"
          from: 0
          to: 1
          duration: 150
          easing.type: Easing.InOutQuad
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
    property bool brandMark

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
        onClicked: root.saveCurrentShellProfile(root.profileSnapshotName())

        Tooltip {
          target: profileSaveButton
          text: "Save current as new profile"
        }
      }

      StyledRect {
        visible: header.brandMark
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 28
        implicitHeight: 28
        radius: Math.max(7, root.rowRadius / 1.4)
        color: Qt.alpha(root.brandAccent, 0.16)

        Logo {
          anchors.centerIn: parent
          width: 20
          height: 20
        }
      }

      ColumnLayout {
        visible: !header.centerTitle
        Layout.fillWidth: true
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: header.title
          color: header.brandMark ? root.brandAccent : Colours.palette.m3onSurface
          font.pointSize: header.brandMark ? Tokens.font.size.normal : Tokens.font.size.smaller
          font.weight: Font.Black
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
          icon: "window"
          text: "Open HyprMod"
          separatorBefore: true
          onClicked: Quickshell.execDetached(["ryoku-launch-hyprmod"])
        },
        MenuItem {
          icon: "sync"
          text: "Reload Hyprland"
          onClicked: Quickshell.execDetached([root.reloadHyprlandCommand])
        },
        MenuItem {
          icon: "refresh"
          text: "Refresh Shell"
          onClicked: Quickshell.execDetached([RyokuAbout.helper, "refresh-shell"])
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
          text: "About Ryoku"
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
      Layout.leftMargin: 14
      Layout.rightMargin: 14
      Layout.topMargin: 12
      Layout.bottomMargin: 4
      text: category.section.title.toUpperCase()
      color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55)
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

    implicitHeight: 36
    radius: root.rowRadius
    color: selected ? Colours.palette.m3surfaceContainerHigh : "transparent"

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
    spacing: 8

    ColumnLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 12
      Layout.rightMargin: 12
      spacing: 2

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
      color: Colours.palette.m3surfaceContainerLow
      border.width: 1
      border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
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

  component ActiveBadge: StyledRect {
    id: activeBadge

    required property string text

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: activeBadgeLabel.implicitWidth + 20
    implicitHeight: 24
    radius: implicitHeight / 2
    color: Qt.alpha(root.accent, 0.25)

    StyledText {
      id: activeBadgeLabel

      anchors.centerIn: parent
      text: activeBadge.text
      color: root.accent
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
    implicitWidth: root.rowActionSize
    implicitHeight: root.rowActionSize
    radius: Math.max(4, root.rowRadius / 2)
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
    property string targetKey
    property int targetPageIndex: -1
    readonly property bool checkedValue: !!root.configValue(switchRow.target, switchRow.propertyName, false)
    readonly property string settingKeyValue: targetKey.length > 0 ? targetKey : root.keyForSetting(switchRow.title, switchRow.propertyName)
    readonly property int settingPageIndex: targetPageIndex >= 0 ? targetPageIndex : root.pageIndexForSetting(switchRow.title, switchRow.propertyName)
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
        pageIndex: switchRow.settingPageIndex,
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
    property string targetKey
    property int targetPageIndex: -1
    readonly property real currentValue: Number(root.configValue(sliderRow.target, sliderRow.propertyName, sliderRow.from))
    readonly property bool atMinimum: sliderRow.currentValue <= sliderRow.from
    readonly property bool atMaximum: sliderRow.currentValue >= sliderRow.to
    property bool baselineReady
    property real baselineValue
    property bool editing
    property real editStartValue
    property string editText: sliderRow.editableText(sliderRow.currentValue)
    readonly property bool hovered: rowHover.hovered
    readonly property string settingKey: targetKey.length > 0 ? targetKey : root.keyForSetting(sliderRow.title, sliderRow.propertyName)
    readonly property int settingPageIndex: targetPageIndex >= 0 ? targetPageIndex : root.pageIndexForSetting(sliderRow.title, sliderRow.propertyName)
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
        pageIndex: sliderRow.settingPageIndex,
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
      sliderRow.editStartValue = sliderRow.currentValue;
      sliderRow.editText = sliderRow.editableText(sliderRow.currentValue);
      sliderRow.editing = true;
      Qt.callLater(() => {
        numberEditor.forceActiveFocus();
        numberEditor.selectAll();
      });
    }

    function cancelEdit(): void {
      const previous = sliderRow.editStartValue;
      sliderRow.editing = false;
      sliderRow.editText = sliderRow.editableText(previous);
      sliderRow.commit(previous);
    }

    function commitEdit(): void {
      if (!sliderRow.editing)
        return;

      const value = Number(numberEditor.text);
      sliderRow.editing = false;
      if (isNaN(value)) {
        sliderRow.editText = sliderRow.editableText(sliderRow.editStartValue);
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
        spacing: Tokens.spacing.small / 2

        RowActionButton {
          icon: "undo"
          active: sliderRow.dirtyValue || sliderRow.editing
          revealed: sliderRow.hovered || sliderRow.editing
          tooltipText: sliderRow.editing ? "Cancel edit" : "Discard changes"
          onActivated: {
            if (sliderRow.editing)
              sliderRow.cancelEdit();
            else
              sliderRow.commit(sliderRow.baselineValue);
          }
        }

        StyledRect {
          id: spinBox

          implicitWidth: Math.max(132, valueLabel.implicitWidth + 92)
          implicitHeight: root.spinControlHeight
          radius: Math.max(8, root.rowRadius / 1.4)
          color: Colours.palette.m3surface
          border.width: 1
          border.color: sliderRow.editing ? root.accent : Colours.palette.m3outlineVariant
          clip: true

          RowLayout {
            anchors.fill: parent
            spacing: 0

            StepperButton {
              icon: "remove"
              disabled: sliderRow.atMinimum
              onActivated: sliderRow.commit(sliderRow.currentValue - sliderRow.stepSize)
            }

            StyledRect {
              Layout.fillHeight: true
              implicitWidth: 1
              color: Qt.alpha(Colours.palette.m3outlineVariant, 0.75)
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

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

            StyledRect {
              Layout.fillHeight: true
              implicitWidth: 1
              color: Qt.alpha(Colours.palette.m3outlineVariant, 0.75)
            }

            StepperButton {
              icon: "add"
              disabled: sliderRow.atMaximum
              onActivated: sliderRow.commit(sliderRow.currentValue + sliderRow.stepSize)
            }
          }
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
    signal activated

    Layout.fillHeight: true
    Layout.preferredWidth: 38
    implicitWidth: 38
    radius: 0
    color: "transparent"

    StateLayer {
      disabled: stepButton.disabled
      color: Colours.palette.m3onSurface
      onClicked: stepButton.activated()
    }

    MaterialIcon {
      anchors.centerIn: parent
      text: stepButton.icon
      color: stepButton.disabled ? Qt.alpha(Colours.palette.m3outline, 0.6) : Colours.palette.m3onSurfaceVariant
      font.pointSize: Tokens.font.size.normal
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
    property bool managedText
    property bool readOnly
    readonly property bool dirtyText: !readOnly && editText !== text
    readonly property bool highlighted: settingKey.length > 0 && root.highlightedSettingKey === settingKey
    property string editText: text
    signal applied(string value)
    signal browseRequested

    function resetText(): void {
      editText = text;
    }

    function applyText(): void {
      const next = editText.trim().length > 0 ? editText.trim() : defaultText;
      editText = next;
      if (!managedText)
        text = next;
      applied(next);
    }

    onTextChanged: editText = text

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
          readOnly: entryRow.readOnly
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
    signal saveProfileRequested

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
          onClicked: saveSplit.saveProfileRequested()
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
        onSaveProfileRequested: root.saveCurrentShellProfile(root.profileSnapshotName())
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

  component CreditTile: StyledRect {
    id: creditTile

    required property string name
    required property string role
    required property string url
    property string repoLabel: ""
    property string mark: name.length > 0 ? name.charAt(0).toUpperCase() : "?"
    property color tileAccent: root.accent

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Math.max(122, tileColumn.implicitHeight + Tokens.padding.large * 2)
    radius: root.groupRadius
    color: tileHover.hovered ? Colours.palette.m3surfaceContainer : Colours.palette.m3surfaceContainerLow
    border.width: 1
    border.color: tileHover.hovered ? Qt.alpha(creditTile.tileAccent, 0.6) : Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
    clip: true

    Behavior on color {
      CAnim {}
    }

    HoverHandler {
      id: tileHover
    }

    StateLayer {
      color: Colours.palette.m3onSurface
      onClicked: RyokuAbout.openUrl(creditTile.url)
    }

    ColumnLayout {
      id: tileColumn

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Tokens.padding.large
      anchors.rightMargin: Tokens.padding.large
      anchors.topMargin: Tokens.padding.large
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledRect {
          Layout.alignment: Qt.AlignTop
          implicitWidth: 40
          implicitHeight: 40
          radius: Math.max(10, root.rowRadius)
          color: Qt.alpha(creditTile.tileAccent, 0.16)

          StyledText {
            anchors.centerIn: parent
            text: creditTile.mark
            color: creditTile.tileAccent
            font.pointSize: Tokens.font.size.large
            font.weight: Font.Black
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: creditTile.name
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.normal
            font.weight: Font.Bold
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            visible: creditTile.repoLabel.length > 0
            text: creditTile.repoLabel
            color: Qt.alpha(creditTile.tileAccent, 0.95)
            font.pointSize: Tokens.font.size.small
            font.weight: Font.Medium
            elide: Text.ElideRight
          }
        }

        MaterialIcon {
          Layout.alignment: Qt.AlignTop
          text: "open_in_new"
          color: tileHover.hovered ? creditTile.tileAccent : Colours.palette.m3outline
          font.pointSize: Tokens.font.size.smaller
        }
      }

      StyledText {
        Layout.fillWidth: true
        text: creditTile.role
        color: Colours.palette.m3outline
        font.pointSize: Tokens.font.size.small
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
      }
    }
  }

  component CommitRow: PreferenceRow {
    required property var commit

    icon: "commit"
    showPrefixIcon: true
    title: (commit && commit.subject) || ""
    description: commit ? `${commit.hash}  ·  ${commit.author}  ·  ${commit.relativeTime}` : ""
  }

  component ChannelPill: StyledRect {
    id: channelPill

    required property string channelId
    required property string label
    readonly property bool current: (RyokuAbout.info && RyokuAbout.info.configuredChannel) === channelId

    implicitWidth: pillLabel.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 30
    radius: implicitHeight / 2
    color: current ? root.accent : Colours.palette.m3surfaceContainerHighest
    border.width: current ? 0 : 1
    border.color: Colours.palette.m3outlineVariant
    opacity: RyokuAbout.switchingChannel ? 0.6 : 1

    StateLayer {
      disabled: channelPill.current || RyokuAbout.switchingChannel
      color: channelPill.current ? root.accentOn : Colours.palette.m3onSurface
      onClicked: RyokuAbout.switchChannel(channelPill.channelId)
    }

    StyledText {
      id: pillLabel

      anchors.centerIn: parent
      text: channelPill.label
      color: channelPill.current ? root.accentOn : Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: Font.DemiBold
    }
  }

  component ProfileCard: StyledRect {
    id: profileCard

    required property string profileId
    required property string profileTitle
    required property string meta
    property bool activeProfile
    property bool allowDelete: true
    property bool allowRename: true
    property bool editing
    signal saveRequested(string profileId)
    signal applyRequested(string profileId)
    signal deleteRequested(string profileId)
    signal renameRequested(string profileId, string name)

    function beginRename(): void {
      nameField.text = profileCard.profileTitle;
      profileCard.editing = true;
      nameField.forceActiveFocus();
      nameField.selectAll();
    }

    function commitRename(): void {
      if (!profileCard.editing)
        return;
      profileCard.editing = false;
      const next = nameField.text.trim();
      if (next.length > 0 && next !== profileCard.profileTitle)
        profileCard.renameRequested(profileCard.profileId, next);
    }

    function cancelRename(): void {
      profileCard.editing = false;
    }

    Layout.fillWidth: true
    implicitHeight: 74
    radius: 0
    color: activeProfile ? Qt.alpha(root.accent, 0.06) : "transparent"

    StyledRect {
      visible: profileCard.activeProfile
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      implicitWidth: 3
      color: root.accent
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
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.small
      spacing: Tokens.spacing.normal

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 36
        implicitHeight: 36
        radius: Math.max(9, root.rowRadius)
        color: profileCard.activeProfile ? Qt.alpha(root.accent, 0.18) : Colours.palette.m3surfaceContainerHigh

        MaterialIcon {
          anchors.centerIn: parent
          text: profileCard.activeProfile ? "bookmark" : "bookmark_border"
          color: profileCard.activeProfile ? root.accent : Colours.palette.m3outline
          font.pointSize: Tokens.font.size.normal
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.small

          StyledText {
            visible: !profileCard.editing
            Layout.fillWidth: true
            text: profileCard.profileTitle
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.smaller
            font.weight: Font.Bold
            elide: Text.ElideRight
          }

          StyledTextField {
            id: nameField

            visible: profileCard.editing
            Layout.fillWidth: true
            text: profileCard.profileTitle
            font.pointSize: Tokens.font.size.smaller
            font.weight: Font.Bold
            onAccepted: profileCard.commitRename()
            Keys.onEscapePressed: profileCard.cancelRename()
            onActiveFocusChanged: {
              if (!activeFocus && profileCard.editing)
                profileCard.commitRename();
            }
          }

          ActiveBadge {
            visible: profileCard.activeProfile && !profileCard.editing
            text: "Active"
          }
        }

        StyledText {
          visible: !profileCard.editing
          Layout.fillWidth: true
          text: profileCard.meta
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      FlatButton {
        visible: profileCard.editing
        text: "Save name"
        onClicked: profileCard.commitRename()
      }

      FlatButton {
        visible: !profileCard.editing && profileCard.activeProfile
        text: "Update"
        onClicked: profileCard.saveRequested(profileCard.profileId)
      }

      FlatButton {
        visible: !profileCard.editing && !profileCard.activeProfile
        text: "Apply"
        onClicked: profileCard.applyRequested(profileCard.profileId)
      }

      IconButton {
        id: renameProfileButton

        visible: profileCard.allowRename && !profileCard.editing
        icon: "edit"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: profileCard.beginRename()

        Tooltip {
          target: renameProfileButton
          text: "Rename profile"
        }
      }

      IconButton {
        id: deleteProfileButton

        visible: profileCard.allowDelete && !profileCard.editing
        icon: "delete"
        type: IconButton.Text
        padding: Tokens.padding.smaller
        onClicked: profileCard.deleteRequested(profileCard.profileId)

        Tooltip {
          target: deleteProfileButton
          text: "Delete profile"
        }
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

  component WallpaperPreviewGrid: StyledRect {
    id: wallpaperGrid

    readonly property var previewItems: Wallpapers.list ? Wallpapers.list.slice(0, 8) : []

    Layout.fillWidth: true
    implicitHeight: gridContent.implicitHeight + Tokens.padding.normal * 2
    radius: 0
    color: "transparent"

    ColumnLayout {
      id: gridContent

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      anchors.topMargin: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
          Layout.fillWidth: true
          text: wallpaperGrid.previewItems.length > 0 ? `${wallpaperGrid.previewItems.length} preview${wallpaperGrid.previewItems.length === 1 ? "" : "s"}` : "No wallpapers found"
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }

        FlatButton {
          text: "Open"
          onClicked: Quickshell.execDetached(["xdg-open", Paths.absolutePath(GlobalConfig.paths.wallpaperDir)])
        }
      }

      GridLayout {
        visible: wallpaperGrid.previewItems.length > 0
        Layout.fillWidth: true
        columns: Math.max(1, Math.min(4, Math.floor(width / 150)))
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        Repeater {
          model: wallpaperGrid.previewItems

          WallpaperPreviewTile {
            required property var modelData

            entry: modelData
          }
        }
      }
    }
  }

  component WallpaperPreviewTile: StyledRect {
    id: wallpaperTile

    required property var entry
    readonly property string path: String(entry.path || "")
    readonly property string label: String(entry.relativePath || entry.name || entry.path || "")
    readonly property bool current: Wallpapers.actualCurrent === path

    Layout.fillWidth: true
    Layout.preferredWidth: 150
    Layout.preferredHeight: 112
    radius: root.rowRadius
    color: current ? Qt.alpha(root.accent, 0.10) : Colours.palette.m3surfaceContainer
    border.width: current ? 1 : 0
    border.color: current ? root.accent : "transparent"
    clip: true

    CachingImage {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 78
      path: wallpaperTile.path
      smooth: true
    }

    StyledRect {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      implicitHeight: 34
      radius: 0
      color: Qt.alpha(Colours.palette.m3surface, 0.86)

      StyledText {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.small
        verticalAlignment: Text.AlignVCenter
        text: wallpaperTile.label
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        elide: Text.ElideRight
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: Wallpapers.preview(wallpaperTile.path)
      onExited: Wallpapers.stopPreview()
      onClicked: Wallpapers.setWallpaper(wallpaperTile.path)
    }
  }

  component AboutPage: SettingsPage {
    id: aboutPage

    property int aboutTab: 0
    readonly property var info: RyokuAbout.info || ({})
    readonly property var upd: RyokuAbout.lastUpdateReport || ({})

    onAboutTabChanged: {
      if (aboutTab === 1 && !aboutPage.upd.ok && !RyokuAbout.checkingUpdates)
        RyokuAbout.checkUpdates();
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      AboutTabButton {
        title: "Overview"
        index: 0
        currentIndex: aboutPage.aboutTab
        onSelected: index => aboutPage.aboutTab = index
      }

      AboutTabButton {
        title: "Updates"
        index: 1
        currentIndex: aboutPage.aboutTab
        onSelected: index => aboutPage.aboutTab = index
      }

      AboutTabButton {
        title: "Credits"
        index: 2
        currentIndex: aboutPage.aboutTab
        onSelected: index => aboutPage.aboutTab = index
      }
    }

    // ── Overview ──
    ColumnLayout {
      visible: aboutPage.aboutTab === 0
      Layout.fillWidth: true
      spacing: Tokens.spacing.larger

      StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 264
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
            Layout.preferredWidth: 118
            Layout.preferredHeight: 118
            radius: root.groupRadius
            color: Qt.alpha(root.brandAccent, 0.18)

            Logo {
              anchors.centerIn: parent
              width: 88
              height: 88
            }
          }

          StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "RYOKU"
            font.pointSize: Tokens.font.size.extraLarge
            font.weight: Font.Black
            color: root.brandAccent
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "力と美のために · For the sake of power and beauty."
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
          value: aboutPage.info.version || "unknown"
        }

        InfoRow {
          icon: "cloud_sync"
          label: "Channel"
          value: aboutPage.info.configuredChannelLabel || "unknown"
        }

        InfoRow {
          icon: "account_tree"
          label: "Branch"
          value: aboutPage.info.currentBranch || "unknown"
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
          command: [RyokuAbout.helper, "refresh-shell"]
        }

        ActionPreferenceRow {
          icon: "health_and_safety"
          title: "Doctor"
          description: "Run shell diagnostics in a terminal."
          buttonText: "Run"
          command: ["ryoku-launch-floating-terminal-with-presentation", "ryoku-doctor shell"]
        }
      }

      PreferenceGroup {
        title: "Recovery"
        description: "Last resort — only when Doctor can't help and updates won't apply."

        PreferenceRow {
          icon: "sos"
          showPrefixIcon: true
          title: "Medevac"
          description: "Re-pull Ryoku from origin in a recovery terminal (ryoku-call911now)."
          managed: true

          FlatButton {
            text: RyokuAbout.startingMedevac ? "Launching…" : "Medevac"
            onClicked: {
              if (!RyokuAbout.startingMedevac)
                RyokuAbout.startMedevac(aboutPage.info.configuredChannel || "");
            }
          }
        }
      }
    }

    // ── Updates ──
    ColumnLayout {
      visible: aboutPage.aboutTab === 1
      Layout.fillWidth: true
      spacing: Tokens.spacing.larger

      StyledRect {
        id: statusCard

        readonly property string updState: aboutPage.upd.updateState || "current"
        readonly property bool attention: updState === "ready"
        readonly property bool problem: updState === "error" || updState === "blocked"

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(120, statusColumn.implicitHeight + Tokens.padding.large * 2)
        radius: root.groupRadius
        color: Colours.palette.m3surfaceContainer
        border.width: 1
        border.color: statusCard.attention ? Qt.alpha(root.accent, 0.5) : statusCard.problem ? Qt.alpha(root.warning, 0.5) : Qt.alpha(Colours.palette.m3outlineVariant, 0.55)

        RowLayout {
          id: statusColumn

          anchors.fill: parent
          anchors.margins: Tokens.padding.large
          spacing: Tokens.spacing.normal

          StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 52
            implicitHeight: 52
            radius: width / 2
            color: statusCard.attention ? Qt.alpha(root.accent, 0.16) : statusCard.problem ? Qt.alpha(root.warning, 0.16) : Qt.alpha(Colours.palette.m3onSurface, 0.08)

            MaterialIcon {
              anchors.centerIn: parent
              text: RyokuAbout.checkingUpdates ? "sync" : statusCard.attention ? "system_update" : statusCard.problem ? "error" : statusCard.updState === "ahead" ? "north" : "check_circle"
              color: statusCard.attention ? root.accent : statusCard.problem ? root.warning : Colours.palette.m3onSurface
              font.pointSize: Tokens.font.size.extraLarge
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
              Layout.fillWidth: true
              text: RyokuAbout.checkingUpdates ? "Checking for updates…" : aboutPage.upd.updateStateLabel || "Up to date"
              color: Colours.palette.m3onSurface
              font.pointSize: Tokens.font.size.normal
              font.weight: Font.Bold
              elide: Text.ElideRight
            }

            StyledText {
              Layout.fillWidth: true
              text: aboutPage.upd.updateStateDetail || `${aboutPage.info.version || "unknown"} · ${aboutPage.info.configuredChannelLabel || ""}`
              color: Colours.palette.m3outline
              font.pointSize: Tokens.font.size.small
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
          }

          SuggestedButton {
            Layout.alignment: Qt.AlignVCenter
            visible: aboutPage.upd.canStartUpdate === true && !RyokuAbout.startingUpdate
            text: "Update now"
            onClicked: RyokuAbout.startUpdate(aboutPage.upd.updateBranch || aboutPage.info.updateBranch)
          }

          FlatButton {
            Layout.alignment: Qt.AlignVCenter
            text: "Doctor"
            onClicked: Quickshell.execDetached(["ryoku-launch-floating-terminal-with-presentation", "ryoku-doctor shell"])
          }

          FlatButton {
            Layout.alignment: Qt.AlignVCenter
            text: RyokuAbout.checkingUpdates ? "Checking…" : "Check"
            onClicked: {
              if (!RyokuAbout.checkingUpdates)
                RyokuAbout.checkUpdates();
            }
          }
        }
      }

      PreferenceGroup {
        title: "Blocking local commits"
        description: `${aboutPage.upd.localHead || "local"} → ${aboutPage.upd.remoteBranch || "remote"} · these local commits prevent a fast-forward update.`
        visible: (aboutPage.upd.local || []).length > 0

        Repeater {
          model: aboutPage.upd.local || []

          CommitRow {
            required property var modelData

            commit: modelData
          }
        }
      }

      PreferenceGroup {
        title: "Channel"
        description: "Switch between the stable and development update streams."

        PreferenceRow {
          title: "Release channel"
          description: aboutPage.info.configuredChannelLabel || "unknown"
          showPrefixIcon: true
          icon: "alt_route"

          RowLayout {
            spacing: Tokens.spacing.small

            Repeater {
              model: (aboutPage.info && aboutPage.info.channels) || []

              ChannelPill {
                required property var modelData

                channelId: modelData.id
                label: modelData.label
              }
            }
          }
        }
      }

      PreferenceGroup {
        title: "Incoming changes"
        description: `${aboutPage.upd.behindCount || 0} commit${(aboutPage.upd.behindCount || 0) === 1 ? "" : "s"} ahead on ${aboutPage.upd.remoteBranch || "the remote"}.`
        visible: (aboutPage.upd.incoming || []).length > 0

        Repeater {
          model: aboutPage.upd.incoming || []

          CommitRow {
            required property var modelData

            commit: modelData
          }
        }
      }

      EmptyState {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.large
        visible: !RyokuAbout.checkingUpdates && aboutPage.upd.ok === true && (aboutPage.upd.behindCount || 0) === 0
        icon: "verified"
        title: "You're up to date"
        description: "No incoming changes on this channel."
      }
    }

    // ── Credits ──
    ColumnLayout {
      visible: aboutPage.aboutTab === 2
      Layout.fillWidth: true
      spacing: Tokens.spacing.normal

      StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        text: "Built on the shoulders of these projects. Tap a card to open its repository."
        color: Colours.palette.m3outline
        font.pointSize: Tokens.font.size.small
        wrapMode: Text.WordWrap
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.normal
        rowSpacing: Tokens.spacing.normal

        CreditTile {
          Layout.columnSpan: 2
          name: "Omarchy"
          role: "Tooling backbone, script ecosystem, theme pipeline, and menu architecture."
          repoLabel: "basecamp/omarchy"
          url: "https://github.com/basecamp/omarchy"
          tileAccent: root.brandAccent
        }

        CreditTile {
          name: "Caelestia Shell"
          role: "The Quickshell codebase Ryoku's shell started from."
          repoLabel: "caelestia-dots/shell"
          url: "https://github.com/caelestia-dots/shell"
          tileAccent: "#6d9eeb"
        }

        CreditTile {
          name: "ActivSpot"
          role: "Dynamic Island code and interaction inspiration."
          repoLabel: "Devvvmn/ActivSpot"
          url: "https://github.com/Devvvmn/ActivSpot"
          tileAccent: "#4db6ac"
        }

        CreditTile {
          name: "HyprMod"
          role: "Hyprland GUI configuration and the settings surface reference."
          repoLabel: "BlueManCZ/hyprmod"
          url: "https://github.com/BlueManCZ/hyprmod"
          tileAccent: "#ba68c8"
        }

        CreditTile {
          name: "qylock"
          mark: "Q"
          role: "Optional SDDM greeter and lockscreen themes."
          repoLabel: "Darkkal44/qylock"
          url: "https://github.com/Darkkal44/qylock"
          tileAccent: "#ec407a"
        }
      }
    }
  }

  component ProfilesPage: SettingsPage {
    PreferenceGroup {
      title: "Current"
      description: "Profiles save the shell config, token config, and current scheme tuple."

      ProfileCard {
        profileId: "current"
        profileTitle: "Current shell profile"
        meta: `${root.pendingCount} pending change${root.pendingCount === 1 ? "" : "s"}`
        activeProfile: true
        allowDelete: false
        allowRename: false
        onSaveRequested: root.saveCurrentShellProfile(root.profileSnapshotName())
      }
    }

    PreferenceGroup {
      title: "Saved"
      description: "Apply or delete saved shell profile snapshots."

      Repeater {
        model: root.profileEntries

        ProfileCard {
          required property var modelData

          profileId: String(modelData.id || "")
          profileTitle: String(modelData.name || modelData.id || "Profile")
          meta: String(modelData.updatedAt || modelData.createdAt || "")
          activeProfile: !!modelData.active
          allowDelete: true
          allowRename: true
          onSaveRequested: id => root.saveCurrentShellProfile(profileTitle)
          onApplyRequested: id => root.applyShellProfile(id)
          onDeleteRequested: id => root.deleteShellProfile(id)
          onRenameRequested: (id, name) => root.renameShellProfile(id, name)
        }
      }
    }

    EmptyState {
      visible: root.profileEntries.length === 0
      icon: "folder_managed"
      title: "No Saved Profiles"
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
        text: root.shellConfigPath
        defaultText: root.shellConfigPath
        placeholderText: root.shellConfigPath
        settingKey: "settings.configPath"
        readOnly: true
        onBrowseRequested: Quickshell.execDetached(["xdg-open", root.ryokuConfigDir])
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
        targetKey: "appearance.transparency.enabled"
        targetPageIndex: 1
        icon: "opacity"
        title: "Transparency"
        description: "Use translucent shell layers."
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.transparency
        propertyName: "base"
        targetKey: "appearance.transparency.base"
        targetPageIndex: 1
        icon: "layers"
        title: "Base opacity"
        description: "Controls the main layer opacity."
        from: 0.45
        to: 1
        stepSize: 0.05
        decimals: 2
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.transparency
        propertyName: "layers"
        targetKey: "appearance.transparency.layers"
        targetPageIndex: 1
        icon: "stack"
        title: "Layer tint"
        description: "Strength of the translucent overlay on raised surfaces."
        from: 0
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
        targetKey: "appearance.rounding.scale"
        targetPageIndex: 1
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
        targetKey: "appearance.padding.scale"
        targetPageIndex: 1
        icon: "padding"
        title: "Padding scale"
        description: "Adjusts internal control spacing."
        from: 0.7
        to: 1.5
        stepSize: 0.05
        decimals: 2
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.spacing
        propertyName: "scale"
        targetKey: "appearance.spacing.scale"
        targetPageIndex: 1
        icon: "space_bar"
        title: "Spacing scale"
        description: "Adjusts the gaps between shell elements."
        from: 0.7
        to: 1.5
        stepSize: 0.05
        decimals: 2
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance.font.size
        propertyName: "scale"
        targetKey: "appearance.font.size.scale"
        targetPageIndex: 1
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
        targetKey: "border.thickness"
        targetPageIndex: 1
        icon: "border_outer"
        title: "Frame thickness"
        description: "Controls top-frame and side-frame thickness."
        from: 2
        to: 24
        stepSize: 1
        decimals: 0
      }

      SliderPreferenceRow {
        target: GlobalConfig.border
        propertyName: "rounding"
        targetKey: "border.rounding"
        targetPageIndex: 1
        icon: "rounded_corner"
        title: "Frame corner radius"
        description: "Roundness of the shell's inner screen-edge corners."
        from: 0
        to: 40
        stepSize: 1
        decimals: 0
      }

      SliderPreferenceRow {
        target: GlobalConfig.border
        propertyName: "smoothing"
        targetKey: "border.smoothing"
        targetPageIndex: 1
        icon: "gradient"
        title: "Corner smoothing"
        description: "Squircle smoothing applied to the frame corners."
        from: 0
        to: 100
        stepSize: 1
        decimals: 0
      }

      SliderPreferenceRow {
        target: GlobalConfig.appearance
        propertyName: "deformScale"
        targetKey: "appearance.deformScale"
        targetPageIndex: 1
        icon: "blur_on"
        title: "Squircle deform"
        description: "How squircle-like rounded surfaces appear across the shell."
        from: 0
        to: 1.5
        stepSize: 0.05
        decimals: 2
      }
    }

    PreferenceGroup {
      title: "Motion"
      description: "Animation timing across the shell."

      SliderPreferenceRow {
        target: GlobalConfig.appearance.anim.durations
        propertyName: "scale"
        targetKey: "appearance.anim.durations.scale"
        targetPageIndex: 1
        icon: "animation"
        title: "Animation duration"
        description: "Scales how long shell animations take. Lower is snappier; 0 disables motion."
        from: 0
        to: 2
        stepSize: 0.05
        decimals: 2
      }
    }

    PreferenceGroup {
      title: "Desktop"

      SwitchPreferenceRow {
        target: GlobalConfig.background
        propertyName: "wallpaperEnabled"
        targetKey: "background.wallpaperEnabled"
        targetPageIndex: 1
        icon: "wallpaper"
        title: "Wallpaper"
        description: "Show the configured wallpaper behind the shell."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.background.desktopClock
        propertyName: "enabled"
        targetKey: "background.desktopClock.enabled"
        targetPageIndex: 1
        icon: "schedule"
        title: "Desktop clock"
        description: "Show the large desktop clock overlay."
      }

      SliderPreferenceRow { target: GlobalConfig.background.desktopClock; propertyName: "scale"; targetKey: "background.desktopClock.scale"; targetPageIndex: 1; icon: "format_size"; title: "Clock scale"; description: "Size of the desktop clock."; from: 0.5; to: 2; stepSize: 0.05; decimals: 2 }
      SwitchPreferenceRow { target: GlobalConfig.background.desktopClock; propertyName: "invertColors"; targetKey: "background.desktopClock.invertColors"; targetPageIndex: 1; icon: "invert_colors"; title: "Invert clock colors"; description: "Flip the clock's foreground and background." }
      SwitchPreferenceRow { target: GlobalConfig.background.desktopClock.shadow; propertyName: "enabled"; targetKey: "background.desktopClock.shadow.enabled"; targetPageIndex: 1; icon: "filter_drop_shadow"; title: "Clock shadow"; description: "Drop a shadow behind the desktop clock." }

      SwitchPreferenceRow {
        target: GlobalConfig.background.visualiser
        propertyName: "enabled"
        targetKey: "background.visualiser.enabled"
        targetPageIndex: 1
        icon: "graphic_eq"
        title: "Audio visualiser"
        description: "Show the wallpaper visualiser."
      }

      SwitchPreferenceRow { target: GlobalConfig.background.visualiser; propertyName: "autoHide"; targetKey: "background.visualiser.autoHide"; targetPageIndex: 1; icon: "visibility_off"; title: "Auto-hide visualiser"; description: "Hide the visualiser when no audio is playing." }
      SwitchPreferenceRow { target: GlobalConfig.background.visualiser; propertyName: "blur"; targetKey: "background.visualiser.blur"; targetPageIndex: 1; icon: "blur_on"; title: "Visualiser blur"; description: "Blur the visualiser bars." }
    }

    PreferenceGroup {
      title: "Wallpapers"
      description: "Choose the folder Ryoku scans and apply wallpapers with live preview."

      EntryPreferenceRow {
        icon: "folder"
        title: "Wallpaper folder"
        text: GlobalConfig.paths.wallpaperDir
        defaultText: `${Paths.pictures}/Wallpapers`
        placeholderText: `${Paths.pictures}/Wallpapers`
        settingKey: "paths.wallpaperDir"
        managedText: true
        onApplied: value => {
          GlobalConfig.paths.setProperty("wallpaperDir", value);
          GlobalConfig.save();
          root.markSaved();
        }
        onBrowseRequested: Quickshell.execDetached(["xdg-open", Paths.absolutePath(GlobalConfig.paths.wallpaperDir)])
      }

      WallpaperPreviewGrid {}
    }
  }

  component BarPage: SettingsPage {
    PreferenceGroup {
      title: "Taskbar"
      description: "Persistent frame bar and workspace controls."

      SwitchPreferenceRow {
        target: GlobalConfig.bar
        propertyName: "persistent"
        targetKey: "bar.persistent"
        targetPageIndex: 2
        icon: "keep"
        title: "Persistent bar"
        description: "Reserve frame space for the bar."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.bar
        propertyName: "showOnHover"
        targetKey: "bar.showOnHover"
        targetPageIndex: 2
        icon: "ads_click"
        title: "Show on hover"
        description: "Reveal the bar when the pointer reaches the frame."
      }

      SliderPreferenceRow { target: GlobalConfig.bar; propertyName: "dragThreshold"; targetKey: "bar.dragThreshold"; targetPageIndex: 2; icon: "swipe_up"; title: "Reveal threshold"; description: "Pointer travel into the frame before the bar reveals."; from: 0; to: 80; stepSize: 5; decimals: 0; suffix: "px" }

      SliderPreferenceRow {
        target: GlobalConfig.bar.workspaces
        propertyName: "shown"
        targetKey: "bar.workspaces.shown"
        targetPageIndex: 2
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
        targetKey: "bar.workspaces.activeIndicator"
        targetPageIndex: 2
        icon: "radio_button_checked"
        title: "Active indicator"
        description: "Show a filled marker for the active workspace."
      }

      SwitchPreferenceRow {
        target: GlobalConfig.bar.workspaces
        propertyName: "occupiedBg"
        targetKey: "bar.workspaces.occupiedBg"
        targetPageIndex: 2
        icon: "space_dashboard"
        title: "Occupied background"
        description: "Highlight workspaces with windows."
      }

      SwitchPreferenceRow { target: GlobalConfig.bar.workspaces; propertyName: "showWindows"; targetKey: "bar.workspaces.showWindows"; targetPageIndex: 2; icon: "window"; title: "Workspace windows"; description: "Show window icons under workspaces." }
      SliderPreferenceRow { target: GlobalConfig.bar.workspaces; propertyName: "maxWindowIcons"; targetKey: "bar.workspaces.maxWindowIcons"; targetPageIndex: 2; icon: "filter_5"; title: "Max window icons"; description: "Window icons shown under one workspace."; from: 1; to: 12; stepSize: 1; decimals: 0 }
      SwitchPreferenceRow { target: GlobalConfig.bar.workspaces; propertyName: "activeTrail"; targetKey: "bar.workspaces.activeTrail"; targetPageIndex: 2; icon: "linear_scale"; title: "Active trail"; description: "Draw a trail to the active workspace." }
      SwitchPreferenceRow { target: GlobalConfig.bar.workspaces; propertyName: "showWindowsOnSpecialWorkspaces"; targetKey: "bar.workspaces.showWindowsOnSpecialWorkspaces"; targetPageIndex: 2; icon: "dynamic_feed"; title: "Special workspace windows"; description: "Show window icons on special workspaces too." }
      SwitchPreferenceRow { target: GlobalConfig.bar.workspaces; propertyName: "perMonitorWorkspaces"; targetKey: "bar.workspaces.perMonitorWorkspaces"; targetPageIndex: 2; icon: "splitscreen"; title: "Per-monitor workspaces"; description: "Show workspaces scoped to each monitor." }
    }

    PreferenceGroup {
      title: "Sidebar"
      description: "Right-edge drawer for notifications and quick toggles."

      SwitchPreferenceRow { target: GlobalConfig.sidebar; propertyName: "enabled"; targetKey: "sidebar.enabled"; targetPageIndex: 2; icon: "dock_to_left"; title: "Sidebar enabled"; description: "Allow the side drawer to open." }
      SliderPreferenceRow { target: GlobalConfig.sidebar; propertyName: "dragThreshold"; targetKey: "sidebar.dragThreshold"; targetPageIndex: 2; icon: "swipe_left"; title: "Reveal threshold"; description: "Pointer travel from the edge before the sidebar reveals."; from: 10; to: 200; stepSize: 10; decimals: 0; suffix: "px" }
      SliderPreferenceRow { target: GlobalConfig.sidebar; propertyName: "rounding"; targetKey: "sidebar.rounding"; targetPageIndex: 2; icon: "rounded_corner"; title: "Corner roundness"; description: "Inner corner radius of the sidebar panel."; from: 0; to: 2; stepSize: 0.05; decimals: 2 }
      SwitchPreferenceRow { target: GlobalConfig.sidebar; propertyName: "shadow"; targetKey: "sidebar.shadow"; targetPageIndex: 2; icon: "filter_drop_shadow"; title: "Drop shadow"; description: "Cast a shadow behind the sidebar panel." }
    }

    PreferenceGroup {
      title: "Active Window"

      SwitchPreferenceRow { target: GlobalConfig.bar.activeWindow; propertyName: "showOnHover"; targetKey: "bar.activeWindow.showOnHover"; targetPageIndex: 2; icon: "ads_click"; title: "Popout on hover"; description: "Show active-window details on hover." }
      SwitchPreferenceRow { target: GlobalConfig.bar.activeWindow; propertyName: "compact"; targetKey: "bar.activeWindow.compact"; targetPageIndex: 2; icon: "compress"; title: "Compact title"; description: "Use a compact active-window label." }
      SwitchPreferenceRow { target: GlobalConfig.bar.activeWindow; propertyName: "inverted"; targetKey: "bar.activeWindow.inverted"; targetPageIndex: 2; icon: "swap_vert"; title: "Invert title"; description: "Flip vertical active-window text." }
    }

    PreferenceGroup {
      title: "Tray"

      SwitchPreferenceRow { target: GlobalConfig.bar.tray; propertyName: "compact"; targetKey: "bar.tray.compact"; targetPageIndex: 2; icon: "unfold_less"; title: "Tray compact"; description: "Collapse tray icons behind an expander." }
      SwitchPreferenceRow { target: GlobalConfig.bar.tray; propertyName: "background"; targetKey: "bar.tray.background"; targetPageIndex: 2; icon: "rounded_corner"; title: "Tray background"; description: "Draw a background behind tray icons." }
      SwitchPreferenceRow { target: GlobalConfig.bar.tray; propertyName: "recolour"; targetKey: "bar.tray.recolour"; targetPageIndex: 2; icon: "format_color_fill"; title: "Recolour tray"; description: "Tint tray icons with shell colours." }
    }

    PreferenceGroup {
      title: "Clock"

      SwitchPreferenceRow { target: GlobalConfig.bar.clock; propertyName: "showDate"; targetKey: "bar.clock.showDate"; targetPageIndex: 2; icon: "calendar_month"; title: "Clock date"; description: "Show the date beside the clock." }
      SwitchPreferenceRow { target: GlobalConfig.bar.clock; propertyName: "showIcon"; targetKey: "bar.clock.showIcon"; targetPageIndex: 2; icon: "schedule"; title: "Clock icon"; description: "Show the clock icon." }
      SwitchPreferenceRow { target: GlobalConfig.bar.clock; propertyName: "background"; targetKey: "bar.clock.background"; targetPageIndex: 2; icon: "rounded_corner"; title: "Clock background"; description: "Draw a background behind the clock." }
    }

    PreferenceGroup {
      title: "Popouts"

      SwitchPreferenceRow { target: GlobalConfig.bar.popouts; propertyName: "activeWindow"; targetKey: "bar.popouts.activeWindow"; targetPageIndex: 2; icon: "preview"; title: "Active window"; description: "Enable active-window popout." }
      SwitchPreferenceRow { target: GlobalConfig.bar.popouts; propertyName: "tray"; targetKey: "bar.popouts.tray"; targetPageIndex: 2; icon: "apps"; title: "Tray"; description: "Enable tray popout." }
      SwitchPreferenceRow { target: GlobalConfig.bar.popouts; propertyName: "statusIcons"; targetKey: "bar.popouts.statusIcons"; targetPageIndex: 2; icon: "info"; title: "Status icons"; description: "Enable status popout." }
    }

    PreferenceGroup {
      title: "Scroll Actions"

      SwitchPreferenceRow { target: GlobalConfig.bar.scrollActions; propertyName: "workspaces"; targetKey: "bar.scrollActions.workspaces"; targetPageIndex: 2; icon: "view_week"; title: "Workspace scroll"; description: "Scroll on workspaces to switch." }
      SwitchPreferenceRow { target: GlobalConfig.bar.scrollActions; propertyName: "volume"; targetKey: "bar.scrollActions.volume"; targetPageIndex: 2; icon: "volume_up"; title: "Volume scroll"; description: "Scroll upper bar area for volume." }
      SwitchPreferenceRow { target: GlobalConfig.bar.scrollActions; propertyName: "brightness"; targetKey: "bar.scrollActions.brightness"; targetPageIndex: 2; icon: "brightness_medium"; title: "Brightness scroll"; description: "Scroll lower bar area for brightness." }
    }

    PreferenceGroup {
      title: "Status Icons"

      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showAudio"; targetKey: "bar.status.showAudio"; targetPageIndex: 2; icon: "volume_up"; title: "Audio"; description: "Show audio volume status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showMicrophone"; targetKey: "bar.status.showMicrophone"; targetPageIndex: 2; icon: "mic"; title: "Microphone"; description: "Show microphone status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showKbLayout"; targetKey: "bar.status.showKbLayout"; targetPageIndex: 2; icon: "keyboard"; title: "Keyboard layout"; description: "Show keyboard layout status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showNetwork"; targetKey: "bar.status.showNetwork"; targetPageIndex: 2; icon: "lan"; title: "Network"; description: "Show network status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showWifi"; targetKey: "bar.status.showWifi"; targetPageIndex: 2; icon: "wifi"; title: "Wi-Fi"; description: "Show Wi-Fi status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showBluetooth"; targetKey: "bar.status.showBluetooth"; targetPageIndex: 2; icon: "bluetooth"; title: "Bluetooth"; description: "Show Bluetooth status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showBattery"; targetKey: "bar.status.showBattery"; targetPageIndex: 2; icon: "battery_full"; title: "Battery"; description: "Show battery status." }
      SwitchPreferenceRow { target: GlobalConfig.bar.status; propertyName: "showLockStatus"; targetKey: "bar.status.showLockStatus"; targetPageIndex: 2; icon: "lock"; title: "Lock status"; description: "Show Caps Lock and Num Lock status." }
    }
  }

  component LauncherPage: SettingsPage {
    PreferenceGroup {
      title: "Behavior"

      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "enabled"; targetKey: "launcher.enabled"; targetPageIndex: 3; icon: "toggle_on"; title: "Enabled"; description: "Allow the launcher drawer to open." }
      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "showOnHover"; targetKey: "launcher.showOnHover"; targetPageIndex: 3; icon: "ads_click"; title: "Show on hover"; description: "Reveal launcher from the lower frame." }
      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "vimKeybinds"; targetKey: "launcher.vimKeybinds"; targetPageIndex: 3; icon: "keyboard"; title: "Vim keybinds"; description: "Use vim-style movement in launcher lists." }
      SwitchPreferenceRow { target: GlobalConfig.launcher; propertyName: "enableDangerousActions"; targetKey: "launcher.enableDangerousActions"; targetPageIndex: 3; icon: "warning"; title: "Dangerous actions"; description: "Show power actions in launcher results." }
    }

    PreferenceGroup {
      title: "Results"

      SliderPreferenceRow { target: GlobalConfig.launcher; propertyName: "maxShown"; targetKey: "launcher.maxShown"; targetPageIndex: 3; icon: "format_list_numbered"; title: "Max results"; description: "Normal results shown at once."; from: 3; to: 14; stepSize: 1; decimals: 0 }
      SliderPreferenceRow { target: GlobalConfig.launcher; propertyName: "maxWallpapers"; targetKey: "launcher.maxWallpapers"; targetPageIndex: 3; icon: "image"; title: "Wallpaper results"; description: "Wallpaper previews shown."; from: 3; to: 18; stepSize: 1; decimals: 0 }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "apps"; targetKey: "launcher.useFuzzy.apps"; targetPageIndex: 3; icon: "apps"; title: "Fuzzy apps"; description: "Use fuzzy matching for applications." }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "actions"; targetKey: "launcher.useFuzzy.actions"; targetPageIndex: 3; icon: "bolt"; title: "Fuzzy actions"; description: "Use fuzzy matching for launcher actions." }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "schemes"; targetKey: "launcher.useFuzzy.schemes"; targetPageIndex: 3; icon: "palette"; title: "Fuzzy schemes"; description: "Use fuzzy matching for scheme search." }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "variants"; targetKey: "launcher.useFuzzy.variants"; targetPageIndex: 3; icon: "tonality"; title: "Fuzzy variants"; description: "Use fuzzy matching for variant search." }
      SwitchPreferenceRow { target: GlobalConfig.launcher.useFuzzy; propertyName: "wallpapers"; targetKey: "launcher.useFuzzy.wallpapers"; targetPageIndex: 3; icon: "wallpaper"; title: "Fuzzy wallpapers"; description: "Use fuzzy matching for wallpapers." }
    }
  }

  component IslandPage: SettingsPage {
    PreferenceGroup {
      title: "General"

      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "enabled"; targetKey: "dashboard.enabled"; targetPageIndex: 4; icon: "toggle_on"; title: "Island enabled"; description: "Allow the top-frame island to open." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showOnHover"; targetKey: "dashboard.showOnHover"; targetPageIndex: 4; icon: "ads_click"; title: "Show on hover"; description: "Reveal the island from the top frame." }
    }

    PreferenceGroup {
      title: "Modules"
      description: "Choose which panels the island expands into."

      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showDashboard"; targetKey: "dashboard.showDashboard"; targetPageIndex: 4; icon: "dashboard"; title: "Dashboard"; description: "Show the dashboard panel." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showMedia"; targetKey: "dashboard.showMedia"; targetPageIndex: 4; icon: "play_circle"; title: "Media"; description: "Now-playing controls and album art." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showPerformance"; targetKey: "dashboard.showPerformance"; targetPageIndex: 4; icon: "monitoring"; title: "Performance"; description: "Live resource usage gauges." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard; propertyName: "showWeather"; targetKey: "dashboard.showWeather"; targetPageIndex: 4; icon: "partly_cloudy_day"; title: "Weather"; description: "Local conditions summary." }
    }

    PreferenceGroup {
      title: "Refresh rates"
      description: "How often island data updates."

      SliderPreferenceRow { target: GlobalConfig.dashboard; propertyName: "mediaUpdateInterval"; targetKey: "dashboard.mediaUpdateInterval"; targetPageIndex: 4; icon: "music_note"; title: "Media poll"; description: "Now-playing refresh interval."; from: 100; to: 2000; stepSize: 100; decimals: 0; suffix: "ms" }
      SliderPreferenceRow { target: GlobalConfig.dashboard; propertyName: "resourceUpdateInterval"; targetKey: "dashboard.resourceUpdateInterval"; targetPageIndex: 4; icon: "speed"; title: "Resource poll"; description: "Performance gauge refresh interval."; from: 250; to: 5000; stepSize: 250; decimals: 0; suffix: "ms" }
    }

    PreferenceGroup {
      title: "Performance gauges"
      description: "Which metrics the performance module displays."

      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showCpu"; targetKey: "dashboard.performance.showCpu"; targetPageIndex: 4; icon: "memory"; title: "CPU"; description: "Processor load." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showGpu"; targetKey: "dashboard.performance.showGpu"; targetPageIndex: 4; icon: "developer_board"; title: "GPU"; description: "Graphics load." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showMemory"; targetKey: "dashboard.performance.showMemory"; targetPageIndex: 4; icon: "memory_alt"; title: "Memory"; description: "RAM usage." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showStorage"; targetKey: "dashboard.performance.showStorage"; targetPageIndex: 4; icon: "hard_drive"; title: "Storage"; description: "Disk usage." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showNetwork"; targetKey: "dashboard.performance.showNetwork"; targetPageIndex: 4; icon: "lan"; title: "Network"; description: "Throughput." }
      SwitchPreferenceRow { target: GlobalConfig.dashboard.performance; propertyName: "showBattery"; targetKey: "dashboard.performance.showBattery"; targetPageIndex: 4; icon: "battery_horiz_075"; title: "Battery"; description: "Charge level." }
    }

    PreferenceGroup {
      title: "Gesture"

      SliderPreferenceRow { target: GlobalConfig.dashboard; propertyName: "dragThreshold"; targetKey: "dashboard.dragThreshold"; targetPageIndex: 4; icon: "swipe_down"; title: "Drag threshold"; description: "Distance before the island drag gesture toggles."; from: 10; to: 140; stepSize: 5; decimals: 0; suffix: "px" }
    }

    PreferenceGroup {
      title: "Visuals"

      PreferenceRow {
        icon: "graphic_eq"
        showPrefixIcon: true
        settingKey: "island.audioBars"
        title: "Audio bars"
        description: "The island shows CAVA bars behind media controls while audio is playing."
      }
    }
  }

  component NotificationsPage: SettingsPage {
    PreferenceGroup {
      title: "Notification Behavior"

      SwitchPreferenceRow { target: GlobalConfig.notifs; propertyName: "expire"; targetKey: "notifs.expire"; targetPageIndex: 5; icon: "timer"; title: "Auto expire"; description: "Automatically dismiss normal notifications." }
      SwitchPreferenceRow { target: GlobalConfig.notifs; propertyName: "actionOnClick"; targetKey: "notifs.actionOnClick"; targetPageIndex: 5; icon: "touch_app"; title: "Click primary action"; description: "Trigger the primary action when clicking a notification." }
      SwitchPreferenceRow { target: GlobalConfig.notifs; propertyName: "openExpanded"; targetKey: "notifs.openExpanded"; targetPageIndex: 5; icon: "unfold_more"; title: "Open expanded"; description: "Show new notification groups expanded." }
    }

    PreferenceGroup {
      title: "Timing"

      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "defaultExpireTimeout"; targetKey: "notifs.defaultExpireTimeout"; targetPageIndex: 5; icon: "timer"; title: "Default timeout"; description: "Normal notification lifetime."; from: 1000; to: 12000; stepSize: 500; decimals: 0; suffix: "ms" }
      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "fullscreenExpireTimeout"; targetKey: "notifs.fullscreenExpireTimeout"; targetPageIndex: 5; icon: "fullscreen"; title: "Fullscreen timeout"; description: "Notification lifetime while fullscreen."; from: 500; to: 8000; stepSize: 500; decimals: 0; suffix: "ms" }
      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "groupPreviewNum"; targetKey: "notifs.groupPreviewNum"; targetPageIndex: 5; icon: "stacks"; title: "Group preview count"; description: "Notifications shown before collapse."; from: 1; to: 8; stepSize: 1; decimals: 0 }
    }

    PreferenceGroup {
      title: "Gestures"

      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "clearThreshold"; targetKey: "notifs.clearThreshold"; targetPageIndex: 5; icon: "swipe"; title: "Swipe-to-clear"; description: "Fraction of width a notification must be swiped to dismiss."; from: 0.1; to: 0.9; stepSize: 0.05; decimals: 2 }
      SliderPreferenceRow { target: GlobalConfig.notifs; propertyName: "expandThreshold"; targetKey: "notifs.expandThreshold"; targetPageIndex: 5; icon: "open_in_full"; title: "Expand threshold"; description: "Drag distance before a group expands."; from: 0; to: 80; stepSize: 5; decimals: 0; suffix: "px" }
    }

    PreferenceGroup {
      title: "Toasts"
      description: "Transient status pop-ups for shell events."

      SwitchPreferenceRow { target: GlobalConfig.utilities; propertyName: "enabled"; targetKey: "utilities.enabled"; targetPageIndex: 5; icon: "notifications_active"; title: "Toasts enabled"; description: "Show transient status toasts." }
      SliderPreferenceRow { target: GlobalConfig.utilities; propertyName: "maxToasts"; targetKey: "utilities.maxToasts"; targetPageIndex: 5; icon: "stacks"; title: "Maximum toasts"; description: "How many toasts stack at once."; from: 1; to: 8; stepSize: 1; decimals: 0 }
      SwitchPreferenceRow { target: GlobalConfig.utilities.toasts; propertyName: "nowPlaying"; targetKey: "utilities.toasts.nowPlaying"; targetPageIndex: 5; icon: "play_circle"; title: "Now playing"; description: "Toast when media playback changes." }
      SwitchPreferenceRow { target: GlobalConfig.utilities.toasts; propertyName: "configLoaded"; targetKey: "utilities.toasts.configLoaded"; targetPageIndex: 5; icon: "task_alt"; title: "Config loaded"; description: "Toast when the shell config reloads." }
      SwitchPreferenceRow { target: GlobalConfig.utilities.toasts; propertyName: "gameModeChanged"; targetKey: "utilities.toasts.gameModeChanged"; targetPageIndex: 5; icon: "sports_esports"; title: "Game mode"; description: "Toast when game mode toggles." }
      SwitchPreferenceRow { target: GlobalConfig.utilities.toasts; propertyName: "dndChanged"; targetKey: "utilities.toasts.dndChanged"; targetPageIndex: 5; icon: "do_not_disturb_on"; title: "Do not disturb"; description: "Toast when DND toggles." }
      SwitchPreferenceRow { target: GlobalConfig.utilities.toasts; propertyName: "capsLockChanged"; targetKey: "utilities.toasts.capsLockChanged"; targetPageIndex: 5; icon: "keyboard_capslock"; title: "Caps lock"; description: "Toast when Caps Lock toggles." }
      SwitchPreferenceRow { target: GlobalConfig.utilities.toasts; propertyName: "chargingChanged"; targetKey: "utilities.toasts.chargingChanged"; targetPageIndex: 5; icon: "power"; title: "Charging"; description: "Toast when AC power connects or disconnects." }
    }
  }

  component SystemPage: SettingsPage {
    PreferenceGroup {
      title: "OSD"

      SwitchPreferenceRow { target: GlobalConfig.osd; propertyName: "enabled"; targetKey: "osd.enabled"; targetPageIndex: 6; icon: "display_settings"; title: "Enabled"; description: "Show brightness, volume, and status overlays." }
      SwitchPreferenceRow { target: GlobalConfig.osd; propertyName: "enableBrightness"; targetKey: "osd.enableBrightness"; targetPageIndex: 6; icon: "brightness_medium"; title: "Brightness"; description: "Show brightness changes in the OSD." }
      SwitchPreferenceRow { target: GlobalConfig.osd; propertyName: "enableMicrophone"; targetKey: "osd.enableMicrophone"; targetPageIndex: 6; icon: "mic"; title: "Microphone"; description: "Show microphone changes in the OSD." }
      SliderPreferenceRow { target: GlobalConfig.osd; propertyName: "hideDelay"; targetKey: "osd.hideDelay"; targetPageIndex: 6; icon: "hourglass"; title: "Hide delay"; description: "How long OSD remains visible."; from: 500; to: 6000; stepSize: 250; decimals: 0; suffix: "ms" }
    }

    PreferenceGroup {
      title: "Services"

      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "smartScheme"; targetKey: "services.smartScheme"; targetPageIndex: 6; icon: "auto_awesome"; title: "Smart scheme"; description: "Adjust schemes from wallpaper context." }
      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "useTwelveHourClock"; targetKey: "services.useTwelveHourClock"; targetPageIndex: 6; icon: "schedule"; title: "12-hour clock"; description: "Use AM/PM time format." }
      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "showLyrics"; targetKey: "services.showLyrics"; targetPageIndex: 6; icon: "lyrics"; title: "Lyrics"; description: "Enable lyrics service integration." }
      SliderPreferenceRow { target: GlobalConfig.services; propertyName: "audioIncrement"; targetKey: "services.audioIncrement"; targetPageIndex: 6; icon: "volume_up"; title: "Audio step"; description: "Volume change amount per step."; from: 0.02; to: 0.25; stepSize: 0.01; decimals: 2 }
      SliderPreferenceRow { target: GlobalConfig.services; propertyName: "brightnessIncrement"; targetKey: "services.brightnessIncrement"; targetPageIndex: 6; icon: "brightness_medium"; title: "Brightness step"; description: "Brightness change amount per step."; from: 0.02; to: 0.25; stepSize: 0.01; decimals: 2 }
    }

    PreferenceGroup {
      title: "Idle"

      SwitchPreferenceRow { target: GlobalConfig.general.idle; propertyName: "lockBeforeSleep"; targetKey: "general.idle.lockBeforeSleep"; targetPageIndex: 6; icon: "lock"; title: "Lock before sleep"; description: "Lock the session before suspend actions." }
      SwitchPreferenceRow { target: GlobalConfig.general.idle; propertyName: "inhibitWhenAudio"; targetKey: "general.idle.inhibitWhenAudio"; targetPageIndex: 6; icon: "music_note"; title: "Inhibit during audio"; description: "Do not trigger idle actions while media is playing." }
    }

    PreferenceGroup {
      title: "Weather"

      EntryPreferenceRow {
        icon: "location_on"
        title: "Weather location"
        text: GlobalConfig.services.weatherLocation
        defaultText: ""
        placeholderText: "City, Country (blank = auto)"
        settingKey: "services.weatherLocation"
        managedText: true
        onApplied: value => {
          GlobalConfig.services.setProperty("weatherLocation", value);
          GlobalConfig.save();
          root.markSaved();
        }
      }

      SwitchPreferenceRow { target: GlobalConfig.services; propertyName: "useFahrenheit"; targetKey: "services.useFahrenheit"; targetPageIndex: 6; icon: "device_thermostat"; title: "Fahrenheit"; description: "Use °F instead of °C for weather." }
    }

    PreferenceGroup {
      title: "Audio & Media"

      SliderPreferenceRow { target: GlobalConfig.services; propertyName: "maxVolume"; targetKey: "services.maxVolume"; targetPageIndex: 6; icon: "volume_up"; title: "Maximum volume"; description: "Volume ceiling, above 1.0 over-amplifies."; from: 1; to: 2; stepSize: 0.05; decimals: 2 }
      SliderPreferenceRow { target: GlobalConfig.services; propertyName: "visualiserBars"; targetKey: "services.visualiserBars"; targetPageIndex: 6; icon: "equalizer"; title: "Visualiser bars"; description: "Number of CAVA bars rendered."; from: 10; to: 100; stepSize: 1; decimals: 0 }

      EntryPreferenceRow {
        icon: "music_note"
        title: "Default media player"
        text: GlobalConfig.services.defaultPlayer
        defaultText: "Spotify"
        placeholderText: "MPRIS player name"
        settingKey: "services.defaultPlayer"
        managedText: true
        onApplied: value => {
          GlobalConfig.services.setProperty("defaultPlayer", value);
          GlobalConfig.save();
          root.markSaved();
        }
      }
    }

    PreferenceGroup {
      title: "Session"
      description: "The power / session menu."

      SwitchPreferenceRow { target: GlobalConfig.session; propertyName: "enabled"; targetKey: "session.enabled"; targetPageIndex: 6; icon: "power_settings_new"; title: "Session menu enabled"; description: "Allow the power menu to open." }
      SwitchPreferenceRow { target: GlobalConfig.session; propertyName: "vimKeybinds"; targetKey: "session.vimKeybinds"; targetPageIndex: 6; icon: "keyboard"; title: "Vim keybinds"; description: "Navigate the session menu with h/j/k/l." }
      SliderPreferenceRow { target: GlobalConfig.session; propertyName: "dragThreshold"; targetKey: "session.dragThreshold"; targetPageIndex: 6; icon: "swipe"; title: "Reveal threshold"; description: "Gesture distance before the session menu reveals."; from: 10; to: 150; stepSize: 5; decimals: 0; suffix: "px" }
    }

    PreferenceGroup {
      title: "Lock screen"

      SwitchPreferenceRow { target: GlobalConfig.lock; propertyName: "enableFprint"; targetKey: "lock.enableFprint"; targetPageIndex: 6; icon: "fingerprint"; title: "Fingerprint unlock"; description: "Allow unlocking with a registered fingerprint." }
      SliderPreferenceRow { target: GlobalConfig.lock; propertyName: "maxFprintTries"; targetKey: "lock.maxFprintTries"; targetPageIndex: 6; icon: "tag"; title: "Fingerprint attempts"; description: "Tries before fingerprint unlock is disabled."; from: 1; to: 10; stepSize: 1; decimals: 0 }
      SwitchPreferenceRow { target: GlobalConfig.lock; propertyName: "hideNotifs"; targetKey: "lock.hideNotifs"; targetPageIndex: 6; icon: "notifications_off"; title: "Hide notifications"; description: "Hide notification content on the lock screen." }
      SwitchPreferenceRow { target: GlobalConfig.lock; propertyName: "recolourLogo"; targetKey: "lock.recolourLogo"; targetPageIndex: 6; icon: "palette"; title: "Recolour logo"; description: "Tint the lock-screen logo with the active scheme." }
    }

    PreferenceGroup {
      title: "General"

      SwitchPreferenceRow { target: GlobalConfig.general; propertyName: "showOverFullscreen"; targetKey: "general.showOverFullscreen"; targetPageIndex: 6; icon: "fullscreen"; title: "Show over fullscreen"; description: "Allow shell surfaces to appear over fullscreen windows." }
      SliderPreferenceRow { target: GlobalConfig.general.battery; propertyName: "criticalLevel"; targetKey: "general.battery.criticalLevel"; targetPageIndex: 6; icon: "battery_alert"; title: "Critical battery"; description: "Battery percentage that triggers the critical warning."; from: 1; to: 20; stepSize: 1; decimals: 0; suffix: "%" }
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
        command: [root.reloadHyprlandCommand]
      }
    }

    PreferenceGroup {
      title: "Configuration files"
      description: "Open the real Hyprland dotfiles and shell config in your default editor or file manager."

      ActionPreferenceRow {
        icon: "folder_open"
        title: "Hyprland config folder"
        description: root.hyprConfigDir
        buttonText: "Open"
        command: ["xdg-open", root.hyprConfigDir]
      }

      ActionPreferenceRow {
        icon: "description"
        title: "hyprland.conf"
        description: "Main compositor config — monitors, keybinds, and sources."
        buttonText: "Edit"
        command: ["xdg-open", `${root.hyprConfigDir}/hyprland.conf`]
      }

      ActionPreferenceRow {
        icon: "tune"
        title: "HyprMod overrides"
        description: "hyprland-gui.conf — written by HyprMod."
        buttonText: "Edit"
        command: ["xdg-open", `${root.hyprConfigDir}/hyprland-gui.conf`]
      }

      ActionPreferenceRow {
        icon: "bedtime"
        title: "Idle daemon"
        description: "hypridle.conf — idle and sleep timeouts."
        buttonText: "Edit"
        command: ["xdg-open", `${root.hyprConfigDir}/hypridle.conf`]
      }

      ActionPreferenceRow {
        icon: "lock"
        title: "Lock screen"
        description: "hyprlock.conf — lockscreen layout and styling."
        buttonText: "Edit"
        command: ["xdg-open", `${root.hyprConfigDir}/hyprlock.conf`]
      }

      ActionPreferenceRow {
        icon: "folder_special"
        title: "Ryoku shell config folder"
        description: root.ryokuConfigDir
        buttonText: "Open"
        command: ["xdg-open", root.ryokuConfigDir]
      }

      ActionPreferenceRow {
        icon: "data_object"
        title: "shell.json"
        description: "Live shell configuration the settings write to."
        buttonText: "Edit"
        command: ["xdg-open", root.shellConfigPath]
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
        icon: "graphic_eq"
        title: "Island"
        description: "Top-frame media island, hover, gesture, and visual controls."
        buttonText: "Open"
        pageIndex: 4
      }
    }
  }
}
