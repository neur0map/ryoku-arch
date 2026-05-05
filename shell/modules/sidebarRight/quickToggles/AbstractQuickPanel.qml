import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    property bool editMode: false
    readonly property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.ryokuEverywhere ? Appearance.ryoku.roundingNormal
        : Appearance.rounding.normal
    color: Appearance.angelEverywhere
        ? (cardStyle ? Appearance.angel.colGlassCard : "transparent")
        : cardStyle 
            ? (Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer1
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1)
            : "transparent"
    border.width: 0
    border.color: "transparent"

    AngelPartialBorder { targetRadius: root.radius; coverage: 0.5; visible: Appearance.angelEverywhere && root.cardStyle }

    signal openAudioOutputDialog()
    signal openAudioInputDialog()
    signal openBluetoothDialog()
    signal openHotspotDialog()
    signal openNightLightDialog()
    signal openWifiDialog()
}
