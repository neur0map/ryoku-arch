import QtQuick
import Quickshell
import "Singletons"

// All-apps grid: every desktop entry in alphabetical sections (A, B, C...), each
// a row of icon tiles with two-line labels, the inir all-apps view. Shown from
// the rest state via the grid toggle. Click launches; Enter launches the
// selection. References flow by id (not parent chains) so the nested model data
// resolves cleanly.
Flickable {
    id: grid

    property real s: 1
    // entries: flat [{ id, title, icon, execute }] sorted by title.
    property var entries: []
    property int selectedIndex: 0

    signal activated()

    readonly property int columns: Metrics.gridColumns
    readonly property real tile: Metrics.tileSize * s

    clip: true
    contentWidth: width
    contentHeight: column.height
    boundsBehavior: Flickable.StopAtBounds

    readonly property var sections: {
        var groups = [];
        var current = null;
        for (var i = 0; i < grid.entries.length; i++) {
            var name = (grid.entries[i].title || "?").trim();
            var ch = name.length > 0 ? name[0].toUpperCase() : "#";
            var letter = /[A-Z]/.test(ch) ? ch : "#";
            if (!current || current.letter !== letter) {
                current = { letter: letter, items: [] };
                groups.push(current);
            }
            current.items.push(grid.entries[i]);
        }
        return groups;
    }

    function move(delta) {
        if (grid.entries.length === 0)
            return;
        grid.selectedIndex = Math.max(0, Math.min(grid.entries.length - 1, grid.selectedIndex + delta));
    }

    function activate() {
        var e = grid.entries[grid.selectedIndex];
        if (e && e.execute)
            e.execute();
        grid.activated();
    }

    function launch(entry) {
        if (entry && entry.execute)
            entry.execute();
        grid.activated();
    }

    Column {
        id: column
        width: grid.width
        spacing: 8 * grid.s

        Repeater {
            model: grid.sections.length

            Column {
                id: sectionCol
                required property int index
                readonly property var section: grid.sections[index]
                width: column.width
                spacing: 4 * grid.s

                Text {
                    text: sectionCol.section.letter
                    color: Theme.verm
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontSection * grid.s
                    font.weight: Font.DemiBold
                    leftPadding: 6 * grid.s
                }

                Grid {
                    columns: grid.columns
                    columnSpacing: 4 * grid.s
                    rowSpacing: 4 * grid.s

                    Repeater {
                        model: sectionCol.section.items.length

                        Rectangle {
                            id: tile
                            required property int index
                            readonly property var entry: sectionCol.section.items[index]
                            width: grid.tile
                            height: grid.tile
                            radius: Metrics.radiusRow * grid.s
                            color: tileArea.containsMouse ? Theme.frameBg : "transparent"

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 8 * grid.s
                                spacing: 4 * grid.s

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 40 * grid.s
                                    height: 40 * grid.s
                                    sourceSize.width: Math.round(80 * grid.s)
                                    sourceSize.height: Math.round(80 * grid.s)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    source: tile.entry && tile.entry.icon ? tile.entry.icon : ""
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tile.entry ? tile.entry.title : ""
                                    color: Theme.cream
                                    font.family: Theme.font
                                    font.pixelSize: Metrics.fontEyebrow * grid.s
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }
                            }

                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: grid.launch(tile.entry)
                            }
                        }
                    }
                }
            }
        }
    }
}
