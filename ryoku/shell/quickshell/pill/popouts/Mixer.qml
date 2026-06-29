pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"

// mixer popout content: an audio control center wired to real hardware. 力 MIXER
// header over OUTPUT and INPUT endpoints (each a device selector + ink fader,
// with battery/codec/profile for a Bluetooth sink), per-app playback streams,
// and a DISPLAY section (brightness + vibrance). plain transparent Item, the
// frame blob behind it IS the surface; Popout sizes and reveals it. the panel
// reports its implicit size so the popout melts open to fit and grows as the
// device picker expands or a stream appears. pointer-driven, no keyboard focus.
Item {
    id: root

    property real s: 1
    // popout open: gates the live VU meters so they never spin while closed.
    property bool open: false

    anchors.fill: parent

    implicitWidth: 340 * s
    implicitHeight: body.implicitHeight + 27 * s

    readonly property var sink: Audio.sink
    readonly property var source: Audio.source
    readonly property var streams: Audio.streams

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 11 * root.s

        Row {
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "力"
                color: Theme.brand
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MIXER"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Column {
            width: parent.width
            spacing: 7 * root.s
            MicroLabel { label: "Output"; s: root.s }
            MixerDeviceRow {
                width: parent.width
                s: root.s
                kind: "output"
                node: root.sink
                candidates: Audio.outputs
                peakEnabled: root.open
            }
        }

        Divider {}

        Column {
            width: parent.width
            spacing: 7 * root.s
            MicroLabel { label: "Input"; s: root.s }
            MixerDeviceRow {
                width: parent.width
                s: root.s
                kind: "input"
                node: root.source
                candidates: Audio.inputs
                peakEnabled: root.open
            }
        }

        Divider {}

        Column {
            width: parent.width
            spacing: 7 * root.s

            Row {
                spacing: 7 * root.s
                MicroLabel { label: "Apps"; s: root.s }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.streams.length > 0
                    text: root.streams.length + ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                visible: root.streams.length === 0
                text: "Nothing playing"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
            }

            Column {
                width: parent.width
                spacing: 9 * root.s
                Repeater {
                    model: root.streams
                    MixerAppRow {
                        required property var modelData
                        width: parent.width
                        s: root.s
                        node: modelData
                        peakEnabled: root.open
                    }
                }
            }
        }

        Divider {}

        Column {
            width: parent.width
            spacing: 7 * root.s
            MicroLabel { label: "Display"; s: root.s }
            MixerDisplay { width: parent.width; s: root.s }
        }
    }
}
