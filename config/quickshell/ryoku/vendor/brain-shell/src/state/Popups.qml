pragma Singleton
import QtQuick

QtObject {
    // ── Per-popup open state ───────────────────────────────────────────────────
    property bool audioOpen:         false
    property bool networkOpen:       false
    property bool batteryOpen:       false
    property bool notificationsOpen: false
    property bool archMenuOpen:      false
    property bool dashboardOpen:     false
    property bool launcherOpen:      false
    // True while the launcher card is visually present. Driven from
    // AppLauncherPopup.qml so TopBar can stay on Overlay and make the
    // card read as an extension of the center pill during close.
    property bool launcherVisible:   false
    // True while the dashboard card is visually present (open, opening,
    // or closing). Driven from Dashboard.qml; TopBar uses this to hold
    // its surface on the Overlay layer for the entire close animation
    // so the bar's pill keeps painting over the retracting card.
    property bool dashboardVisible:  false
    property bool wallpaperOpen:     false
    // "wallpaper" and "theme" share the bottom selector surface.
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

    // ── Global state ──────────────────────────────────────────────────────────
    readonly property bool anyOpen: audioOpen || networkOpen || batteryOpen
                                    || notificationsOpen || archMenuOpen
                                    || dashboardOpen || wallpaperOpen || quickOpen

    function closeAll() {
        audioOpen         = false
        networkOpen       = false
        batteryOpen       = false
        notificationsOpen = false
        archMenuOpen      = false
        dashboardOpen     = false
        launcherOpen      = false
        wallpaperOpen     = false
        quickOpen           = false
    }
}
