pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The layer's sound-in instrument: the default microphone's gain and mute, a
// live level meter, the capture-device roster (tap to switch), who is
// recording right now, and the ryoku-mic unity-gain normalizer as an action.
Item {
    id: mic

    property var slot: null
    property bool active: false

    readonly property var src: Sound.source

    Column {
        anchors.fill: parent
        spacing: Tokens.s3

        // ── the live line: mute plate + meter ────────────────────────────
        Row {
            width: parent.width
            spacing: Tokens.s3

            Rectangle {
                id: muteBtn
                width: Tokens.rowH; height: Tokens.rowH
                radius: Tokens.radius
                readonly property bool muted: mic.src && mic.src.audio ? mic.src.audio.muted : false
                color: muted ? Tokens.bone : "transparent"
                border { width: Tokens.border; color: muted ? Tokens.bone : Tokens.lineStrong }
                Text {
                    anchors.centerIn: parent
                    text: muteBtn.muted ? "MUTED" : "LIVE"
                    color: muteBtn.muted ? Tokens.inkOnBone : Tokens.ink
                    font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                }
                TapHandler {
                    enabled: mic.src && mic.src.audio
                    onTapped: mic.src.audio.muted = !mic.src.audio.muted
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            Column {
                width: parent.width - muteBtn.width - Tokens.s3
                spacing: Tokens.s1
                Text {
                    width: parent.width
                    text: mic.src ? (mic.src.description || mic.src.name) : "No input device"
                    color: Tokens.ink
                    elide: Text.ElideRight
                    font { family: Tokens.ui; pixelSize: Tokens.fSmall }
                }
                LevelMeter {
                    width: parent.width
                    height: Tokens.s3
                    active: mic.active && mic.src !== null && !(mic.src.audio && mic.src.audio.muted)
                }
            }
        }

        // ── gain fader ───────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: Tokens.s2
            Text {
                text: "GAIN"
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.inkFaint
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            Slid {
                width: parent.width - 110
                anchors.verticalCenter: parent.verticalCenter
                from: 0; to: 1
                value: mic.src && mic.src.audio ? mic.src.audio.volume : 0
                onModified: (v) => { if (mic.src && mic.src.audio) mic.src.audio.volume = v; }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mic.src && mic.src.audio ? Math.round(mic.src.audio.volume * 100) + "%" : "--"
                color: Tokens.inkMuted
                font { family: Tokens.mono; pixelSize: Tokens.fTiny }
            }
        }

        // ── devices ──────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Tokens.s1
            visible: Sound.inputs.length > 1
            Repeater {
                model: Sound.inputs
                delegate: Rectangle {
                    id: devRow
                    required property var modelData
                    readonly property bool current: modelData === mic.src
                    width: parent.width
                    height: Tokens.ctlH
                    radius: Tokens.radius
                    color: current ? Tokens.tint10 : (devHover.hovered ? Tokens.tint5 : "transparent")
                    Row {
                        anchors { left: parent.left; leftMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.s2
                        Rectangle {
                            width: Tokens.s1; height: Tokens.s1; radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: devRow.current ? Tokens.sun : Tokens.inkFaint
                        }
                        Text {
                            text: devRow.modelData.description || devRow.modelData.name
                            color: devRow.current ? Tokens.ink : Tokens.inkDim
                            font { family: Tokens.ui; pixelSize: Tokens.fSmall }
                        }
                    }
                    HoverHandler { id: devHover }
                    TapHandler { onTapped: Sound.setInput(devRow.modelData) }
                }
            }
        }

        // ── who is listening ─────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Tokens.s1
            Text {
                text: "RECORDING NOW"
                color: Tokens.inkFaint
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            Text {
                visible: Sound.recorders.length === 0
                text: "Nothing is capturing the microphone."
                color: Tokens.inkMuted
                font { family: Tokens.ui; pixelSize: Tokens.fSmall }
            }
            Repeater {
                model: Sound.recorders
                delegate: Text {
                    required property var modelData
                    text: modelData.description || modelData.name
                    color: Tokens.inkDim
                    font { family: Tokens.ui; pixelSize: Tokens.fSmall }
                }
            }
        }

        // ── normalize action ─────────────────────────────────────────────
        Btn {
            text: "Normalize gain (unity)"
            onAct: Quickshell.execDetached(["ryoku-mic", "apply"])
        }
    }
}
