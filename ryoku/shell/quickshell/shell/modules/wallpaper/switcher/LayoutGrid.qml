pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Grid layout: a scrolling grid for scanning a large collection at a glance.
// Native GridView flick momentum carries the scroll; arrows move the focus and
// the view keeps it in sight. Cells reuse WallCell/ThemeCell so live previews,
// the on-air dot and hover behave exactly as in the filmstrip.
Item {
    id: grid

    required property real s
    required property var model
    required property string kind            // "wall" | "theme"
    required property color bg
    property int selIndex: 0
    property bool active: true
    property string activeKey: ""
    property bool interactive: true
    signal focusIndex(int i)
    signal chosen(int i)

    readonly property int count: model ? model.length : 0
    readonly property real cellH: Math.round((kind === "theme" ? 150 : 116) * s)
    readonly property real cellW: kind === "theme" ? Math.round(cellH * 0.82) : Math.round(cellH * 16 / 9)
    readonly property int cellGap: Math.round(12 * s)
    // exposed for the body's up/down arrow nav (move by a whole row).
    readonly property int columns: Math.max(1, Math.floor((width - Math.round(16 * s)) / (cellW + cellGap)))

    onSelIndexChanged: gv.positionViewAtIndex(grid.selIndex, GridView.Contain)

    GridView {
        id: gv
        anchors.fill: parent
        anchors.leftMargin: Math.round(8 * grid.s)
        anchors.rightMargin: Math.round(8 * grid.s)
        topMargin: Math.max(0, (grid.height - Math.ceil(grid.count / Math.max(1, grid.columns)) * (grid.cellH + grid.cellGap)) / 2)
        clip: true
        cellWidth: grid.cellW + grid.cellGap
        cellHeight: grid.cellH + grid.cellGap
        model: grid.model
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.round(grid.cellH * 4)
        flickDeceleration: 3500

        delegate: Item {
            id: cellSlot
            required property int index
            required property var modelData
            width: gv.cellWidth
            height: gv.cellHeight

            Loader {
                anchors.centerIn: parent
                width: grid.cellW
                height: grid.cellH
                sourceComponent: grid.kind === "theme" ? themeC : wallC
            }
            Component {
                id: wallC
                WallCell {
                    s: grid.s; item: cellSlot.modelData; bg: grid.bg
                    selected: cellSlot.index === grid.selIndex
                    live: true
                    beltMoving: gv.moving
                    onEntered: grid.focusIndex(cellSlot.index)
                    onChosen: grid.chosen(cellSlot.index)
                }
            }
            Component {
                id: themeC
                ThemeCell {
                    s: grid.s; item: cellSlot.modelData; bg: grid.bg
                    selected: cellSlot.index === grid.selIndex
                    active: !!cellSlot.modelData && cellSlot.modelData.id === grid.activeKey
                    interactive: grid.interactive
                    onEntered: grid.focusIndex(cellSlot.index)
                    onChosen: grid.chosen(cellSlot.index)
                }
            }
        }
    }
}
