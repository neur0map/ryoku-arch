import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "Singletons"

Card {
    id: root
    eyebrow: "Display"

    property bool opened: false

    property int brightness: 75
    property int vibrance: 40

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/nvibrant-value"

    function applyBrightness(pct) {
        var p = Math.max(5, Math.min(100, Math.round(pct)));
        Quickshell.execDetached(["bash", "-c", "timeout 3 ddcutil setvcp 10 " + p + " --bus 3 --noverify & timeout 3 ddcutil setvcp 10 " + p + " --bus 4 --noverify & wait"]);
    }

    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        Quickshell.execDetached(["nvibrant", String(raw), "0", String(raw)]);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname '" + root.stateFile + "')\" && echo " + Math.round(pct) + " > '" + root.stateFile + "'"]);
    }

    onOpenedChanged: if (opened) brRead.running = true

    Component.onCompleted: {
        var v = parseInt((vibState.text() || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
    }

    Process {
        id: brRead
        command: ["timeout", "3", "ddcutil", "getvcp", "10", "--bus", "3", "--brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/C\s+(\d+)\s+/);
                if (m)
                    root.brightness = parseInt(m[1]);
            }
        }
    }

    FileView {
        id: vibState
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    component VolRow: Item {
        property string icon: ""
        property real value: 0.5
        property string valueLabel: ""
        signal moved(real v)
        signal committed(real v)
        width: parent ? parent.width : 0
        implicitHeight: 19 * root.s

        Item {
            id: vicon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 19 * root.s; height: 19 * root.s
            Image {
                id: vIconImg
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/icons/" + icon + ".svg")
                sourceSize.width: 64; sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true; visible: false
            }
            MultiEffect {
                anchors.fill: vIconImg
                source: vIconImg
                colorization: 1.0
                colorizationColor: Theme.vermLit
            }
        }
        Text {
            id: vval
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * root.s
            horizontalAlignment: Text.AlignRight
            text: valueLabel
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
        }
        Slider {
            s: root.s
            value: parent.value
            anchors.left: vicon.right
            anchors.leftMargin: 12 * root.s
            anchors.right: vval.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            onMoved: (v) => parent.moved(v)
            onCommitted: (v) => parent.committed(v)
        }
    }

    Column {
        width: parent.width
        spacing: 8 * root.s
        Text {
            text: "Brightness"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.Medium
        }
        VolRow {
            icon: "sun"
            value: root.brightness / 100
            valueLabel: root.brightness + "%"
            onMoved: (v) => root.brightness = Math.round(v * 100)
            onCommitted: (v) => root.applyBrightness(v * 100)
        }
    }

    Column {
        width: parent.width
        spacing: 8 * root.s
        Text {
            text: "Vibrance"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.Medium
        }
        VolRow {
            icon: "monitor"
            value: root.vibrance / 100
            valueLabel: root.vibrance + "%"
            onMoved: (v) => root.vibrance = Math.round(v * 100)
            onCommitted: (v) => { root.applyVibrance(v * 100); root.saveVibrance(v * 100); }
        }
    }
}
