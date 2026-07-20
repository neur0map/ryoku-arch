pragma ComponentBehavior: Bound
import QtQuick
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The equalizer drawer under the transport: enable, presets, ten band faders
// (-12..+12 dB) over the live playback spectrum. Every change is real DSP:
// gains stream to the ryoku-eq filter-chain as the fader moves and persist to
// eq.json on release.
Column {
    id: eq

    property bool activeFeed: false
    spacing: Tokens.s3

    Row {
        width: parent.width
        spacing: Tokens.s3

        Sw {
            id: onSw
            on: Eq.enabled
            onToggled: Eq.setEnabled(!Eq.enabled)
        }
        Text {
            anchors.verticalCenter: onSw.verticalCenter
            text: "EQUALIZER"
            color: Eq.enabled ? Tokens.ink : Tokens.inkFaint
            font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackMark }
        }
        Item { width: Tokens.s3; height: 1 }
        Repeater {
            model: ["flat", "bass", "vocal", "bright"]
            delegate: Rectangle {
                id: pre
                required property string modelData
                readonly property bool current: Eq.preset === modelData
                width: preT.implicitWidth + Tokens.s2 * 2
                height: Tokens.ctlH - 8
                radius: Tokens.radius
                color: current ? Tokens.bone : "transparent"
                border { width: Tokens.border; color: current ? Tokens.bone : Tokens.lineSoft }
                opacity: Eq.enabled ? 1 : 0.4
                Text {
                    id: preT
                    anchors.centerIn: parent
                    text: pre.modelData.toUpperCase()
                    color: pre.current ? Tokens.inkOnBone : Tokens.inkFaint
                    font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                }
                TapHandler { enabled: Eq.enabled; onTapped: Eq.applyPreset(pre.modelData) }
            }
        }
    }

    Item {
        id: field
        width: parent.width
        height: 140

        SpectrumGhost {
            anchors { fill: parent; bottomMargin: Tokens.s4 }
            active: eq.activeFeed && Eq.enabled
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -Tokens.s2 }
            height: Tokens.border
            color: Tokens.lineSoft
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: 10
                delegate: Item {
                    id: band
                    required property int index
                    width: field.width / 10
                    height: field.height
                    readonly property real db: (Eq.gains && Eq.gains.length > band.index) ? Eq.gains[band.index] : 0
                    // dB -> y: +12 at top of the fader run, -12 at bottom.
                    readonly property real run: height - Tokens.s4 - knob.height

                    Rectangle {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom; bottomMargin: Tokens.s4 }
                        width: Tokens.border
                        color: Tokens.line
                    }
                    Rectangle {
                        id: knob
                        width: Tokens.s4; height: Tokens.s2
                        radius: Tokens.radius
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (1 - (band.db + 12) / 24) * band.run
                        color: Eq.enabled ? Tokens.ink : Tokens.inkFaint
                        border { width: Tokens.border; color: Tokens.paper }
                    }
                    MouseArea {
                        anchors { fill: parent; bottomMargin: Tokens.s4 + knob.height }
                        enabled: Eq.enabled
                        onPositionChanged: (e) => { if (pressed) band.push(e.y); }
                        onPressed: (e) => band.push(e.y)
                        onReleased: Eq.save()
                    }
                    function push(yPos) {
                        var db = (1 - Math.max(0, Math.min(1, yPos / band.run))) * 24 - 12;
                        Eq.setBand(band.index, db);
                    }
                    Text {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        text: Eq.bandHz[band.index]
                        color: Tokens.inkFaint
                        font { family: Tokens.mono; pixelSize: Tokens.fTiny }
                    }
                }
            }
        }
    }
}
