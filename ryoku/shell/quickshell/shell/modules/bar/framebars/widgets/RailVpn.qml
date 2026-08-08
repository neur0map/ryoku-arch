pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// VPN indicator: a box-shape indicator (no click) that self-hides unless a
// tunnel is up. `active` (the host visibility) gates the singleton's polling so a
// new tunnel is still discovered while the chip itself is hidden. Contract 04
// sec 3.2 (vpn_indicator).
Item {
    id: root

    required property string edge
    required property real scale
    required property bool active

    readonly property bool selfShown: Network.vpnActive
    visible: selfShown
    implicitWidth: selfShown ? btn.implicitWidth : 0
    implicitHeight: selfShown ? btn.implicitHeight : 0

    onActiveChanged: Network.setVpnPolling(root, root.active)
    Component.onCompleted: Network.setVpnPolling(root, root.active)
    Component.onDestruction: Network.setVpnPolling(root, false)

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: "shield-check"
        interactive: false
    }
}
