pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// one application playback stream in the mixer: app icon + name + a mute glyph
// over a bare HFader bound to the stream's own volume. the headline per-app
// control. icon and name come from the stream's PipeWire metadata.
Item {
    id: root

    property real s: 1
    property var node: null
    property bool peakEnabled: false

    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    readonly property var au: (node && node.audio) ? node.audio : null

    HoverHandler { id: rowHover }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 3 * root.s

        Item {
            width: parent.width
            height: 18 * root.s

            Image {
                id: appIco
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                source: Audio.streamIcon(root.node)
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready
            }
            GlyphIcon {
                anchors.fill: appIco
                visible: appIco.status !== Image.Ready
                name: "music"
                color: Theme.iconDim
                stroke: 1.6
            }

            Text {
                anchors.left: appIco.right
                anchors.leftMargin: 9 * root.s
                anchors.right: muteBtn.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.streamName(root.node)
                color: rowHover.hovered ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Item {
                id: muteBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.s
                height: 18 * root.s

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 15 * root.s
                    height: 15 * root.s
                    name: (root.au && root.au.muted) ? "speaker-off" : "speaker"
                    color: (root.au && root.au.muted) ? Theme.faint
                        : (muteHover.hovered ? Theme.cream : Theme.iconDim)
                    stroke: 1.7
                }

                HoverHandler { id: muteHover }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.au) root.au.muted = !root.au.muted; }
                }
            }
        }

        HFader {
            width: parent.width
            s: root.s
            showIcon: false
            lit: rowHover.hovered
            peakEnabled: root.peakEnabled
            peakNode: root.node
            muted: root.au ? root.au.muted : false
            value: root.au ? root.au.volume : 0
            valueLabel: !root.au ? "" : (root.au.muted ? "off" : (Math.round(root.au.volume * 100) + "%"))
            onMoved: (v) => { if (root.au) root.au.volume = v; }
        }
    }
}
