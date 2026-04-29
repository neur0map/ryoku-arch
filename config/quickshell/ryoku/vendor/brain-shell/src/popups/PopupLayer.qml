import QtQuick
import Quickshell
import "../"

// ============================================================
// PopupLayer - the only file that instantiates popup windows.
//
// shell.qml creates the anchor windows and passes them in.
//
// Ryoku Spec 1 activation: only Dashboard is instantiated. The dashboard
// is its own layer-shell window that slides down from above the screen
// (caelestia-style spatial motion) so the TopBar surface itself never
// resizes during animation.
// Other popups are vendored as code but commented out; each is
// re-enabled in a follow-up spec when its replacement for the
// existing Ryoku surface (mako, swayosd, fuzzel, etc.) is
// validated. Border-anchor properties softened from
// `required property var` to `property var ... : null` so
// callers can pass null when no Border is mounted.
// ============================================================

Item {
    id: root

    // Anchor windows (set by shell.qml). Border anchors default to null
    // because Brain_Shell's Border is dormant in Spec 1 (Ryoku Frame
    // provides the border surface).
    required property var topBar
    property var leftBorder:   null
    property var rightBorder:  null
    property var bottomBorder: null

    // Active in Spec 1
    Dashboard { anchorWindow: root.topBar }

    // Dormant in follow-up specs.
    // ArchMenu              { anchorWindow: root.leftBorder }
    // WallpaperPopup        {}
    // AudioPopup            { anchorWindow: root.rightBorder }
    // QuickControl          { anchorWindow: root.topBar }
    // NotificationsPopup    { anchorWindow: root.topBar }
    // NotificationToast     { anchorWindow: root.rightBorder }
    // ScreenRecOptionsPopup { anchorWindow: root.topBar }
    // NetworkPopup          {}
}
