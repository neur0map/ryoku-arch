pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// The switcher body: a centered card holding the colour strip, the unified
// image+video grid, and a footer. Owns the pick + filter state and the keyboard;
// hovering or arrowing moves the pick, a click or Enter sets it and closes.
Item {
    id: body

    required property real s
    required property bool active
    signal requestClose()

    property string typeFilter: "all"   // all | image | live
    property int colorFilter: -1        // -1 = every colour, else a Colors group id
    property int sel: 0
    property bool seeded: false
    readonly property int gap: Math.round(10 * s)

    // entries under the current type + colour filter (already colour-sorted).
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

    // colour groups present under the current type filter, for the strip.
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

    readonly property var cur: (sel >= 0 && sel < shown.length) ? shown[sel] : null

    function indexOfCurrent() {
        for (var i = 0; i < shown.length; i++)
            if (shown[i].path === Walls.current)
                return i;
        return -1;
    }
    function seed() {
        if (body.seeded || body.shown.length === 0)
            return;
        var i = body.indexOfCurrent();
        body.sel = i >= 0 ? i : 0;
        body.seeded = true;
        centerT.restart();
    }
    // let the grid lay out the fresh model before scrolling the pick into view.
    Timer { id: centerT; interval: 60; onTriggered: grid.positionViewAtIndex(body.sel, GridView.Center) }
    onShownChanged: {
        body.seed();
        if (body.sel >= body.shown.length)
            body.sel = Math.max(0, body.shown.length - 1);
    }
    Connections { target: Walls; function onEntriesChanged() { body.seed(); } }

    function setType(t) {
        if (body.typeFilter === t)
            return;
        body.typeFilter = t;
        body.colorFilter = -1;
        body.sel = 0;
    }
    function setColor(g) {
        body.colorFilter = (body.colorFilter === g) ? -1 : g;
        body.sel = 0;
    }
    function move(d) {
        if (body.shown.length === 0)
            return;
        body.sel = Math.max(0, Math.min(body.shown.length - 1, body.sel + d));
        grid.positionViewAtIndex(body.sel, GridView.Contain);
    }
    function moveRow(d) { body.move(d * grid.cols); }
    function activate() {
        if (!body.cur)
            return;
        Walls.apply(body.cur.path);
        body.requestClose();
    }

    // keyboard: this body only exists on the focused monitor, so it owns the keys.
    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: (e) => {
        var shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        if (e.key === Qt.Key_Escape)
            body.requestClose();
        else if (e.key === Qt.Key_Tab)
            body.move(shift ? -1 : 1);
        else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left)
            body.move(-1);
        else if (e.key === Qt.Key_Right)
            body.move(1);
        else if (e.key === Qt.Key_Up)
            body.moveRow(-1);
        else if (e.key === Qt.Key_Down)
            body.moveRow(1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            body.activate();
        else
            return;
        e.accepted = true;
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.round(Math.min(parent.width * 0.86, 1640 * body.s))
        height: Math.round(Math.min(parent.height * 0.86, 1000 * body.s))
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.border

        readonly property int pad: Math.round(22 * body.s)

        // ---- header ----
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: card.pad
            height: Math.round(40 * body.s)

            Text {
                id: glyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "力"
                color: Theme.brand
                font.family: Theme.fontJp
                font.pixelSize: Math.round(30 * body.s)
            }
            Column {
                anchors.left: glyph.right
                anchors.leftMargin: Math.round(12 * body.s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "Wallpapers"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: Math.round(20 * body.s)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: body.shown.length + " wallpaper" + (body.shown.length === 1 ? "" : "s")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Math.round(11.5 * body.s)
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
                        width: Math.round(64 * body.s)
                        height: Math.round(30 * body.s)
                        color: seg.on ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: seg.on ? Theme.brand : Theme.border
                        z: seg.on ? 1 : 0
                        Text {
                            anchors.centerIn: parent
                            text: seg.modelData.l
                            color: seg.on ? Theme.brand : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Math.round(12.5 * body.s)
                            font.weight: seg.on ? Font.DemiBold : Font.Normal
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

        // ---- grid ----
        GridView {
            id: grid
            anchors {
                left: parent.left; right: parent.right
                top: strip.bottom; bottom: footer.top
                topMargin: Math.round(14 * body.s)
                bottomMargin: Math.round(10 * body.s)
                leftMargin: card.pad
                rightMargin: card.pad
            }
            clip: true
            visible: body.shown.length > 0
            model: body.shown
            cacheBuffer: Math.round(cellHeight * 2)
            boundsBehavior: Flickable.StopAtBounds

            readonly property int cols: Math.max(3, Math.min(8, Math.floor(width / (250 * body.s))))
            cellWidth: Math.floor(width / cols)
            cellHeight: Math.round(cellWidth * 0.6)

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                id: slot
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                WallCell {
                    anchors.fill: parent
                    anchors.margins: body.gap / 2
                    s: body.s
                    item: slot.modelData
                    selected: slot.index === body.sel
                    current: slot.modelData.path === Walls.current
                    onEntered: body.sel = slot.index
                    onChosen: { Walls.apply(slot.modelData.path); body.requestClose(); }
                }
            }
        }

        // empty / loading state.
        Column {
            anchors.centerIn: parent
            spacing: Math.round(8 * body.s)
            visible: body.shown.length === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Walls.loading ? "力" : "◍"
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
                text: body.cur
                    ? (body.cur.name + "   " + (body.cur.type === "live" ? "Live" : "Image") + " · " + Colors.names[body.cur.group])
                    : ""
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
