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
    required property var profile  // {name, path, isActive}

    // Bubble up to the Tab composer (parent-chain is too deep for direct calls).
    signal expandLogRequested(string name)
    signal renameRequested(string name)
    signal deleteRequested(string name)

    readonly property bool isActive: root.profile?.name === RyokuOpenVpn.activeProfile && RyokuOpenVpn.activeProfile.length > 0

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: Appearance.rounding.small
    color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 8
        StyledText {
            text: root.profile.name
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.normal
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        DialogButton {
            visible: !root.isActive
            enabled: !RyokuOpenVpn.transitioning
            buttonText: "Connect"
            onClicked: RyokuOpenVpn.connect(root.profile.name)
        }
        RowLayout {
            visible: root.isActive
            spacing: 4
            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: root.colAccent }
            StyledText { text: "Active"; color: root.colAccent; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Bold }
        }
        Button {
            text: "⋮"
            flat: true
            onClicked: rowMenu.popup()
        }
    }

    Menu {
        id: rowMenu
        MenuItem {
            text: "View full log"
            onTriggered: root.expandLogRequested(root.profile.name)
        }
        MenuItem {
            text: "Edit config…"
            onTriggered: {
                const ed = Quickshell.env("EDITOR") || "nano"
                Quickshell.execDetached([
                    "kitty",
                    "--class=ryoku-vpn-edit",
                    "--title=Edit " + root.profile.name,
                    "-e",
                    "pkexec",
                    "env", "EDITOR=" + ed,
                    ed,
                    "/etc/openvpn/client/" + root.profile.name + ".conf"
                ])
            }
        }
        MenuItem {
            text: "Rename…"
            onTriggered: root.renameRequested(root.profile.name)
        }
        MenuItem {
            text: "Delete"
            onTriggered: root.deleteRequested(root.profile.name)
        }
    }
}
