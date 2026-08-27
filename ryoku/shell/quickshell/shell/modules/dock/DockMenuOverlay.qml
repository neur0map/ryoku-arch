pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services

// Full-screen overlay that renders the dock's right-click context menu on the
// monitor the click came from. The dock surface itself is a thin edge strip, so
// the menu cannot live inside it; this dedicated layer draws above the desktop
// and dismisses on an outside click. One instance per monitor (shell.qml).
//
// While open the overlay is modal on its monitor: any click lands here, the menu
// handles its own rows and the dismiss layer catches everything else. The window
// is not visible when closed, so it never steals desktop input then.
PanelWindow {
    id: overlay

    // Shown only on the monitor that owns the open menu.
    readonly property string screenName: overlay.screen ? overlay.screen.name : ""
    readonly property bool shown: Dock.menuOpen && Dock.menuScreen === overlay.screenName
    readonly property bool horizontalEdge: Dock.menuEdge === "top" || Dock.menuEdge === "bottom"

    color: "transparent"
    visible: overlay.shown
    WlrLayershell.namespace: "ryoku-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // Outside click dismisses.
    MouseArea {
        id: dismiss
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: Dock.closeMenu()
    }

    DockMenu {
        id: ctxMenu
        readonly property real gap: 8
        // The click's global coordinate is only reliable along the dock's own axis
        // (the perpendicular offset differs between the dock strip and this
        // full-screen layer), so the along-axis follows the icon while the other
        // axis is pinned to the dock edge, clearing the band by Dock.menuEdgeClear.
        readonly property point ic: dismiss.mapFromGlobal(Dock.menuGx, Dock.menuGy)
        readonly property real edgeOff: Dock.menuEdgeClear + gap
        x: overlay.horizontalEdge
            ? Math.max(gap, Math.min(overlay.width - width - gap, ic.x - width / 2))
            : (Dock.menuEdge === "left" ? edgeOff : (overlay.width - edgeOff - width))
        y: overlay.horizontalEdge
            ? (Dock.menuEdge === "top" ? edgeOff : (overlay.height - edgeOff - height))
            : Math.max(gap, Math.min(overlay.height - height - gap, ic.y - height / 2))
    }
}
