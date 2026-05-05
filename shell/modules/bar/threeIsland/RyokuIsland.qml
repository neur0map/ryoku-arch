import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common

/**
 * One pill background for the Three-Island topbar.
 * Mirrors the color/border/radius decision tree of BarContent.qml's barBackground.
 *
 * If you change the color/border/radius branches in BarContent.qml's barBackground,
 * mirror the same change here. The static test in tests/topbar-three-island.sh
 * grep-asserts that all five global-style branch names appear in both files.
 */
Item {
    id: root

    property var blendedColors: null
    property real cornerRadiusOverride: -1   // -1 = use computed; 0+ = explicit
    property bool fullyRounded: false        // true for the floating center pill
    property bool hugLeft: false             // hug screen left (sharp top-left)
    property bool hugRight: false            // hug screen right (sharp top-right)

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
        // Material/Cards
        const corner = Config.options?.bar?.cornerStyle ?? 0
        if (corner === 3) {
            return Appearance.colors.colLayer1
        }
        return Appearance.colors.colLayer0
    }

    readonly property real resolvedRadius: {
        if (root.cornerRadiusOverride >= 0) return root.cornerRadiusOverride
        if (root.fullyRounded) {
            // floating center pill: full window-style rounding
            if (root.angelEverywhere) return Appearance.angel.roundingNormal
            if (root.ryokuEverywhere) return Appearance.ryoku.roundingNormal
            return Appearance.rounding.windowRounding
        }
        // hugged corner pill: only inner corners are rounded; the Rectangle
        // uses a single radius and is masked to chop the outer corners.
        if (root.angelEverywhere) return Appearance.angel.roundingNormal
        if (root.ryokuEverywhere) return Appearance.ryoku.roundingNormal
        return Appearance.rounding.windowRounding
    }

    readonly property real resolvedBorderWidth: {
        if (root.angelEverywhere) return Appearance.angel.panelBorderWidth
        if (root.ryokuEverywhere) return root.fullyRounded ? 1 : 0
        if (root.auroraEverywhere) return root.fullyRounded ? 1 : 0
        return root.fullyRounded ? 1 : 0
    }

    readonly property color resolvedBorderColor: {
        if (root.angelEverywhere) return Appearance.angel.colPanelBorder
        if (root.ryokuEverywhere) return Appearance.ryoku.colBorder
        if (root.auroraEverywhere) return Appearance.aurora.colTooltipBorder
        return Appearance.colors.colLayer0Border
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        color: root.resolvedColor
        radius: root.resolvedRadius
        border.width: root.resolvedBorderWidth
        border.color: root.resolvedBorderColor
        clip: true
    }

    // For corner-hugged pills, extend the mask off the outer side so its
    // rounded corners on that side are clipped, leaving sharp top+bottom
    // outer corners that flush with the screen edge. The inner side keeps
    // its rounded corners visible.
    layer.enabled: root.hugLeft || root.hugRight
    layer.effect: GE.OpacityMask {
        maskSource: Item {
            width: root.width
            height: root.height
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: root.hugLeft ? -root.resolvedRadius : 0
                anchors.rightMargin: root.hugRight ? -root.resolvedRadius : 0
                radius: root.resolvedRadius
            }
        }
    }
}
