import QtQuick
import Quickshell.Services.Pipewire
import "Singletons"

// horizontal ink fader for the mixer: a matte thread track with a vermilion
// fill and a flat tick; the leading glyph doubles as a mute toggle; a faint VU
// shimmer rides the track from the node's live peak while the popout is open.
// value 0..1. drag the track, wheel to nudge, tap the leading glyph to mute.
Item {
    id: root

    property real s: 1
    property string icon: "speaker"
    property real value: 0.5
    property string valueLabel: ""
    property bool muted: false
    property bool lit: false
    property var peakNode: null
    property bool peakEnabled: false
    property bool showIcon: true

    signal moved(real v)
    signal committed(real v)
    signal iconTapped()

    implicitHeight: 28 * s

    readonly property bool active: lit && !muted

    property real wheelAcc: 0

    // nudge by signed percent, clamped, firing both signals so hardware tracks.
    function step(deltaPct) {
        var v = Math.max(0, Math.min(1, root.value + deltaPct / 100));
        root.moved(v);
        root.committed(v);
    }

    PwNodePeakMonitor {
        id: vu
        node: root.peakNode
        enabled: root.peakEnabled && !!root.peakNode
    }

    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.showIcon ? 20 * root.s : 0
        height: 20 * root.s
        visible: root.showIcon

        GlyphIcon {
            anchors.centerIn: parent
            width: 17 * root.s
            height: 17 * root.s
            name: root.muted ? (root.icon === "mic" ? "mic-off" : "speaker-off") : root.icon
            color: root.muted ? Theme.faint : (root.lit ? Theme.cream : Theme.iconDim)
            stroke: 1.7
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4 * root.s
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconTapped()
        }
    }

    Text {
        id: readout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34 * root.s
        horizontalAlignment: Text.AlignRight
        text: root.valueLabel
        color: root.muted ? Theme.faint : (root.lit ? Theme.cream : Theme.dim)
        opacity: (root.lit || root.muted) ? 1 : 0.7
        font.family: Theme.font
        font.pixelSize: 9.5 * root.s
        font.weight: Font.DemiBold
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Item {
        id: trackArea
        anchors.left: iconBox.right
        anchors.leftMargin: root.showIcon ? 11 * root.s : 0
        anchors.right: readout.left
        anchors.rightMargin: 11 * root.s
        anchors.verticalCenter: parent.verticalCenter
        height: 14 * root.s

        Rectangle {
            id: thread
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 3 * root.s
            radius: height / 2
            color: Theme.threadBg

            Rectangle {
                id: shimmer
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, vu.peak))
                radius: parent.radius
                visible: root.peakEnabled && !root.muted
                color: Theme.vermLit
                opacity: 0.26
            }

            Rectangle {
                id: fill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, root.value))
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.muted ? Theme.ghost : (root.active ? Theme.verm : Theme.vermDim) }
                    GradientStop { position: 1.0; color: root.muted ? Theme.faint : (root.active ? Theme.vermLit : Theme.vermDimDeep) }
                }
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Motion.fast } }
            }
        }

        Rectangle {
            id: tick
            width: 2.5 * root.s
            height: 11 * root.s
            radius: 2 * root.s
            color: Theme.tickRest
            anchors.verticalCenter: thread.verticalCenter
            x: Math.max(0, Math.min(parent.width - width,
                Math.max(0, Math.min(1, root.value)) * parent.width - width / 2))
            opacity: root.lit ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            Behavior on x { enabled: !drag.pressed; NumberAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.topMargin: -8 * root.s
            anchors.bottomMargin: -8 * root.s
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function setFromX(mx) {
                root.moved(Math.max(0, Math.min(1, mx / width)));
            }
            onPressed: (e) => setFromX(e.x)
            onPositionChanged: (e) => { if (pressed) setFromX(e.x); }
            onReleased: root.committed(root.value)
        }

        WheelHandler {
            target: null
            onWheel: (event) => {
                root.wheelAcc += event.angleDelta.y / 120;
                var notches = Math.trunc(root.wheelAcc);
                if (notches !== 0) {
                    root.step(notches * 5);
                    root.wheelAcc -= notches;
                }
            }
        }
    }
}
