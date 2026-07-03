pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "Singletons"

// Saved-playlist chips under the now-playing stack. When you play a pasted
// YouTube playlist or mix link it is cached (Singletons/Playlists.qml); this row
// shows the recent ones as small cover chips so the whole playlist replays with
// one tap and no /next round-trip. Hidden when nothing is saved. Slim, matching
// the source strips above it.
Column {
    id: root

    property real s: 1
    spacing: 5 * s
    visible: Playlists.items.length > 0

    // eyebrow so the row reads as its own thing, not another player strip.
    Text {
        text: "力 SAVED PLAYLISTS"
        color: Theme.vermLit
        font.family: Theme.font
        font.pixelSize: Metrics.fontEyebrow * root.s
        font.letterSpacing: 1.2
    }

    // up to four most-recent chips fit the card width; the cache holds more but
    // the row stays one line so it never balloons.
    Row {
        spacing: 6 * root.s

        Repeater {
            model: Math.min(4, Playlists.items.length)

            delegate: Rectangle {
                id: chip
                required property int index
                readonly property var entry: Playlists.items[index]
                width: 128 * root.s
                height: 34 * root.s
                radius: Metrics.radiusRow * root.s
                color: hover.containsMouse ? Theme.frameBg : Qt.rgba(0.94, 0.88, 0.84, 0.03)
                border.width: hover.containsMouse ? 1 : 0
                border.color: Theme.frameBorder

                ClippingRectangle {
                    id: thumb
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 5 * root.s
                    width: 24 * root.s
                    height: 24 * root.s
                    radius: Theme.radius
                    color: Theme.tileBg

                    Image {
                        anchors.fill: parent
                        source: chip.entry.cover || ""
                        sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !chip.entry.cover
                        text: "\u266a"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                    }
                }

                Column {
                    anchors.left: thumb.right
                    anchors.right: remove.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8 * root.s
                    anchors.rightMargin: 4 * root.s
                    spacing: 0

                    Text {
                        width: parent.width
                        text: chip.entry.label || "Playlist"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Metrics.fontSubtitle * root.s
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: (chip.entry.count || 0) + " tracks"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: Metrics.fontEyebrow * root.s
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Radio.playCached(Playlists.tracksFor(chip.entry.id))
                }

                // remove affordance, only on hover so the chip stays clean.
                // Declared after (and z-raised above) the chip-body MouseArea,
                // otherwise the body area swallows the \u00d7 click and replays
                // the playlist the user meant to delete.
                Text {
                    id: remove
                    z: 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 5 * root.s
                    anchors.topMargin: 3 * root.s
                    text: "\u00d7"
                    color: rmArea.containsMouse ? Theme.vermLit : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    visible: hover.containsMouse || rmArea.containsMouse
                    MouseArea {
                        id: rmArea
                        anchors.fill: parent
                        anchors.margins: -4 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Playlists.remove(chip.entry.id)
                    }
                }
            }
        }
    }
}
