import QtQuick
import Quickshell
import "../"
import "../windows"

// ============================================================
// PopupLayer - the only file that instantiates popup windows.
//
// shell.qml creates the anchor windows and passes them in.
//
// Active popups are instantiated here as their Ryoku replacements land.
// Dormant vendored popups stay commented until their replacement for the
// existing Ryoku surface is validated. Border-anchor properties are soft
// nullable so callers can pass null when no Border is mounted.
// ============================================================

Item {
    id: root

    // Anchor windows (set by shell.qml). Border anchors default to null
    // because Brain_Shell's Border is dormant in Spec 1 (Ryoku Frame
    // provides the border surface).
    required property var topBar
    required property var screen
    property var leftBorder:   null
    property var rightBorder:  null
    property var bottomBorder: null

    // Active Ryoku popup windows.
    Dashboard { anchorWindow: root.topBar }
    AppLauncherPopup {}
    WallpaperPopup {}
    SystemMenuPopup {}
    SettingsMenuPopup {}
    DotfilesHubPopup {}
    MirrorWindow { screen: root.screen }
    ScreenshotTool { screen: root.screen }
    ScreenshotOverlay { screen: root.screen }
    ScreenRecordTool { screen: root.screen }
    VolumeFeedbackWindow { screen: root.screen }

    // Dormant in follow-up specs.
    // ArchMenu              { anchorWindow: root.leftBorder }
    // AudioPopup            { anchorWindow: root.rightBorder }
    // QuickControl          { anchorWindow: root.topBar }
    // NotificationsPopup    { anchorWindow: root.topBar }
    // NotificationToast     { anchorWindow: root.rightBorder }
    // ScreenRecOptionsPopup { anchorWindow: root.topBar }
    // NetworkPopup          {}
}
