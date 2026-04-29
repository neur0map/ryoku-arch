import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../components"

// Brightness card — horizontal drag bar wired to brightnessctl.
// Polls every second to reflect keyboard hotkey changes.

StatCard {
    id: root
    padding: 0

    // ── State ─────────────────────────────────────────────────────────────────
    property real _val:  0.72
    property int  _max:  100
    property bool _busy: false   // true while write is in flight, blocks poll

    // ── Processes ─────────────────────────────────────────────────────────────

    // Read: brightnessctl -m  →  "device,name,X%,current,max"
    Process {
        id: brightRead
        command: ["bash", "-c", "brightnessctl -m"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.split(",")
                if (parts.length >= 5) {
                    var cur = parseInt(parts[2])
                    var max = parseInt(parts[4])
                    if (max > 0) {
                        root._max = max
                        root._val = cur / max
                    }
                }
            }
        }
    }

    // Write: brightnessctl set <value>
    Process {
        id: brightWrite
        command: ["bash", "-c",
            "brightnessctl set " +
            (Math.round(root._val * root._max) <= 0 ? 2 : Math.round(root._val * root._max))]
        running: false
        onRunningChanged: if (!running) root._busy = false
    }

    // Debounce — 50ms after last drag
    Timer {
        id: debounce; interval: 50; repeat: false
        onTriggered: { root._busy = true; brightWrite.running = true }
    }

    // Poll — keeps bar in sync with keyboard hotkeys
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: if (!root._busy) brightRead.running = true
    }

    Component.onCompleted: brightRead.running = true

    function _set(v) {
        root._val = Math.max(0.0, Math.min(1.0, v))
        debounce.restart()
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    Item {
        anchors { fill: parent; margins: 12 }

        Text {
            id: lbl
            anchors { left: parent.left; top: parent.top }
            text: "BRIGHTNESS"; font.pixelSize: 9; font.weight: Font.Bold
            color: Qt.rgba(166/255,208/255,247/255,0.35)
        }

        Text {
            anchors { right: parent.right; top: parent.top }
            text: Math.round(root._val * 100) + "%"
            font.pixelSize: 9; font.family: "JetBrains Mono"; font.weight: Font.Bold
            color: Qt.rgba(166/255,208/255,247/255,0.6)
        }

        Row {
            anchors { left: parent.left; right: parent.right; top: lbl.bottom; topMargin: 10 }
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃞"; font.pixelSize: 14; color: Qt.rgba(1,1,1,0.3)
            }

            // ── Bar — same anatomy as AudioControl ChannelColumn, rotated horizontal ──
            Item {
                id: trackWrap
                width: parent.width - 14 - 14 - parent.spacing * 2
                height: 22; anchors.verticalCenter: parent.verticalCenter

                readonly property int barH:   6
                readonly property int thumbD: 16

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: trackWrap.barH; radius: height / 2
                    color: Qt.rgba(1,1,1,0.08)

                    // Fill from left
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: Math.max(parent.radius * 2, parent.width * root._val)
                        radius: parent.radius; color: Theme.active
                        Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeHorCursor
                        function _calc(mx) {
                            return Math.max(0.0, Math.min(1.0,
                                (mx - trackWrap.thumbD / 2) /
                                (track.width - trackWrap.thumbD)))
                        }
                        onPressed:         root._set(_calc(mouseX))
                        onPositionChanged: if (pressed) root._set(_calc(mouseX))
                    }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(e) { root._set(root._val + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
                    }
                }

                // Thumb — sits above track
                Rectangle {
                    id: thumb
                    width:  trackWrap.thumbD; height: trackWrap.thumbD; radius: trackWrap.thumbD / 2
                    color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(trackWrap.width - width, root._val * (trackWrap.width - width)))
                    Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃠"; font.pixelSize: 14; color: Qt.rgba(166/255,208/255,247/255,0.7)
            }
        }
    }
}
