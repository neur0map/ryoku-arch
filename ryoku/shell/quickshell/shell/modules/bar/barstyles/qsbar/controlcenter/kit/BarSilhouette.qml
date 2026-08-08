import QtQuick
import QtQuick.Shapes

// A miniature drawing of a bar form, for the QUICK cards, the Bars route form
// grid, and the CONFIGURE preview. `form` is one of full|fit|dock|notch|islands.
// A rough silhouette + three widget-dot clusters; it reads the accent from root
// so previews track the live palette. The notch approximates the real V2
// flowing-shoulder lobe; the Bars route may refine it against the live geometry.
Item {
    id: sil
    property var root
    property string form: "full"
    property color surface: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14) : "#333333"
    property color dotColor: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55) : "#888888"
    property color accent: root ? root.seal : "#c4746e"

    implicitWidth: 240
    implicitHeight: 64

    readonly property real barH: 16
    readonly property real inset: 16
    readonly property real bodyW: Math.min(width - 2 * inset, 168)
    readonly property real bodyX: (width - bodyW) / 2

    // ── the surface ──
    Rectangle {                              // full: edge to edge
        visible: sil.form === "full"
        x: 0; y: 0; width: sil.width; height: sil.barH
        bottomLeftRadius: 3; bottomRightRadius: 3
        color: sil.surface
    }
    Rectangle {                              // fit: inset rounded capsule
        visible: sil.form === "fit"
        x: sil.bodyX; y: 4; width: sil.bodyW; height: sil.barH
        radius: sil.barH / 2
        color: sil.surface
    }
    Rectangle {                              // dock: content-width, attached to edge
        visible: sil.form === "dock"
        x: sil.bodyX; y: 0; width: sil.bodyW; height: sil.barH
        bottomLeftRadius: 6; bottomRightRadius: 6
        color: sil.surface
    }
    Shape {                                  // notch: flowing shoulders
        visible: sil.form === "notch"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: np
            fillColor: sil.surface
            strokeWidth: 0
            readonly property real l: sil.bodyX
            readonly property real r: sil.bodyX + sil.bodyW
            readonly property real sh: 12          // shoulder run
            readonly property real b: sil.barH
            startX: np.l - np.sh
            startY: 0
            PathLine { x: np.r + np.sh; y: 0 }
            PathCubic { x: np.r; y: np.b; control1X: np.r + np.sh; control1Y: np.b * 0.5; control2X: np.r + 2; control2Y: np.b }
            PathLine { x: np.l; y: np.b }
            PathCubic { x: np.l - np.sh; y: 0; control1X: np.l - 2; control1Y: np.b; control2X: np.l - np.sh; control2Y: np.b * 0.5 }
        }
    }
    Row {                                    // islands: three separated pills
        visible: sil.form === "islands"
        x: sil.inset; y: 4
        width: sil.width - 2 * sil.inset; height: sil.barH
        spacing: 10
        Repeater {
            model: 3
            delegate: Rectangle {
                width: (sil.width - 2 * sil.inset - 20) / 3
                height: sil.barH
                radius: sil.barH / 2
                color: sil.surface
            }
        }
    }

    // ── widget dots: three clusters over the surface ──
    readonly property real dotY: (barH - 4) / 2 + (form === "fit" || form === "islands" ? 4 : 0)
    Row {
        x: sil.form === "full" ? sil.inset : sil.bodyX + 8
        y: sil.dotY
        spacing: 4
        Repeater { model: 3; delegate: Rectangle { width: 8; height: 4; radius: 2; color: sil.dotColor } }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: sil.dotY
        spacing: 4
        Repeater { model: 3; delegate: Rectangle { required property int index; width: 8; height: 4; radius: 2; color: index === 1 ? sil.accent : sil.dotColor } }
    }
    Row {
        x: (sil.form === "full" ? sil.width - sil.inset : sil.bodyX + sil.bodyW - 8) - width
        y: sil.dotY
        spacing: 4
        Repeater { model: 4; delegate: Rectangle { width: 8; height: 4; radius: 2; color: sil.dotColor } }
    }
}
