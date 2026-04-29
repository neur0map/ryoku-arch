import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../vendor/brain-shell/src/state" as BS

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    surfaceFormat.opaque: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Spec 2 follow-up: Frame is now a unified Canvas that paints the
    // exact same SeamlessBarShape outline at the top (notches + gaps,
    // wallpaper showing through gaps) plus extends down as side strips
    // and a bottom strip. The cutout (window area) has rounded inner
    // corners. Result: bar's floating-pill design preserved, AND the
    // corner where bar bottom meets side frame is rounded by the cutout.
    Canvas {
        id: canvas
        anchors.fill: parent

        // Bar widths bound from TopBar via ShellState singleton.
        property int leftW:   BS.ShellState.topBarLWidth   > 0 ? BS.ShellState.topBarLWidth   : 180
        property int centerW: BS.ShellState.topBarCWidth   > 0 ? BS.ShellState.topBarCWidth   : 300
        property int rightW:  BS.ShellState.topBarRWidth   > 0 ? BS.ShellState.topBarRWidth   : 200

        // Bar shape parameters - must match SeamlessBarShape's defaults
        // which read from Theme. Hardcoded here because Frame doesn't
        // import the vendored Theme (path complexity); update if Theme
        // changes notchHeight / notchRadius / borderWidth.
        property int notchHeight: 32
        property int notchRadius: 15
        property int topBorderWidth: 6

        // Frame parameters from Config.
        property int frameThickness: Config.frameThickness
        property int rounding:       Config.rounding
        property int matboard:       Config.matboard
        property int topMatboard:    Config.topMatboard

        property color color: Config.frameColor

        onLeftWChanged:    requestPaint()
        onCenterWChanged:  requestPaint()
        onRightWChanged:   requestPaint()
        onWidthChanged:    requestPaint()
        onHeightChanged:   requestPaint()
        onColorChanged:    requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w  = width
            var sh = height
            var h  = notchHeight
            var r  = notchRadius
            var b  = topBorderWidth
            var ft = frameThickness
            var rd = rounding

            var centerStart = (w / 2) - (centerW / 2)
            var centerEnd   = (w / 2) + (centerW / 2)
            var rightStart  = w - rightW

            ctx.beginPath()
            ctx.fillStyle = color

            // OUTER PATH: bar shape at top + side and bottom strips.
            // Replicates SeamlessBarShape's path through notches and gaps.

            ctx.moveTo(0, h)                                    // bar bottom-left

            // LEFT NOTCH
            ctx.lineTo(leftW - r, h)
            ctx.arcTo(leftW, h, leftW, h - r, r)
            ctx.lineTo(leftW, b + r)
            ctx.arcTo(leftW, b, leftW + r, b, r)

            // GAP 1 (left to center)
            ctx.lineTo(centerStart - r, b)

            // CENTER NOTCH
            ctx.arcTo(centerStart, b, centerStart, b + r, r)
            ctx.lineTo(centerStart, h - r)
            ctx.arcTo(centerStart, h, centerStart + r, h, r)
            ctx.lineTo(centerEnd - r, h)
            ctx.arcTo(centerEnd, h, centerEnd, h - r, r)
            ctx.lineTo(centerEnd, b + r)
            ctx.arcTo(centerEnd, b, centerEnd + r, b, r)

            // GAP 2 (center to right)
            ctx.lineTo(rightStart - r, b)

            // RIGHT NOTCH
            ctx.arcTo(rightStart, b, rightStart, b + r, r)
            ctx.lineTo(rightStart, h - r)
            ctx.arcTo(rightStart, h, rightStart + r, h, r)
            ctx.lineTo(w, h)                                    // bar bottom-right

            // EXTEND DOWN AS SIDE + BOTTOM STRIPS
            ctx.lineTo(w, sh)                                   // right side down to screen bottom
            ctx.lineTo(0, sh)                                   // across bottom
            ctx.lineTo(0, h)                                    // left side back up to bar bottom-left

            // CUTOUT (window area) with rounded inner corners.
            // Counterclockwise winding so evenodd fill rule carves it out.
            ctx.moveTo(ft + rd, h)
            ctx.arcTo(ft, h, ft, h + rd, rd)
            ctx.lineTo(ft, sh - ft - rd)
            ctx.arcTo(ft, sh - ft, ft + rd, sh - ft, rd)
            ctx.lineTo(w - ft - rd, sh - ft)
            ctx.arcTo(w - ft, sh - ft, w - ft, sh - ft - rd, rd)
            ctx.lineTo(w - ft, h + rd)
            ctx.arcTo(w - ft, h, w - ft - rd, h, rd)
            ctx.lineTo(ft + rd, h)

            ctx.fill("evenodd")
        }

        // Repaint when ShellState's bar widths change (Dashboard expand etc.)
        Connections {
            target: BS.ShellState
            function onTopBarLWidthChanged() { canvas.requestPaint() }
            function onTopBarCWidthChanged() { canvas.requestPaint() }
            function onTopBarRWidthChanged() { canvas.requestPaint() }
        }
    }
}
