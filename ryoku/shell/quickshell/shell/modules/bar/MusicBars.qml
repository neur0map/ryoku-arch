pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// A spectrum strip fed by the shared AudioBars cava feed. Two orientations, each
// spreading its bars evenly across the size the caller gives:
//   "vertical"   bars stand on the bottom and grow up, spread across `width`
//                (the card's wide sweep).
//   "horizontal" cava lines grow sideways from the centre, spread down `height`
//                (the vertical rail strip).
// Each bar averages the cava bands that fall in its slice, so a coarse strip
// reads the whole spectrum instead of sampling one spiky band. Bars are tinted
// on a low -> high ramp (the album-art accent in the card, the palette
// otherwise); loud tips lighten. `running` off eases every bar to its rest
// sliver, and the ticker halts once the strip settles on silence.
Item {
    id: root

    property int bands: 24
    property bool running: true
    property real s: 1
    property string orient: "vertical"          // "vertical" | "horizontal"
    property color lowColor: Theme.primary
    property color highColor: Theme.tertiary

    readonly property bool horiz: root.orient === "horizontal"
    readonly property real sliver: Math.max(1.5, 2 * root.s)

    // sensible defaults; the caller sets the fill axis (width for a sweep,
    // height for a strip) and the bars spread to fit it.
    implicitWidth: root.horiz ? 24 * root.s : root.bands * 6 * root.s
    implicitHeight: root.horiz ? root.bands * 6 * root.s : 22 * root.s

    property var shown: []

    function lerpColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    function bandColor(i, level) {
        var c = root.lerpColor(root.lowColor, root.highColor, root.bands > 1 ? i / (root.bands - 1) : 0.5);
        return Qt.lighter(c, 1 + 0.4 * level);
    }
    function levelAt(i) {
        var l = root.shown;
        return (l && i < l.length) ? l[i] : 0;
    }

    // average the cava bands that fall in this bar's slice, with a perceptual
    // boost so quiet bands still read.
    function targetAt(i) {
        if (!root.running)
            return 0;
        var src = AudioBars.levels;
        var n = AudioBars.bars;
        var lo = Math.floor(i / root.bands * n);
        var hi = Math.max(lo + 1, Math.floor((i + 1) / root.bands * n));
        var sum = 0, cnt = 0;
        for (var k = lo; k < hi && k < n; k++) {
            sum += (src && k < src.length) ? src[k] : 0;
            cnt++;
        }
        var v = cnt > 0 ? sum / cnt : 0;
        return Math.min(1, Math.pow(v, 0.7));
    }

    Timer {
        interval: Math.round(1000 / AudioBars.fps)
        running: root.visible && (AudioBars.energy > 0.015 || root._live)
        repeat: true
        onTriggered: root.tick()
    }

    // any bar still off its target keeps the ticker alive for one last settle.
    property bool _live: false

    function tick() {
        var out = [];
        var prev = root.shown;
        var live = AudioBars.energy > 0.015;
        for (var i = 0; i < root.bands; i++) {
            var target = root.targetAt(i);
            var cur = (prev && i < prev.length) ? prev[i] : 0;
            // fast attack, slow decay.
            var k = target > cur ? 0.5 : 0.18;
            var next = cur + (target - cur) * k;
            if (Math.abs(next - target) < 0.004)
                next = target;
            out.push(next);
            if (next > 0.004)
                live = true;
        }
        root.shown = out;
        root._live = live;
    }

    onBandsChanged: root.shown = []
    onRunningChanged: if (!root.running) root._live = true

    Repeater {
        model: root.bands
        Rectangle {
            required property int index
            readonly property real level: root.levelAt(index)
            // an even slice of the fill axis, the bar centred within it.
            readonly property real slot: (root.horiz ? root.height : root.width) / Math.max(1, root.bands)
            readonly property real thick: Math.max(2, Math.min(slot * 0.6, 7 * root.s))
            readonly property real grow: Math.max(root.sliver, (root.horiz ? root.width : root.height) * level)

            width: root.horiz ? grow : thick
            height: root.horiz ? thick : grow
            x: root.horiz ? (root.width - width) / 2 : (index * slot + (slot - thick) / 2)
            y: root.horiz ? (index * slot + (slot - thick) / 2) : (root.height - height)
            radius: Math.min(width, height) / 2
            antialiasing: true
            color: root.bandColor(index, level)
            Behavior on height { enabled: !root.horiz; NumberAnimation { duration: Math.round(1000 / AudioBars.fps); easing.type: Easing.OutQuad } }
            Behavior on width { enabled: root.horiz; NumberAnimation { duration: Math.round(1000 / AudioBars.fps); easing.type: Easing.OutQuad } }
        }
    }
}
