import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: visible ? content.implicitHeight + 20 : 0
    visible: RyokuOpenVpn.activeProfile.length > 0 || RyokuOpenVpn.transitioning
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.color: Appearance.colors.colLayer3Hover
    border.width: 1

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary
    readonly property color colError: Appearance.colors.colError ?? "#fb4934"

    readonly property string headline: {
        if (RyokuOpenVpn.transitioning) {
            if (RyokuOpenVpn.transitionTarget.length === 0) return "Disconnecting…"
            if (RyokuOpenVpn.activeProfile.length > 0) return "Switching " + RyokuOpenVpn.activeProfile + " → " + RyokuOpenVpn.transitionTarget + "…"
            return "Connecting to " + RyokuOpenVpn.transitionTarget + "…"
        }
        return "Connected"
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: RyokuOpenVpn.transitioning ? "sync" : "vpn_key"
                fill: RyokuOpenVpn.transitioning ? 0 : 1
                iconSize: Appearance.font.pixelSize.normal
                color: root.colAccent
                RotationAnimation on rotation {
                    running: RyokuOpenVpn.transitioning
                    from: 0; to: 360; duration: 1500
                    loops: Animation.Infinite
                }
            }
            StyledText {
                text: root.headline
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
        }
        StyledText {
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0
            text: RyokuOpenVpn.activeProfile + " · since " + (RyokuOpenVpn.activeSince.length > 0 ? RyokuOpenVpn.activeSince.substring(11, 16) : "?")
            color: Appearance.colors.colOnLayer2Subtitle
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeIp.length > 0
            text: RyokuOpenVpn.activeIp + " · tun"
            color: Appearance.colors.colOnLayer2Subtitle
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0 && RyokuOpenVpn.activeIp.length === 0
            text: "Tunnel up, no IP yet, check log"
            color: root.colError
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: RyokuOpenVpn.otherActiveCount > 0
            text: "(+" + RyokuOpenVpn.otherActiveCount + " other unit" + (RyokuOpenVpn.otherActiveCount === 1 ? "" : "s") + " active)"
            color: Appearance.colors.colOnLayer2Subtitle
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.preferredHeight: 4 }
        Button {
            Layout.fillWidth: true
            enabled: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0
            text: "Disconnect"
            onClicked: RyokuOpenVpn.disconnect()
        }
    }
}
