pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// A cubic-bezier editor: the endpoints are pinned at (0,0) and (1,1); the two
// control points drag freely (Y overshoots past 1 for bounce, like ryokuBloom).
// The page owns the values; the editor reports changed(x0,y0,x1,y1) as a handle
// moves. X is clamped to [0,1] (Hyprland needs a monotonic-in-time curve), Y is
// free within the drawn range.
Item {
    id: ed

    property real x0: 0.25
    property real y0: 0.1
    property real x1: 0.25
    property real y1: 1.0
    signal changed(real x0, real y0, real x1, real y1)

    readonly property real pad: 18
    readonly property real yMin: -0.45
    readonly property real yMax: 1.55

    implicitWidth: 300
    implicitHeight: 280

    function px(x) { return ed.pad + x * (ed.width - 2 * ed.pad); }
    function py(y) { return ed.height - ed.pad - (y - ed.yMin) / (ed.yMax - ed.yMin) * (ed.height - 2 * ed.pad); }
    function ux(p) { return Math.max(0, Math.min(1, (p - ed.pad) / (ed.width - 2 * ed.pad))); }
    function uy(p) { return ed.yMin + (ed.height - ed.pad - p) / (ed.height - 2 * ed.pad) * (ed.yMax - ed.yMin); }

    onX0Changed: cv.requestPaint()
    onY0Changed: cv.requestPaint()
    onX1Changed: cv.requestPaint()
    onY1Changed: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.surfaceLo
        border.width: 1
        border.color: Theme.line
    }

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            // baselines at y=0 and y=1
            ctx.lineWidth = 1;
            ctx.strokeStyle = Theme.lineSoft;
            ctx.beginPath();
            ctx.moveTo(ed.px(0), ed.py(0));
            ctx.lineTo(ed.px(1), ed.py(0));
            ctx.moveTo(ed.px(0), ed.py(1));
            ctx.lineTo(ed.px(1), ed.py(1));
            ctx.stroke();
            // handle arms
            ctx.strokeStyle = Theme.dim;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(ed.px(0), ed.py(0));
            ctx.lineTo(ed.px(ed.x0), ed.py(ed.y0));
            ctx.moveTo(ed.px(1), ed.py(1));
            ctx.lineTo(ed.px(ed.x1), ed.py(ed.y1));
            ctx.stroke();
            // the curve
            ctx.strokeStyle = Theme.ember;
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(ed.px(0), ed.py(0));
            ctx.bezierCurveTo(ed.px(ed.x0), ed.py(ed.y0), ed.px(ed.x1), ed.py(ed.y1), ed.px(1), ed.py(1));
            ctx.stroke();
        }
    }

    component Handle: Rectangle {
        id: h
        required property real hx
        required property real hy
        signal moved(real x, real y)
        width: 16
        height: 16
        radius: 8
        x: ed.px(hx) - 8
        y: ed.py(hy) - 8
        color: hd.active ? Theme.ember : Theme.bright
        border.width: 2
        border.color: Theme.ember
        Behavior on color { ColorAnimation { duration: Theme.quick } }

        DragHandler {
            id: hd
            target: null
            property real lastX: 0
            property real lastY: 0
            onActiveChanged: { if (active) { lastX = 0; lastY = 0; } }
            onTranslationChanged: {
                var nx = ed.ux(ed.px(h.hx) + (translation.x - lastX));
                var ny = ed.uy(ed.py(h.hy) + (translation.y - lastY));
                lastX = translation.x;
                lastY = translation.y;
                h.moved(nx, ny);
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Handle {
        hx: ed.x0
        hy: ed.y0
        onMoved: (x, y) => ed.changed(x, y, ed.x1, ed.y1)
    }
    Handle {
        hx: ed.x1
        hy: ed.y1
        onMoved: (x, y) => ed.changed(ed.x0, ed.y0, x, y)
    }
}
