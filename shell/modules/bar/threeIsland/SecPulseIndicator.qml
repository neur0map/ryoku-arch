import qs
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

        // Tailscale indicator. Click runs bar.secPulse.vpnClickCommand
        // (default: trayscale GUI). Hover surfaces hostname / IP / exit-node.
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
