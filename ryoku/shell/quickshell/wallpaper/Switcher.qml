pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The switcher body: a card with the colour strip on top, two endless belts of
// wallpapers below (the top drifts right, the bottom drifts left), and a footer.
// The belts idle-drift on their own; a scroll pushes them faster and they ease
// back. Hover a tile to light it, click or Enter to set it, Esc to close.
Item {
    id: body

    required property real s
    required property bool active
    signal requestClose()

    property string typeFilter: "all"   // all | image | live
    property int colorFilter: -1        // -1 = every colour, else a Colors group id
    property var hoverEntry: null
    property int kbRow: 0               // which belt Enter picks from when not hovering

    // entries under the current type + colour filter, already colour-sorted.
    readonly property var shown: {
        var out = [];
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter)
                continue;
            if (body.colorFilter !== -1 && e.group !== body.colorFilter)
                continue;
            out.push(e);
        }
        return out;
    }
    // split across the two belts so each carries a varied slice.
    readonly property var topCells: shown.filter((e, i) => i % 2 === 0)
    readonly property var bottomCells: shown.filter((e, i) => i % 2 === 1)

    readonly property var groups: {
        var seen = ({});
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter)
                continue;
            seen[e.group] = true;
        }
        var out = [];
        for (var g = 0; g < Colors.order.length; g++)
            if (seen[Colors.order[g]])
                out.push(Colors.order[g]);
        return out;
    }

    // the pick: whatever's hovered, else the centred tile of the active belt.
    readonly property var selEntry: hoverEntry ? hoverEntry
        : (kbRow === 0 ? topRow.centerEntry : bottomRow.centerEntry)

    function setType(t) {
        if (body.typeFilter === t)
            return;
        body.typeFilter = t;
        body.colorFilter = -1;
        body.hoverEntry = null;
    }
    function setColor(g) {
        body.colorFilter = (body.colorFilter === g) ? -1 : g;
        body.hoverEntry = null;
    }
    function apply(entry) {
        if (!entry)
            return;
        Walls.apply(entry.path);
        body.requestClose();
    }

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape)
            body.requestClose();
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            body.apply(body.selEntry);
        else if (e.key === Qt.Key_Right) {
            topRow.boostBy(760);
            bottomRow.boostBy(-760);
        } else if (e.key === Qt.Key_Left) {
            topRow.boostBy(-760);
            bottomRow.boostBy(760);
        } else if (e.key === Qt.Key_Up)
            body.kbRow = 0;
        else if (e.key === Qt.Key_Down)
            body.kbRow = 1;
        else
            return;
        e.accepted = true;
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.round(Math.min(parent.width * 0.9, 1720 * body.s))
        height: Math.round(Math.min(parent.height * 0.86, 1040 * body.s))
        radius: Theme.radius
        color: Theme.cardTop
        border.width: 1
        border.color: Theme.border

        readonly property int pad: Math.round(22 * body.s)

        // ---- header ----
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: card.pad
            height: Math.round(48 * body.s)

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)

                Eyebrow { s: body.s; label: "Wallpapers" }

                Row {
                    spacing: Math.round(8 * body.s)
                    Text {
                        id: num
                        text: "" + body.shown.length
                        color: Theme.bright
                        font.family: Theme.display
                        font.pixelSize: Math.round(23 * body.s)
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors.baseline: num.baseline
                        text: body.typeFilter === "image" ? "images"
                            : body.typeFilter === "live" ? "live"
                            : "images + live"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: Math.round(10 * body.s)
                        font.letterSpacing: 1.6 * body.s
                        font.capitalization: Font.AllUppercase
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: -1
                Repeater {
                    model: [{ k: "all", l: "All" }, { k: "image", l: "Images" }, { k: "live", l: "Live" }]
                    delegate: Rectangle {
                        id: seg
                        required property var modelData
                        readonly property bool on: body.typeFilter === seg.modelData.k
                        width: Math.round(72 * body.s)
                        height: Math.round(28 * body.s)
                        color: seg.on ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: seg.on ? Theme.brand : Theme.border
                        z: seg.on ? 1 : 0
                        Text {
                            anchors.centerIn: parent
                            text: seg.modelData.l
                            color: seg.on ? Theme.brand : Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: Math.round(10 * body.s)
                            font.weight: seg.on ? Font.DemiBold : Font.Normal
                            font.letterSpacing: 1.4 * body.s
                            font.capitalization: Font.AllUppercase
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: body.setType(seg.modelData.k) }
                    }
                }
            }
        }

        // ---- colour strip ----
        ColorStrip {
            id: strip
            anchors { left: parent.left; right: parent.right; top: header.bottom }
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad
            anchors.topMargin: Math.round(14 * body.s)
            height: Math.round(24 * body.s)
            s: body.s
            groups: body.groups
            selected: body.colorFilter
            onPicked: (g) => body.setColor(g)
        }

        // ---- the two belts ----
        Item {
            id: rows
            anchors {
                left: parent.left; right: parent.right
                top: strip.bottom; bottom: footer.top
                topMargin: Math.round(16 * body.s)
                bottomMargin: Math.round(10 * body.s)
            }
            visible: body.shown.length > 0

            readonly property int rowGap: Math.round(20 * body.s)
            readonly property real rowH: (height - rowGap) / 2
            readonly property real cH: Math.max(120 * body.s, Math.min(240 * body.s, rowH - 14 * body.s))
            readonly property real cW: Math.round(cH * 1.55)
            readonly property int cGap: Math.round(14 * body.s)

            WallRow {
                id: topRow
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: rows.rowH
                s: body.s
                dir: 1
                topRow: true
                cells: body.topCells
                cellW: rows.cW
                cellH: rows.cH
                gap: rows.cGap
                bg: Theme.cardTop
                running: body.active
                hovering: rowsHover.hovered
                highlightKey: body.hoverEntry ? body.hoverEntry.path : ""
                onEntered: (e) => body.hoverEntry = e
                onChosen: (e) => body.apply(e)
            }
            WallRow {
                id: bottomRow
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: rows.rowH
                s: body.s
                dir: -1
                topRow: false
                cells: body.bottomCells
                cellW: rows.cW
                cellH: rows.cH
                gap: rows.cGap
                bg: Theme.cardTop
                running: body.active
                hovering: rowsHover.hovered
                highlightKey: body.hoverEntry ? body.hoverEntry.path : ""
                onEntered: (e) => body.hoverEntry = e
                onChosen: (e) => body.apply(e)
            }

            // scroll pushes both belts faster (they ease back to the idle drift).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    var f = e.angleDelta.y * 3.2;
                    topRow.boostBy(f);
                    bottomRow.boostBy(-f);
                }
            }
            HoverHandler {
                id: rowsHover
                onHoveredChanged: if (!hovered) body.hoverEntry = null
            }

            // faint guide marking the tile Enter picks when nothing is hovered.
            Rectangle {
                visible: !body.hoverEntry
                width: Math.round(30 * body.s)
                height: Math.round(2 * body.s)
                radius: height / 2
                color: Theme.brand
                opacity: 0.5
                x: (rows.width - width) / 2
                y: body.kbRow === 0
                    ? topRow.y + topRow.height - height / 2
                    : bottomRow.y + bottomRow.height - height / 2
            }
        }

        // empty / loading state.
        Column {
            anchors.centerIn: parent
            spacing: Math.round(8 * body.s)
            visible: body.shown.length === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "力"
                color: Theme.faint
                font.family: Theme.fontJp
                font.pixelSize: Math.round(34 * body.s)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Walls.loading ? "Reading wallpapers"
                    : (body.colorFilter !== -1 || body.typeFilter !== "all" ? "Nothing in this filter"
                    : "No wallpapers in ~/Pictures/Wallpapers")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Math.round(13 * body.s)
            }
        }

        // ---- footer ----
        Item {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: card.pad
            height: Math.round(20 * body.s)

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - hint.width - Math.round(20 * body.s)
                elide: Text.ElideRight
                text: body.selEntry
                    ? (body.selEntry.name + "   " + (body.selEntry.type === "live" ? "Live" : "Image") + " · " + Colors.names[body.selEntry.group] + (body.hoverEntry ? "" : "  · centre"))
                    : "Scroll to browse, hover a tile to set it"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Math.round(12 * body.s)
            }
            Text {
                id: hint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter set · Esc close"
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: Math.round(11 * body.s)
            }
        }
    }
}
