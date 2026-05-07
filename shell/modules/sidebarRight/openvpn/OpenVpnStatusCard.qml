import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 18
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    border.color: Appearance.colors.colLayer3Hover
    border.width: 1

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary
    readonly property color colError: Appearance.colors.colError ?? "#fb4934"

    function _formatSince(raw) {
        if (!raw || raw.length === 0) return "?"
        // systemd ActiveEnterTimestamp format: "Wed 2026-05-06 13:14:38 EDT"
        // Pull first HH:MM out of the string. Falls back to "?" if no match.
        const m = raw.match(/(\d{2}:\d{2}):\d{2}/)
        return m ? m[1] : "?"
    }

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
        anchors.margins: 12
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
            text: RyokuOpenVpn.activeProfile + " · since " + root._formatSince(RyokuOpenVpn.activeSince)
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
        Item {
            id: ipRow
            visible: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeIp.length > 0
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
                          : (RyokuOpenVpn.activeIp + " · tun")
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
                    Quickshell.clipboardText = RyokuOpenVpn.activeIp
                    ipRow.justCopied = true
                    copyResetTimer.restart()
                }
            }
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
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.preferredHeight: 4 }
        DialogButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            enabled: !RyokuOpenVpn.transitioning && RyokuOpenVpn.activeProfile.length > 0
            buttonText: "Disconnect"
            onClicked: RyokuOpenVpn.disconnect()
        }
    }
}
