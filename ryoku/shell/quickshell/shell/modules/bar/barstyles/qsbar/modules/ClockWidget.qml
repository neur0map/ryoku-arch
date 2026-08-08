import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property date now: new Date()

    function pad(n) { return n < 10 ? "0" + n : String(n) }

    readonly property string timeStr: {
        if (root.clock12h) {
            var h = now.getHours() % 12; if (h === 0) h = 12
            return h + ":" + pad(now.getMinutes()) + " " + (now.getHours() < 12 ? "AM" : "PM")
        }
        return pad(now.getHours()) + ":" + pad(now.getMinutes())
    }

    readonly property var months: ["January","February","March","April","May","June",
                                    "July","August","September","October","November","December"]
    readonly property var days: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

    readonly property string tooltipText: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()] + " " + now.getFullYear()

    implicitWidth: label.implicitWidth
    implicitHeight: 28

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: rootMod.now = new Date()
    }

    UiText {
        id: label
        anchors.centerIn: parent
        text: rootMod.timeStr
        color: root.ink
        font.family: root.mono
        font.pixelSize: 12
        font.letterSpacing: 1
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process {
        id: tzRunner
        command: ["bash", "-c", "kitty true 2>/dev/null"]
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: { tip.show(); }
        onExited: { tip.hide(); }
        onClicked: (e) => {
            if (e.button === Qt.LeftButton) {
                root.clock12h = !root.clock12h;          // toggle 24h / 12h
            } else if (e.button === Qt.RightButton) {
                tip.hide();
                tzRunner.running = false;                // timezone picker (unchanged)
                tzRunner.running = true;
            }
        }
    }
}
