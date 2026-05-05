import QtQuick
import qs.modules.common

/**
 * Single Canvas frame for the Three-Island topbar - a thin top strip across
 * the screen with three notches (left/center/right) dropping down from it.
 * Adapted from Brain_Shell's src/shapes/SeamlessBarShape.qml (MIT).
 *
 * Color follows the same global-style decision tree BarContent.qml uses for
 * its barBackground; if that branch logic changes upstream, mirror here.
 */
Canvas {
    id: root
    anchors.fill: parent

    // Notch widths set by RyokuThreeIslandContent.qml from content sizes.
    property int leftWidth: 200
    property int centerWidth: 200
    property int rightWidth: 200

    property int notchHeight: Appearance.sizes.barHeight
    property int radius: Math.min(12, Appearance.rounding.windowRounding)
    property int topBorderHeight: 4
    property var blendedColors: null

    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool ryokuEverywhere: Appearance.ryokuEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    readonly property color resolvedColor: {
        if (root.angelEverywhere) {
            const base = root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
            if (Appearance.compositorBlurActive)
                return ColorUtils.transparentize(base, Appearance.angel.compositorPanelTransparentize)
            return ColorUtils.applyAlpha(base, 1)
        }
        if (root.ryokuEverywhere) {
            return Appearance.ryoku.colLayer0
        }
        if (root.auroraEverywhere) {
            const base = root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
            if (Appearance.compositorBlurActive)
                return ColorUtils.transparentize(base, Appearance.aurora.compositorOverlayTransparentize)
            return ColorUtils.applyAlpha(base, 1)
        }
        const corner = Config.options?.bar?.cornerStyle ?? 0
        if (corner === 3) {
            return Appearance.colors.colLayer1
        }
        return Appearance.colors.colLayer0
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onResolvedColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const leftW = root.leftWidth
        const centerW = root.centerWidth
        const rightW = root.rightWidth

        const r = root.radius
        const h = root.notchHeight
        const b = root.topBorderHeight
        const w = width

        const centerStart = (w / 2) - (centerW / 2)
        const centerEnd = (w / 2) + (centerW / 2)
        const rightStart = w - rightW

        ctx.beginPath()
        ctx.fillStyle = root.resolvedColor

        // Left notch
        ctx.moveTo(0, h)
        ctx.lineTo(leftW - r, h)
        ctx.arcTo(leftW, h, leftW, h - r, r)
        ctx.lineTo(leftW, b + r)
        ctx.arcTo(leftW, b, leftW + r, b, r)

        // Gap left to center
        ctx.lineTo(centerStart - r, b)

        // Center notch
        ctx.arcTo(centerStart, b, centerStart, b + r, r)
        ctx.lineTo(centerStart, h - r)
        ctx.arcTo(centerStart, h, centerStart + r, h, r)
        ctx.lineTo(centerEnd - r, h)
        ctx.arcTo(centerEnd, h, centerEnd, h - r, r)
        ctx.lineTo(centerEnd, b + r)
        ctx.arcTo(centerEnd, b, centerEnd + r, b, r)

        // Gap center to right
        ctx.lineTo(rightStart - r, b)

        // Right notch
        ctx.arcTo(rightStart, b, rightStart, b + r, r)
        ctx.lineTo(rightStart, h - r)
        ctx.arcTo(rightStart, h, rightStart + r, h, r)
        ctx.lineTo(w, h)

        // Close along the top edge
        ctx.lineTo(w, 0)
        ctx.lineTo(0, 0)
        ctx.lineTo(0, h)

        ctx.fill()
    }
}
