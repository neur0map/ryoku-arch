import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent

    // (Child OpenVpnProfileRow rows bubble up via signals;
    // see the Repeater delegate below for the wiring.)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // openvpn not installed → stub
        Rectangle {
            visible: !RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            Layout.preferredHeight: stubCol.implicitHeight + 20
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            ColumnLayout {
                id: stubCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                StyledText { text: "OpenVPN not installed"; font.weight: Font.Bold; color: Appearance.colors.colOnLayer2 }
                StyledText {
                    text: "Install with: pacman -S openvpn"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        OpenVpnStatusCard {
            id: statusCard
            visible: RyokuOpenVpn.openvpnInstalled
        }

        // Profiles header
        RowLayout {
            visible: RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            StyledText {
                text: "Profiles"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            DialogButton {
                buttonText: "+"
                onClicked: RyokuOpenVpn.importNew()
            }
        }

        // Profiles list (or empty state)
        Rectangle {
            visible: RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            Layout.fillHeight: RyokuOpenVpn.profiles.length > 0
            Layout.preferredHeight: RyokuOpenVpn.profiles.length > 0 ? -1 : 180
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: RyokuOpenVpn.profiles.length === 0
                spacing: 6
                StyledText {
                    text: "No profiles yet"
                    color: Appearance.colors.colOnLayer2
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "Import a .ovpn from THM, HTB, or your corp portal."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                DialogButton {
                    buttonText: "Import .ovpn"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    onClicked: RyokuOpenVpn.importNew()
                }
            }

            // List
            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                visible: RyokuOpenVpn.profiles.length > 0
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: RyokuOpenVpn.profiles
                        delegate: OpenVpnProfileRow {
                            required property var modelData
                            profile: modelData
                            onExpandLogRequested: name => { logTail.expanded = true }
                            onRenameRequested:    name => renameDialog.openFor(name)
                            onDeleteRequested:    name => deleteDialog.openFor(name)
                        }
                    }
                }
            }
        }

        OpenVpnLogTail {
            id: logTail
            visible: RyokuOpenVpn.openvpnInstalled
        }
    }

    // Rename dialog
    Dialog {
        id: renameDialog
        property string oldName: ""
        title: "Rename profile"
        standardButtons: Dialog.Ok | Dialog.Cancel
        function openFor(name) { oldName = name; renameInput.text = name; open() }
        ColumnLayout {
            spacing: 6
            StyledText { text: "Rename '" + renameDialog.oldName + "' to:" }
            TextField {
                id: renameInput
                Layout.preferredWidth: 240
                validator: RegularExpressionValidator { regularExpression: /^[a-z0-9-]+$/ }
            }
            StyledText {
                text: "Lowercase letters, digits, dashes only."
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
        onAccepted: {
            const re = /^[a-z0-9-]+$/
            if (renameInput.text && re.test(renameInput.text) && renameInput.text !== renameDialog.oldName)
                RyokuOpenVpn.rename(renameDialog.oldName, renameInput.text)
        }
    }

    // Delete confirm
    Dialog {
        id: deleteDialog
        property string name: ""
        title: "Delete profile?"
        standardButtons: Dialog.Yes | Dialog.No
        function openFor(n) { name = n; open() }
        StyledText { text: "Delete '" + deleteDialog.name + "'? The .conf file is removed permanently." }
        onAccepted: RyokuOpenVpn.remove(deleteDialog.name)
    }
}
