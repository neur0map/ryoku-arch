import QtQuick
import Quickshell
import Quickshell.Wayland
import "../components"
import "../shapes/"
import "../services/"
import "../"

PopupWindow {
    id: root

    required property var anchorWindow

    readonly property int popupWidth:   Theme.notificationsWidth
    readonly property int maxHeight:    700
    readonly property int fw:           Theme.notchRadius
    readonly property int fh:           Theme.notchRadius
    readonly property int animDuration: Theme.animDuration

    // Fixed — never zero, never dynamic
    implicitWidth:  popupWidth +fw
    implicitHeight: maxHeight

    anchor.window: root.anchorWindow
    anchor.rect: Qt.rect(
        (anchorWindow.width - Theme.notificationsWidth / 2)-(fw/2),
        0,
        Theme.notificationsWidth,
        Theme.notchHeight
    )
    anchor.gravity:    Edges.Bottom
    anchor.adjustment: PopupAdjustment.None
    
    Item {
    id:      maskProxy
    x:       root.implicitWidth - sizer.width-root.fw
    y:       -root.fh
    width:   sizer.width
    height:  sizer.height
    }

    color:   "transparent"
    visible: windowVisible
    mask: Region { item: maskProxy }

    // ── Visibility gate ───────────────────────────────────────
    // Window stays alive until the close animation finishes.
    property bool windowVisible: false

    Connections {
        target: Popups
        function onNotificationsOpenChanged() {
            if (Popups.notificationsOpen) {
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id:       closeTimer
        interval: root.animDuration + 20
        onTriggered: root.windowVisible = false
    }

    // ── Sizer ─────────────────────────────────────────────────
    // Anchored top-right so it grows leftward + downward from
    // the right notch — mirroring how Dashboard grows from center.
    Item {
        id:            sizer
        anchors.top:   parent.top
        anchors.right: parent.right
        clip:          true

        // Width: rNotchMinWidth → notificationsWidth  (+ fw for flare region)
        width: Popups.notificationsOpen
               ? Theme.notificationsWidth + root.fw
               : Theme.rNotchMinWidth + root.fw

        // Height: fh (invisible sliver) → full content height
        height: Popups.notificationsOpen
                ? notifList.height + Theme.popupPadding * 2 + root.fh
                : root.fh

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        // ── Background ─────────────────────────────────────────
        PopupShape {
            anchors.fill: parent
            attachedEdge: "right"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        // ── Content ────────────────────────────────────────────
        // Inset clear of the flare region.
        // Fades in slowly after expansion, fades out fast on close.
        Item {
            anchors {
                fill:         parent
                topMargin:    root.fh + 4
                leftMargin:   root.fw + 4
                rightMargin:  4
                bottomMargin: 4
            }

            opacity: Popups.notificationsOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.notificationsOpen
                              ? root.animDuration * 0.5
                              : root.animDuration * 0.15
                }
            }

            NotificationList {
                id:    notifList
                width: parent.width
            }
        }
    }
}
