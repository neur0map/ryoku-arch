import QtQuick
import QtQuick.Shapes

// Shared counterpart to AiPanelSurface's caret. The complete curved section is
// one stroked path so the horizontal tangents have no joined border fragments.
Item {
    id: inset

    required property var root
    property real reveal: 0

    width: 26
    height: 6

    readonly property real progress: Math.max(0, Math.min(1, reveal))
    readonly property real centerX: width / 2
    readonly property real curveHalfWidth: 7 * progress
    readonly property real tangentControl: 4.25 * progress
    readonly property real tipControl: 2 * progress
    readonly property real baselineY: root.barPosition === "bottom" ? 0.5 : 5.5
    readonly property real innerY: root.barPosition === "bottom"
        ? baselineY + 5 * progress
        : baselineY - 5 * progress
    readonly property int renderScale: 4

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.ceil(width * inset.renderScale),
            Math.ceil(height * inset.renderScale))

        ShapePath {
            strokeColor: inset.root.barBorderEnabled
                ? inset.root.v2BarBorder
                : "transparent"
            strokeWidth: 1
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            startX: 0
            startY: inset.baselineY
            PathLine {
                x: inset.centerX - inset.curveHalfWidth
                y: inset.baselineY
            }
            PathCubic {
                x: inset.centerX
                y: inset.innerY
                control1X: inset.centerX - inset.tangentControl
                control1Y: inset.baselineY
                control2X: inset.centerX - inset.tipControl
                control2Y: inset.innerY
            }
            PathCubic {
                x: inset.centerX + inset.curveHalfWidth
                y: inset.baselineY
                control1X: inset.centerX + inset.tipControl
                control1Y: inset.innerY
                control2X: inset.centerX + inset.tangentControl
                control2Y: inset.baselineY
            }
            PathLine { x: inset.width; y: inset.baselineY }
        }
    }
}
