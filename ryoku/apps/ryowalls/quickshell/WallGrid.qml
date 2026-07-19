pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The browse collection: a scrollable wall of thumbnails bound to
// Wallhaven.results. Picking a cell selects it for the preview; the empty and
// loading states carry the torii mark and one sentence, per the skeleton.
Item {
    id: g

    readonly property int gap: Tokens.s2
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
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

        ScrollBar.vertical: ScrollRail {}

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
                selectable: Wallhaven.source === "local"
                selected: Wallhaven.localSelection.indexOf(parent.modelData.id) >= 0
                onToggledSelect: Wallhaven.toggleLocalSelect(parent.modelData)
            }
        }
    }

    // empty / loading / error state: a vertical specimen poster, the state woven
    // into its title and caption, so a dead grid still has a face (like the hub's
    // dead-slot placards) instead of a lone mark.
    Placard {
        anchors.fill: parent
        visible: Wallhaven.results.length === 0
        opacity: Wallhaven.searching ? 0.75 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        code: "WALL-02"
        title: Wallhaven.searching ? "検索" : (Wallhaven.error.length > 0 ? "圏外" : "無")
        sub: Wallhaven.searching ? "SEARCHING" : (Wallhaven.error.length > 0 ? "NO SIGNAL" : "NO WALLPAPERS")
        quote: Wallhaven.searching ? "Fetching the latest wallpapers."
            : (Wallhaven.error.length > 0 ? Wallhaven.error
            : (Wallhaven.source === "live" ? "No live wallpapers yet — add an MP4 to begin."
            : "Nothing here yet. Search above, or switch the source."))
        tate: "壁を探す"
        seal: "壁"
        art: "aurelius.png"
        seed: 3
    }
}
