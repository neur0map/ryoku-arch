import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/**
 * Tailscale status card for the OpenVPN sidebar tab. Peer pattern of
 * OpenVpnStatusCard. Binds to RyokuTailscale; click anywhere on the
 * card body or the Open Trayscale button launches the Trayscale GUI.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: cardCol.implicitHeight + 24
    color: Appearance.colors.colLayer2
    radius: Appearance.rounding.normal

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: RyokuTailscale.installed ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: { if (RyokuTailscale.installed) RyokuTailscale.openTrayscale() }
        propagateComposedEvents: true
    }

    ColumnLayout {
        id: cardCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Header row.
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            MaterialSymbol {
                text: "lan"
                iconSize: Appearance.font.pixelSize.larger
                color: RyokuTailscale.connected ? root.colAccent : Appearance.colors.colSubtext
            }
            StyledText {
                text: "Tailscale"
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer2
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: RyokuTailscale.transitioning ? "starting..."
                    : RyokuTailscale.connected ? "connected"
                    : "off"
                font.pixelSize: Appearance.font.pixelSize.small
                color: RyokuTailscale.connected ? root.colAccent
                    : RyokuTailscale.transitioning ? root.colAccent
                    : Appearance.colors.colSubtext
            }
        }

        // Detail rows when connected.
        StyledText {
            visible: RyokuTailscale.connected && RyokuTailscale.hostname.length > 0
            text: RyokuTailscale.hostname
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: RyokuTailscale.connected && RyokuTailscale.tailIp.length > 0
            text: RyokuTailscale.tailIp + (RyokuTailscale.relay.length > 0 ? (", via " + RyokuTailscale.relay) : "")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: RyokuTailscale.connected && RyokuTailscale.exitNode.length > 0
            text: "exit: " + RyokuTailscale.exitNode
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        // Action row.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 8

            DialogButton {
                enabled: RyokuTailscale.installed
                buttonText: "Open Trayscale"
                onClicked: RyokuTailscale.openTrayscale()
            }
        }
    }
}
