import QtQuick
import QtQuick.Controls
import "Singletons"

// The browse grid: a scrollable wall of thumbnails bound to Wallhaven.results.
// Picking a cell selects it for the preview; right-click opens it on the web.
Item {
    id: g

    readonly property real gap: 10
    readonly property int cols: Math.max(2, Math.floor(width / 200))

    GridView {
        id: grid
        anchors.fill: parent
        visible: Wallhaven.results.length > 0
        clip: true
        cellWidth: Math.floor(g.width / g.cols)
        cellHeight: Math.round(cellWidth * 0.62)
        model: Wallhaven.results
        cacheBuffer: 1200
        boundsBehavior: Flickable.StopAtBounds
        opacity: Wallhaven.searching ? 0.45 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight

            WallCell {
                anchors.fill: parent
                anchors.margins: g.gap / 2
                item: parent.modelData
                active: Wallhaven.selected && Wallhaven.selected.id === parent.modelData.id
                onPicked: Wallhaven.select(parent.modelData)
                onOpened: Wallhaven.openWeb(parent.modelData)
            }
        }
    }

    // empty / busy state.
    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: Wallhaven.results.length === 0
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Wallhaven.searching ? "refresh" : (Wallhaven.error.length > 0 ? "close" : "image")
            size: 30
            tint: Theme.faint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Wallhaven.searching ? "Searching wallhaven"
                : (Wallhaven.error.length > 0 ? Wallhaven.error : "No wallpapers")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
