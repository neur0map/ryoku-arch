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
        Item {
            id: menuAnchor
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28

            readonly property bool _hovered: menuMouse.containsMouse || rowMenu.active

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: menuMouse.containsPress ? Appearance.colors.colLayer2Active
                       : menuAnchor._hovered ? Appearance.colors.colLayer2Hover
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "more_vert"
                iconSize: Appearance.font.pixelSize.normal
                color: menuAnchor._hovered ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
            }

            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rowMenu.active = true
            }
        }
    }

    ContextMenu {
        id: rowMenu
        anchorItem: menuAnchor
        anchorHovered: menuAnchor !== null && (menuMouse.containsMouse || rowMenu.active)
        popupAbove: false
        model: [
            { iconName: "description", monochromeIcon: true, text: "View full log",
              action: () => root.expandLogRequested(root.profile.name) },
            { iconName: "edit", monochromeIcon: true, text: "Edit config",
              action: () => Quickshell.execDetached([
                  "kitty", "--class=ryoku-vpn-edit",
                  "--title=Edit " + root.profile.name, "-e",
                  "pkexec", "env", "EDITOR=" + (Quickshell.env("EDITOR") || "nano"),
                  (Quickshell.env("EDITOR") || "nano"),
                  "/etc/openvpn/client/" + root.profile.name + ".conf"
              ]) },
            { type: "separator" },
            { iconName: "drive_file_rename_outline", monochromeIcon: true, text: "Rename",
              action: () => root.renameRequested(root.profile.name) },
            { iconName: "delete", monochromeIcon: true, text: "Delete",
              action: () => root.deleteRequested(root.profile.name) },
        ]
    }
}
