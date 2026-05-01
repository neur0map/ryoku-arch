import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../modules/Gap/"

PanelWindow {
    id: root

    readonly property int toastWidth: 150
    readonly property int toastSurfaceHeight: Theme.notchHeight + 30
    readonly property real gapLeft: width / 2 + ShellState.topBarCWidth / 2
    readonly property real gapRight: width - ShellState.topBarRWidth
    readonly property real gapWidth: Math.max(0, gapRight - gapLeft)
    readonly property bool canShow: gapWidth >= toastWidth + 18
                                    && !ShellState.focusMode
                                    && !Popups.toolboxOpen
                                    && !Popups.dashboardOpen
                                    && !Popups.networkOpen
                                    && !Popups.notificationsOpen

    property bool windowVisible: false

    color: "transparent"
    visible: windowVisible
    implicitHeight: toastSurfaceHeight
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Connections {
        target: VolumeFeedback
        function onVisibleChanged() {
            if (VolumeFeedback.visible) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: root.windowVisible = false
    }

    mask: Region { item: maskProxy }
    Item {
        id: maskProxy
        x: toast.x
        y: toast.y
        width: toast.width
        height: toast.visible && toast.active ? toast.height : -1
    }

    VolumeToast {
        id: toast
        width: root.toastWidth
        height: implicitHeight
        x: root.gapLeft + (root.gapWidth - width) / 2
        active: VolumeFeedback.visible && root.canShow
    }
}
