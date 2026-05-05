import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    property string buttonText

    horizontalPadding: 8
    verticalPadding: 6

    baseWidth: contentItem.implicitWidth + horizontalPadding * 2
    clickedWidth: baseWidth + 14
    baseHeight: contentItem.implicitHeight + verticalPadding * 2
    buttonRadius: down ? (Appearance.ryokuEverywhere ? Appearance.ryoku.roundingSmall : Appearance.rounding.verysmall) : (Appearance.ryokuEverywhere ? Appearance.ryoku.roundingNormal : Appearance.rounding.small)

    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2 
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
    colBackgroundActive: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Active 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: Appearance.ryokuEverywhere ? Appearance.ryoku.colText : Appearance.m3colors.m3onSurface
    }
}