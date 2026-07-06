pragma ComponentBehavior: Bound
import QtQuick

// A row of tiles on an endless belt. It drifts on its own (dir +1 rightwards,
// -1 leftwards); a scroll adds a boost that eases back to the idle drift. A
// short set is repeated so the belt always fills the width, a full one loops
// as-is, and only the tiles near the viewport build their visual.
Item {
    id: row
    clip: true

    required property real s
    required property var cells
    required property int dir
    required property real cellW
    required property real cellH
    required property int gap
    required property color bg
    required property bool topRow
    property string highlightKey: ""
    property bool running: true

    signal entered(var entry)
    signal chosen(var entry)

    readonly property real step: cellW + gap
    readonly property var belt: {
        if (!cells || cells.length === 0 || width <= 0)
            return cells || [];
        var one = cells.length * step;
        var reps = Math.max(1, Math.ceil((width + 2 * cellW) / one));
        if (reps <= 1)
            return cells;
        var out = [];
        for (var r = 0; r < reps; r++)
            for (var i = 0; i < cells.length; i++)
                out.push(cells[i]);
        return out;
    }
    readonly property real setW: belt.length * step

    property real pos: 0
    property real boost: 0
    readonly property real base: 26 * s

    function boostBy(delta) {
        row.boost = Math.max(-2400, Math.min(2400, row.boost + delta));
    }

    readonly property int centerIndex: {
        if (belt.length === 0 || setW === 0)
            return -1;
        var idx = Math.round((width / 2 - cellW / 2 - pos) / step);
        return ((idx % belt.length) + belt.length) % belt.length;
    }
    readonly property var centerEntry: (centerIndex >= 0 && centerIndex < belt.length) ? belt[centerIndex] : null

    FrameAnimation {
        running: row.running && row.setW > 0
        onTriggered: {
            var dt = Math.min(0.05, frameTime);
            row.boost -= row.boost * Math.min(1, 3.5 * dt);
            if (Math.abs(row.boost) < 0.5)
                row.boost = 0;
            var v = row.dir * row.base + row.boost;
            row.pos = (((row.pos + v * dt) % row.setW) + row.setW) % row.setW;
        }
    }

    Repeater {
        model: row.belt
        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            width: row.cellW
            height: row.cellH
            y: (row.height - height) / 2

            readonly property real raw: (((index * row.step + row.pos) % row.setW) + row.setW) % row.setW
            x: raw < row.width ? raw : (raw > row.setW - 2 * row.cellW ? raw - row.setW : raw)
            readonly property bool shown: x + width > -row.cellW && x < row.width + row.cellW

            Loader {
                anchors.fill: parent
                active: slot.shown
                asynchronous: true
                sourceComponent: WallCell {
                    s: row.s
                    item: slot.modelData
                    bg: row.bg
                    topRow: row.topRow
                    selected: !!slot.modelData && slot.modelData.path === row.highlightKey
                    onEntered: row.entered(slot.modelData)
                    onChosen: row.chosen(slot.modelData)
                }
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.round(48 * row.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: row.bg }
            GradientStop { position: 1.0; color: Qt.alpha(row.bg, 0) }
        }
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: Math.round(48 * row.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(row.bg, 0) }
            GradientStop { position: 1.0; color: row.bg }
        }
    }
}
