import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

/**
 * Material 3 dialog button. See https://m3.material.io/components/dialogs/overview
 */
RippleButton {
    id: root

    property string buttonText
    padding: 14
    implicitHeight: 36
    implicitWidth: buttonTextWidget.implicitWidth + padding * 2
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
               : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : (Appearance?.rounding.full ?? 9999)

    property color colEnabled: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : (Appearance?.colors.colPrimary ?? "#65558F")
    property color colDisabled: Appearance.inirEverywhere ? Appearance.inir.colTextDisabled : (Appearance?.m3colors.m3outline ?? "#8D8C96")
    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
        : Appearance.auroraEverywhere ? "transparent" 
        : ColorUtils.transparentize(Appearance.colors.colLayer3)
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
        : Appearance.colors.colLayer3Hover
    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
        : Appearance.colors.colLayer3Active
    property alias colText: buttonTextWidget.color

    contentItem: StyledText {
        id: buttonTextWidget
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        text: buttonText
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance?.font.pixelSize.small ?? 12
        color: root.enabled ? root.colEnabled : root.colDisabled

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

}
