pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.dashboard.modules.services
import qs.dashboard.config

Singleton {
    id: root

    property var wallpaperManager: null
    property string avatarCacheBuster: ""

    function pickUserAvatar() {
        filePickerProcess.running = true;
    }

    Process {
        id: filePickerProcess
        running: false
        command: ["zenity", "--file-selection", "--title=Select User Icon", "--file-filter=Images | *.png *.jpg *.jpeg *.svg *.webp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) {
                    console.log("Selected icon:", path);
                    copyIconProcess.command = ["cp", path, Quickshell.env("HOME") + "/.face.icon"];
                    copyIconProcess.running = true;
                }
            }
        }
    }

    Process {
        id: copyIconProcess
        running: false
        command: []

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Icon updated successfully");
                avatarCacheBuster = Date.now();
            } else {
                console.warn("Failed to update icon");
            }
        }
    }

    property string compositorLayout: ""
    property bool compositorLayoutReady: false
    // RYOKU PORT: ryoku's dynamic island drives dashboard open/close (see getActiveDashboard).
    property bool ryokuDashboardOpen: false
    readonly property var availableLayouts: ["dwindle", "master", "scrolling"]

    Process {
        id: getLayoutProcess
        command: ["hyprctl", "getoption", "general:layout", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed && typeof parsed.str === 'string') {
                        const layout = parsed.str.trim();
                        if (root.availableLayouts.includes(layout)) {
                            root.compositorLayout = layout;
                        } else {
                            root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                        }
                    } else {
                        root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                    }
                } catch (e) {
                    console.warn("GlobalStates: Failed to parse hyprctl layout:", e);
                    root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                }
                root.compositorLayoutReady = true;
            }
        }
    }

    function setCompositorLayout(layout) {
        if (availableLayouts.includes(layout)) {
            compositorLayout = layout;
            StateService.set("compositorLayout", layout);
        }
    }

    function cycleCompositorLayout() {
        const currentIndex = availableLayouts.indexOf(compositorLayout);
        const nextIndex = (currentIndex + 1) % availableLayouts.length;
        setCompositorLayout(availableLayouts[nextIndex]);
    }


    Component.onCompleted: {
        LockscreenService.toString();
        getLayoutProcess.running = true;
    }

    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1
    property int launcherCurrentTab: 0

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    property int dashboardCurrentTab: 0
    
    property int widgetsTabCurrentIndex: 0

    property int wallpaperSelectedIndex: -1

    function clearWallpaperState() {
        wallpaperSelectedIndex = -1;
    }

    function getNotchOpen(screenName) {
        let visibilities = Visibilities.getForScreen(screenName);
        return visibilities.launcher || visibilities.dashboard || visibilities.overview || visibilities.presets;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveDashboard() {
        // Driven by ryoku's dynamic-island open state (see ryokuDashboardOpen).
        // The per-screen Visibilities path depends on AxctlService.focusedMonitor
        // (the axctl daemon), which is not used here, so getForActive() is always null.
        return root.ryokuDashboardOpen;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview : false;
    }

    function getActivePresets() {
        let active = Visibilities.getForActive();
        return active ? active.presets : false;
    }

    function getActiveNotchOpen() {
        let active = Visibilities.getForActive();
        return active ? (active.launcher || active.dashboard || active.overview) : false;
    }

    readonly property bool notchOpen: getActiveNotchOpen()
    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool presetsOpen: getActivePresets()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: getActiveDashboard()

    property bool lockscreenVisible: false

    property bool osdVisible: false
    property string osdIndicator: "volume"

    property bool screenshotToolVisible: false
    // property string screenshotToolMode: "normal" // DEPRECATED
    property string screenshotCaptureMode: "region"
    
    property int screenshotSelectionX: 0
    property int screenshotSelectionY: 0
    property int screenshotSelectionW: 0
    property int screenshotSelectionH: 0

    property bool screenRecordToolVisible: false

    // Mirror Tool state
    property bool mirrorWindowVisible: false

    property bool settingsWindowVisible: false
    property int settingsTargetWorkspaceId: 0
    property string settingsTargetScreenName: ""

    property bool themeHasChanges: false
    property var themeSnapshot: null

    // Constants for theme snapshot operations (avoid duplication)
    // Get SR variant names dynamically from Config.theme
    function _getSrVariantNames() {
        var names = [];
        var keys = Object.keys(Config.theme);
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].startsWith("sr")) {
                names.push(keys[i]);
            }
        }
        return names;
    }

    readonly property var _simpleThemeProps: [
        "roundness", "oledMode", "lightMode", "font", "fontSize", "monoFont", "monoFontSize",
        "tintIcons", "enableCorners", "animDuration",
        "shadowOpacity", "shadowColor", "shadowXOffset", "shadowYOffset", "shadowBlur"
    ]
    readonly property var _srVariantProps: [
        "gradientType", "gradientAngle", "gradientCenterX", "gradientCenterY",
        "halftoneDotMin", "halftoneDotMax", "halftoneStart", "halftoneEnd",
        "halftoneDotColor", "halftoneBackgroundColor", "itemColor", "opacity"
    ]

    function _copySrVariant(src) {
        var copy = {};
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                copy[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        try {
            copy.gradient = (src.gradient !== undefined) ? JSON.parse(JSON.stringify(src.gradient)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning gradient: " + e);
            copy.gradient = [];
        }
        
        try {
            copy.border = (src.border !== undefined) ? JSON.parse(JSON.stringify(src.border)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning border: " + e);
            copy.border = [];
        }
        
        return copy;
    }

    function _restoreSrVariant(src, dest) {
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                dest[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        if (src.gradient !== undefined) {
            try {
                dest.gradient = JSON.parse(JSON.stringify(src.gradient));
            } catch (e) { console.warn("GlobalStates: Error restoring gradient: " + e); }
        }
        
        if (src.border !== undefined) {
            try {
                dest.border = JSON.parse(JSON.stringify(src.border));
            } catch (e) { console.warn("GlobalStates: Error restoring border: " + e); }
        }
    }

    function createThemeSnapshot() {
        var snapshot = {};
        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            snapshot[prop] = theme[prop];
        }

        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            snapshot[name] = _copySrVariant(theme[name]);
        }

        return snapshot;
    }

    function restoreThemeSnapshot(snapshot) {
        if (!snapshot) return;

        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            theme[prop] = snapshot[prop];
        }

        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            if (snapshot[name]) {
                _restoreSrVariant(snapshot[name], theme[name]);
            }
        }
    }

    function markThemeChanged() {
        if (!themeHasChanges) {
            themeSnapshot = createThemeSnapshot();
            Config.pauseAutoSave = true;
        }
        themeHasChanges = true;
    }

    function applyThemeChanges() {
        if (themeHasChanges) {
            Config.loader.writeAdapter();
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardThemeChanges() {
        if (themeHasChanges && themeSnapshot) {
            restoreThemeSnapshot(themeSnapshot);
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    property bool shellHasChanges: false
    property var shellSnapshot: null

    readonly property var _shellSections: {
        "bar": ["position", "launcherIcon", "launcherIconTint", "launcherIconFullTint", "launcherIconSize", "enableFirefoxPlayer", "screenList", "frameEnabled", "frameThickness", "pinnedOnStartup", "hoverToReveal", "hoverRegionHeight", "showPinButton", "availableOnFullscreen", "pillStyle", "use12hFormat", "containBar", "keepBarShadow", "keepBarBorder"],
        "notch": ["theme", "position", "hoverRegionHeight", "keepHidden"],
        "workspaces": ["shown", "showAppIcons", "alwaysShowNumbers", "showNumbers", "dynamic"],
        "overview": ["rows", "columns", "scale", "workspaceSpacing"],
        "dock": ["enabled", "theme", "position", "height", "iconSize", "spacing", "margin", "hoverRegionHeight", "pinnedOnStartup", "hoverToReveal", "availableOnFullscreen", "showRunningIndicators", "showPinButton", "showOverviewButton", "screenList", "keepHidden"],
        "lockscreen": ["position"],
        "desktop": ["enabled", "iconSize", "spacingVertical", "textColor"],
        "system": ["idle", "ocr"]
    }

    function createShellSnapshot() {
        var snapshot = {};
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            snapshot[section] = {};
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = Config[section][prop];
                if (typeof val === 'object' && val !== null) {
                    snapshot[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    snapshot[section][prop] = val;
                }
            }
        }
        return snapshot;
    }

    function restoreShellSnapshot(snapshot) {
        if (!snapshot) return;
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = snapshot[section][prop];
                
                if (section === "system" && prop === "idle" && val) {
                    if (val.general) {
                        var generalProps = ["lock_cmd", "before_sleep_cmd", "after_sleep_cmd"];
                        for (var k = 0; k < generalProps.length; k++) {
                            var gp = generalProps[k];
                            if (val.general[gp] !== undefined) {
                                Config.system.idle.general[gp] = val.general[gp];
                            }
                        }
                    }
                    if (val.listeners) {
                        Config.system.idle.listeners = JSON.parse(JSON.stringify(val.listeners));
                    }
                }
                else if (section === "system" && prop === "ocr" && val) {
                    var keys = Object.keys(val);
                    for (var k = 0; k < keys.length; k++) {
                        var key = keys[k];
                        Config.system.ocr[key] = val[key];
                    }
                }
                else if (typeof val === 'object' && val !== null) {
                    Config[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config[section][prop] = val;
                }
            }
        }
    }

    function markShellChanged() {
        if (!shellHasChanges) {
            shellSnapshot = createShellSnapshot();
            Config.pauseAutoSave = true;
        }
        shellHasChanges = true;
    }

    function applyShellChanges() {
        if (shellHasChanges) {
            Config.saveBar();
            Config.saveNotch();
            Config.saveWorkspaces();
            Config.saveOverview();
            Config.saveLockscreen();
            Config.saveDesktop();
            Config.saveSystem();
            
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardShellChanges() {
        if (shellHasChanges && shellSnapshot) {
            restoreShellSnapshot(shellSnapshot);
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    property bool compositorHasChanges: false
    property var compositorSnapshot: null

    // Compositor config properties (AxctlService)
    readonly property var _compositorProps: [
        "syncBorderWidth", "borderSize",
        "syncRoundness", "rounding",
        "gapsIn", "gapsOut",
        "borderAngle", "inactiveBorderAngle",
        "syncBorderColor", "activeBorderColor", "inactiveBorderColor",
        "shadowEnabled", "syncShadowColor", "syncShadowOpacity",
        "shadowRange", "shadowRenderPower", "shadowScale",
        "shadowOpacity", "shadowSharp", "shadowIgnoreWindow",
        "blurEnabled", "blurSize", "blurPasses", "blurXray",
        "blurNewOptimizations", "blurIgnoreOpacity",
        "blurNoise", "blurContrast", "blurBrightness", "blurVibrancy",
        "blurVibrancyDarkness", "blurSpecial", "blurPopups", "blurPopupsIgnorealpha",
        "blurInputMethods", "blurInputMethodsIgnorealpha",
        "blurExplicitIgnoreAlpha", "blurIgnoreAlphaValue",
        "shadowOffset", "shadowColorInactive"
    ]

    function createCompositorSnapshot() {
        var snapshot = {};
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            var val = Config.compositor[prop];
            if (Array.isArray(val)) {
                snapshot[prop] = JSON.parse(JSON.stringify(val));
            } else {
                snapshot[prop] = val;
            }
        }
        return snapshot;
    }

    function restoreCompositorSnapshot(snapshot) {
        if (!snapshot) return;
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            if (snapshot[prop] !== undefined) {
                var val = snapshot[prop];
                if (Array.isArray(val)) {
                    Config.compositor[prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config.compositor[prop] = val;
                }
            }
        }
    }

    function markCompositorChanged() {
        if (!compositorHasChanges) {
            compositorSnapshot = createCompositorSnapshot();
            Config.pauseAutoSave = true;
        }
        compositorHasChanges = true;
    }

    function applyCompositorChanges() {
        if (compositorHasChanges) {
            Config.saveCompositor();
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardCompositorChanges() {
        if (compositorHasChanges && compositorSnapshot) {
            restoreCompositorSnapshot(compositorSnapshot);
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    property bool assistantVisible: false
    property bool assistantPinned: Config.ai.sidebarPinnedOnStartup ?? false
    property int assistantWidth: Config.ai.sidebarWidth ?? 400
    property string assistantPosition: Config.ai.sidebarPosition ?? "right"
    property string assistantScreenName: ""

    signal assistantFocusRequested(bool wasAlreadyOpen)

    function toggleAssistant() {
        if (assistantVisible) {
            assistantFocusRequested(true);
        } else {
            assistantVisible = true;
            if (AxctlService.focusedMonitor && AxctlService.focusedMonitor.name) {
                assistantScreenName = AxctlService.focusedMonitor.name;
            } else if (Quickshell.screens.length > 0) {
                assistantScreenName = Quickshell.screens[0].name;
            }
            assistantFocusRequested(false);
        }
    }

    function hideAssistant() {
        assistantVisible = false;
    }

    property int settingsCurrentTab: 0
}
