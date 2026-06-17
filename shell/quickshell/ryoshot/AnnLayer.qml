import QtQuick
import QtQuick.Shapes

Item {
    id: canvas

    required property int sx
    required property int sy
    property var model: null
    property var draft: null
    property int revision: 0
    property var selectedIndex: null
    property var moveOffset: null

    function shifted(a, dx, dy) {
        var pts = [];
        for (var i = 0; i < a.points.length; i++)
            pts.push({ x: a.points[i].x + dx, y: a.points[i].y + dy });
        var copy = JSON.parse(JSON.stringify(a));
        copy.points = pts;
        return copy;
    }

    function items() {
        var src = model ? model.items.slice() : [];
        if (selectedIndex !== null && moveOffset
            && (moveOffset.x !== 0 || moveOffset.y !== 0)
            && selectedIndex >= 0 && selectedIndex < src.length)
            src[selectedIndex] = shifted(src[selectedIndex], moveOffset.x, moveOffset.y);
        if (draft) src.push(draft);
        return src;
    }

    function lp(a, i) {
        return Qt.point(a.points[i].x - sx, a.points[i].y - sy);
    }

    function polyPath(a) {
        var out = [];
        for (var i = 0; i < a.points.length; i++)
            out.push(Qt.point(a.points[i].x - sx, a.points[i].y - sy));
        return out;
    }

    function strokeColorOf(a) {
        if (a.type !== "marker") return a.color;
        var c = Qt.color(a.color);
        return Qt.rgba(c.r, c.g, c.b, 0.35);
    }

    function strokeWidthOf(a) {
        return a.type === "marker" ? a.width * 2.5 : a.width;
    }

    function ellipseGeom(a) {
        var p0 = lp(a, 0), p1 = lp(a, 1);
        return {
            cx: (p0.x + p1.x) / 2,
            cy: (p0.y + p1.y) / 2,
            rx: Math.abs(p1.x - p0.x) / 2,
            ry: Math.abs(p1.y - p0.y) / 2
        };
    }

    function arrowHead(a) {
        var p0 = lp(a, 0), p1 = lp(a, 1);
        var ang = Math.atan2(p1.y - p0.y, p1.x - p0.x);
        var len = Math.max(a.width * 5, 22);
        var spread = 0.45;
        return {
            tip: p1,
            a: Qt.point(p1.x - len * Math.cos(ang - spread), p1.y - len * Math.sin(ang - spread)),
            b: Qt.point(p1.x - len * Math.cos(ang + spread), p1.y - len * Math.sin(ang + spread))
        };
    }

    Repeater {
        model: { canvas.revision; return canvas.items(); }

        Item {
            id: cell
            required property var modelData
            readonly property var a: modelData
            readonly property bool present: a !== undefined && a !== null && a.points !== undefined
            readonly property bool isText: present && a.type === "text" && a.points.length >= 1
            readonly property bool valid: present && a.points.length >= 2 && a.type !== "blur"
            readonly property string kind: valid ? a.type : (isText ? "text" : "")
            anchors.fill: parent
            visible: valid || isText

            Rectangle {
                visible: cell.valid && cell.kind === "rect"
                x: cell.valid ? Math.min(cell.a.points[0].x, cell.a.points[1].x) - canvas.sx : 0
                y: cell.valid ? Math.min(cell.a.points[0].y, cell.a.points[1].y) - canvas.sy : 0
                width: cell.valid ? Math.abs(cell.a.points[1].x - cell.a.points[0].x) : 0
                height: cell.valid ? Math.abs(cell.a.points[1].y - cell.a.points[0].y) : 0
                color: (cell.valid && cell.a.filled === true) ? cell.a.color : "transparent"
                border.color: cell.valid ? cell.a.color : "transparent"
                border.width: cell.valid ? cell.a.width : 0
                antialiasing: true
            }

            Rectangle {
                visible: cell.valid && cell.kind === "marker"
                x: cell.valid ? Math.min(cell.a.points[0].x, cell.a.points[1].x) - canvas.sx : 0
                y: cell.valid ? Math.min(cell.a.points[0].y, cell.a.points[1].y) - canvas.sy : 0
                width: cell.valid ? Math.abs(cell.a.points[1].x - cell.a.points[0].x) : 0
                height: cell.valid ? Math.abs(cell.a.points[1].y - cell.a.points[0].y) : 0
                color: {
                    if (!cell.valid) return "transparent";
                    var c = Qt.color(cell.a.color);
                    return Qt.rgba(c.r, c.g, c.b, 0.4);
                }
                antialiasing: true
            }

            Shape {
                id: polyShape
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                visible: cell.valid && (cell.kind === "line" || cell.kind === "arrow"
                    || cell.kind === "pen")

                ShapePath {
                    strokeColor: cell.valid ? canvas.strokeColorOf(cell.a) : "transparent"
                    strokeWidth: cell.valid ? canvas.strokeWidthOf(cell.a) : 0
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: cell.valid ? canvas.lp(cell.a, 0).x : 0
                    startY: cell.valid ? canvas.lp(cell.a, 0).y : 0
                    PathPolyline {
                        path: {
                            if (!cell.valid) return [];
                            if (cell.kind === "pen") return canvas.polyPath(cell.a);
                            return [canvas.lp(cell.a, 0), canvas.lp(cell.a, 1)];
                        }
                    }
                }
            }

            Shape {
                id: ellShape
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                visible: cell.valid && cell.kind === "ellipse"
                readonly property var eg: (cell.valid && cell.kind === "ellipse") ? canvas.ellipseGeom(cell.a) : null

                ShapePath {
                    strokeColor: cell.valid ? canvas.strokeColorOf(cell.a) : "transparent"
                    strokeWidth: cell.valid ? canvas.strokeWidthOf(cell.a) : 0
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: ellShape.eg ? ellShape.eg.cx - ellShape.eg.rx : 0
                    startY: ellShape.eg ? ellShape.eg.cy : 0
                    PathArc {
                        x: ellShape.eg ? ellShape.eg.cx + ellShape.eg.rx : 0
                        y: ellShape.eg ? ellShape.eg.cy : 0
                        radiusX: ellShape.eg ? ellShape.eg.rx : 0
                        radiusY: ellShape.eg ? ellShape.eg.ry : 0
                    }
                    PathArc {
                        x: ellShape.eg ? ellShape.eg.cx - ellShape.eg.rx : 0
                        y: ellShape.eg ? ellShape.eg.cy : 0
                        radiusX: ellShape.eg ? ellShape.eg.rx : 0
                        radiusY: ellShape.eg ? ellShape.eg.ry : 0
                    }
                }
            }

            Shape {
                id: headShape
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                visible: cell.valid && cell.kind === "arrow"
                readonly property var pts: (cell.valid && cell.kind === "arrow") ? canvas.arrowHead(cell.a) : null

                ShapePath {
                    strokeColor: cell.valid ? cell.a.color : "transparent"
                    strokeWidth: cell.valid ? cell.a.width : 0
                    fillColor: cell.valid ? cell.a.color : "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: headShape.pts ? headShape.pts.tip.x : 0
                    startY: headShape.pts ? headShape.pts.tip.y : 0
                    PathLine { x: headShape.pts ? headShape.pts.a.x : 0; y: headShape.pts ? headShape.pts.a.y : 0 }
                    PathLine { x: headShape.pts ? headShape.pts.b.x : 0; y: headShape.pts ? headShape.pts.b.y : 0 }
                    PathLine { x: headShape.pts ? headShape.pts.tip.x : 0; y: headShape.pts ? headShape.pts.tip.y : 0 }
                }
            }

            Text {
                visible: cell.isText && cell.a !== canvas.draft
                x: cell.isText ? cell.a.points[0].x - canvas.sx : 0
                y: cell.isText ? cell.a.points[0].y - canvas.sy : 0
                text: cell.isText ? (cell.a.text || "") : ""
                color: cell.isText ? cell.a.color : "transparent"
                font.family: "Inter"
                font.pixelSize: cell.isText ? cell.a.size : 16
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
        }
    }
}
