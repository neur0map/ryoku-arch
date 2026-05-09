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
        Item {
            id: ipRow
            visible: RyokuTailscale.connected && RyokuTailscale.tailIp.length > 0
            Layout.fillWidth: true
            implicitHeight: ipText.implicitHeight
            property bool justCopied: false

            Timer {
                id: copyResetTimer
                interval: 1500
                onTriggered: ipRow.justCopied = false
            }

            RowLayout {
                anchors.fill: parent
                spacing: 6
                StyledText {
                    id: ipText
                    text: ipRow.justCopied
                          ? "Copied!"
                          : (RyokuTailscale.tailIp + (RyokuTailscale.relay.length > 0 ? (", via " + RyokuTailscale.relay) : ""))
                    color: ipRow.justCopied
                           ? root.colAccent
                           : (ipMouse.containsMouse ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext)
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                MaterialSymbol {
                    visible: !ipRow.justCopied
                    text: "content_copy"
                    iconSize: Appearance.font.pixelSize.small
                    color: ipMouse.containsMouse ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    opacity: ipMouse.containsMouse ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                Item { Layout.fillWidth: true }
            }
            MouseArea {
                id: ipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.clipboardText = RyokuTailscale.tailIp
                    ipRow.justCopied = true
                    copyResetTimer.restart()
                }
            }
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
                enabled: RyokuTailscale.installed && !RyokuTailscale.transitioning
                buttonText: RyokuTailscale.connected ? "Disconnect" : "Connect"
                onClicked: RyokuTailscale.connected ? RyokuTailscale.disconnect() : RyokuTailscale.connect()
            }

            DialogButton {
                enabled: RyokuTailscale.installed
                buttonText: "Open Trayscale"
                onClicked: RyokuTailscale.openTrayscale()
            }
        }
    }
}
