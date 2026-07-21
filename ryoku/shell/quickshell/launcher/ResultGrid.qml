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
    // entries: flat [{ id, title, icon, actions: [{ execute }] }] sorted by title,
    // the same row shape the dispatcher and ResultList use.
    property var entries: []
    property int selectedIndex: 0

    signal activated()

    readonly property int columns: Metrics.gridColumns
    readonly property real tile: Metrics.tileSize * s

    clip: true
    contentWidth: width
    contentHeight: column.height
    boundsBehavior: Flickable.StopAtBounds

    // Items carry their flat index so tiles can tell whether they hold the
    // keyboard selection (Enter launches entries[selectedIndex]).
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
            current.items.push({ e: grid.entries[i], flat: i });
        }
        return groups;
    }

    function move(delta) {
        if (grid.entries.length === 0)
            return;
        grid.selectedIndex = Math.max(0, Math.min(grid.entries.length - 1, grid.selectedIndex + delta));
    }

    // Keep the selected tile on screen while arrowing through the grid.
    function reveal(item) {
        var y = item.mapToItem(column, 0, 0).y;
        if (y < grid.contentY + 8 * grid.s)
            grid.contentY = Math.max(0, y - 8 * grid.s);
        else if (y + grid.tile > grid.contentY + grid.height - 8 * grid.s)
            grid.contentY = Math.min(Math.max(0, grid.contentHeight - grid.height), y + grid.tile - grid.height + 8 * grid.s);
    }

    // Fresh view every time the grid is summoned.
    onVisibleChanged: if (visible) { selectedIndex = 0; contentY = 0; }

    // Run a row's primary action (actions[0]); the row shape comes from the apps
    // provider's rowFor(), shared with the search results.
    function runPrimary(entry) {
        if (entry && entry.actions && entry.actions.length > 0 && entry.actions[0].execute)
            entry.actions[0].execute();
        grid.activated();
    }

    function activate() {
        runPrimary(grid.entries[grid.selectedIndex]);
    }

    function launch(entry) {
        runPrimary(entry);
    }

    Column {
        id: column
        width: grid.width
        spacing: 8 * grid.s

        // inir-style header: a drawn 3x3 mark, the title in the accent, the
        // "alphabetical index" subtitle, and the app count on the right.
        Item {
            width: column.width
            height: 34 * grid.s

            Rectangle {
                id: mark
                anchors.left: parent.left
                anchors.leftMargin: 6 * grid.s
                anchors.verticalCenter: parent.verticalCenter
                width: 26 * grid.s
                height: 26 * grid.s
                radius: Metrics.radiusGlyph * grid.s
                color: Theme.frameBg
                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    rowSpacing: 3 * grid.s
                    columnSpacing: 3 * grid.s
                    Repeater {
                        model: 9
                        Rectangle {
                            width: 3.5 * grid.s
                            height: 3.5 * grid.s
                            radius: 1 * grid.s
                            color: Theme.vermLit
                        }
                    }
                }
            }
            Column {
                anchors.left: mark.right
                anchors.leftMargin: 11 * grid.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: "All apps"
                    color: Theme.verm
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontSection * grid.s
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Alphabetical index"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontEyebrow * grid.s
                }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 6 * grid.s
                anchors.verticalCenter: parent.verticalCenter
                text: grid.entries.length + " apps"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Metrics.fontEyebrow * grid.s
                font.features: { "tnum": 1 }
            }
        }

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
                            readonly property var item: sectionCol.section.items[index]
                            readonly property var entry: item.e
                            readonly property bool sel: grid.selectedIndex === item.flat
                            width: grid.tile
                            height: grid.tile
                            radius: Metrics.radiusRow * grid.s
                            color: sel || tileArea.containsMouse ? Theme.frameBg : "transparent"
                            onSelChanged: if (sel) grid.reveal(tile)

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
                                // keep pointer and keyboard on one selection so
                                // Enter always launches the highlighted tile.
                                onEntered: grid.selectedIndex = tile.item.flat
                                onClicked: grid.launch(tile.entry)
                            }
                        }
                    }
                }
            }
        }
    }
}
