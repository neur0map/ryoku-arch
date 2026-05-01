pragma Singleton
import QtQuick

QtObject {
    signal toolboxActionRequested(string action)
    signal batteryWarningRequested(int level)

    // ── Per-popup open state ───────────────────────────────────────────────────
    property bool audioOpen:         false
    property bool networkOpen:       false
    property bool batteryOpen:       false
    property bool notificationsOpen: false
    property bool archMenuOpen:      false
    property bool dashboardOpen:     false
    property bool launcherOpen:      false
    property bool toolboxOpen:       false
    property bool screenshotToolOpen: false
    property bool screenRecordToolOpen: false
    property bool mirrorOpen:        false
    property string mirrorScreenName: ""
    property bool systemMenuOpen:    false
    property bool settingsMenuOpen:  false
    property string settingsMenuRequestedPage:    "home"
    property string settingsMenuRequestedSubpage: ""
    property bool legacySettingsMenuOpen: false
    property string legacySettingsMenuRequestedPage: "home"
    property string legacySettingsMenuRequestedSubpage: ""
    property bool dotfilesOpen:      false
    // True while the launcher card is visually present. Driven from
    // AppLauncherPopup.qml so TopBar can stay on Overlay and make the
    // card read as an extension of the center pill during close.
    property bool launcherVisible:   false
    // Topbar-attached menu visual states. The popup windows drive
    // these so TopBar can remain on Overlay through close animations.
    property bool systemMenuVisible:   false
    property bool settingsMenuVisible: false
    property bool legacySettingsMenuVisible: false
    property bool dotfilesVisible:     false
    // True while the dashboard card is visually present (open, opening,
    // or closing). Driven from Dashboard.qml; TopBar uses this to hold
    // its surface on the Overlay layer for the entire close animation
    // so the bar's pill keeps painting over the retracting card.
    property bool dashboardVisible:  false
    property bool wallpaperOpen:     false
    // Appearance modes share the bottom selector surface.
    property string wallpaperMode:   "wallpaper"
    // True while the wallpaper selector is visually present. Driven
    // from WallpaperPopup.qml for shared dismissal and visual-state
    // checks; the selector is a fullscreen modal layer above the bar.
    property bool wallpaperVisible:  false
    property bool notificationToastOpen:    false
    property bool quickOpen: false

    // ── Dashboard — per-page width (px, content only, excluding fw padding) ───
    property int dashboardPageWidth: 900
    
    // ── Network popup — per-page content (string key) ─────────────────────────
    property string networkPage: ""

    // ── Per-popup trigger hover state ─────────────────────────────────────────
    property bool archMenuTriggerHovered: false
    property bool audioTriggerHovered:         false
    property bool networkTriggerHovered:       false
    property bool batteryTriggerHovered:       false
    property bool notificationsTriggerHovered: false
    property bool wallpaperTriggerHovered:     false
    property bool quickTriggerHovered: false

    // ── Universal popup behavior settings ─────────────────────────────────────
    property int  slideDuration:   260
    property int  hoverCloseDelay: 180

    // ── Confirm dialog ────────────────────────────────────────────────────────
    property bool   confirmOpen:    false
    property string confirmTitle:   ""
    property string confirmMessage: ""
    property string confirmLabel:   "Confirm"
    property string confirmAction:  ""
    property string confirmGfxMode: ""
    property bool   confirmRunning: false

    function showConfirm(title, message, label, action, gfxMode) {
        confirmTitle   = title
        confirmMessage = message
        confirmLabel   = label
        confirmAction  = action
        confirmGfxMode = gfxMode ?? ""
        confirmOpen    = true
    }

    function cancelConfirm() {
        confirmOpen    = false
        confirmAction  = ""
        confirmGfxMode = ""
    }

    function requestToolboxAction(action) {
        toolboxActionRequested(action)
    }

    function requestSettingsMenuPage(page, subpage) {
        settingsMenuRequestedPage = page && page !== "" ? page : "home"
        settingsMenuRequestedSubpage = subpage && subpage !== "" ? subpage : ""
    }

    function requestLegacySettingsMenuPage(page, subpage) {
        legacySettingsMenuRequestedPage = page && page !== "" ? page : "home"
        legacySettingsMenuRequestedSubpage = subpage && subpage !== "" ? subpage : ""
    }

    function requestBatteryWarning(level) {
        var numericLevel = Number(level)
        if (isNaN(numericLevel)) numericLevel = 10
        numericLevel = Math.max(1, Math.min(100, Math.round(numericLevel)))
        batteryWarningRequested(numericLevel)
    }

    // ── Global state ──────────────────────────────────────────────────────────
    readonly property bool anyOpen: audioOpen || networkOpen || batteryOpen
                                    || notificationsOpen || archMenuOpen
                                    || dashboardOpen || wallpaperOpen
                                    || toolboxOpen || quickOpen

    function closeAll() {
        audioOpen         = false
        networkOpen       = false
        batteryOpen       = false
        notificationsOpen = false
        archMenuOpen      = false
        dashboardOpen     = false
        launcherOpen      = false
        toolboxOpen       = false
        screenshotToolOpen = false
        screenRecordToolOpen = false
        mirrorOpen        = false
        mirrorScreenName  = ""
        systemMenuOpen     = false
        settingsMenuOpen   = false
        legacySettingsMenuOpen = false
        dotfilesOpen       = false
        wallpaperOpen     = false
        quickOpen           = false
    }
}
