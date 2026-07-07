pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

// Notification toasts in their own small layer window, top-right (the standard
// notification corner). Re-homed from the floating pill: shows the latest
// Notifs popup with a '+N' overflow count; clicking it opens the inbox popout
// (via openInbox, wired in shell.qml). Maps only while a popup is live; never
// takes focus, never reserves space.
PanelWindow {
    id: win

    required property var modelData
    readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))

    // top/bottom bar (left/right collapse to top, as the overlay does).
    readonly property string barPos: Config.barEnabled ? (Config.barPosition === "bottom" ? "bottom" : "top") : ""
    readonly property bool barTop: barPos === "top"
    readonly property real frameLip: Math.max(0, Config.frameBorder - 50)
    readonly property real barVisibleH: frameLip + Config.barHeight * s
    // clear the top frame lip (plus a top bar's band) and the right frame lip.
    readonly property real topInset: (barTop ? barVisibleH : frameLip) + 12 * s
    readonly property real rightInset: frameLip + 12 * s

    // this monitor's active workspace has a fullscreen window: the shell hides
    // then, so toasts stay hidden (they still expire silently on their timer).
    readonly property bool monFullscreen: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.hasFullscreen : false;
        return false;
    }

    readonly property real toastW: 342 * s
    readonly property real padX: 16 * s
    readonly property real padY: 12 * s

    // clicking the toast opens the inbox popout; shell.qml routes this to the
    // owning monitor.
    signal openInbox()

    screen: modelData
    visible: Notifs.popups.length > 0 && !monFullscreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-toast"

    anchors.top: true
    anchors.right: true
    margins.top: topInset
    margins.right: rightInset

    implicitWidth: toastW
    implicitHeight: (toastLoader.item ? toastLoader.item.implicitHeight : 44 * s) + 2 * padY

    // warm surface fill + hairline border, fully rounded; the Toast supplies
    // no background of its own.
    Rectangle {
        anchors.fill: parent
        radius: Config.osdRadius * win.s
        color: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
        opacity: Config.osdOpacity
        border.width: 1.5
        border.color: Wallust.border
        antialiasing: true
    }

    Loader {
        id: toastLoader
        // kept active whenever a popup exists (even hidden under fullscreen), so
        // the Toast's expire timer keeps running and null-notif never binds.
        active: Notifs.popups.length > 0
        anchors.fill: parent
        anchors.topMargin: win.padY
        anchors.bottomMargin: win.padY
        anchors.leftMargin: win.padX
        anchors.rightMargin: win.padX

        sourceComponent: Item {
            implicitHeight: toastContent.implicitHeight

            Toast {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                s: win.s
                notif: Notifs.popups.length > 0 ? Notifs.popups[Notifs.popups.length - 1] : null
                onOpenCenter: win.openInbox()
            }

            // '+N' overflow: how many more popups wait behind this one.
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: Notifs.popups.length > 1
                text: "+" + (Notifs.popups.length - 1)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9 * win.s
                font.weight: Font.DemiBold
            }
        }
    }
}
