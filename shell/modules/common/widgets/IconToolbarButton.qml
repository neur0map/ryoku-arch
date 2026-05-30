import QtQuick
import QtQuick.Layouts
import qs.modules.common

ToolbarButton {
    id: iconBtn
    implicitWidth: height

    colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colSelection 
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface 
        : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colSelectionHover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover 
        : Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
        : Appearance.colors.colSecondaryContainerActive
    property color colText: toggled ? (Appearance.inirEverywhere ? Appearance.inir.colOnSelection : Appearance.colors.colOnSecondaryContainer) : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant)

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        iconSize: 22
        text: iconBtn.text
        color: iconBtn.colText
    }
}
