import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../services/"
import "../"

PanelWindow {
    id: root

    required property var anchorWindow

    Binding { target: Popups; property: "dashboardPageWidth"; value: Theme.dashboardWidth }

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: Theme.animDuration

    color:   "transparent"
    visible: windowVisible

    anchors.top:   true
    anchors.left:  true
    anchors.right: true

    implicitHeight: Theme.notchHeight + Theme.dashboardHeight
    exclusionMode:  ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: maskProxy }
    Item {
        id:     maskProxy
        x:      ((root.width - sizer.width) / 2) + root.fw
        y:      Theme.notchHeight
        width:  sizer.width - root.fw
        height: sizer.height - Theme.notchHeight
    }

    property bool windowVisible: false

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.animDuration + 20
        onTriggered: root.windowVisible = false
    }

    Item {
        id: sizer
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        width:  Popups.dashboardOpen ? Popups.dashboardPageWidth + 2 * root.fw : Theme.cNotchMinWidth + 2 * root.fw
        height: Popups.dashboardOpen ? Theme.dashboardHeight : Theme.notchHeight / 2

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        PopupShape {
            anchors.fill:  parent
            attachedEdge:  "top"
            color:         Theme.background
            radius:        Theme.cornerRadius
            flareWidth:    root.fw
            flareHeight:   root.fh
        }

        Item {
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
                bottomMargin: 8
            }

            opacity: Popups.dashboardOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.dashboardOpen
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

            DashHome {
                anchors.fill: parent
            }
        }
    }
}
