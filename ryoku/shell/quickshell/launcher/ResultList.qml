import QtQuick
import Quickshell
import "Singletons"
import "lib/fuzzy.js" as Fuzzy

// The result list: ranked rows from the dispatcher. A row is a mono icon, a
// category eyebrow, the title with the matched chars highlighted, a subtitle, and
// the primary action verb on the selected row. Keyboard + pointer select; the
// primary action runs on activate.
ListView {
    id: list

    property real s: 1
    property var results: []
    property string query: ""
    property int selectedIndex: 0

    // window-position of the last hover allowed to move the selection, so rows
    // sliding under a still cursor during keyboard scroll don't steal it.
    property point lastPointer: Qt.point(-1, -1)

    signal activated()

    spacing: Metrics.gapRow * s
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: results.length

    function move(delta) {
        if (results.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta));
        positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (selectedIndex < 0 || selectedIndex >= results.length)
            return;
        var row = results[selectedIndex];
        if (row && row.actions && row.actions.length > 0 && row.actions[0].execute)
            row.actions[0].execute();
        list.activated();
    }

    onResultsChanged: if (selectedIndex >= results.length) selectedIndex = 0;

    delegate: Item {
        id: row
        required property int index
        width: list.width
        height: Metrics.rowHeight * list.s

        readonly property var entry: list.results[index]
        readonly property bool selected: index === list.selectedIndex
        readonly property var spans: entry ? Fuzzy.highlight(entry.title, list.query) : []

        Rectangle {
            anchors.fill: parent
            radius: Metrics.radiusRow * list.s
            visible: row.selected || rowArea.containsMouse
            color: row.selected ? Theme.frameBg : Qt.rgba(0.94, 0.88, 0.84, 0.03)
            border.width: row.selected ? 1 : 0
            border.color: Theme.frameBorder
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: (m) => {
                var g = rowArea.mapToItem(null, m.x, m.y);
                if (g.x !== list.lastPointer.x || g.y !== list.lastPointer.y) {
                    list.lastPointer = Qt.point(g.x, g.y);
                    list.selectedIndex = row.index;
                }
            }
            onClicked: { list.selectedIndex = row.index; list.activate(); }
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: Metrics.padRow * list.s
            anchors.rightMargin: Metrics.padRow * list.s

            Rectangle {
                id: iconBg
                anchors.verticalCenter: parent.verticalCenter
                width: Metrics.iconSize * list.s
                height: Metrics.iconSize * list.s
                radius: 6 * list.s
                color: Qt.rgba(1, 1, 1, 0.05)
                visible: !(icon.status === Image.Ready && icon.source != "")
            }
            Image {
                id: icon
                anchors.fill: iconBg
                sourceSize.width: Math.round(Metrics.iconSize * 2 * list.s)
                sourceSize.height: Math.round(Metrics.iconSize * 2 * list.s)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: status === Image.Ready && source != ""
                source: row.entry && row.entry.icon ? row.entry.icon : ""
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: icon.right
                anchors.leftMargin: 12 * list.s
                anchors.right: verb.left
                anchors.rightMargin: 10 * list.s
                spacing: 1 * list.s

                Text {
                    visible: row.entry && row.entry.type && row.entry.type !== "App"
                    text: row.entry ? row.entry.type : ""
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontEyebrow * list.s
                }
                Text {
                    width: parent.width
                    textFormat: Text.StyledText
                    text: row.entry ? list.markup(row.entry.title, row.spans) : ""
                    color: row.selected ? Theme.bright : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontTitle * list.s
                    font.weight: row.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                Text {
                    visible: row.entry && row.entry.subtitle && row.entry.subtitle.length > 0
                    width: parent.width
                    text: row.entry ? row.entry.subtitle : ""
                    color: row.selected ? Theme.dim : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontSubtitle * list.s
                    elide: Text.ElideRight
                }
            }

            Text {
                id: verb
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: row.entry && row.entry.actions && row.entry.actions.length > 0 ? row.entry.actions[0].name : ""
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: 11 * list.s
                visible: row.selected
            }
        }
    }

    // Wrap the matched spans in the accent color for the title's StyledText. Spans
    // come from Fuzzy.highlight (subsequence positions over the title).
    function markup(title, spans) {
        if (!spans || spans.length === 0)
            return list.escapeHtml(title);
        var out = "";
        var last = 0;
        for (var i = 0; i < spans.length; i++) {
            var sp = spans[i];
            if (sp.start > last)
                out += list.escapeHtml(title.slice(last, sp.start));
            out += "<font color=\"" + Theme.vermLit + "\">" + list.escapeHtml(title.slice(sp.start, sp.start + sp.len)) + "</font>";
            last = sp.start + sp.len;
        }
        if (last < title.length)
            out += list.escapeHtml(title.slice(last));
        return out;
    }

    function escapeHtml(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
}
