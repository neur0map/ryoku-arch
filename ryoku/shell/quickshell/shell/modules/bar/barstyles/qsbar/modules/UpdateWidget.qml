import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property bool updateAvailable: false
    onUpdateAvailableChanged: root.omarchyUpdateAvail = updateAvailable   // mirror for the swarm reactor

    visible: updateAvailable
    implicitWidth: updateAvailable ? 20 : 0
    implicitHeight: 28


    readonly property string tooltipText: "Ryoku update available"

    IconText {
        anchors.centerIn: parent
        text: "\uE627"   // sync
        color: root.seal
        font.pixelSize: 15
    }

    Process {
        id: updateProc
        command: ["bash", "-c", "ryoku status --json 2>/dev/null | grep -q '\"available\":true' && echo YES || echo NO"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { rootMod.updateAvailable = this.text.trim() === "YES" }
        }
    }

    Timer {
        interval: 21600000   // 6h
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { updateProc.running = false; updateProc.running = true }
    }

    Process { id: runProc; command: ["bash", "-c", "kitty ryoku update"] }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: {
            tip.hide()
            runProc.running = false; runProc.running = true
        }
    }
}
