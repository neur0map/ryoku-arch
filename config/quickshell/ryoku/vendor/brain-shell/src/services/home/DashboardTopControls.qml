import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../"

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    property real _brightnessVal:  0.72
    property int  _brightnessMax:  100
    property bool _brightnessBusy: false
    property int  _brightnessTarget: 72

    width:  300
    height: 24

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Process {
        id: brightnessRead
        command: ["bash", "-c", "brightnessctl -c backlight -m"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (root._brightnessBusy) return

                var parts = line.split(",")
                if (parts.length < 5) return

                var cur = parseInt(parts[2])
                var max = parseInt(parts[4])
                if (max > 0) {
                    root._brightnessMax = max
                    root._brightnessVal = cur / max
                }
            }
        }
    }

    Process {
        id: brightnessWrite
        command: ["bash", "-c", "brightnessctl -c backlight set " + root._brightnessTarget]
        running: false
        onExited: {
            root._brightnessBusy = false
            brightnessRead.running = false
            brightnessRead.running = true
        }
    }

    Timer {
        id: brightnessDebounce
        interval: 50
        repeat: false
        onTriggered: {
            brightnessWrite.running = false
            brightnessWrite.running = true
        }
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: if (!root._brightnessBusy) {
            brightnessRead.running = false
            brightnessRead.running = true
        }
    }

    Component.onCompleted: brightnessRead.running = true

    function setBrightness(v) {
        var clamped = Math.max(0.0, Math.min(1.0, v))
        var target = Math.round(clamped * root._brightnessMax)
        root._brightnessVal = clamped
        root._brightnessTarget = target <= 0 ? 2 : target
        root._brightnessBusy = true
        brightnessDebounce.restart()
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        TopWaveControl {
            label: "VOL"
            value: root.sink?.ready ? Math.max(0, Math.min(1, root.sink.audio.volume)) : 0
            active: root.sink?.ready ?? false
            color: root.sink?.audio.muted ? Qt.rgba(1, 1, 1, 0.28) : Theme.active
            onValueRequested: function(v) {
                if (root.sink?.ready) root.sink.audio.volume = v
            }
        }

        TopWaveControl {
            label: "BRI"
            value: root._brightnessVal
            active: true
            color: "#f5c47a"
            onValueRequested: function(v) {
                root.setBrightness(v)
            }
        }
    }

    component TopWaveControl: Item {
        id: control

        property string label: ""
        property real value: 0
        property bool active: true
        property color color: Theme.active

        signal valueRequested(real value)

        width:  136
        height: 24

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.055)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
        }

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            text: control.label
            font.pixelSize: 8
            font.weight: Font.Bold
            font.family: "JetBrains Mono"
            color: control.active ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(1, 1, 1, 0.24)
        }

        Text {
            id: pctText
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            horizontalAlignment: Text.AlignRight
            text: control.active ? Math.round(control.value * 100) + "%" : "--%"
            font.pixelSize: 8
            font.weight: Font.Bold
            font.family: "JetBrains Mono"
            color: control.active ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(1, 1, 1, 0.24)
        }

        Item {
            id: waveHit
            anchors.left: labelText.right
            anchors.leftMargin: 5
            anchors.right: pctText.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 18

            WaveBar {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: control.active ? control.value : 0
                color: control.active ? control.color : Qt.rgba(1, 1, 1, 0.18)
                wavelength: 11
                amplitude: 2.4
                strokeWidth: 2
                valueDuration: 160
            }
        }

        MouseArea {
            id: controlHit
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor

            function calc(mx) {
                return Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)))
            }

            onPressed: control.valueRequested(calc(mouseX))
            onPositionChanged: if (pressed) control.valueRequested(calc(mouseX))
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
                control.valueRequested(Math.max(0.0, Math.min(1.0, control.value + delta)))
            }
        }
    }
}
