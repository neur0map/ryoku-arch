import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent

    // Inline import-result banner. Bound to the helper's manifest.
    property string importError: ""

    function _parseImportManifest(jsonText) {
        try {
            const d = JSON.parse(jsonText)
            if (d.status === "error")          root.importError = d.error || "Import failed"
            else if (d.status === "cancelled") root.importError = ""   // user cancel: silent
            else                                root.importError = ""   // ok
        } catch (e) {
            root.importError = ""
        }
    }

    FileView {
        id: importManifest
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/openvpn/last-import.json"
        watchChanges: true
        onFileChanged: { reload(); root._parseImportManifest(text()) }
        onLoaded: root._parseImportManifest(text())
        onLoadFailed: (err) => { /* expected before first import */ }
    }

    // (Child OpenVpnProfileRow rows bubble up via signals;
    // see the Repeater delegate below for the wiring.)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // tailscale-not-installed stub
        Rectangle {
            visible: !RyokuTailscale.installed
            Layout.fillWidth: true
            Layout.preferredHeight: tsStubCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            ColumnLayout {
                id: tsStubCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "warning_amber"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: "Tailscale not installed"
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer2
                    }
                }
                StyledText {
                    text: "Install with: pacman -S tailscale"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        // Tailscale status card (only when installed).
        TailscaleStatusCard {
            visible: RyokuTailscale.installed
        }

        // openvpn-not-installed stub
        Rectangle {
            visible: !RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            Layout.preferredHeight: stubCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            ColumnLayout {
                id: stubCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "warning_amber"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: "OpenVPN not installed"
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer2
                    }
                }
                StyledText {
                    text: "Install with: pacman -S openvpn"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        // Status card (only when connected or transitioning)
        OpenVpnStatusCard {
            id: statusCard
            visible: RyokuOpenVpn.openvpnInstalled
                     && (RyokuOpenVpn.activeProfile.length > 0 || RyokuOpenVpn.transitioning)
        }

        // Profiles section
        ColumnLayout {
            visible: RyokuOpenVpn.openvpnInstalled
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "folder_open"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: "Profiles"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.Bold
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    visible: RyokuOpenVpn.profiles.length > 0
                    text: RyokuOpenVpn.profiles.length === 1
                          ? "1 saved"
                          : RyokuOpenVpn.profiles.length + " saved"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                Item { Layout.fillWidth: true }
                DialogButton {
                    visible: RyokuOpenVpn.profiles.length > 0
                    buttonText: "Import"
                    onClicked: { root.importError = ""; RyokuOpenVpn.importNew() }
                }
            }

            // Inline import error banner
            Rectangle {
                visible: root.importError.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: errRow.implicitHeight + 16
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.85)
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.5)

                RowLayout {
                    id: errRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    MaterialSymbol {
                        text: "error_outline"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3error ?? "#fb4934"
                        Layout.alignment: Qt.AlignTop
                    }
                    StyledText {
                        text: "Import failed: " + root.importError
                        color: Appearance.m3colors.m3error ?? "#fb4934"
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Button {
                        text: "✕"
                        flat: true
                        onClicked: root.importError = ""
                        Layout.alignment: Qt.AlignTop
                    }
                }
            }

            // Profiles list area: ALWAYS fills remaining height. Renders either
            // the empty-state hero or the scrollable list.
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: RyokuOpenVpn.profiles.length === 0 ? "transparent" : Appearance.colors.colLayer2
                radius: Appearance.rounding.normal
                border.width: RyokuOpenVpn.profiles.length === 0 ? 1 : 0
                border.color: RyokuOpenVpn.profiles.length === 0
                              ? ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)
                              : "transparent"

                // Empty-state hero (centered, fills the available card)
                ColumnLayout {
                    visible: RyokuOpenVpn.profiles.length === 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 32, 320)
                    spacing: 14

                    MaterialSymbol {
                        text: "vpn_key_off"
                        iconSize: 56
                        color: Appearance.colors.colSubtext
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: "No profiles yet"
                        color: Appearance.colors.colOnLayer1
                        font.weight: Font.Bold
                        font.pixelSize: Appearance.font.pixelSize.larger ?? 16
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: "Import a .ovpn from TryHackMe, Hack The Box, or your corp portal."
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    DialogButton {
                        buttonText: "Import .ovpn"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        onClicked: { root.importError = ""; RyokuOpenVpn.importNew() }
                    }
                }

                // Profile list
                ScrollView {
                    visible: RyokuOpenVpn.profiles.length > 0
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    ColumnLayout {
                        width: parent.width
                        spacing: 4
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
        }

        // Log tail (only when something is connected)
        OpenVpnLogTail {
            id: logTail
            visible: RyokuOpenVpn.openvpnInstalled && RyokuOpenVpn.activeProfile.length > 0
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
            StyledText {
                visible: renameDialog.oldName === RyokuOpenVpn.activeProfile && RyokuOpenVpn.activeProfile.length > 0
                text: "⚠ Renaming the active profile will briefly drop the connection."
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3error ?? "#fb4934"
                wrapMode: Text.Wrap
                Layout.maximumWidth: 240
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
