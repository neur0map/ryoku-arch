import QtQuick
import Quickshell
import qs.components
import Quickshell.Io

PanelWindow {
    id: calendarWindow

    visible: false
    color: "transparent"

    anchors.top: true
    anchors.left: true
    margins.top: 0
    margins.left: 240

    implicitWidth: 340
    implicitHeight: 380

    Calendar {
        anchors.fill: parent
    }

    IpcHandler {
        target: "calendarWindow"
        function toggle(): void {
            calendarWindow.visible = !calendarWindow.visible
        }

    }

}
