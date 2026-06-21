import QtQuick
import "Singletons"

// One monitor on the layout canvas: a draggable rectangle labelled with its
// output and resolution. The page owns all geometry (position and size are set by
// the page from the logical layout); the tile only reports drag deltas (already
// divided by the canvas scale, so in logical pixels) and selection. Disabled
// monitors read greyed; the selected one gets the ember ring.
Rectangle {
    id: tile

    property bool selected: false
    property bool live: true
    property bool mirrored: false
    property string title: ""
    property string sub: ""
    property real canvasScale: 1

    signal tapped()
    signal dragDelta(real dx, real dy)
    signal dragEnded()

    radius: 8
    color: tile.live ? (tile.selected ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.16) : Theme.surface)
                        : Theme.surfaceLo
    border.width: tile.selected ? 2 : 1
    border.color: tile.selected ? Theme.ember : Theme.line
    opacity: tile.live ? 1 : 0.5
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
    Behavior on color { ColorAnimation { duration: Theme.quick } }

    Column {
        anchors.centerIn: parent
        spacing: 3
        width: parent.width - 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.title
            color: tile.live ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.live ? tile.sub : "off"
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 10
            elide: Text.ElideRight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            visible: tile.mirrored
            anchors.horizontalCenter: parent.horizontalCenter
            text: "MIRROR"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 8
            font.letterSpacing: 1.5
        }
    }

    DragHandler {
        id: dh
        target: null
        property real lastX: 0
        property real lastY: 0
        onActiveChanged: {
            if (active) {
                lastX = 0;
                lastY = 0;
                tile.tapped();
            } else {
                tile.dragEnded();
            }
        }
        onTranslationChanged: {
            var dx = translation.x - lastX;
            var dy = translation.y - lastY;
            lastX = translation.x;
            lastY = translation.y;
            tile.dragDelta(dx / tile.canvasScale, dy / tile.canvasScale);
        }
    }

    TapHandler { onTapped: tile.tapped(); cursorShape: Qt.PointingHandCursor }
}
