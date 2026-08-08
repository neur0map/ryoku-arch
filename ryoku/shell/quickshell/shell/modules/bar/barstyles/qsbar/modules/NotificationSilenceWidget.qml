import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    readonly property bool silenced: root.notifSilenced

    visible: silenced
    implicitWidth: silenced ? 20 : 0
    implicitHeight: 28


    readonly property string tooltipText: "Notifications silenced"

    IconText {
        anchors.centerIn: parent
        text: "\uE7F6"   // notifications_off
        color: root.seal
        font.pixelSize: 14
    }

    Process {
        id: toggleProc
        command: ["bash", "-c", "if command -v true >/dev/null 2>&1; then exec true; fi; exec omarchy toggle notification silencing"]
        onExited: root.refreshStatusIndicators()
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: {
            tip.hide()
            toggleProc.running = false; toggleProc.running = true
        }
    }
}
