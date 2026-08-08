import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import shell.services
import "Palette.js" as Palette

Item {
    id: theme
    property var variantHost: null

    property string omarchyCurrentRoot: Quickshell.env("HOME") + "/.config/ryoku/current"
    property string omarchyInstallRoot: Quickshell.env("HOME") + "/.local/share/ryoku"
    property bool omarchyCurrentRootResolved: false
    readonly property string themeNamePath: omarchyCurrentRoot + "/theme.name"
    readonly property string colorsPath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
    readonly property string currentBackgroundPath: omarchyCurrentRoot + "/background"
    property string currentThemeName: ""
    readonly property var wallpaperSourcePaths: [
        Quickshell.env("HOME") + "/Pictures/Wallpapers",
        Quickshell.env("HOME") + "/Pictures/livewalls"
    ]

    function setCurrentThemeName(rawName) {
        var name = String(rawName || "").trim()
        if (name === "." || name === ".." || name.indexOf("/") >= 0 || name.indexOf("\\") >= 0)
            name = ""
        currentThemeName = name
    }

    function reloadCurrentThemeFiles() {
        if (!omarchyCurrentRootResolved) return
        themeReloadDebounce.restart()
    }

    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color sumi:    "#a6a69c"
    property color color01: "#c4746e"
    property color color02: "#8a9a73"
    property color color03: "#c8b36a"
    property color color04: "#658594"
    property color color05: "#957fb8"
    property color color06: "#7aa89f"
    property color color07: "#c8c093"
    readonly property color inkDeep: color07
    readonly property color indigo:  color04
    readonly property color sealRaw: color01
    readonly property color sumiHi:  Qt.rgba(sumi.r*0.45 + ink.r*0.55, sumi.g*0.45 + ink.g*0.55, sumi.b*0.45 + ink.b*0.55, 1.0)  // lifted section-header text
    property color green:   "#8a9a73"   // gate "OK" verdict
    property color accentHint: sealRaw    // filled by palette; default = same as red
    readonly property color foregroundSoft: Qt.rgba(
        ink.r * 0.88 + paper.r * 0.12,
        ink.g * 0.88 + paper.g * 0.12,
        ink.b * 0.88 + paper.b * 0.12,
        1.0)
    property string barColor: "color01"
    property bool widgetIconsForeground: false
    readonly property bool barColorIsAccent: barColor === "accent"
    // Compatibility alias for older local code/reviews that still use the
    // previous boolean name.
    readonly property bool useThemeAccent: barColorIsAccent

    function paletteColor(id) {
        if (id === "color02") return color02
        if (id === "color03") return color03
        if (id === "color04") return color04
        if (id === "color05") return color05
        if (id === "color06") return color06
        if (id === "color07") return color07
        if (id === "foreground") return foregroundSoft
        if (id === "accent") return accentHint
        return color01
    }
    function normalizedPaletteId(id) {
        if (id === "red" || id === "accent") return "color01"
        return paletteColorValid(id) ? id : "color01"
    }
    readonly property color seal: paletteColor(barColor)
    // Legacy global foreground switch is retained only for cache compatibility.
    // Widget colors now inherit Bar Color or use a per-GID palette style.
    readonly property color widgetIconColor: seal
    readonly property var barColorOptions: [
        "color01", "color02", "color03", "color04",
        "color05", "color06", "color07", "foreground"
    ]
    function paletteColorValid(id) {
        return id === "color01" || id === "color02" || id === "color03"
            || id === "color04" || id === "color05" || id === "color06"
            || id === "color07" || id === "foreground"
    }
    function barColorValid(id) {
        return paletteColorValid(id) || id === "red" || id === "accent"
    }
    function barColorLabel(id) {
        if (id === "color01" || id === "red" || id === "accent") return "Color 01"
        if (id === "color02") return "Color 02"
        if (id === "color03") return "Color 03"
        if (id === "color04") return "Color 04"
        if (id === "color05") return "Color 05"
        if (id === "color06") return "Color 06"
        if (id === "color07") return "Color 07"
        if (id === "foreground") return "Foreground"
        return "Color 01"
    }

    readonly property string mono:  "JetBrainsMono Nerd Font"

    // ── transparency knobs (0.0 = fully transparent, 1.0 = opaque) ──
    property real barOpacity:  0.94   // durchgehende V2-Leiste
    property real pillOpacity: 0.18   // einzelne Widget-Pillen (workspace, mem, cpu, …)

    readonly property real surfaceOpacity: barOpacity
    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, surfaceOpacity)
    readonly property color barBg:  Qt.rgba(paper.r, paper.g, paper.b, surfaceOpacity)
    readonly property color pill:   Qt.rgba(paper.r, paper.g, paper.b, pillOpacity)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    // ── interactive fill tokens (button/tile backgrounds) ──
    // One source of truth so every panel uses the same hover/active/idle alpha
    // instead of ad-hoc rgba literals scattered across the panels.
    readonly property real  fillActiveAlpha: 0.18
    readonly property real  fillHoverAlpha:  0.10
    readonly property color fillActive:      Qt.rgba(seal.r, seal.g, seal.b, fillActiveAlpha) // selected/active OR ghost-action hover
    readonly property color fillHover:        Qt.rgba(seal.r, seal.g, seal.b, fillHoverAlpha)  // light-seal hover (idle chip → this → fillActive)
    readonly property color fillIdle:         Qt.rgba(0, 0, 0, 0.12)              // resting chip (slight darken)
    // faint, NEUTRAL backdrop behind picker thumbnails — NOT an interactive fill.
    // ink-tinted and much weaker than fillIdle so a thumbnail sits on a quiet frame,
    // not on a dark interactive-looking box.
    readonly property color frameWeak:        Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color fillPrimaryHover: Qt.lighter(seal, 1.15)                // solid-seal button hover
    function evenW(w) { return 2 * Math.round(w / 2) }  // even px width -> integer-centered native text (crisp)

    // ── Multi-monitor popup routing ─────────────────────────────
    // Bars exist per screen, but panels remain singletons. The bar under the
    // pointer publishes its screen + local anchor map before any widget opens a
    // popup, so the singleton panel can move to the correct output.
    property var activePopupScreen: null
    property string activePopupScreenName: ""
    property var barAnchorsByScreen: ({})
    property bool _closingPopups: false
    property var barLayoutControllers: ({})
    property bool _barLayoutSyncing: false

    readonly property bool anyPopupVisible: calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || imagePickerVisible || mediaBrowserVisible || notifVisible
        || powerProfileVisible || storageVisible || archVisible || trayVisible || trayMenuVisible
    readonly property bool keyboardPopupVisible: imagePickerVisible || mediaBrowserVisible

    function registerBarLayoutController(screenName, controller) {
        if (!screenName || !controller) return

        var next = {}
        for (var screen in barLayoutControllers) next[screen] = barLayoutControllers[screen]
        next[screenName] = controller
        barLayoutControllers = next
    }

    function unregisterBarLayoutController(screenName, controller) {
        if (!screenName) return
        if (controller && barLayoutControllers[screenName] !== controller) return

        var next = {}
        for (var screen in barLayoutControllers) {
            if (screen !== screenName) next[screen] = barLayoutControllers[screen]
        }
        barLayoutControllers = next
    }

    function barLayoutControllerScreenValid(screenName) {
        if (!screenName) return false

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i]
            if (screen.name === screenName && screen.width > 0 && screen.height > 0) return true
        }
        return false
    }

    function barLayoutControllerKeys() {
        var keys = []
        for (var screen in barLayoutControllers) {
            if (barLayoutControllerScreenValid(screen)) keys.push(screen)
        }
        keys.sort()
        return keys
    }

    function applyToBarLayoutControllers(actionName) {
        var keys = barLayoutControllerKeys()

        _barLayoutSyncing = true
        try {
            for (var i = 0; i < keys.length; i++) {
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller[actionName]) controller[actionName]()
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function syncBarOrder(sourceScreenName, serialized) {
        if (_barLayoutSyncing || !serialized) return

        _barLayoutSyncing = true
        try {
            var keys = barLayoutControllerKeys()
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] === sourceScreenName) continue
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller.applyOrder) controller.applyOrder(serialized)
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function resetAllBarLayouts() {
        applyToBarLayoutControllers("defaultLayout")
        resetBarLayoutPresentation()
    }

    function resetBarLayoutPresentation() {
        var separatorsChanged = barSeps.length > 0
        var densityChanged = iconOnlyGids.length > 0
        var widgetFillsChanged = resetAllWidgetFillColors()
        var mprisChanged = mprisBarStyle !== "default"

        if (separatorsChanged) barSeps = []
        if (densityChanged) iconOnlyGids = []

        // mprisBarStyle has its own persistence handler. If it was already at
        // the default, persist the other layout-only resets explicitly.
        if (mprisChanged) mprisBarStyle = "default"
        else if ((separatorsChanged || densityChanged || widgetFillsChanged)
                && _widgetsLoaded) saveWidgets()
    }

    function activatePopupScreen(screen) {
        if (!screen || screen.name === "") return

        activePopupScreen = screen
        activePopupScreenName = screen.name
        applyActiveBarAnchors()
    }

    function activateFocusedPopupScreen() {
        var monitor = Hyprland.focusedMonitor
        var targetName = monitor ? monitor.name : ""

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === targetName
                    && candidate.width > 0
                    && candidate.height > 0) {
                activatePopupScreen(candidate)
                return true
            }
        }

        if (activePopupScreenName !== "") return true

        for (var j = 0; j < Quickshell.screens.length; j++) {
            var fallback = Quickshell.screens[j]
            if (fallback.name !== ""
                    && fallback.width > 0
                    && fallback.height > 0) {
                activatePopupScreen(fallback)
                return true
            }
        }

        return false
    }

    function activatePopupScreenByName(screenName) {
        if (screenName) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var candidate = Quickshell.screens[i]
                if (candidate.name === screenName
                        && candidate.width > 0
                        && candidate.height > 0) {
                    activatePopupScreen(candidate)
                    return true
                }
            }
        }

        return activateFocusedPopupScreen()
    }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            if (!theme.keyboardPopupVisible || theme.activePopupScreenName === "") return

            var monitor = Hyprland.focusedMonitor
            var focusedName = monitor ? monitor.name : ""
            if (focusedName !== "" && focusedName !== theme.activePopupScreenName) {
                theme.closePopups()
            }
        }
    }

    function isActivePopupScreenName(screenName) {
        return activePopupScreenName !== "" && screenName === activePopupScreenName
    }

    function applyAnchor(name, x) {
        if (name === "tray") trayBarX = x
        else if (name === "trayCaret") trayCaretBarX = x
        else if (name === "notif") notifBarX = x
        else if (name === "notifCaret") notifCaretBarX = x
        else if (name === "quickActions") quickActionsBarX = x
        else if (name === "volume") volumeBarX = x
        else if (name === "network") networkBarX = x
        else if (name === "battery") batteryBarX = x
        else if (name === "memory") memoryBarX = x
        else if (name === "cpu") cpuBarX = x
        else if (name === "gpu") gpuBarX = x
        else if (name === "thermal") thermalBarX = x
        else if (name === "storage") storageBarX = x
        else if (name === "ai") aiBarX = x
        else if (name === "workspace") workspaceBarX = x
        else if (name === "arch") archBarX = x
        else if (name === "archCaret") archCaretBarX = x
        else if (name === "bluetooth") bluetoothBarX = x
        else if (name === "brightness") brightnessBarX = x
        else if (name === "power") powerBarX = x
        else if (name === "mpris") mprisBarX = x
        else if (name === "weather") weatherBarX = x
        else if (name === "calendar") calendarBarX = x
        else if (name === "launcher") launcherBarX = x
        else if (name === "trayMenu") trayMenuX = x
    }

    function applyActiveBarAnchors() {
        var anchors = activePopupScreenName ? barAnchorsByScreen[activePopupScreenName] : null
        if (!anchors) return

        for (var name in anchors) applyAnchor(name, anchors[name])
    }

    function publishBarAnchors(screenName, anchors) {
        if (!screenName || !anchors) return

        var next = {}
        for (var screen in barAnchorsByScreen) next[screen] = barAnchorsByScreen[screen]
        next[screenName] = anchors
        barAnchorsByScreen = next

        if (screenName === activePopupScreenName) applyActiveBarAnchors()
    }

    function setPanelAnchor(name, x, screenName) {
        var targetScreen = screenName || activePopupScreenName
        if (targetScreen) {
            var next = {}
            for (var screen in barAnchorsByScreen) next[screen] = barAnchorsByScreen[screen]

            var current = next[targetScreen] || {}
            var anchors = {}
            for (var key in current) anchors[key] = current[key]
            anchors[name] = x
            next[targetScreen] = anchors
            barAnchorsByScreen = next
        }

        if (!targetScreen || targetScreen === activePopupScreenName) applyAnchor(name, x)
    }

    function closePopups(except) {
        _closingPopups = true
        if (except !== "calendarVisible") calendarVisible = false
        if (except !== "cpuVisible") cpuVisible = false
        if (except !== "gpuVisible") gpuVisible = false
        if (except !== "thermalVisible") thermalVisible = false
        if (except !== "aiUsageVisible") aiUsageVisible = false
        if (except !== "memVisible") memVisible = false
        if (except !== "volVisible") volVisible = false
        if (except !== "controlVisible") controlVisible = false
        if (except !== "networkVisible") networkVisible = false
        if (except !== "bluetoothVisible") bluetoothVisible = false
        if (except !== "batteryVisible") batteryVisible = false
        if (except !== "brightnessVisible") brightnessVisible = false
        if (except !== "mprisVisible") mprisVisible = false
        if (except !== "weatherVisible") weatherVisible = false
        if (except !== "workspaceVisible") workspaceVisible = false
        if (except !== "imagePickerVisible") imagePickerVisible = false
        if (except !== "mediaBrowserVisible") mediaBrowserVisible = false
        if (except !== "notifVisible") notifVisible = false
        if (except !== "powerProfileVisible") powerProfileVisible = false
        if (except !== "storageVisible") storageVisible = false
        if (except !== "archVisible") archVisible = false
        if (except !== "trayVisible") trayVisible = false
        if (except !== "trayMenuVisible") trayMenuVisible = false
        hideTooltip()
        _closingPopups = false
    }

    function popupUsesConnectedInset(prop) {
        return prop !== "imagePickerVisible"
            && prop !== "mediaBrowserVisible"
            && prop !== "trayMenuVisible"
    }

    function popupOpened(prop) {
        if (!_closingPopups && theme[prop]) {
            // The new panel surface publishes its clamped caret position on the
            // first reveal tick. Invalidate the previous panel's cached position
            // now so the bar cannot render one frame at that stale anchor.
            if (popupUsesConnectedInset(prop)) panelInsetReady = false
            closePopups(prop)
        }
    }

    function openImagePicker(mode, screen) {
        if (imagePickerVisible && imagePickerMode !== mode)
            imagePickerVisible = false
        if (screen && screen.name !== "") activatePopupScreen(screen)
        else activateFocusedPopupScreen()
        mediaBrowserVisible = false
        imagePickerMode = mode
        imagePickerVisible = true
    }

    function toggleImagePicker(mode, screen) {
        if (imagePickerVisible && imagePickerMode === mode) {
            imagePickerVisible = false
            return
        }

        openImagePicker(mode, screen)
    }

    function openMediaBrowser(mode) {
        if (mediaBrowserVisible && mediaBrowserMode !== mode)
            mediaBrowserVisible = false
        activateFocusedPopupScreen()
        imagePickerVisible = false
        mediaBrowserMode = mode
        mediaBrowserVisible = true
    }

    // ── pill/card border (default, non-borderless mode) ──
    // A premium "inactive window border" look: the surface tone (paper) nudged a
    // tick toward the foreground (ink) → a quiet edge a touch brighter than the
    // background, theme-aware in BOTH dark and light palettes. Tune via pillBorderMix.
    property real pillBorderMix: 0.13
    readonly property color pillBorder: Qt.rgba(
        paper.r * (1 - pillBorderMix) + ink.r * pillBorderMix,
        paper.g * (1 - pillBorderMix) + ink.g * pillBorderMix,
        paper.b * (1 - pillBorderMix) + ink.b * pillBorderMix, 1.0)
    // outer frame (the island edge against the wallpaper): a tick brighter than
    // the inner pill border so the bar lifts off the background → two readable
    // borders (subtle inner pills + a defined outer frame).
    property real islandBorderMix: 0.16
    readonly property color islandBorder: Qt.rgba(
        paper.r * (1 - islandBorderMix) + ink.r * islandBorderMix,
        paper.g * (1 - islandBorderMix) + ink.g * islandBorderMix,
        paper.b * (1 - islandBorderMix) + ink.b * islandBorderMix, 1.0)

    // ── V2 continuous edge-bar tokens ──
    // The compact visible strip uses one full-width surface, one quiet
    // screen-facing edge and a shadow cast away from that edge. Keeping these
    // separate from the pill recipe lets widgets and panels retain their
    // established hierarchy.
    readonly property int v2BarHeight: 33
    readonly property int v2NotchFrameThickness: 6
    readonly property int v2NotchFrameRadius: 14
    // Horizontal rhythm for the bar. Closely related icon buttons use the
    // 2px cluster step; icon+text pairs use 4px; independent widgets use 6px;
    // distinct information sections use 8px. A compact action cell stays 22px
    // wide, yielding a calm 24px centre-to-centre pitch inside icon clusters.
    readonly property int v2IconClusterSpacing: 2
    readonly property int v2InlineSpacing: 4
    readonly property int v2WidgetSpacing: 6
    readonly property int v2SectionSpacing: 8
    readonly property int v2ActionIconCellWidth: 22
    readonly property int v2IconGroupPadding: 5
    property real v2BarBorderMix: 0.22
    readonly property color v2BarBorder: Qt.rgba(
        paper.r * (1 - v2BarBorderMix) + ink.r * v2BarBorderMix,
        paper.g * (1 - v2BarBorderMix) + ink.g * v2BarBorderMix,
        paper.b * (1 - v2BarBorderMix) + ink.b * v2BarBorderMix, 1.0)
    readonly property color v2BarShadow: Qt.rgba(0, 0, 0, 0.46)
    // Popovers, tooltips and their interactive tiles share the calmer V2 shape;
    // bar-widget pills remain independently configurable below.
    readonly property int panelRadius: 6
    readonly property int panelButtonRadius: 6
    readonly property color panelBorder: v2BarBorder
    readonly property int panelBorderW: 1
    readonly property color panelOuterBorderColor: panelTooltipBorderEnabled
        ? panelBorder : Qt.rgba(0, 0, 0, 0)
    readonly property int panelOuterBorderW: panelTooltipBorderEnabled ? panelBorderW : 0

    // Fixed V2 geometry. The former Style section was removed; keeping these
    // shared constants avoids duplicating the established dimensions.
    readonly property int   pillRadius:   12
    readonly property int   pillH:        24
    readonly property int   pillBorderW:  1
    readonly property int   islandRadius: 16
    readonly property int   tileRadius:   10
    readonly property int   wsPillPad:    0
    readonly property color pillShadow:   Qt.rgba(0, 0, 0, 0.55)   // dark, theme-independent

    property string lastAppliedName: ""

    // ── Tooltip state ──
    property string tooltipText: ""
    property real tooltipX: 0
    property real tooltipY: 0
    property real tooltipTopY: 0
    property real tooltipBottomY: 0
    property bool tooltipShown: false
    property var tooltipOwner: null   // the widget currently owning the tooltip

    function showTooltip(text, x, topY, bottomY, owner) {
        if (!text) return;
        tooltipText = text;
        tooltipX = x;
        tooltipTopY = topY;
        tooltipBottomY = bottomY;
        tooltipY = (topY + bottomY) / 2;
        tooltipOwner = owner !== undefined ? owner : null;
        tooltipShown = true;
    }

    // hide only if the caller owns the current tooltip (owner match is stable
    // even when the tooltip text changes, e.g. a live timer). A null/undefined
    // owner force-hides. Legacy string args fall back to a text match.
    function hideTooltip(owner) {
        if (owner === undefined || owner === null) {
            tooltipShown = false; tooltipOwner = null;
        } else if (typeof owner === "object") {
            if (tooltipOwner === owner) { tooltipShown = false; tooltipOwner = null; }
        } else if (tooltipText === owner) {
            tooltipShown = false; tooltipOwner = null;
        }
    }

    // safety net: if the owning widget disappears while its tooltip is shown
    // (e.g. ScreenRecord stops mid-hover, or a slot widget gets disabled), force-hide.
    // Via Connections — NOT a `_visible` property whose change-handler writes
    // tooltipOwner (that property read tooltipOwner → binding loop).
    Connections {
        target: theme.tooltipOwner
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (theme.tooltipOwner && !theme.tooltipOwner.visible) {
                theme.tooltipShown = false; theme.tooltipOwner = null;
            }
        }
    }

    // ── Calendar state ──
    property bool calendarVisible: false
    onCalendarVisibleChanged: popupOpened("calendarVisible")
    property int calendarMonthOffset: 0
    property int calendarTick: 0
    property int selectedDay: 0

    readonly property var calendarCells: {
        calendarTick;
        const now = new Date();
        const first = new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
        const year = first.getFullYear();
        const month = first.getMonth();
        const lastDay = new Date(year, month + 1, 0).getDate();
        const startDay = (first.getDay() + 6) % 7;
        const today = new Date();
        const isCurrentMonth = year === today.getFullYear() && month === today.getMonth();
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({day: 0, today: false});
        for (let d = 1; d <= lastDay; d++) {
            cells.push({day: d, today: isCurrentMonth && d === today.getDate()});
        }
        while (cells.length < 42) cells.push({day: 0, today: false});
        return cells;
    }

    readonly property string calendarMonthName: {
        const months = ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                        "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"];
        const now = new Date();
        return months[(now.getMonth() + calendarMonthOffset + 12000) % 12];
    }

    readonly property string calendarYear: {
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
        return String(d.getFullYear());
    }

    function openCalendar() {
        calendarMonthOffset = 0;
        calendarTick++;
        selectedDay = (new Date()).getDate();
        calendarVisible = true;
    }

    // ── CPU panel state ──
    property bool cpuVisible: false
    onCpuVisibleChanged: popupOpened("cpuVisible")

    // ── GPU panel state ──
    property bool gpuVisible: false
    onGpuVisibleChanged: popupOpened("gpuVisible")

    // ── Thermal panel state ──
    property bool thermalVisible: false
    onThermalVisibleChanged: popupOpened("thermalVisible")

    // ── AI usage panel state + which tool the bar pill shows ──
    property bool   aiUsageVisible: false
    property real   aiUsageReveal: aiUsageVisible ? 1 : 0
    Behavior on aiUsageReveal {
        NumberAnimation {
            duration: theme.aiUsageVisible ? 160 : 120
            easing.type: theme.aiUsageVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    onAiUsageVisibleChanged: {
        popupOpened("aiUsageVisible")
        if (aiUsageVisible) refreshAiUsage()
    }
    property string aiTool: "claude"   // "claude", "codex", or "opencode" — icon shown in the bar

    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (ClaudeWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".
    property bool   aiClHas: false
    property bool   aiClFresh: false
    property int    aiClPct5h: 0
    property int    aiClPct7d: 0
    property bool   aiClBlocked: false
    property string aiClTokens: ""
    property string aiClRate: ""
    property int    aiClReset5hTs: 0
    property int    aiClReset7dTs: 0
    property int    aiClToday: 0

    property bool   aiCxHas: false
    property bool   aiCxFresh: false
    property int    aiCxPct5h: 0
    property int    aiCxPct7d: 0
    property string aiCxPlan: ""
    property string aiCxTokens: ""
    property string aiCxRate: ""
    property int    aiCxReset5hTs: 0
    property int    aiCxReset7dTs: 0
    property int    aiCxToday: 0
    property var    aiCxBuckets: []
    property var    aiCxWindows: []
    property int    aiCxPrimaryPct: 0
    property string aiCxPrimaryLabel: ""
    property int    aiCxPrimaryResetTs: 0
    property int    aiCxQuotaPct: 0
    property string aiCxQuotaLabel: ""
    property string aiCxLimitStatus: ""
    property string aiCxLimitReachedType: ""

    property bool   aiOcHas: false
    property bool   aiOcFresh: false
    property int    aiOcPct5h: 0
    property int    aiOcPct7d: 0
    property string aiOcPlan: ""
    property string aiOcTokens: ""
    property string aiOcRate: ""
    property string aiOcModel: ""
    property int    aiOcToday: 0
    property var    aiOcModels: []
    property int    aiClockTick: 0

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100))) }

    function aiWindowLabel(minutes) {
        if (minutes === 300) return "5h"
        if (minutes === 10080) return "Weekly"
        if (minutes > 0 && minutes % 1440 === 0) return (minutes / 1440) + "d"
        if (minutes > 0 && minutes % 60 === 0) return (minutes / 60) + "h"
        return minutes > 0 ? minutes + "m" : "window"
    }

    function aiResetCodexUsage() {
        aiCxHas = false; aiCxFresh = false
        aiCxPct5h = 0; aiCxPct7d = 0
        aiCxPlan = ""; aiCxTokens = ""; aiCxRate = ""; aiCxToday = 0
        aiCxReset5hTs = 0; aiCxReset7dTs = 0
        aiCxBuckets = []; aiCxWindows = []
        aiCxPrimaryPct = 0; aiCxPrimaryLabel = ""; aiCxPrimaryResetTs = 0
        aiCxQuotaPct = 0; aiCxQuotaLabel = ""
        aiCxLimitStatus = ""; aiCxLimitReachedType = ""
    }

    function aiCodexWindowFromCache(w) {
        w = w || {}
        var minutes = parseInt(w.minutes) || 0
        return {
            kind: String(w.kind || ""),
            minutes: minutes,
            label: String(w.label || theme.aiWindowLabel(minutes)),
            pct: theme.aiPct(w.utilization),
            resetTs: parseInt(w.reset) || 0
        }
    }

    function aiCodexWindowsFromArray(arr) {
        var out = []
        if (!arr || arr.length === undefined) return out
        for (var i = 0; i < arr.length; i++) {
            out.push(theme.aiCodexWindowFromCache(arr[i]))
        }
        return out
    }

    function aiCodexLegacyWindowsFromCache(d) {
        var out = []
        if (!d) return out
        var has5 = d["5h-utilization"] !== undefined && String(d["5h-utilization"]) !== ""
        var has7 = d["7d-utilization"] !== undefined && String(d["7d-utilization"]) !== ""
        if (has5 || parseInt(d["5h-reset"]) > 0)
            out.push({ kind: "primary", minutes: 300, label: "5h", pct: theme.aiPct(d["5h-utilization"]), resetTs: parseInt(d["5h-reset"]) || 0 })
        if (has7 || parseInt(d["7d-reset"]) > 0)
            out.push({ kind: "secondary", minutes: 10080, label: "Weekly", pct: theme.aiPct(d["7d-utilization"]), resetTs: parseInt(d["7d-reset"]) || 0 })
        return out
    }

    function aiCodexBucketsFromCache(d) {
        var buckets = []
        if (d && parseInt(d.schemaVersion) === 3 && d.buckets && d.buckets.length !== undefined) {
            for (var i = 0; i < d.buckets.length; i++) {
                var b = d.buckets[i] || {}
                var windows = theme.aiCodexWindowsFromArray(b.windows)
                if (windows.length === 0) continue
                buckets.push({
                    id: String(b.id || ""),
                    label: String(b.label || b.id || "Codex"),
                    isGeneral: b.isGeneral === true,
                    windows: windows,
                    plan: String(b.plan || ""),
                    rateLimitReachedType: String(b.rateLimitReachedType || "")
                })
            }
        } else if (d && parseInt(d.schemaVersion) === 2 && d.windows && d.windows.length !== undefined) {
            var win2 = theme.aiCodexWindowsFromArray(d.windows)
            if (win2.length > 0)
                buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: win2, plan: String(d._plan || "") })
        } else {
            var legacy = theme.aiCodexLegacyWindowsFromCache(d)
            if (legacy.length > 0)
                buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: legacy, plan: String((d && d._plan) || "") })
        }
        return buckets
    }

    function aiCodexGeneralBucket(buckets) {
        for (var i = 0; i < buckets.length; i++) {
            if (buckets[i].isGeneral === true || buckets[i].id === "codex") return buckets[i]
        }
        return { windows: [] }
    }

    function aiPlanLabel(plan) {
        var p = String(plan || "").toLowerCase()
        if (p === "prolite") return "Pro Lite"
        if (p === "pro") return "Pro"
        if (p === "plus") return "Plus"
        if (p === "team" || p === "business") return "Business"
        if (p === "enterprise") return "Enterprise"
        if (p === "edu") return "Edu"
        if (p === "free") return "Free"
        return String(plan || "")
    }

    function aiApplyCodexCache(d, ageOk) {
        var buckets = theme.aiCodexBucketsFromCache(d)
        var general = theme.aiCodexGeneralBucket(buckets)
        var windows = general.windows || []
        theme.aiCxHas = windows.length > 0
        theme.aiCxFresh = ageOk && d._source !== "stale"
        theme.aiCxBuckets = buckets
        theme.aiCxWindows = windows
        theme.aiCxPlan = theme.aiPlanLabel(d._plan || general.plan || "")
        theme.aiCxPct5h = 0; theme.aiCxPct7d = 0
        theme.aiCxReset5hTs = 0; theme.aiCxReset7dTs = 0
        theme.aiCxQuotaPct = 0
        theme.aiCxQuotaLabel = ""
        theme.aiCxLimitStatus = String(d.status || "")
        theme.aiCxLimitReachedType = String(d._limit_reached_type || general.rateLimitReachedType || "")
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i]
            if (i === 0) {
                theme.aiCxPrimaryPct = w.pct
                theme.aiCxPrimaryLabel = w.label
                theme.aiCxPrimaryResetTs = w.resetTs
            }
            if (w.minutes === 300) { theme.aiCxPct5h = w.pct; theme.aiCxReset5hTs = w.resetTs }
            else if (w.minutes === 10080) { theme.aiCxPct7d = w.pct; theme.aiCxReset7dTs = w.resetTs }
            if (w.pct > theme.aiCxQuotaPct) {
                theme.aiCxQuotaPct = w.pct
                theme.aiCxQuotaLabel = String(general.label || "Codex") + " " + String(w.label || "window")
            }
        }
        if (windows.length === 0) {
            theme.aiCxPrimaryPct = 0
            theme.aiCxPrimaryLabel = ""
            theme.aiCxPrimaryResetTs = 0
        }
        var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
        theme.aiCxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
        theme.aiCxToday = parseInt(d._today_tokens) || 0
        theme.aiCxTokens = ""
    }

    function aiCodexStatusLabel(status, reachedType) {
        if (status === "rejected")
            return reachedType ? "reached (" + reachedType + ")" : "reached"
        if (status === "allowed_warning") return "warning"
        if (status === "allowed") return "ok (not reached)"
        return "unknown"
    }

    function aiFmtReset(ts) {
        aiClockTick
        var now = Date.now() / 1000
        if (!(ts > now)) return ""
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

    function aiPad2(n) { return n < 10 ? "0" + n : "" + n }

    function aiFmtResetClock(ts) {
        aiClockTick
        if (!(ts > Date.now() / 1000)) return ""
        var d = new Date(ts * 1000)
        var now = new Date()
        var day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        var resetDay0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
        var dayDelta = Math.round((resetDay0 - day0) / 86400000)
        var time = aiPad2(d.getHours()) + ":" + aiPad2(d.getMinutes())
        if (dayDelta <= 0) return time
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[d.getDay()] + " " + time
    }

    function aiFmtResetDetail(ts) {
        var rel = aiFmtReset(ts)
        var clock = aiFmtResetClock(ts)
        return rel && clock ? rel + " • " + clock : (rel || clock)
    }

    Process {
        id: aiReadClaude
        command: ["bash", "-c",
            "f=\"$HOME/.cache/claude-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiClHas = true
                    theme.aiClFresh = ageOk && d._source !== "stale"
                    theme.aiClPct5h = theme.aiPct(d["5h-utilization"])
                    theme.aiClPct7d = theme.aiPct(d["7d-utilization"])
                    theme.aiClBlocked = d.status === "rejected" || d.status === "blocked"
                    theme.aiClReset5hTs = parseInt(d["5h-reset"]) || 0
                    theme.aiClReset7dTs = parseInt(d["7d-reset"]) || 0
                    var used = (d["_tokens_used"] || 0), lim = (d["_window_limit"] || 0)
                    theme.aiClTokens = used ? (used / 1e6).toFixed(2) + "M / " + (lim / 1e6).toFixed(1) + "M" : ""
                    var rateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    theme.aiClRate = rateH > 0 ? rateH + "k tok/h" : ""
                    theme.aiClToday = parseInt(d._today_tokens) || 0
                } catch (e) {
                    theme.aiClHas = false; theme.aiClFresh = false
                    theme.aiClPct5h = 0; theme.aiClPct7d = 0
                    theme.aiClBlocked = false; theme.aiClTokens = ""; theme.aiClRate = ""
                    theme.aiClReset5hTs = 0; theme.aiClReset7dTs = 0; theme.aiClToday = 0
                }
            }
        }
    }

    Process {
        id: aiReadCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiApplyCodexCache(d, ageOk)
                } catch (e) {
                    theme.aiResetCodexUsage()
                }
            }
        }
    }

    Process {
        id: aiReadOpenCode
        command: ["bash", "-c",
            "f=\"$HOME/.cache/opencode-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiOcHas = true
                    theme.aiOcFresh = ageOk && d._source !== "stale"
                    theme.aiOcPct5h = theme.aiPct(d["5h-utilization"])
                    theme.aiOcPct7d = theme.aiPct(d["7d-utilization"])
                    theme.aiOcPlan = d._plan || ""
                    var ocUsed = (d["_tokens_used"] || 0), ocLim = (d["_window_limit"] || 0)
                    theme.aiOcTokens = ocUsed ? (ocUsed / 1e6).toFixed(2) + "M / " + (ocLim / 1e6).toFixed(1) + "M" : ""
                    var ocRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    theme.aiOcRate = ocRateH > 0 ? ocRateH + "k tok/h" : ""
                    theme.aiOcToday = parseInt(d._today_tokens) || 0
                    theme.aiOcModel = d._model || ""
                    theme.aiOcModels = d._models instanceof Array ? d._models : []
                } catch (e) {
                    theme.aiOcHas = false; theme.aiOcFresh = false
                    theme.aiOcPct5h = 0; theme.aiOcPct7d = 0
                    theme.aiOcPlan = ""; theme.aiOcTokens = ""; theme.aiOcRate = ""; theme.aiOcModel = ""
                    theme.aiOcToday = 0; theme.aiOcModels = []
                }
            }
        }
    }

    function refreshAiUsage(selectedOnly) {
        aiClockTick++
        var only = selectedOnly === true
        if (!only || aiTool === "claude") {
            aiReadClaude.running = false; aiReadClaude.running = true
        }
        if (!only || aiTool === "codex") {
            aiReadCodex.running = false;  aiReadCodex.running = true
        }
        if (!only || aiTool === "opencode") {
            aiReadOpenCode.running = false; aiReadOpenCode.running = true
        }
    }

    Timer {
        // 30s normally; 5s while the AI panel is open (responsive when looked at)
        interval: theme.aiUsageVisible ? 5000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: theme.refreshAiUsage(theme.aiUsageVisible)
    }

    // ── Central system telemetry ──
    // One ShellRoot-level sampler feeds all monitor BarSlots. This replaces
    // per-widget bash/awk polling for CPU and memory, so adding monitors does not
    // multiply these status process chains.
    property int systemCpuPercent: 0
    property int systemCpuUserPercent: 0
    property int systemCpuSystemPercent: 0
    property int systemCpuIoWaitPercent: 0
    property real _systemCpuPrevIdle: -1
    property real _systemCpuPrevTotal: -1
    property real _systemCpuPrevUser: -1
    property real _systemCpuPrevSystem: -1
    property real _systemCpuPrevIoWait: -1
    property string cpuModelName: ""
    property int cpuCoreCount: 0
    property int cpuThreadCount: 0
    property int cpuClockMHz: 0
    property int cpuMaxClockMHz: 0
    property string cpuEnergyPreference: ""
    property string cpuScalingGovernor: ""
    property int cpuThrottleCount: 0
    property real systemLoad1: 0
    property real systemLoad5: 0
    property real systemLoad15: 0
    property string kernelRelease: ""
    property var cpuTopProcesses: []

    property int systemMemTotalMiB: 0
    property int systemMemAvailMiB: 0
    property int systemMemFreeMiB: 0
    property int systemMemBuffersMiB: 0
    property int systemMemCachedMiB: 0
    property string memoryType: ""
    property int memorySpeedMTs: 0
    readonly property int systemMemUsedMiB: Math.max(0, systemMemTotalMiB - systemMemAvailMiB)
    readonly property int systemMemPercent: systemMemTotalMiB > 0
        ? Math.max(0, Math.min(100, Math.round(systemMemUsedMiB / systemMemTotalMiB * 100)))
        : 0
    readonly property real systemMemUsedGiB: systemMemUsedMiB / 1024
    readonly property real systemMemTotalGiB: systemMemTotalMiB / 1024

    // Compact V2 telemetry. These samplers live on the singleton Theme so a
    // second monitor adds another view, not another nvidia-smi/df/hwmon poller.
    property string gpuBackend: ""
    property string gpuName: ""
    property string gpuDriverVersion: ""
    property int gpuPercent: 0
    property int gpuTemperatureC: 0
    property int gpuMemoryUsedMiB: 0
    property int gpuMemoryTotalMiB: 0
    property int gpuClockMHz: 0
    property real gpuPowerW: 0
    property real gpuPowerLimitW: 0
    property string gpuPerformanceState: ""
    property int gpuFanPercent: 0
    readonly property bool gpuAvailable: gpuBackend !== ""

    property int cpuTemperatureC: 0
    property int cpuCoreMaxTemperatureC: 0
    property int cpuTemperatureMaxC: 0
    property int cpuTemperatureCriticalC: 0
    property int nvmeTemperatureC: 0
    property int nvmeTemperatureMaxC: 0
    property int nvmeTemperatureCriticalC: 0
    property int memoryTemperatureC: 0
    readonly property bool cpuTemperatureAvailable: cpuTemperatureC > 0

    property string barTemperatureSource: "cpu"
    readonly property int barTemperatureC: barTemperatureSource === "core" ? cpuCoreMaxTemperatureC
        : barTemperatureSource === "gpu" ? gpuTemperatureC
        : barTemperatureSource === "nvme" ? nvmeTemperatureC
        : barTemperatureSource === "memory" ? memoryTemperatureC
        : cpuTemperatureC
    readonly property bool barTemperatureAvailable: barTemperatureC > 0

    function barTemperatureSourceValid(source) {
        return source === "cpu" || source === "core" || source === "gpu"
            || source === "nvme" || source === "memory"
    }
    function barTemperatureSourceLabel(source) {
        if (source === "core") return "Hottest CPU core"
        if (source === "gpu") return "GPU"
        if (source === "nvme") return "NVMe"
        if (source === "memory") return "Memory"
        return "CPU package"
    }
    function barTemperatureSourceAvailable(source) {
        if (source === "core") return cpuCoreMaxTemperatureC > 0
        if (source === "gpu") return gpuTemperatureC > 0
        if (source === "nvme") return nvmeTemperatureC > 0
        if (source === "memory") return memoryTemperatureC > 0
        return cpuTemperatureC > 0
    }

    property int storagePercent: 0
    property real storageUsedBytes: 0
    property real storageTotalBytes: 0
    property bool storageAvailable: false
    readonly property real storageUsedGiB: storageUsedBytes / 1073741824
    readonly property real storageTotalGiB: storageTotalBytes / 1073741824
    property var storageDrives: []
    property bool storageInventoryAvailable: false

    function parseSystemCpu(text) {
        var lines = String(text || "").split("\n")
        if (lines.length === 0 || lines[0].indexOf("cpu ") !== 0) return
        var parts = lines[0].trim().split(/\s+/)
        if (parts.length < 8) return

        function field(index) {
            var value = parseFloat(parts[index])
            return isNaN(value) ? 0 : value
        }
        var user = field(1) + field(2)
        var system = field(3) + field(6) + field(7) + field(8)
        var ioWait = field(5)
        var idle = field(4) + ioWait
        var total = 0
        for (var i = 1; i < parts.length; i++) {
            var v = parseFloat(parts[i])
            if (!isNaN(v)) total += v
        }
        if (isNaN(idle) || isNaN(total) || total <= 0) return

        if (_systemCpuPrevTotal >= 0 && total > _systemCpuPrevTotal) {
            var totalDelta = total - _systemCpuPrevTotal
            var idleDelta = idle - _systemCpuPrevIdle
            var busy = totalDelta > 0 ? Math.round((totalDelta - idleDelta) / totalDelta * 100) : 0
            systemCpuPercent = Math.max(0, Math.min(100, busy))
            systemCpuUserPercent = Math.max(0, Math.min(100,
                Math.round((user - _systemCpuPrevUser) / totalDelta * 100)))
            systemCpuSystemPercent = Math.max(0, Math.min(100,
                Math.round((system - _systemCpuPrevSystem) / totalDelta * 100)))
            systemCpuIoWaitPercent = Math.max(0, Math.min(100,
                Math.round((ioWait - _systemCpuPrevIoWait) / totalDelta * 100)))
        }

        _systemCpuPrevIdle = idle
        _systemCpuPrevTotal = total
        _systemCpuPrevUser = user
        _systemCpuPrevSystem = system
        _systemCpuPrevIoWait = ioWait
    }

    function parseCpuInfo(text) {
        var blocks = String(text || "").trim().split(/\n\s*\n/)
        var model = ""
        var threads = 0
        var cores = {}
        var fallbackCores = 0

        for (var i = 0; i < blocks.length; i++) {
            var lines = blocks[i].split("\n")
            var physical = "0"
            var core = ""
            var processorFound = false
            for (var j = 0; j < lines.length; j++) {
                var splitAt = lines[j].indexOf(":")
                if (splitAt < 0) continue
                var key = lines[j].slice(0, splitAt).trim()
                var value = lines[j].slice(splitAt + 1).trim()
                if (key === "processor") processorFound = true
                else if ((key === "model name" || key === "Hardware") && model === "") model = value
                else if (key === "physical id") physical = value
                else if (key === "core id") core = value
                else if (key === "cpu cores" && fallbackCores === 0) fallbackCores = parseInt(value) || 0
            }
            if (processorFound) threads++
            if (core !== "") cores[physical + ":" + core] = true
        }

        cpuModelName = model.replace(/\(R\)|\(TM\)/g, "")
            .replace(/\s+CPU\s+@\s+.*$/, "").replace(/\s+/g, " ").trim()
        cpuThreadCount = threads
        var coreKeys = Object.keys(cores)
        cpuCoreCount = coreKeys.length > 0 ? coreKeys.length : fallbackCores
    }

    function parseSystemLoad(text) {
        var fields = String(text || "").trim().split(/\s+/)
        if (fields.length < 3) return
        systemLoad1 = parseFloat(fields[0]) || 0
        systemLoad5 = parseFloat(fields[1]) || 0
        systemLoad15 = parseFloat(fields[2]) || 0
    }

    function parseCpuDetail(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 5) return
        cpuClockMHz = Math.max(0, parseInt(fields[0]) || 0)
        cpuMaxClockMHz = Math.max(0, parseInt(fields[1]) || 0)
        cpuEnergyPreference = String(fields[2] || "").trim()
        cpuScalingGovernor = String(fields[3] || "").trim()
        cpuThrottleCount = Math.max(0, parseInt(fields[4]) || 0)
    }

    function parseCpuTopProcesses(text) {
        var lines = String(text || "").split("\n")
        var processes = []
        for (var i = 0; i < lines.length && processes.length < 3; i++) {
            var match = lines[i].trim().match(/^(.*\S)\s+([0-9]+(?:[.,][0-9]+)?)$/)
            if (!match || match[1] === "ps") continue
            var percent = parseFloat(match[2].replace(",", "."))
            if (isNaN(percent)) continue
            processes.push({ name: match[1], percent: percent })
        }
        cpuTopProcesses = processes
    }

    function parseSystemMem(text) {
        var total = 0, avail = 0, free = 0, buffers = 0, cached = 0
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)
            if (parts.length < 2) continue
            var value = parseInt(parts[1])
            if (isNaN(value)) continue
            if (parts[0] === "MemTotal:") total = value
            else if (parts[0] === "MemAvailable:") avail = value
            else if (parts[0] === "MemFree:") free = value
            else if (parts[0] === "Buffers:") buffers = value
            else if (parts[0] === "Cached:") cached = value
        }
        if (total <= 0) return
        systemMemTotalMiB = Math.round(total / 1024)
        systemMemAvailMiB = Math.round(avail / 1024)
        systemMemFreeMiB = Math.round(free / 1024)
        systemMemBuffersMiB = Math.round(buffers / 1024)
        systemMemCachedMiB = Math.round(cached / 1024)
    }

    function parseMemoryHardware(text) {
        var raw = String(text || "")
        var matcher = /type:\s*(DDR[0-9]+)\b[^\n]*\bspeed:\s*([0-9]+)\s*MT\/s/gi
        var match
        var type = ""
        var speed = 0
        while ((match = matcher.exec(raw)) !== null) {
            var candidate = parseInt(match[2]) || 0
            if (type === "") type = match[1].toUpperCase()
            if (candidate > 0 && (speed === 0 || candidate < speed)) speed = candidate
        }
        memoryType = type
        memorySpeedMTs = speed
    }

    function parseGpuTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 12 || fields[0] === "none") {
            gpuBackend = ""
            gpuName = ""
            gpuDriverVersion = ""
            gpuPercent = 0
            gpuTemperatureC = 0
            gpuMemoryUsedMiB = 0
            gpuMemoryTotalMiB = 0
            gpuClockMHz = 0
            gpuPowerW = 0
            gpuPowerLimitW = 0
            gpuPerformanceState = ""
            gpuFanPercent = 0
            return
        }

        function clean(value) { return String(value || "").trim() }
        function number(value) {
            var parsed = parseFloat(clean(value))
            return isNaN(parsed) ? 0 : parsed
        }

        gpuBackend = clean(fields[0])
        gpuName = clean(fields[1])
        gpuDriverVersion = clean(fields[2])
        gpuPercent = Math.max(0, Math.min(100, Math.round(number(fields[3]))))
        gpuTemperatureC = Math.max(0, Math.round(number(fields[4])))
        gpuMemoryUsedMiB = Math.max(0, Math.round(number(fields[5])))
        gpuMemoryTotalMiB = Math.max(0, Math.round(number(fields[6])))
        gpuClockMHz = Math.max(0, Math.round(number(fields[7])))
        gpuPowerW = Math.max(0, number(fields[8]))
        gpuPowerLimitW = Math.max(0, number(fields[9]))
        gpuPerformanceState = clean(fields[10])
        gpuFanPercent = Math.max(0, Math.min(100, Math.round(number(fields[11]))))
    }

    function parseThermalTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        function thermal(index) {
            var value = parseInt(fields[index])
            return isNaN(value) ? 0 : Math.max(0, Math.min(150, value))
        }
        cpuTemperatureC = thermal(0)
        cpuCoreMaxTemperatureC = thermal(1)
        cpuTemperatureMaxC = thermal(2)
        cpuTemperatureCriticalC = thermal(3)
        nvmeTemperatureC = thermal(4)
        nvmeTemperatureMaxC = thermal(5)
        nvmeTemperatureCriticalC = thermal(6)
        memoryTemperatureC = thermal(7)
    }

    function parseStorageInventory(text) {
        var parsed
        try {
            parsed = JSON.parse(String(text || ""))
        } catch (error) {
            storageInventoryAvailable = false
            storageDrives = []
            return
        }

        var devices = parsed && parsed.blockdevices ? parsed.blockdevices : []
        var drives = []

        function textValue(value) {
            return value === null || value === undefined ? "" : String(value).trim()
        }
        function collectVolumes(node, target) {
            var fs = textValue(node.fstype)
            var mounts = node.mountpoints || []
            var mountedAt = ""
            for (var m = 0; m < mounts.length; m++) {
                var candidate = textValue(mounts[m])
                if (candidate !== "" && candidate !== "[SWAP]") {
                    mountedAt = candidate
                    break
                }
            }
            if (fs !== "") {
                var pct = parseInt(textValue(node["fsuse%"]).replace("%", ""))
                var freeText = textValue(node.fsavail)
                var freeBytes = freeText === "" ? -1 : Number(freeText)
                var usedText = textValue(node.fsused)
                var usedBytes = usedText === "" ? -1 : Number(usedText)
                target.push({
                    fs: fs,
                    mount: mountedAt,
                    percent: isNaN(pct) ? -1 : Math.max(0, Math.min(100, pct)),
                    freeBytes: isNaN(freeBytes) ? -1 : Math.max(0, freeBytes),
                    usedBytes: isNaN(usedBytes) ? -1 : Math.max(0, usedBytes)
                })
            }
            var children = node.children || []
            for (var c = 0; c < children.length; c++) collectVolumes(children[c], target)
        }

        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            var name = textValue(device.name)
            if (device.type !== "disk" || name.indexOf("loop") === 0
                    || name.indexOf("ram") === 0 || name.indexOf("zram") === 0)
                continue

            var volumes = []
            collectVolumes(device, volumes)
            var fileSystems = []
            var mountedAt = ""
            var usage = -1
            var freeBytes = -1
            var usedBytes = -1
            for (var v = 0; v < volumes.length; v++) {
                if (fileSystems.indexOf(volumes[v].fs) < 0) fileSystems.push(volumes[v].fs)
                if (mountedAt === "" && volumes[v].mount !== "") {
                    mountedAt = volumes[v].mount
                    usage = volumes[v].percent
                    freeBytes = volumes[v].freeBytes
                    usedBytes = volumes[v].usedBytes
                }
            }

            var transport = textValue(device.tran).toUpperCase()
            var removable = device.rm === true || device.hotplug === true || transport === "USB"
            var driveType = transport === "NVME" ? "nvme"
                : device.rota === true ? "hdd"
                : "ssd"
            var media = removable ? "USB DRIVE"
                : transport === "NVME" ? "NVME SSD"
                : device.rota === true ? (transport !== "" ? transport + " HDD" : "HDD")
                : (transport !== "" ? transport + " SSD" : "SSD")
            var state = mountedAt !== "" ? mountedAt
                : (fileSystems.length > 0 ? "Not mounted" : "No filesystem")

            drives.push({
                name: name,
                model: textValue(device.model) || name,
                size: Number(device.size) || 0,
                driveType: driveType,
                media: media,
                fileSystems: fileSystems.join(" + ").toUpperCase(),
                state: state,
                percent: usage,
                freeBytes: freeBytes,
                usedBytes: usedBytes,
                totalBytes: usedBytes >= 0 && freeBytes >= 0 ? usedBytes + freeBytes : -1
            })
        }

        storageDrives = drives
        storageInventoryAvailable = true
    }

    function parseStorageTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 3) {
            storageAvailable = false
            storagePercent = 0
            storageUsedBytes = 0
            storageTotalBytes = 0
            return
        }

        var percent = parseInt(fields[0])
        var used = parseFloat(fields[1])
        var total = parseFloat(fields[2])
        if (isNaN(percent) || isNaN(used) || isNaN(total) || total <= 0) {
            storageAvailable = false
            return
        }

        storageAvailable = true
        storagePercent = Math.max(0, Math.min(100, percent))
        storageUsedBytes = Math.max(0, used)
        storageTotalBytes = Math.max(0, total)
    }

    FileView {
        id: systemCpuFile
        path: "/proc/stat"
        onLoaded: theme.parseSystemCpu(systemCpuFile.text())
    }

    FileView {
        id: systemCpuInfoFile
        path: "/proc/cpuinfo"
        onLoaded: theme.parseCpuInfo(systemCpuInfoFile.text())
    }

    FileView {
        id: systemLoadFile
        path: "/proc/loadavg"
        onLoaded: theme.parseSystemLoad(systemLoadFile.text())
    }

    FileView {
        id: kernelReleaseFile
        path: "/proc/sys/kernel/osrelease"
        onLoaded: theme.kernelRelease = String(kernelReleaseFile.text() || "").trim()
    }

    FileView {
        id: systemMemFile
        path: "/proc/meminfo"
        onLoaded: theme.parseSystemMem(systemMemFile.text())
    }

    Process {
        id: cpuDetailProc
        command: ["bash", "-c",
            "sum=0; count=0; max=0; epp=''; governor=''; throttle=0; "
            + "for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do [[ -r $f ]] || continue; IFS= read -r v < \"$f\"; "
            + "[[ $v =~ ^[0-9]+$ ]] || continue; sum=$((sum + v)); count=$((count + 1)); done; "
            + "(( count > 0 )) && avg=$((sum / count / 1000)) || avg=0; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && max=$((v / 1000)); }; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference; [[ -r $f ]] && IFS= read -r epp < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; [[ -r $f ]] && IFS= read -r governor < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && throttle=$v; }; "
            + "printf '%s|%s|%s|%s|%s\\n' \"$avg\" \"$max\" \"$epp\" \"$governor\" \"$throttle\""]
        stdout: StdioCollector { onStreamFinished: theme.parseCpuDetail(this.text) }
    }

    Process {
        id: memoryHardwareProc
        command: ["bash", "-c",
            "if command -v inxi >/dev/null 2>&1; then LC_ALL=C inxi -m -c 0 --no-host 2>/dev/null; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: theme.parseMemoryHardware(this.text) }
    }

    Process {
        id: cpuTopProcessesProc
        command: ["ps", "-eo", "comm=,%cpu=", "--sort=-%cpu"]
        stdout: StdioCollector { onStreamFinished: theme.parseCpuTopProcesses(this.text) }
    }

    Process {
        id: gpuTelemetryProc
        command: ["bash", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then "
            + "IFS=, read -r name driver util temp used total clock power limit pstate fan < <(nvidia-smi --query-gpu=name,driver_version,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.current.graphics,power.draw,power.limit,pstate,fan.speed --format=csv,noheader,nounits 2>/dev/null | head -n1); "
            + "if [[ $util =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $temp =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $used =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $total =~ ^[[:space:]]*[0-9]+[[:space:]]*$ ]]; then "
            + "printf 'nvidia|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$name\" \"$driver\" \"$util\" \"$temp\" \"$used\" \"$total\" \"$clock\" \"$power\" \"$limit\" \"$pstate\" \"$fan\"; exit 0; fi; "
            + "fi; "
            + "for busy in /sys/class/drm/card*/device/gpu_busy_percent; do "
            + "[[ -r $busy ]] || continue; read -r util < \"$busy\"; temp=0; "
            + "for sensor in \"${busy%/gpu_busy_percent}\"/hwmon/hwmon*/temp1_input; do "
            + "[[ -r $sensor ]] || continue; read -r raw < \"$sensor\"; temp=$((raw / 1000)); break; done; "
            + "printf 'sysfs|GPU||%s|%s|0|0|0|0|0||0\\n' \"$util\" \"$temp\"; exit 0; done; "
            + "printf 'none|||||||||||\\n'"]
        stdout: StdioCollector { onStreamFinished: theme.parseGpuTelemetry(this.text) }
    }

    Process {
        id: cpuTemperatureProc
        command: ["bash", "-c",
            "cpu=0; core=0; cpu_max=0; cpu_crit=0; nvme=0; nvme_max=0; nvme_crit=0; dimm=0; "
            + "for d in /sys/class/hwmon/hwmon*; do [[ -r $d/name ]] || continue; IFS= read -r name < \"$d/name\"; "
            + "case $name in coretemp|k10temp|zenpower|cpu_thermal) "
            + "for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; raw=0; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "label_file=${input%_input}_label; label=''; [[ -r $label_file ]] && IFS= read -r label < \"$label_file\"; value=$((raw / 1000)); "
            + "case $label in 'Package id 0'|Tctl|Tdie|'CPU Package'|CPU) cpu=$value; max_file=${input%_input}_max; crit_file=${input%_input}_crit; "
            + "[[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_crit=$((v / 1000)); };; "
            + "Core*) (( value > core )) && core=$value;; esac; (( cpu == 0 )) && cpu=$value; done;; "
            + "nvme) for label_file in \"$d\"/temp*_label; do [[ -r $label_file ]] || continue; IFS= read -r label < \"$label_file\"; [[ $label == Composite ]] || continue; "
            + "input=${label_file%_label}_input; [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; nvme=$((raw / 1000)); "
            + "max_file=${input%_input}_max; crit_file=${input%_input}_crit; [[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_crit=$((v / 1000)); }; break; done;; "
            + "jc42) for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "value=$((raw / 1000)); (( value > dimm )) && dimm=$value; done;; esac; done; "
            + "if (( cpu == 0 )); then for zone in /sys/class/thermal/thermal_zone*; do [[ -r $zone/type && -r $zone/temp ]] || continue; "
            + "IFS= read -r type < \"$zone/type\"; case $type in x86_pkg_temp|cpu-thermal|cpu_thermal) IFS= read -r raw < \"$zone/temp\"; "
            + "[[ $raw =~ ^[0-9]+$ ]] && { cpu=$((raw / 1000)); break; };; esac; done; fi; "
            + "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$cpu\" \"$core\" \"$cpu_max\" \"$cpu_crit\" \"$nvme\" \"$nvme_max\" \"$nvme_crit\" \"$dimm\""]
        stdout: StdioCollector { onStreamFinished: theme.parseThermalTelemetry(this.text) }
    }

    Process {
        id: storageTelemetryProc
        command: ["bash", "-c",
            "LC_ALL=C df -P -B1 / 2>/dev/null | awk 'NR == 2 { gsub(/%/, \"\", $5); printf \"%s|%s|%s\\n\", $5, $3, $2 }'"]
        stdout: StdioCollector { onStreamFinished: theme.parseStorageTelemetry(this.text) }
    }

    Process {
        id: storageInventoryProc
        command: ["lsblk", "-J", "-b", "-o",
            "NAME,PATH,TYPE,SIZE,FSTYPE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG"]
        stdout: StdioCollector { onStreamFinished: theme.parseStorageInventory(this.text) }
    }

    Timer {
        interval: (theme.modCpu || theme.cpuVisible || theme.modMemory || theme.memVisible) ? 2000 : 10000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            systemCpuFile.reload()
            systemLoadFile.reload()
            systemMemFile.reload()
        }
    }

    Timer {
        interval: 2500
        running: theme.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuDetailProc.running) cpuDetailProc.running = true
    }

    Timer {
        interval: 3000
        running: theme.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTopProcessesProc.running) cpuTopProcessesProc.running = true
    }

    Timer {
        interval: 2500
        running: theme.modGpu || theme.gpuVisible || theme.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!gpuTelemetryProc.running) gpuTelemetryProc.running = true
    }

    Timer {
        interval: 5000
        running: theme.modCpuTemperature || theme.cpuVisible || theme.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTemperatureProc.running) cpuTemperatureProc.running = true
    }

    Timer {
        interval: 30000
        running: theme.modStorage || theme.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageTelemetryProc.running) storageTelemetryProc.running = true
    }

    Timer {
        interval: theme.storageVisible ? 5000 : 60000
        running: theme.modStorage || theme.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageInventoryProc.running) storageInventoryProc.running = true
    }

    // ── Memory panel state ──
    property bool memVisible: false
    onMemVisibleChanged: popupOpened("memVisible")

    // ── Volume panel state ──
    property bool volVisible: false
    property real volReveal: volVisible ? 1 : 0
    Behavior on volReveal {
        NumberAnimation {
            duration: theme.volVisible ? 160 : 120
            easing.type: theme.volVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    onVolVisibleChanged: popupOpened("volVisible")

    // ── Control center state ──
    property bool controlVisible: false
    onControlVisibleChanged: {
        popupOpened("controlVisible")
        if (!controlVisible) wwSubVisible = false
    }

    // ── Bar layout / unlock (drag&drop reorder). barUnlocked is transient. ──
    property bool barUnlocked: false
    property var  fnDefaultLayout: function () { theme.resetAllBarLayouts() }
    property bool wwSubVisible: false   // "Widgets & Workspaces" fly-out

    // ── module enable flags (controlled by ControlPanel) ──
    property bool modStatus:     true
    property bool modMemory:     true
    property bool modCpu:        true
    property bool modCpuTemperature: true
    property bool modGpu:        true
    property bool modStorage:    true
    property bool modVolume:     true
    property bool modWeather:    true
    property bool modNetwork:    true
    property string networkMode: "none"   // mirrored from NetworkWidget: wifi/ethernet/none
    // Centralized status indicators. These live on Theme so BarSlot-per-monitor
    // widgets don't each spawn their own status poller.
    property bool stayAwake: false            // idle lock disabled / stay-awake indicator
    readonly property bool hypridleAwake: stayAwake // compatibility alias for older modules
    property bool _idleBackendChecked: false
    property bool _idleRyokuShellBackend: false
    property bool _idleRyokuShellSystem: false
    property bool _omarchyBackendReprobePending: false
    property int _omarchyBackendRetryIndex: 0
    readonly property var _omarchyBackendRetryDelays: [2000, 5000, 15000]
    readonly property string omarchyShellConfigPath: Quickshell.env("HOME") + "/.config/ryoku/shell.json"
    readonly property string idleStatePath: Quickshell.env("HOME") + "/.local/state/ryoku/indicators/stay-awake"
    property bool notifSilenced: false        // notification do-not-disturb mode
    property bool _notifBackendChecked: false
    property bool _notifRyokuShellBackend: false
    property bool _notifRyokuShellSystem: false
    readonly property string notificationsStatePath: Quickshell.env("HOME") + "/.local/state/ryoku/notifications.json"
    property bool screenRecording: false
    property int screenRecordingElapsed: 0
    property string _screenRecordingPid: ""
    property string _screenRecordingElapsedProbePid: ""
    property int _screenRecordingBaseElapsed: 0
    property real _screenRecordingBaseMs: 0
    readonly property string screenRecordingStatePath: "/tmp/ryoku-screenrecord-filename"
    property bool _recordingRefreshPending: false
    property string voxState: "idle"          // idle/recording/transcribing
    property string voxHint: ""
    property bool voxAvailable: true
    readonly property bool _statusPollingWanted: modStatus
    readonly property bool _voxActive: voxState === "recording" || voxState === "transcribing"

    function refreshIdleStatus() {
        if (!_idleBackendChecked) return
        if (_idleRyokuShellSystem) {
            idleStateFile.reload()
            return
        }
        if (!idleProc.running) idleProc.running = true
    }
    function refreshStatusIndicators() {
        refreshIdleStatus()
        refreshNotificationStatus()
    }
    function reprobeRyokuShellBackends() {
        if (idleBackendProc.running || notifBackendProc.running) {
            _omarchyBackendReprobePending = true
            return
        }
        _omarchyBackendReprobePending = false
        idleBackendProc.running = true
        notifBackendProc.running = true
    }
    function finishRyokuBackendReprobe() {
        if (idleBackendProc.running || notifBackendProc.running) return
        if (_omarchyBackendReprobePending) {
            omarchyBackendProbeDebounce.restart()
            return
        }
        scheduleRyokuBackendRetry()
    }
    function omarchyBackendRetryNeeded() {
        return (_idleRyokuShellSystem && !_idleRyokuShellBackend)
            || (_notifRyokuShellSystem && !_notifRyokuShellBackend)
    }
    function scheduleRyokuBackendRetry() {
        if (!omarchyBackendRetryNeeded()) {
            omarchyBackendRetryTimer.stop()
            _omarchyBackendRetryIndex = 0
            return
        }
        if (omarchyBackendConfirmTimer.running || omarchyBackendRetryTimer.running
                || _omarchyBackendRetryIndex >= _omarchyBackendRetryDelays.length) return
        omarchyBackendRetryTimer.interval = _omarchyBackendRetryDelays[_omarchyBackendRetryIndex]
        _omarchyBackendRetryIndex++
        omarchyBackendRetryTimer.restart()
    }
    function resetRyokuBackendProbes() {
        omarchyBackendRetryTimer.stop()
        _omarchyBackendRetryIndex = 0
        omarchyBackendProbeDebounce.restart()
        omarchyBackendConfirmTimer.restart()
    }
    function parseNotificationsState(text) {
        try {
            var parsed = JSON.parse(String(text || "{}"))
            notifSilenced = parsed && parsed.dnd === true
        } catch (e) {
            notifSilenced = false
        }
    }
    function refreshNotificationStatus() {
        if (!_notifBackendChecked) return
        if (_notifRyokuShellSystem) {
            notificationsStateFile.reload()
            return
        }
        if (!dndProc.running) dndProc.running = true
    }
    function refreshRecordingStatus() {
        if (recordingPidProc.running) {
            _recordingRefreshPending = true
            return
        }
        recordingPidProc.running = true
    }
    function reconcileSlowStatusIndicators() {
        refreshRecordingStatus()
    }
    function setScreenRecordingPid(pid) {
        pid = String(pid || "").trim()
        if (pid === _screenRecordingPid) return

        _screenRecordingPid = pid
        if (pid === "") {
            screenRecording = false
            screenRecordingElapsed = 0
            _screenRecordingBaseElapsed = 0
            _screenRecordingBaseMs = 0
            _screenRecordingElapsedProbePid = ""
            return
        }

        screenRecording = true
        screenRecordingElapsed = 0
        _screenRecordingBaseElapsed = 0
        _screenRecordingBaseMs = Date.now()
        _screenRecordingElapsedProbePid = pid
        recordingElapsedProc.command = ["ps", "-o", "etimes=", "-p", pid]
        recordingElapsedProc.running = false
        recordingElapsedProc.running = true
    }
    function updateScreenRecordingElapsed() {
        if (!screenRecording || _screenRecordingBaseMs <= 0) return
        screenRecordingElapsed = _screenRecordingBaseElapsed + Math.floor((Date.now() - _screenRecordingBaseMs) / 1000)
    }
    function refreshVoxtypeStatus() {
        if (!voxAvailable && !modStatus) return
        if (voxProc.running) return
        voxProc.running = true
    }

    Process {
        id: idleBackendProc
        command: ["bash", "-c", "root=${RYOKU_PATH:-/usr/share/ryoku}; [[ -f $root/shell/plugins/services/idle/manifest.json ]] || exit 2; command -v true >/dev/null 2>&1 && RYOKU_PATH=$root true idle status >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => {
            theme._idleRyokuShellSystem = exitCode !== 2
            theme._idleRyokuShellBackend = exitCode === 0
            theme._idleBackendChecked = true
            theme.refreshIdleStatus()
            theme.finishRyokuBackendReprobe()
        }
    }

    FileView {
        id: idleStateFile
        path: theme.idleStatePath
        watchChanges: theme._idleRyokuShellSystem
        printErrors: false
        onFileChanged: idleStateFile.reload()
        onLoaded: {
            if (theme._idleRyokuShellSystem) theme.stayAwake = true
        }
        onLoadFailed: {
            if (theme._idleRyokuShellSystem) theme.stayAwake = false
        }
    }

    Process {
        id: notifBackendProc
        command: ["bash", "-c", "root=${RYOKU_PATH:-/usr/share/ryoku}; [[ -f $root/shell/plugins/notifications/manifest.json ]] || exit 2; command -v true >/dev/null 2>&1 && RYOKU_PATH=$root true notifications ping 2>/dev/null | grep -Fxq ok"]
        running: true
        onExited: (exitCode) => {
            theme._notifRyokuShellSystem = exitCode !== 2
            theme._notifRyokuShellBackend = exitCode === 0
            theme._notifBackendChecked = true
            theme.refreshNotificationStatus()
            theme.finishRyokuBackendReprobe()
        }
    }

    FileView {
        id: notificationsStateFile
        path: theme.notificationsStatePath
        watchChanges: theme._notifRyokuShellSystem
        printErrors: false
        onFileChanged: notificationsStateFile.reload()
        onLoaded: {
            if (theme._notifRyokuShellSystem) theme.parseNotificationsState(notificationsStateFile.text())
        }
        onLoadFailed: {
            if (theme._notifRyokuShellSystem) theme.notifSilenced = false
        }
    }

    Timer {
        id: omarchyBackendProbeDebounce
        interval: 250
        repeat: false
        onTriggered: theme.reprobeRyokuShellBackends()
    }

    Timer {
        id: omarchyBackendRetryTimer
        repeat: false
        onTriggered: theme.reprobeRyokuShellBackends()
    }

    Timer {
        id: omarchyBackendConfirmTimer
        interval: 2000
        repeat: false
        onTriggered: {
            theme._omarchyBackendRetryIndex = Math.max(1, theme._omarchyBackendRetryIndex)
            theme.reprobeRyokuShellBackends()
        }
    }

    FileView {
        id: omarchyShellConfigFile
        path: theme.omarchyShellConfigPath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            omarchyShellConfigFile.reload()
            theme.resetRyokuBackendProbes()
        }
    }

    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        running: false
        onExited: (exitCode) => {
            if (!theme._idleRyokuShellSystem) theme.stayAwake = exitCode !== 0
        }
    }

    Process {
        id: dndProc
        command: ["makoctl", "mode"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0 && !theme._notifRyokuShellSystem) theme.notifSilenced = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!theme._notifRyokuShellSystem) theme.notifSilenced = this.text.indexOf("do-not-disturb") >= 0
            }
        }
    }

    Process {
        id: recordingPidProc
        command: ["pgrep", "-o", "-f", "^gpu-screen-recorder"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) theme.setScreenRecordingPid("")
            if (theme._recordingRefreshPending) {
                theme._recordingRefreshPending = false
                theme.refreshRecordingStatus()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/)
                theme.setScreenRecordingPid(parts[0] || "")
            }
        }
    }

    FileView {
        id: screenRecordingStateFile
        path: theme.screenRecordingStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            screenRecordingStateFile.reload()
            theme.refreshRecordingStatus()
        }
        onLoaded: theme.refreshRecordingStatus()
        onLoadFailed: theme.refreshRecordingStatus()
    }

    Process {
        id: recordingElapsedProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (theme._screenRecordingElapsedProbePid !== theme._screenRecordingPid) return
                var elapsed = parseInt(this.text.trim())
                if (isNaN(elapsed)) elapsed = 0
                theme._screenRecordingBaseElapsed = Math.max(0, elapsed)
                theme._screenRecordingBaseMs = Date.now()
                theme.updateScreenRecordingElapsed()
            }
        }
    }

    Timer {
        interval: 1500
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshStatusIndicators()
    }

    Timer {
        interval: 45000
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.reconcileSlowStatusIndicators()
    }

    Timer {
        interval: 1000
        running: theme.screenRecording
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.updateScreenRecordingElapsed()
    }

    Process {
        id: voxProc
        command: ["bash", "-c",
            "if command -v voxtype >/dev/null 2>&1; then " +
            "timeout 1 voxtype status --extended --format json 2>/dev/null | jq -r '[(.class // .alt // \"idle\"), ((.tooltip // \"\") | split(\"\\n\")[0])] | @tsv' 2>/dev/null; " +
            "else echo 'MISSING'; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                if (parts[0] === "MISSING") {
                    theme.voxAvailable = false
                    theme.voxState = "idle"
                    theme.voxHint = ""
                    return
                }
                theme.voxAvailable = true
                theme.voxState = parts[0] || "idle"
                theme.voxHint = parts[1] || ""
            }
        }
    }
    Timer {
        interval: theme._voxActive ? 1000 : (theme.voxAvailable ? 10000 : 60000)
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshVoxtypeStatus()
    }
    // battery presence (laptop) — drives the Battery indicator tile's visibility (shown only
    // where a battery exists, like Brightness uses hasBacklight). Direct UPower check, event-driven.
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    // NetworkManager active (Ryoku 4.0) → the panel's iwctl scan/connect won't work,
    // so it shows an "open nmtui" button instead of an empty list
    property bool useNM: false
    Process {
        command: ["bash", "-c", "systemctl is-active --quiet NetworkManager && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: theme.useNM = this.text.trim() === "1" }
    }

    // ── wifi/bluetooth settings launchers (Ryoku way, via uwsm-app) ──
    // iwd (Ryoku 3.8.x) → impala/bluetui through kitty *; if NetworkManager
    // is the active backend (Ryoku 4.0) → nmtui instead. Quattro removed the
    // dedicated Bluetooth launcher; prefer a retained bluetui, then bluetoothctl.
    readonly property string launchWifiCmd: "ryoku-shell hub open"
    readonly property string launchBtCmd:   "if command -v kitty bluetoothctl >/dev/null 2>&1; then exec kitty bluetoothctl; elif command -v kitty >/dev/null 2>&1; then if command -v bluetui >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec kitty bluetui; elif command -v bluetoothctl >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec kitty bluetoothctl; fi; fi; command -v notify-send >/dev/null 2>&1 && notify-send -a QS-Shell -u critical 'Bluetooth settings unavailable' 'No supported Bluetooth settings backend was found' || true; exit 0"
    property bool modPower:      false   // default off (toggle in ControlPanel)
    property bool modBluetooth:  false   // default off (toggle in ControlPanel)
    property bool modBrightness: true
    property bool modMedia:      true
    property bool modQuick:      true    // G10 group pill (idle-inhibitor · media · theme)
    property bool modMpris:      true    // G9 now-playing / mpris pill
    property string mprisBarStyle: "default" // "default" or "full"
    property bool modClaude:     false   // default off (toggle in ControlPanel)

    // backlight presence — set by BrightnessWidget once it probes /sys/class/backlight.
    // ControlPanel uses this to hide the Brightness toggle on desktops without one.
    property bool hasBacklight:  false

    // ── workspace display mode ──
    property string workspaceMode: "active"   // "10", "5", "active"
    // ── workspace display style (orthogonal to mode; persisted) ──
    // "rings" is the stable cache token for the user-facing Frame style.
    property string workspaceStyle: "default"   // default, numbers, magic, kanji, rings, aurora
    // The marker styles this variant offers (continuous V2 adds Kanji, Frame,
    // Aurora; "rings" is the persisted cache token for the Frame style).
    readonly property var workspaceStyleOptions: [
        { key: "default", label: "Dots" },
        { key: "numbers", label: "Numbers" },
        { key: "magic",   label: "Glyph" },
        { key: "kanji",   label: "Kanji" },
        { key: "rings",   label: "Frame" },
        { key: "aurora",  label: "Aurora" }
    ]

    // ── bar screen position (persisted) ──
    property string barPosition: "top"   // "top" or "bottom"
    // ── gap animation mode (Bar Studio; drives the V2 gap/reactor layer) ──
    // 0=off, 1=stream, 2=surge, 3=bolt, 7=reactor, 8=quotes.
    property int barAnim: 1
    onBarAnimChanged: if (_widgetsLoaded) saveWidgets()
    // Reactor IPC (barAnim modes 7/8): ParticleStream listens via onReactorTest.
    // Mirrors the root V1 Theme signal so V2's reactor path resolves.
    signal reactorTest(string kind, string arg)
    // ── outer bar shell (persisted) ──
    // full  = current edge-to-edge strip
    // fit   = centered content-width capsule
    // dock  = centered content-width surface attached to the screen edge
    // notch = attached content-width surface with desktop-facing side wings
    property string barShellStyle: "full"
    property bool barBorderEnabled: true
    property bool panelTooltipBorderEnabled: true
    function barShellStyleValid(value) {
        return value === "full" || value === "fit"
            || value === "dock" || value === "notch"
    }

    // ── picker visual style (theme/wallpaper/screenshot/video pickers) ──
    property string pickerStyle: "tanzaku"   // "tanzaku", "hearthstone", "carousel"
    property string launcherLogoMode: "text"     // "text" or "icon"
    property string launcherLogoText: "omarchy"  // "omarchy", "hyprland", "arch", or "omacom"
    property string launcherLogoIcon: "omarchy"  // see launcherLogoIconGlyph()
    property bool   weatherImperial: false   // false = °C / km·h, true = °F / mph
    property bool   clock12h:        false   // false = 24h, true = 12h (AM/PM)

    // ── widget/workspace state persistence ──
    property var barSeps: []
    property var iconOnlyGids: []
    function sepAfter(gid) { return barSeps.indexOf(gid) >= 0 }
    function iconOnly(gid) { return iconOnlyGids.indexOf(gid) >= 0 }
    function toggleSep(gid) {
        var a = barSeps.slice()
        var i = a.indexOf(gid)
        if (i >= 0) a.splice(i, 1); else a.push(gid)
        barSeps = a
        if (_widgetsLoaded) saveWidgets()
    }
    function toggleIconOnly(gid) {
        if (gid === "G3") return // Status is an icon-only group by design.
        var a = iconOnlyGids.slice()
        var i = a.indexOf(gid)
        if (i >= 0) a.splice(i, 1); else a.push(gid)
        iconOnlyGids = a
        if (_widgetsLoaded) saveWidgets()
    }
    function parseGidCsv(s) {
        if (!s || s === "-") return []
        var out = []
        var toks = s.split(",")
        for (var i = 0; i < toks.length; i++)
            if (/^G\d{1,2}$/.test(toks[i]) && toks[i] !== "G3") out.push(toks[i])
        return out
    }

    // ── per-widget palette styles ──
    // Stored by stable GID, so slot reordering and temporarily hidden widgets
    // never lose their visual assignment.
    property var widgetColorStyles: ({})
    function widgetGidValid(gid) {
        var m = String(gid || "").match(/^G(\d{1,2})$/)
        if (!m) return false
        var n = Number(m[1])
        return n >= 1 && n <= 18
    }
    function widgetColorModeValid(mode) {
        return mode === "fill" || mode === "border" || mode === "both"
    }
    function normalizedWidgetColorMode(mode, colorId) {
        var borderOn = mode === "both" || mode === "border"
        if (!borderOn) return "fill"
        return colorId === "inherit" ? "border" : "both"
    }
    function widgetToneValid(tone) {
        return tone === "auto" || tone === "background" || tone === "foreground"
    }
    function widgetColorStyle(gid) {
        var raw = widgetColorStyles[gid]
        var colorId = raw && (raw.color === "inherit" || paletteColorValid(raw.color))
            ? raw.color
            : "inherit"
        return {
            color: colorId,
            mode: raw && widgetColorModeValid(raw.mode)
                ? normalizedWidgetColorMode(raw.mode, colorId)
                : "fill",
            tone: raw && widgetToneValid(raw.tone) ? raw.tone : "auto"
        }
    }
    function setWidgetColorStyle(gid, colorId, mode, tone) {
        if (!widgetGidValid(gid)) return
        var next = {}
        for (var key in widgetColorStyles) next[key] = widgetColorStyles[key]

        var storedColor = colorId === "inherit"
            ? "inherit"
            : (paletteColorValid(colorId) ? colorId : "color01")
        var storedMode = normalizedWidgetColorMode(mode, storedColor)
        if (storedColor === "inherit" && storedMode !== "border") {
            delete next[gid]
        } else {
            next[gid] = {
                color: storedColor,
                mode: storedMode,
                tone: widgetToneValid(tone) ? tone : "auto"
            }
        }
        widgetColorStyles = next
        if (_widgetsLoaded) saveWidgets()
    }
    function setWidgetPaletteColor(gid, colorId) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, colorId, style.mode, style.tone)
    }
    function setWidgetColorMode(gid, mode) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, style.color, mode, style.tone)
    }
    function setWidgetBorderEnabled(gid, enabled) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, style.color,
            enabled ? (style.color === "inherit" ? "border" : "both") : "fill",
            style.tone)
    }
    function setWidgetTone(gid, tone) {
        var style = widgetColorStyle(gid)
        if (style.color !== "inherit") setWidgetColorStyle(gid, style.color, style.mode, tone)
    }
    function resetWidgetColor(gid) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, "inherit",
            style.mode === "both" || style.mode === "border" ? "border" : "fill",
            "auto")
    }
    function resetAllWidgetFillColors() {
        var next = {}
        var changed = false

        for (var n = 1; n <= 18; n++) {
            var gid = "G" + n
            var style = widgetColorStyle(gid)

            if (style.color !== "inherit") changed = true
            if (style.mode === "border" || style.mode === "both") {
                next[gid] = {
                    color: "inherit",
                    mode: "border",
                    tone: "auto"
                }
            }
        }

        if (changed) widgetColorStyles = next
        return changed
    }
    function widgetPaletteId(gid) { return widgetColorStyle(gid).color }
    function widgetColorMode(gid) { return widgetColorStyle(gid).mode }
    function widgetTone(gid) { return widgetColorStyle(gid).tone }
    function widgetHasFill(gid) {
        var style = widgetColorStyle(gid)
        return style.color !== "inherit"
    }
    function widgetHasBorder(gid) {
        var style = widgetColorStyle(gid)
        return style.mode === "border" || style.mode === "both"
    }
    function widgetAssignedColor(gid) {
        var id = widgetPaletteId(gid)
        return id === "inherit" ? seal : paletteColor(id)
    }
    function _linearColorChannel(v) {
        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }
    function _relativeLuminance(c) {
        return 0.2126 * _linearColorChannel(c.r)
             + 0.7152 * _linearColorChannel(c.g)
             + 0.0722 * _linearColorChannel(c.b)
    }
    function _contrastRatio(a, b) {
        var la = _relativeLuminance(a)
        var lb = _relativeLuminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function paletteContrastColor(id) {
        var fill = paletteColor(id)
        return _contrastRatio(fill, paper) >= _contrastRatio(fill, ink) ? paper : ink
    }
    function widgetContrastColor(gid) {
        var fill = widgetAssignedColor(gid)
        var tone = widgetTone(gid)
        if (tone === "background") return paper
        if (tone === "foreground") return ink
        return _contrastRatio(fill, paper) >= _contrastRatio(fill, ink) ? paper : ink
    }
    function widgetContentColor(gid, fallback) {
        return widgetHasFill(gid) ? widgetContrastColor(gid) : fallback
    }
    function widgetFillColor(gid) {
        return widgetHasFill(gid) ? widgetAssignedColor(gid) : Qt.rgba(0, 0, 0, 0)
    }
    function widgetBorderColor(gid) {
        if (!widgetHasBorder(gid)) return Qt.rgba(0, 0, 0, 0)
        return panelBorder
    }
    function serializeWidgetColorStyles() {
        var out = []
        for (var n = 1; n <= 18; n++) {
            var gid = "G" + n
            var style = widgetColorStyle(gid)
            if (style.color !== "inherit" || style.mode === "border")
                out.push(gid + "~" + style.color + "~" + style.mode + "~" + style.tone)
        }
        return out.length ? out.join(",") : "-"
    }
    function parseWidgetColorStyles(raw) {
        var out = {}
        if (!raw || raw === "-") return out
        var entries = String(raw).split(",")
        for (var i = 0; i < entries.length; i++) {
            var fields = entries[i].split("~")
            if (fields.length !== 4 || !widgetGidValid(fields[0])
                    || (fields[1] !== "inherit" && !paletteColorValid(fields[1]))
                    || !widgetColorModeValid(fields[2])
                    || !widgetToneValid(fields[3])) continue
            out[fields[0]] = {
                color: fields[1],
                mode: normalizedWidgetColorMode(fields[2], fields[1]),
                tone: fields[3]
            }
        }
        return out
    }

    readonly property string widgetsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_widgets_v2"
    property bool _widgetsLoaded: false

    onModMemoryChanged:     if (_widgetsLoaded) saveWidgets()
    onModCpuTemperatureChanged: if (_widgetsLoaded) saveWidgets()
    onModGpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModStorageChanged:    if (_widgetsLoaded) saveWidgets()
    onModBrightnessChanged: if (_widgetsLoaded) saveWidgets()
    onModClaudeChanged:     if (_widgetsLoaded) saveWidgets()
    onModPowerChanged:      if (_widgetsLoaded) saveWidgets()
    onModBluetoothChanged:  if (_widgetsLoaded) saveWidgets()
    onModNetworkChanged:    if (_widgetsLoaded) saveWidgets()
    onModStatusChanged:     if (_widgetsLoaded) saveWidgets()
    onModQuickChanged:      if (_widgetsLoaded) saveWidgets()
    onModCpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModVolumeChanged:     if (_widgetsLoaded) saveWidgets()
    onModMprisChanged:      if (_widgetsLoaded) saveWidgets()
    onMprisBarStyleChanged: if (_widgetsLoaded) saveWidgets()
    onAiToolChanged:        if (_widgetsLoaded) saveWidgets()
    onWorkspaceModeChanged: if (_widgetsLoaded) saveWidgets()
    onPickerStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onLauncherLogoModeChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoTextChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoIconChanged: if (_widgetsLoaded) saveWidgets()
    onWeatherImperialChanged: if (_widgetsLoaded) saveWidgets()
    onClock12hChanged:        if (_widgetsLoaded) saveWidgets()
    onArchBadgePackagesChanged: if (_widgetsLoaded) saveWidgets()
    onArchBadgeThemesChanged:   if (_widgetsLoaded) saveWidgets()
    onArchBadgeShellChanged:    if (_widgetsLoaded) saveWidgets()
    onWorkspaceStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onBarPositionChanged:      if (_widgetsLoaded) saveWidgets()
    onBarShellStyleChanged:    if (_widgetsLoaded) saveWidgets()
    onBarBorderEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onPanelTooltipBorderEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onBarColorChanged:         if (_widgetsLoaded) saveWidgets()
    onWidgetIconsForegroundChanged: if (_widgetsLoaded) saveWidgets()
    onBarTemperatureSourceChanged: if (_widgetsLoaded) saveWidgets()

    function saveWidgets() {
        var line = (modMemory    ? "1" : "0") + " "
                 + (modBrightness ? "1" : "0") + " "
                 + (modClaude    ? "1" : "0") + " "
                 + (modPower     ? "1" : "0") + " "
                 + (modBluetooth ? "1" : "0") + " "
                 + workspaceMode + " "
                 + pickerStyle + " "
                 + (weatherImperial ? "1" : "0") + " "
                 + (clock12h        ? "1" : "0") + " "
                 + (modNetwork      ? "1" : "0") + " "
                 + "0 "                                     // +5 legacy shadow field (V2 disabled)
                 + "0 0 "                                     // +6..+7 retired V2 Style fields
                 + workspaceStyle + " "
                 + barPosition + " "
                 + "1 "                                     // +10 legacy border field (V2 always on)
                 + (modStatus ? "1" : "0") + " "          // +11 group pill: status (arch/tray/notif)
                 + (modQuick  ? "1" : "0") + " "          // +12 group pill: quick (idle/media/theme)
                 + (modCpu    ? "1" : "0") + " "          // +13
                 + (modVolume ? "1" : "0") + " "          // +14
                 + (modMpris  ? "1" : "0") + " "          // +15 now-playing / mpris
                 + aiTool + " "                           // +16 AI tool shown in bar (claude/codex/opencode)
                 + "0 "                                     // +17 retired transparent/frost field
                 + launcherLogoMode + " "                 // +18 launcher logo mode (text/icon)
                 + launcherLogoText + " "                 // +19 text logo id
                 + launcherLogoIcon + " "                 // +20 icon logo id
                 + (archBadgePackages ? "1" : "0") + " "  // +21 updater package badge
                 + (archBadgeThemes   ? "1" : "0") + " "  // +22 updater clean-theme badge
                 + "1 1 1 1 1 1 1 1 "                       // +23..+30 legacy compact fields; V2 is always compact
                 + (archBadgeShell    ? "1" : "0") + " "  // +31 updater shell badge
                 + barColor + " "                            // +32 V2 bar accent source
                 + (modGpu            ? "1" : "0") + " "  // +33 GPU load
                 + (modCpuTemperature ? "1" : "0") + " "  // +34 CPU temperature
                 + (modStorage        ? "1" : "0") + " "  // +35 root-filesystem usage
                 + (barSeps.length ? barSeps.join(",") : "-") + " "         // +36 separator gids (CSV, "-" = none)
                 + (iconOnlyGids.length ? iconOnlyGids.join(",") : "-") + " " // +37 icon-only gids (CSV, "-" = none)
                 + barTemperatureSource + " "                            // +38 temperature sensor shown in bar
                 + "0 "                                                  // +39 retired global widget-foreground switch
                 + serializeWidgetColorStyles() + " "                   // +40 per-GID palette styles
                 + mprisBarStyle + " "                                  // +41 now-playing bar presentation
                 + barShellStyle + " "                                  // +42 outer bar shell
                 + (barBorderEnabled ? "1" : "0") + " "                 // +43 outer bar border
                 + (panelTooltipBorderEnabled ? "1" : "0") + " "        // +44 panel + tooltip outer border
                 + barAnim                                              // +45 gap-animation mode
        widgetSaveProc.command = ["bash", "-c",
            "echo '" + line + "' > '" + widgetsCachePath + "'"]
        widgetSaveProc.running = false
        widgetSaveProc.running = true
        persistWidgetsToConfig()
    }

    readonly property var launcherLogoTextOptions: ["omarchy", "hyprland", "arch", "omacom"]
    readonly property var launcherLogoIconOptions: ["omarchy", "hyprland", "arch", "grid", "spark", "power", "dragon", "mark", "nix", "branch", "rebel"]

    function launcherLogoTextIndex(id) {
        for (var i = 0; i < launcherLogoTextOptions.length; i++)
            if (launcherLogoTextOptions[i] === id) return i
        return 0
    }
    function launcherLogoIconIndex(id) {
        for (var i = 0; i < launcherLogoIconOptions.length; i++)
            if (launcherLogoIconOptions[i] === id) return i
        return 0
    }
    function launcherLogoTextValid(id) {
        return launcherLogoTextIndex(id) >= 0 && launcherLogoTextOptions[launcherLogoTextIndex(id)] === id
    }
    function launcherLogoIconValid(id) {
        return launcherLogoIconIndex(id) >= 0 && launcherLogoIconOptions[launcherLogoIconIndex(id)] === id
    }
    function launcherConfigValue(config, a, b, c) {
        if (!config) return undefined
        if (config[a] !== undefined) return config[a]
        if (b && config[b] !== undefined) return config[b]
        if (c && config[c] !== undefined) return config[c]
        return undefined
    }
    function applyLauncherConfig(config) {
        if (!config) return

        var launcher = config.launcher || config.logo || config
        var mode = launcherConfigValue(launcher, "launcherLogoMode", "logoMode", "mode")
        var text = launcherConfigValue(launcher, "launcherLogoText", "textLogo", "text")
        var icon = launcherConfigValue(launcher, "launcherLogoIcon", "iconLogo", "icon")

        if (mode === "text" || mode === "icon") launcherLogoMode = mode
        if (text !== undefined && launcherLogoTextValid(text)) launcherLogoText = text
        if (icon !== undefined && launcherLogoIconValid(icon)) launcherLogoIcon = icon
    }

    Process {
        id: widgetLoadProc
        command: ["cat", theme.widgetsCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(" ")
                if (parts.length >= 4) {
                    theme.modMemory    = parts[0] !== "0"
                    theme.modBrightness = parts[1] !== "0"
                    theme.modClaude    = parts[2] !== "0"
                    theme.modPower     = parts[3] !== "0"
                }
                // parts[4] is the bluetooth flag in the new format, but in the OLD
                // format it was the workspace mode ("10"/"5"/"active") — detect which.
                var wsField = -1
                if (parts.length >= 5) {
                    if (parts[4] === "5" || parts[4] === "active" || parts[4] === "10") {
                        wsField = 4                         // old format: no bluetooth field
                    } else {
                        theme.modBluetooth = parts[4] !== "0"
                        wsField = 5
                    }
                }
                if (wsField >= 0 && parts.length > wsField) {
                    var m = parts[wsField]
                    theme.workspaceMode = (m === "5" || m === "active") ? m : "10"
                    // pickerStyle is the field right after the workspace mode
                    if (parts.length > wsField + 1) {
                        var ps = parts[wsField + 1]
                        if (ps === "hearthstone" || ps === "carousel" || ps === "tanzaku")
                            theme.pickerStyle = ps
                    }
                    // weatherImperial / clock12h follow pickerStyle
                    if (parts.length > wsField + 2) theme.weatherImperial = parts[wsField + 2] === "1"
                    if (parts.length > wsField + 3) theme.clock12h        = parts[wsField + 3] === "1"
                    if (parts.length > wsField + 4) theme.modNetwork      = parts[wsField + 4] === "1"
                    // style tokens — appended after modNetwork, each guarded
                    // +5 is the retired V2 shadow field and is intentionally ignored.
                    // +6..+7 are retired V2 Style fields, retained only so older
                    // cache layouts keep stable offsets.
                    if (parts.length > wsField + 8) {
                        var wss = parts[wsField + 8]
                        if (wss === "numbers" || wss === "magic" || wss === "kanji"
                                || wss === "rings" || wss === "aurora" || wss === "default")
                            theme.workspaceStyle = wss
                    }
                    if (parts.length > wsField + 9) {
                        var bp = parts[wsField + 9]
                        if (bp === "top" || bp === "bottom") theme.barPosition = bp
                    }
                    // +10 is the retired V2 border toggle; structural borders stay on.
                    // +11..+15 widget-group toggles (default ON → only an explicit "0"
                    // hides; old caches lack these fields → groups stay visible)
                    if (parts.length > wsField + 11) theme.modStatus = parts[wsField + 11] !== "0"
                    if (parts.length > wsField + 12) theme.modQuick  = parts[wsField + 12] !== "0"
                    if (parts.length > wsField + 13) theme.modCpu    = parts[wsField + 13] !== "0"
                    if (parts.length > wsField + 14) theme.modVolume = parts[wsField + 14] !== "0"
                    if (parts.length > wsField + 15) theme.modMpris  = parts[wsField + 15] !== "0"
                    if (parts.length > wsField + 16) {
                        var at = parts[wsField + 16]
                        if (at === "claude" || at === "codex" || at === "opencode") theme.aiTool = at
                    }
                    // +17 is the retired transparent/frost field.
                    if (parts.length > wsField + 18) {
                        var lm = parts[wsField + 18]
                        if (lm === "text" || lm === "icon") {
                            theme.launcherLogoMode = lm
                            if (parts.length > wsField + 19 && theme.launcherLogoTextValid(parts[wsField + 19]))
                                theme.launcherLogoText = parts[wsField + 19]
                            if (parts.length > wsField + 20 && theme.launcherLogoIconValid(parts[wsField + 20]))
                                theme.launcherLogoIcon = parts[wsField + 20]
                        } else if (lm === "omarchy" || lm === "hyprland") {
                            // Legacy cache field from the first text-logo picker.
                            theme.launcherLogoMode = "text"
                            theme.launcherLogoText = lm
                        }
                    }
                    if (parts.length > wsField + 21) theme.archBadgePackages = parts[wsField + 21] !== "0"
                    if (parts.length > wsField + 22) theme.archBadgeThemes   = parts[wsField + 22] !== "0"
                    // +23..+30 are retained only as cache-schema placeholders.
                    // V2 has one compact presentation and deliberately ignores them.
                    if (parts.length > wsField + 31) theme.archBadgeShell    = parts[wsField + 31] !== "0"
                    if (parts.length > wsField + 32 && theme.barColorValid(parts[wsField + 32]))
                        theme.barColor = theme.normalizedPaletteId(parts[wsField + 32])
                    if (parts.length > wsField + 33) theme.modGpu = parts[wsField + 33] !== "0"
                    if (parts.length > wsField + 34) theme.modCpuTemperature = parts[wsField + 34] !== "0"
                    if (parts.length > wsField + 35) theme.modStorage = parts[wsField + 35] !== "0"
                    if (parts.length > wsField + 36) theme.barSeps      = theme.parseGidCsv(parts[wsField + 36])
                    if (parts.length > wsField + 37) theme.iconOnlyGids = theme.parseGidCsv(parts[wsField + 37])
                    if (parts.length > wsField + 38 && theme.barTemperatureSourceValid(parts[wsField + 38]))
                        theme.barTemperatureSource = parts[wsField + 38]
                    // +39 was the retired global foreground override. Bar Color
                    // now includes Foreground and per-widget styles provide local overrides.
                    theme.widgetIconsForeground = false
                    if (parts.length > wsField + 40)
                        theme.widgetColorStyles = theme.parseWidgetColorStyles(parts[wsField + 40])
                    if (parts.length > wsField + 41) {
                        var mbs = parts[wsField + 41]
                        if (mbs === "default" || mbs === "full") theme.mprisBarStyle = mbs
                    }
                    if (parts.length > wsField + 42) {
                        var bss = parts[wsField + 42]
                        if (theme.barShellStyleValid(bss)) theme.barShellStyle = bss
                    }
                    if (parts.length > wsField + 43)
                        theme.barBorderEnabled = parts[wsField + 43] !== "0"
                    if (parts.length > wsField + 44)
                        theme.panelTooltipBorderEnabled = parts[wsField + 44] !== "0"
                    if (parts.length > wsField + 45) {
                        var ba = parseInt(parts[wsField + 45], 10)
                        if (isFinite(ba) && ba >= 0 && ba <= 8) theme.barAnim = ba
                    }
                }
                theme._widgetsLoaded = true
                theme.applyStudioSettings()
            }
        }
    }

    Process { id: widgetSaveProc }

    // Persist widget visibility to shell.json .qsbar.widgets, the store Bar Studio
    // writes and applyStudioSettings applies on every load. Without this, a
    // control-center toggle only reached the local cache and was overridden by a
    // stale Bar Studio value on the next reload (the widgets reset). shell.json has
    // one writer, the daemon; reach it over the settings.patch seam Weather uses.
    readonly property string _cfgSockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"
    function persistWidgetsToConfig() {
        var cur = Config.qsbar || ({})
        var q = ({})
        for (var k in cur) q[k] = cur[k]
        // Mirror EVERY key applyStudioSettings() applies, from the LIVE
        // properties. Persisting only `widgets` (and copying the rest from the
        // stale Config frame) let applyStudioSettings re-apply an old value over
        // an unpersisted control-center change on the next qsbar change or
        // reload, resetting the user's choice. Keep this set in lockstep with
        // applyStudioSettings below.
        q.barColor = barColor
        q.barAnim = barAnim
        q.barPosition = barPosition
        q.workspaceMode = workspaceMode
        q.workspaceStyle = workspaceStyle
        q.pickerStyle = pickerStyle
        q.launcherLogoMode = launcherLogoMode
        q.aiTool = aiTool
        q.barTemperatureSource = barTemperatureSource
        q.barShellStyle = barShellStyle
        q.barBorderEnabled = barBorderEnabled
        q.panelTooltipBorderEnabled = panelTooltipBorderEnabled
        q.widgets = {
            "status": modStatus, "memory": modMemory, "cpu": modCpu, "volume": modVolume,
            "weather": modWeather, "network": modNetwork, "brightness": modBrightness,
            "media": modMedia, "mpris": modMpris, "quick": modQuick, "claude": modClaude,
            "power": modPower, "bluetooth": modBluetooth, "gpu": modGpu,
            "cpuTemperature": modCpuTemperature, "storage": modStorage
        }
        _cfgCtl.queued += "call settings.patch " + JSON.stringify({ path: "qsbar", value: q }) + "\n"
        if (_cfgCtl.connected) _cfgCtl.flushQueued()
        else _cfgCtl.connected = true
    }
    Socket {
        id: _cfgCtl
        path: theme._cfgSockPath
        property string queued: ""
        function flushQueued() {
            if (queued.length === 0) return
            write(queued); flush(); queued = ""
        }
        onConnectionStateChanged: if (connected) flushQueued()
    }

    // ── Bar Studio bridge ──
    // Ryoku Hub (Bar Studio) writes a `qsbar` map into shell.json; the Config
    // singleton watches it, so these settings apply live and win over the local
    // widget cache. Only keys the user set are present; the rest keep defaults.
    function applyStudioSettings() {
        var q = Config.qsbar
        if (!q) return
        // Config is the source of truth for these keys, so suppress the widget
        // cache writes the property-change handlers would make (all gated on
        // _widgetsLoaded). Clearing a key in Bar Studio then reverts to the
        // cache/default on the next load instead of sticking.
        var wl = _widgetsLoaded
        _widgetsLoaded = false
        if (q.barColor !== undefined && barColorValid(q.barColor)) barColor = q.barColor
        if (q.barAnim !== undefined) barAnim = q.barAnim
        if (q.barPosition === "top" || q.barPosition === "bottom") barPosition = q.barPosition
        if (q.workspaceMode !== undefined) workspaceMode = q.workspaceMode
        if (q.workspaceStyle  !== undefined) workspaceStyle  = q.workspaceStyle
        if (q.pickerStyle     !== undefined) pickerStyle     = q.pickerStyle
        if (q.launcherLogoMode !== undefined) launcherLogoMode = q.launcherLogoMode
        if (q.aiTool === "claude" || q.aiTool === "codex" || q.aiTool === "opencode") aiTool = q.aiTool
        if (q.barTemperatureSource !== undefined && barTemperatureSourceValid(q.barTemperatureSource)) barTemperatureSource = q.barTemperatureSource
        if (q.barShellStyle !== undefined && barShellStyleValid(q.barShellStyle)) barShellStyle = q.barShellStyle
        if (q.barBorderEnabled !== undefined) barBorderEnabled = q.barBorderEnabled
        if (q.panelTooltipBorderEnabled !== undefined) panelTooltipBorderEnabled = q.panelTooltipBorderEnabled
        var w = q.widgets
        if (w) {
            if (w.status     !== undefined) modStatus     = w.status
            if (w.memory     !== undefined) modMemory     = w.memory
            if (w.cpu        !== undefined) modCpu        = w.cpu
            if (w.volume     !== undefined) modVolume     = w.volume
            if (w.weather    !== undefined) modWeather    = w.weather
            if (w.network    !== undefined) modNetwork    = w.network
            if (w.brightness !== undefined) modBrightness = w.brightness
            if (w.media      !== undefined) modMedia      = w.media
            if (w.mpris      !== undefined) modMpris      = w.mpris
            if (w.quick      !== undefined) modQuick      = w.quick
            if (w.claude     !== undefined) modClaude     = w.claude
            if (w.power      !== undefined) modPower      = w.power
            if (w.bluetooth  !== undefined) modBluetooth  = w.bluetooth
            if (w.gpu            !== undefined) modGpu            = w.gpu
            if (w.cpuTemperature !== undefined) modCpuTemperature = w.cpuTemperature
            if (w.storage        !== undefined) modStorage        = w.storage
        }
        _widgetsLoaded = wl
    }
    Connections {
        target: Config
        function onQsbarChanged() { theme.applyStudioSettings() }
    }
    Component.onCompleted: theme.applyStudioSettings()

    // ── New widget panel states ──
    property bool networkVisible:   false
    onNetworkVisibleChanged: popupOpened("networkVisible")
    property bool storageVisible:   false
    onStorageVisibleChanged: popupOpened("storageVisible")
    property bool bluetoothVisible: false
    onBluetoothVisibleChanged: popupOpened("bluetoothVisible")
    property bool batteryVisible:   false
    onBatteryVisibleChanged: popupOpened("batteryVisible")
    property bool brightnessVisible: false
    onBrightnessVisibleChanged: popupOpened("brightnessVisible")
    property bool mprisVisible:     false
    onMprisVisibleChanged: popupOpened("mprisVisible")
    property bool weatherVisible:   false
    onWeatherVisibleChanged: popupOpened("weatherVisible")
    property bool workspaceVisible: false
    onWorkspaceVisibleChanged: popupOpened("workspaceVisible")

    // ── Image picker state (theme/wallpaper carousel) ──
    property bool   imagePickerVisible:  false
    onImagePickerVisibleChanged: popupOpened("imagePickerVisible")
    property string imagePickerMode:     "wallpaper"   // "theme" or "wallpaper"
    property real   quickActionsBarX:    0
    // ── Media browser state (screenshots/videos carousel) ──
    property bool   mediaBrowserVisible: false
    onMediaBrowserVisibleChanged: popupOpened("mediaBrowserVisible")
    property string mediaBrowserMode:    "screenshots"  // "screenshots" or "videos"
    // ── Idle inhibitor (Wayland idle-inhibit protocol) ──
    property bool   idleInhibited:       false
    // ── Notification state ──
    property bool notifVisible: false
    onNotifVisibleChanged: popupOpened("notifVisible")
    property int  notifCount:   0
    property real notifBarX:    0

    // ── Power Profile state ──
    property bool powerProfileVisible: false
    onPowerProfileVisibleChanged: popupOpened("powerProfileVisible")
    property string powerProfileCurrent: ""

    Process {
        id: initPowerProfile
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p) theme.powerProfileCurrent = p
            }
        }
    }

    // Available power profiles, parsed from `powerprofilesctl list`. Header lines
    // look like "* performance:" / "  balanced:" (the marker flags the active one);
    // detail lines have a value after the colon, so we keep only lines that END at
    // the colon. Defaults to the standard three so nothing regresses if the list
    // can't be read; the panel/widget offer and cycle only through this set, so a
    // profile the hardware lacks never shows up as a dead button.
    property var powerProfileAvailable: ["power-saver", "balanced", "performance"]

    Process {
        id: initPowerProfileList
        command: ["bash", "-c", "powerprofilesctl list 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var found = []
                for (var i = 0; i < lines.length; i++) {
                    var m = lines[i].match(/^\s*\*?\s*([a-z][a-z0-9-]*):\s*$/)
                    if (m) found.push(m[1])
                }
                if (found.length > 0) theme.powerProfileAvailable = found
            }
        }
    }

    // ── Hyprland workspace dispatch (config-mode-aware) ──
    // Hyprland 0.55 added Lua configs but still supports classic hyprlang, and
    // BOTH ship the same version number — so the dispatch form depends on which
    // config is ACTIVE, not the version: classic wants "workspace N", Lua wants
    // hl.dsp.focus({ workspace = N }). Probe the mode once with a harmless token:
    // "hl.dsp" alone yields the Lua error "hl.dispatch: expected a dispatcher"
    // under Lua, or "Invalid dispatcher" under classic — neither switches.
    property bool hyprUsesLua: false
    Process {
        id: hyprDispatchProbe
        command: ["bash", "-c", "hyprctl dispatch 'hl.dsp' 2>&1 | grep -qi 'hl\\.dispatch' && echo lua || echo classic"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { theme.hyprUsesLua = (this.text.trim() === "lua") }
        }
    }
    function gotoWorkspace(id) {
        if (hyprUsesLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else
            Hyprland.dispatch("workspace " + id)
    }

    // ── Arch Updater state ──
    property bool archVisible: false
    onArchVisibleChanged: popupOpened("archVisible")
    property var archUpdates: []
    property int archRefreshTick: 0
    property string archScanId: ""
    property int archScanCheckedEpoch: 0
    property string archScanHash: ""
    property int archScanSystemCount: 0
    readonly property int archScanMaxAge: 900

    // ── Arch security gate (pre-install verdict per package) ──
    // idle | scanning | clean | warn | blocked | degraded
    property string archGateState: "idle"
    property var    archGateResults: []   // [{pkg,repo,old,new,verdict,reason}]
    property int    archGateOk: 0
    property int    archGateWarn: 0
    property int    archGateFail: 0
    property int    archGateBlacklist: 0
    property bool   archGateDegraded: false
    property string archGateListDate: ""   // freshest blacklist date (meta updated_at, else mtime)
    property bool   archGateStale: false          // protection list older than the gate's stale window
    property bool   archGateMirrorsAgree: false   // both feed mirrors produced an identical list
    property bool   archGateMirrorMismatch: false // feeds diverged → using their union, flagged

    // Manual retry, e.g. on panel open: a degraded verdict can be a transient
    // (blacklist file mid-update at scan time) and must not stick until the
    // next refresh.
    function archGateRescan() { theme.applyBenignArchGate() }

    // Ryoku has no per-package security gate: applying is owned by `ryoku update`
    // (the panel's Ryoku-updater backend), and upstream's qs-arch-security-gate.sh
    // is not shipped. Keep the advisory gate benignly "clean" — mirror each pending
    // update as an OK verdict — so the panel never shows a false scanning/degraded
    // state from a scan that no longer runs.
    onArchUpdatesChanged: theme.applyBenignArchGate()
    function applyBenignArchGate() {
        var ups = theme.archUpdates || []
        var results = []
        for (var i = 0; i < ups.length; i++) {
            var u = ups[i] || {}
            results.push({ pkg: u.name, repo: (u.source === "aur") ? "aur" : "system",
                           old: u.oldVer || "", new: u.newVer || "", verdict: "OK", reason: "" })
        }
        theme.archGateResults = results
        theme.archGateOk = ups.length
        theme.archGateWarn = 0
        theme.archGateFail = 0
        theme.archGateBlacklist = 0
        theme.archGateDegraded = false
        theme.archGateStale = false
        theme.archGateMirrorsAgree = false
        theme.archGateMirrorMismatch = false
        theme.archGateState = "clean"
    }

    // ── Shell Updater state (shared by ArchUpdaterWidget and ShellUpdateTab) ──
    property int  shellUpdateBehind: 0
    property var  shellUpdateSummary: []
    property string shellUpdateVersion: ""
    property string shellUpdateChecked: ""
    property string shellUpdateBaseCommit: ""
    property string shellUpdateTargetCommit: ""
    property string shellUpdateRepository: ""
    property string shellUpdateUpstreamRef: ""
    property string shellInstalledCommit: ""
    property bool shellUpdateChecking: false
    property string shellProgressRunId: ""
    property string shellProgressState: "idle"
    property string shellProgressPhase: ""
    property int shellProgressStep: 0
    property int shellProgressTotalSteps: 5
    property string shellProgressTargetCommit: ""
    property int shellProgressStartedEpoch: 0
    property int shellProgressUpdatedEpoch: 0
    property string shellProgressScreenName: ""
    property string shellProgressError: ""
    property bool shellProgressAcknowledged: true
    property bool shellProgressPanelOpen: true
    property int shellProgressNowEpoch: Math.floor(Date.now() / 1000)
    property string _shellProgressCompleteRunId: ""
    readonly property bool shellProgressInterrupted: shellProgressState === "running"
        && shellProgressUpdatedEpoch > 0
        && shellProgressNowEpoch - shellProgressUpdatedEpoch > 600
    readonly property bool shellProgressRunning: shellProgressState === "running" && !shellProgressInterrupted
    readonly property bool shellProgressFailed: shellProgressState === "failed"
    readonly property bool shellProgressCompleted: shellProgressState === "completed" && !shellProgressAcknowledged
    readonly property bool shellUpdateProgressVisible: shellProgressRunning
        || shellProgressFailed || shellProgressCompleted || shellProgressInterrupted

    function updateShellProgressClock() {
        shellProgressNowEpoch = Math.floor(Date.now() / 1000)
    }

    function resetShellProgress() {
        shellProgressRunId = ""
        shellProgressState = "idle"
        shellProgressPhase = ""
        shellProgressStep = 0
        shellProgressTotalSteps = 5
        shellProgressTargetCommit = ""
        shellProgressStartedEpoch = 0
        shellProgressUpdatedEpoch = 0
        shellProgressScreenName = ""
        shellProgressError = ""
        shellProgressAcknowledged = true
        shellProgressPanelOpen = true
    }

    function openShellProgressPanel() {
        activatePopupScreenByName(shellProgressScreenName)
        activeUpdateTab = "shell"
        archVisible = true
    }

    function resetShellUpdateState() {
        shellUpdateBehind = 0
        shellUpdateSummary = []
        shellUpdateVersion = ""
        shellUpdateChecked = ""
        shellUpdateBaseCommit = ""
        shellUpdateTargetCommit = ""
        shellUpdateRepository = ""
        shellUpdateUpstreamRef = ""
    }

    function parseShellUpdateState(raw) {
        try {
            var j = JSON.parse(raw)
            if (j.schemaVersion !== 5) {
                resetShellUpdateState()
                return
            }
            shellUpdateBehind = j.behind || 0
            shellUpdateSummary = j.summary || []
            shellUpdateVersion = j.version || ""
            shellUpdateChecked = j.checked || ""
            shellUpdateBaseCommit = j.baseCommit || ""
            shellUpdateTargetCommit = j.targetCommit || ""
            shellUpdateRepository = j.repository || ""
            shellUpdateUpstreamRef = j.upstreamRef || ""
        } catch (e) {
            resetShellUpdateState()
        }
    }

    function parseShellInstalledCommit(raw) {
        shellInstalledCommit = raw.trim()
    }

    function parseShellProgress(raw) {
        try {
            var j = JSON.parse(raw)
            if (j.schemaVersion !== 1) {
                resetShellProgress()
                return
            }

            shellProgressRunId = j.runId || ""
            shellProgressState = j.state || "idle"
            shellProgressPhase = j.phase || ""
            shellProgressStep = j.step || 0
            shellProgressTotalSteps = j.totalSteps || 5
            shellProgressTargetCommit = j.targetCommit || ""
            shellProgressStartedEpoch = j.startedEpoch || 0
            shellProgressUpdatedEpoch = j.updatedEpoch || 0
            shellProgressScreenName = j.screenName || ""
            shellProgressError = j.error || ""
            shellProgressAcknowledged = j.acknowledged === true
            shellProgressPanelOpen = j.panelOpen !== false
            updateShellProgressClock()

            if (shellUpdateProgressVisible && shellProgressPanelOpen) openShellProgressPanel()
            if (shellProgressRunning
                    && shellProgressPhase === "restarting"
                    && shellProgressRunId !== ""
                    && _shellProgressCompleteRunId !== shellProgressRunId) {
                _shellProgressCompleteRunId = shellProgressRunId
                shellProgressCompleteProc.command = [
                    "bash",
                    Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh",
                    "--complete-progress",
                    shellProgressRunId
                ]
                shellProgressCompleteProc.running = false
                shellProgressCompleteProc.running = true
            }
        } catch (e) {
            resetShellProgress()
        }
    }

    function ackShellProgress() {
        if (!shellProgressRunId) return
        shellProgressAckProc.command = [
            "bash",
            Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh",
            "--ack-progress",
            shellProgressRunId
        ]
        shellProgressAckProc.running = false
        shellProgressAckProc.running = true
    }

    function setShellProgressPanelOpen(open) {
        if (!shellProgressRunId || !shellUpdateProgressVisible) return
        shellProgressPanelOpen = open
        shellProgressPanelProc.command = [
            "bash",
            Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh",
            "--progress-panel",
            shellProgressRunId,
            open ? "open" : "closed"
        ]
        shellProgressPanelProc.running = false
        shellProgressPanelProc.running = true
    }

    function closeArchUpdatesPanel() {
        if (shellUpdateProgressVisible) setShellProgressPanelOpen(false)
        archVisible = false
    }

    function showShellUpdateTabFromWidget() {
        if (shellUpdateProgressVisible) setShellProgressPanelOpen(true)
        activeUpdateTab = "shell"
        archVisible = true
    }

    function reloadShellUpdateState() {
        shellUpdateStateFile.reload()
        shellInstalledCommitFile.reload()
        shellProgressFile.reload()
    }

    Timer {
        interval: 15000
        running: shellProgressState === "running"
        repeat: true
        triggeredOnStart: true
        onTriggered: updateShellProgressClock()
    }

    FileView {
        id: shellUpdateStateFile
        path: Quickshell.env("HOME") + "/.cache/qs-shell/update-available.json"
        watchChanges: true
        printErrors: false
        onFileChanged: shellUpdateStateFile.reload()
        onLoaded: parseShellUpdateState(shellUpdateStateFile.text())
        onLoadFailed: resetShellUpdateState()
    }

    FileView {
        id: shellInstalledCommitFile
        path: Quickshell.env("HOME") + "/.config/quickshell/bar/.qsrise-commit"
        watchChanges: true
        printErrors: false
        onFileChanged: shellInstalledCommitFile.reload()
        onLoaded: parseShellInstalledCommit(shellInstalledCommitFile.text())
        onLoadFailed: shellInstalledCommit = ""
    }

    FileView {
        id: shellProgressFile
        path: Quickshell.env("HOME") + "/.cache/qs-shell/apply-status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: shellProgressFile.reload()
        onLoaded: parseShellProgress(shellProgressFile.text())
        onLoadFailed: resetShellProgress()
    }

    Process {
        id: shellProgressCompleteProc
        command: ["true"]
        onExited: shellProgressFile.reload()
    }

    Process {
        id: shellProgressAckProc
        command: ["true"]
        onExited: {
            shellProgressFile.reload()
            archVisible = false
        }
    }

    Process {
        id: shellProgressPanelProc
        command: ["true"]
        onExited: shellProgressFile.reload()
    }

    // ── Theme Updater state (fed by ArchUpdaterPanel's FileView over
    //    ~/.cache/qs-theme-updates.json; the panel owns the check Process so it
    //    runs ONCE, not per-monitor). The bar/tooltip only read these counts;
    //    the panel renders themeUpdList. Theme updates run in a visible terminal
    //    through qs-theme-apply-update.sh and are pinned to the checked target
    //    commit. ──
    property int    themeUpdOutdated: 0
    property int    themeUpdLocalEdits: 0
    property int    themeUpdTotal: 0
    property int    themeUpdReachable: 0
    property bool   themeUpdDegraded: false
    property bool   themeUpdCurrentStale: false
    property string themeUpdChecked: ""      // ISO timestamp of the last check, "" = never
    property var    themeUpdList: []          // outdated/unreachable entries shown in the panel
    property bool   themeUpdChecking: false   // a check is in flight (button disabled)
    property int    themeCheckTick: 0         // ++ from the panel button to trigger a check
    property string activeUpdateTab: "packages"   // which ArchUpdaterPanel tab is shown
    property bool   archBadgePackages: true   // package count badge on the bar updater icon
    property bool   archBadgeThemes: true     // clean-theme count badge on the bar updater icon
    property bool   archBadgeShell: true      // shell-update badge on the bar updater icon

    // ── Tray state ──
    property bool trayVisible: false
    onTrayVisibleChanged: popupOpened("trayVisible")
    property var trayPinned: []
    property real trayBarX: 10
    property real trayCaretBarX: trayBarX

    // ── slot-aware panel X anchors (center-X of each group; set by BarSlot) ──
    property real volumeBarX:     0
    property real networkBarX:    0
    property real batteryBarX:    0
    property real memoryBarX:     0
    property real cpuBarX:        0
    property real gpuBarX:        0
    property real thermalBarX:    0
    property real storageBarX:    0
    property real aiBarX:         0
    property real workspaceBarX:  0
    property real archBarX:       0
    property real archCaretBarX:  archBarX
    property real notifCaretBarX: notifBarX
    property real bluetoothBarX:  0
    property real brightnessBarX: 0
    property real powerBarX:      0
    property real mprisBarX:      0
    property real weatherBarX:    0
    property real calendarBarX:   weatherBarX
    property real launcherBarX:   6   // ControlPanel follows the Launcher/Control group

    // One connected popover at a time: the active panel publishes the exact
    // bar-widget center used by both the caret and the small border opening.
    readonly property bool anchoredPanelVisible: calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || notifVisible || powerProfileVisible || storageVisible
        || archVisible || trayVisible

    // Preserve the panel surface's actually rendered tip while it closes so
    // the matching bar notch retracts at the same point. Edge panels clamp the
    // tip away from their rounded corner, so the raw widget center is not
    // always the final rendered position.
    property real panelInsetX: 0
    property bool panelInsetReady: false
    function setPanelInsetX(x) {
        if (!anchoredPanelVisible) return

        if (isFinite(x) && x > 0) {
            panelInsetX = x
            panelInsetReady = true
        }
    }
    property real panelInsetReveal: anchoredPanelVisible ? 1 : 0
    onPanelInsetRevealChanged: {
        if (!anchoredPanelVisible && panelInsetReveal <= 0.001)
            panelInsetReady = false
    }
    Behavior on panelInsetReveal {
        NumberAnimation {
            duration: theme.anchoredPanelVisible ? 160 : 120
            easing.type: theme.anchoredPanelVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    // ── Tray context-menu state (themed menu, rendered by TrayMenu.qml) ──
    property bool trayMenuVisible: false
    onTrayMenuVisibleChanged: popupOpened("trayMenuVisible")
    property string trayMenuService: ""  // service key of the clicked item; menu resolved live from Tray.items
    property real trayMenuX: 0           // global x to anchor the menu under the icon
    property string trayMenuTitle: ""
    property string trayMenuIcon: ""

    function trayDisplayName(item) {
        if (!item) return "Tray App"

        var title = String(item.title || "").trim()
        if (title !== "") return title

        var tooltipTitle = String((item.tooltip && item.tooltip.title) || "").trim()
        if (tooltipTitle !== "") return tooltipTitle

        var fallback = String(item.id || "").trim()
        var slash = fallback.lastIndexOf("/")
        if (slash >= 0 && slash < fallback.length - 1)
            fallback = fallback.substring(slash + 1)
        fallback = fallback.replace(/^org\.(kde|ayatana|freedesktop)\./i, "")
                           .replace(/[_-]+/g, " ")
        return fallback !== "" ? fallback : "Tray App"
    }

    function trayDescription(item, displayName) {
        if (!item) return ""

        var description = String((item.tooltip && item.tooltip.description) || "").trim()
        var tooltipTitle = String((item.tooltip && item.tooltip.title) || "").trim()
        var name = String(displayName || "").trim().toLowerCase()
        if (description !== "" && description.toLowerCase() !== name)
            return description
        if (tooltipTitle !== "" && tooltipTitle.toLowerCase() !== name)
            return tooltipTitle
        return ""
    }

    function openTrayMenu(service, x, title, icon) {
        if (!service) return
        trayMenuService = service
        trayMenuTitle = String(title || "App Menu")
        trayMenuIcon = String(icon || "")
        setPanelAnchor("trayMenu", x)
        trayMenuVisible = true
    }

    function trayIsHidden(item) {
        return trayPinned.indexOf(item.service) < 0
    }

    // toggle: hidden items get pinned (shown in bar); pinned items get unpinned (back to panel)
    function trayToggleHide(item) {
        var key = item.service
        if (!key) return
        var i = trayPinned.indexOf(key)
        if (i >= 0) {
            var a = trayPinned.slice(0, i)
            var b = trayPinned.slice(i + 1)
            trayPinned = a.concat(b)
            trayVisible = false
        } else {
            trayPinned = trayPinned.concat([key])
        }
    }

    Process {
        id: omarchyCurrentRootProbe
        command: ["bash", "-c",
            "state=\"$HOME/.local/state/ryoku/current\"; legacy=\"$HOME/.config/ryoku/current\"; " +
            "if command -v true >/dev/null 2>&1 && [ -d \"$state\" ] && [ -d /usr/share/ryoku ]; then printf '%s\\t%s\\n' \"$state\" /usr/share/ryoku; " +
            "elif [ -d \"$legacy\" ]; then printf '%s\\t%s\\n' \"$legacy\" \"$HOME/.local/share/ryoku\"; " +
            "else printf '%s\\t%s\\n' \"$legacy\" \"$HOME/.local/share/ryoku\"; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                var resolved = parts.length > 0 ? parts[0] : ""
                var installRoot = parts.length > 1 ? parts[1] : ""
                if (resolved) theme.omarchyCurrentRoot = resolved
                if (installRoot) theme.omarchyInstallRoot = installRoot
                theme.omarchyCurrentRootResolved = true
                currentThemeNameWatcher.reload()
                theme.reloadCurrentThemeFiles()
            }
        }
    }

    Timer {
        id: themeReloadDebounce
        interval: 40
        repeat: false
        onTriggered: {
            paletteReader.running = false
            paletteReader.running = true
        }
    }

    // Ryoku writes theme.name immediately after the complete theme directory
    // swap, before its slower application retint commands and final hooks.
    FileView {
        id: currentThemeNameWatcher
        path: theme.themeNamePath
        watchChanges: theme.omarchyCurrentRootResolved
        printErrors: false
        onLoaded: {
            theme.setCurrentThemeName(currentThemeNameWatcher.text())
            theme.reloadCurrentThemeFiles()
        }
        onLoadFailed: theme.setCurrentThemeName("")
        onFileChanged: {
            reload()
            theme.reloadCurrentThemeFiles()
        }
    }

    Process {
        id: paletteReader
        command: ["cat", theme.colorsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                Palette.apply(theme, Palette.parse(this.text));
            }
        }
    }

    // retint live on a palette-file change (a wallpaper swap never touches theme.name)
    FileView {
        id: paletteWatcher
        path: theme.colorsPath
        watchChanges: true
        printErrors: false
        onFileChanged: { paletteWatcher.reload(); theme.reloadCurrentThemeFiles() }
    }

    function ipcApplyTheme(payload) {
        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.apply: bad payload —", e); return; }
        if (!p || !p.colors) return;
        Palette.apply(theme, Palette.mapKeys(p.colors));
        theme.lastAppliedName = p.name || "";
    }

    function ipcApplyLauncher(payload) {
        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.applyLauncher: bad payload —", e); return; }
        theme.applyLauncherConfig(p);
    }

    function ipcReloadTheme() {
        paletteReader.running = false;
        paletteReader.running = true;
    }

    function ipcOpenPicker(mode) {
        if (mode === "theme" || mode === "wallpaper") openImagePicker(mode)
        else if (mode === "screenshots" || mode === "videos") openMediaBrowser(mode)
    }

    // Standalone compatibility while the integrated bootstrap is being rolled
    // out. VariantRoot supplies variantHost, so only the common IPC router owns
    // these targets in integrated mode.
    LazyLoader {
        active: theme.variantHost === null
        IpcHandler {
            target: "theme"
            function apply(payload: string): void { theme.ipcApplyTheme(payload) }
            function applyLauncher(payload: string): void { theme.ipcApplyLauncher(payload) }
            function reload(): void { theme.ipcReloadTheme() }
        }
    }

    LazyLoader {
        active: theme.variantHost === null
        IpcHandler {
            target: "picker"
            function theme(): void { ipcOpenPicker("theme") }
            function wallpaper(): void { ipcOpenPicker("wallpaper") }
            function screenshots(): void { ipcOpenPicker("screenshots") }
            function videos(): void { ipcOpenPicker("videos") }
        }
    }
}
