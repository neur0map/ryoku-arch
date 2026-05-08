import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * SecPulse: at-a-glance OpenVPN connection state for the topbar.
 * Click opens the right sidebar (lands on the user's last tab,
 * which is the OpenVPN tab if they were just there).
 * Always visible when bar.modules.secPulse is on; four states drive the icon.
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

    readonly property bool _connected: RyokuOpenVpn.activeProfile.length > 0 && !RyokuOpenVpn.transitioning
    readonly property bool _missing: !RyokuOpenVpn.openvpnInstalled

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
        text: RyokuOpenVpn.transitioning ? "sync"
            : root._connected ? "vpn_key"
            : "vpn_key_off"
        fill: root._connected ? 1 : 0
        iconSize: Appearance.font.pixelSize.larger
        color: root._missing ? Appearance.m3colors.m3error
            : (root._connected || RyokuOpenVpn.transitioning) ? root.accentColor
            : Appearance.colors.colSubtext

        RotationAnimation on rotation {
            loops: Animation.Infinite
            running: RyokuOpenVpn.transitioning
            from: 0
            to: 360
            duration: 1200
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.containsMouse
        text: {
            if (RyokuOpenVpn.transitioning) {
                if (RyokuOpenVpn.transitionTarget.length === 0) return "Disconnecting..."
                if (RyokuOpenVpn.activeProfile.length > 0)
                    return "Switching " + RyokuOpenVpn.activeProfile + " to " + RyokuOpenVpn.transitionTarget + "..."
                return "Connecting to " + RyokuOpenVpn.transitionTarget + "..."
            }
            if (root._connected) {
                let line = RyokuOpenVpn.activeProfile
                if (RyokuOpenVpn.activeIp.length > 0) line += ", " + RyokuOpenVpn.activeIp
                if (RyokuOpenVpn.activeSince.length > 0) line += ", since " + RyokuOpenVpn.activeSince
                return line
            }
            if (root._missing) return "OpenVPN not installed"
            return "VPN: not connected"
        }
    }
}
