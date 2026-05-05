import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool showVpn: Config.options?.bar?.secPulse?.showVpn ?? true
    readonly property bool showPublicIp: Config.options?.bar?.secPulse?.showPublicIp ?? false
    readonly property bool showListening: Config.options?.bar?.secPulse?.showListening ?? false

    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer1
    readonly property color colSubtle: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary
        : Appearance.colors.colSubtext

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 8

        // VPN indicator: lock_open / lock based on wg interface presence
        RowLayout {
            visible: root.showVpn
            spacing: 2
            MaterialSymbol {
                text: RyokuSecPulse.vpnActive ? "lock" : "lock_open"
                iconSize: Appearance.font.pixelSize.normal
                color: RyokuSecPulse.vpnActive ? root.colText : root.colSubtle
            }
            StyledText {
                text: RyokuSecPulse.vpnActive ? "VPN" : "off"
                color: RyokuSecPulse.vpnActive ? root.colText : root.colSubtle
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        // Public IP (opt-in)
        RowLayout {
            visible: root.showPublicIp && RyokuSecPulse.publicIp.length > 0
            spacing: 2
            MaterialSymbol {
                text: "public"
                iconSize: Appearance.font.pixelSize.normal
                color: root.colSubtle
            }
            StyledText {
                text: RyokuSecPulse.publicIp
                color: root.colText
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        // Listening socket count (opt-in)
        RowLayout {
            visible: root.showListening
            spacing: 2
            MaterialSymbol {
                text: "hearing"
                iconSize: Appearance.font.pixelSize.normal
                color: root.colSubtle
            }
            StyledText {
                text: RyokuSecPulse.listeningCount
                color: root.colText
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
