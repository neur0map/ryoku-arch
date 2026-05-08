import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool showVpn: Config.options?.bar?.secPulse?.showVpn ?? true
    readonly property bool showPublicIp: Config.options?.bar?.secPulse?.showPublicIp ?? false
    readonly property bool showListening: Config.options?.bar?.secPulse?.showListening ?? false
    readonly property int maxListeningRows: 8
    readonly property int listeningPopupWidth: 360
    readonly property color colPopupText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colOnLayer3
        : Appearance.colors.colOnLayer3
    readonly property color colPopupSecondaryText: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary
        : Appearance.colors.colOnLayer3

    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer1
    readonly property color colSubtle: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 8

        // Tailscale indicator. Click runs bar.secPulse.vpnClickCommand.
        // Hover surfaces hostname / IP / exit-node.
        Item {
            id: vpnItem
            visible: root.showVpn
            implicitWidth: vpnIcon.implicitWidth
            implicitHeight: vpnIcon.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            MaterialSymbol {
                id: vpnIcon
                anchors.centerIn: parent
                text: "vpn_lock"
                iconSize: Appearance.font.pixelSize.normal
                fill: RyokuSecPulse.tsConnected ? 1 : 0
                color: RyokuSecPulse.tsConnected
                    ? (vpnMouse.containsMouse ? root.colText : root.colAccent)
                    : (vpnMouse.containsMouse ? root.colText : root.colSubtle)
            }

            MouseArea {
                id: vpnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const cmd = (Config.options?.bar?.secPulse?.vpnClickCommand ?? "").trim()
                    if (cmd.length === 0) return
                    Quickshell.execDetached(["sh", "-c", cmd])
                }
            }

            StyledToolTip {
                extraVisibleCondition: vpnMouse.containsMouse
                text: {
                    if (!RyokuSecPulse.tsConnected) return "Tailscale · off"
                    let lines = ["Tailscale · " + (RyokuSecPulse.tsHostname || "?")]
                    const ipLine = (RyokuSecPulse.tsIp || "")
                        + (RyokuSecPulse.tsRelay ? "  ·  relay " + RyokuSecPulse.tsRelay : "")
                    if (ipLine.trim().length > 0) lines.push(ipLine)
                    lines.push("exit: " + (RyokuSecPulse.tsExitNode || "none"))
                    if (root.showPublicIp && RyokuSecPulse.publicIp.length > 0)
                        lines.push("public " + RyokuSecPulse.publicIp)
                    return lines.join("\n")
                }
            }
        }

        // OpenVPN indicator (separate from tailscale: engagement tunnels
        // come and go, tailscale stays).
        Item {
            id: ovpnItem
            visible: (Config.options?.bar?.secPulse?.showOpenVpn ?? true)
            implicitWidth: ovpnIcon.implicitWidth
            implicitHeight: ovpnIcon.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            MaterialSymbol {
                id: ovpnIcon
                anchors.centerIn: parent
                text: "vpn_key"
                iconSize: Appearance.font.pixelSize.normal
                fill: RyokuOpenVpn.activeProfile.length > 0 ? 1 : 0
                color: RyokuOpenVpn.activeProfile.length > 0
                    ? (ovpnMouse.containsMouse ? root.colText : root.colAccent)
                    : (ovpnMouse.containsMouse ? root.colText : root.colSubtle)
            }
            MouseArea {
                id: ovpnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { GlobalStates.sidebarRightOpen = true }
            }
            StyledToolTip {
                extraVisibleCondition: ovpnMouse.containsMouse
                text: {
                    if (RyokuOpenVpn.activeProfile.length === 0) return "OpenVPN · off"
                    let lines = ["OpenVPN · " + RyokuOpenVpn.activeProfile]
                    if (RyokuOpenVpn.activeIp) lines.push(RyokuOpenVpn.activeIp + " · tun")
                    if (RyokuOpenVpn.activeSince) lines.push("since " + RyokuOpenVpn.activeSince.substring(11, 16))
                    return lines.join("\n")
                }
            }
        }

        // Listening socket count (opt-in)
        Item {
            id: listeningItem
            visible: root.showListening
            implicitWidth: listeningRow.implicitWidth
            implicitHeight: listeningRow.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: listeningRow
                anchors.centerIn: parent
                spacing: 2

                MaterialSymbol {
                    text: "hearing"
                    iconSize: Appearance.font.pixelSize.normal
                    color: listeningMouse.containsMouse ? root.colText : root.colSubtle
                }
                StyledText {
                    text: RyokuSecPulse.listeningCount
                    color: root.colText
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            MouseArea {
                id: listeningMouse
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
            }

            StyledPopup {
                hoverTarget: listeningMouse
                horizontalPadding: 28
                verticalPadding: 22
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassTooltip
                    : Appearance.ryokuEverywhere ? Appearance.ryoku.colTooltip
                    : Appearance.colors.colLayer3
                colBorder: Appearance.angelEverywhere ? Appearance.angel.colTooltipBorder
                    : Appearance.ryokuEverywhere ? Appearance.ryoku.colTooltipBorder
                    : Appearance.colors.colLayer3Hover

                Item {
                    id: listeningPopupContent
                    anchors.centerIn: parent
                    readonly property var ports: RyokuSecPulse.listeningPorts ?? []
                    readonly property var visiblePorts: ports.slice(0, root.maxListeningRows)
                    readonly property int hiddenRows: Math.max(0, ports.length - visiblePorts.length)

                    implicitWidth: root.listeningPopupWidth
                    implicitHeight: listeningPopupColumn.implicitHeight

                    ColumnLayout {
                        id: listeningPopupColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                text: "hearing"
                                iconSize: Appearance.font.pixelSize.normal
                                color: root.colPopupText
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: "TCP listeners"
                                color: root.colPopupText
                                font.weight: Font.Medium
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                text: RyokuSecPulse.listeningCount
                                color: root.colPopupSecondaryText
                                opacity: 0.78
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        Rectangle {
                            visible: listeningPopupContent.ports.length > 0
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.colPopupSecondaryText
                            opacity: 0.22
                        }

                        StyledText {
                            visible: listeningPopupContent.ports.length === 0
                            text: "No TCP listeners"
                            color: root.colPopupSecondaryText
                            opacity: 0.78
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }

                        Repeater {
                            model: listeningPopupContent.visiblePorts

                            ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.purpose
                                        color: root.colPopupText
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }

                                    StyledText {
                                        text: modelData.port
                                        color: root.colPopupSecondaryText
                                        opacity: 0.76
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.endpoint + " · " + modelData.processLabel
                                    color: root.colPopupSecondaryText
                                    opacity: 0.78
                                    elide: Text.ElideMiddle
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                }
                            }
                        }

                        StyledText {
                            visible: listeningPopupContent.hiddenRows > 0
                            text: "+" + listeningPopupContent.hiddenRows + " more"
                            color: root.colPopupSecondaryText
                            opacity: 0.78
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
        }
    }
}
