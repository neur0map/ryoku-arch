import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * SecPulse: at-a-glance combined OpenVPN + Tailscale connection state for
 * the topbar. Click opens the right sidebar (lands on the user's last tab,
 * which is the OpenVPN tab if they were just there). Always visible when
 * bar.modules.secPulse is on; combined-state logic drives one icon and the
 * tooltip surfaces both VPN states on separate lines.
 */
MouseArea {
    id: root

    implicitWidth: pill.width
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    readonly property color accentColor:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    readonly property bool _anyTransitioning: RyokuOpenVpn.transitioning || RyokuTailscale.transitioning
    readonly property bool _anyConnected: (RyokuOpenVpn.activeProfile.length > 0 && !RyokuOpenVpn.transitioning)
                                          || (RyokuTailscale.connected && !RyokuTailscale.transitioning)
    readonly property bool _bothMissing: !RyokuOpenVpn.openvpnInstalled && !RyokuTailscale.installed

    onClicked: { GlobalStates.sidebarRightOpen = true }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: icon.implicitWidth + 12
        height: icon.implicitHeight + 8
        radius: height / 2
        color: root.containsMouse
            ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer1Hover
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1Hover)
            : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    MaterialSymbol {
        id: icon
        anchors.centerIn: pill
        text: root._anyTransitioning ? "sync"
            : root._anyConnected ? "vpn_key"
            : "vpn_key_off"
        fill: root._anyConnected ? 1 : 0
        iconSize: Appearance.font.pixelSize.larger
        color: root._bothMissing ? Appearance.m3colors.m3error
            : (root._anyConnected || root._anyTransitioning) ? root.accentColor
            : Appearance.colors.colSubtext

        RotationAnimation on rotation {
            loops: Animation.Infinite
            running: root._anyTransitioning
            from: 0
            to: 360
            duration: 1200
        }
    }

    function _ovpnLine() {
        if (RyokuOpenVpn.transitioning) {
            if (RyokuOpenVpn.transitionTarget.length === 0) return "OpenVPN: Disconnecting..."
            if (RyokuOpenVpn.activeProfile.length > 0)
                return "OpenVPN: Switching " + RyokuOpenVpn.activeProfile + " to " + RyokuOpenVpn.transitionTarget + "..."
            return "OpenVPN: Connecting to " + RyokuOpenVpn.transitionTarget + "..."
        }
        if (RyokuOpenVpn.activeProfile.length > 0) {
            let line = "OpenVPN: " + RyokuOpenVpn.activeProfile
            if (RyokuOpenVpn.activeIp.length > 0) line += ", " + RyokuOpenVpn.activeIp
            if (RyokuOpenVpn.activeSince.length > 0) line += ", since " + RyokuOpenVpn.activeSince
            return line
        }
        if (!RyokuOpenVpn.openvpnInstalled) return "OpenVPN: not installed"
        return "OpenVPN: off"
    }

    function _tsLine() {
        if (RyokuTailscale.transitioning) return "Tailscale: starting..."
        if (RyokuTailscale.connected) {
            let line = "Tailscale: " + RyokuTailscale.hostname
            if (RyokuTailscale.tailIp.length > 0) line += ", " + RyokuTailscale.tailIp
            if (RyokuTailscale.relay.length > 0) line += ", via " + RyokuTailscale.relay
            if (RyokuTailscale.exitNode.length > 0) line += ", exit " + RyokuTailscale.exitNode
            return line
        }
        if (!RyokuTailscale.installed) return "Tailscale: not installed"
        return "Tailscale: off"
    }

    StyledToolTip {
        extraVisibleCondition: root.containsMouse
        text: root._ovpnLine() + "\n" + root._tsLine()
    }
}
