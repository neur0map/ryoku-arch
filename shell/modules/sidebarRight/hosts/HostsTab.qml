import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * Hosts editor sidebar tab. Adds and removes entries inside the
 * ryoku-hosts managed block of /etc/hosts via the existing pkexec +
 * WafflePolkit prompt UI. Mirrors OpenVpnTab.qml's overall shape.
 */
Item {
    id: root
    anchors.fill: parent

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    // Loose v4-or-v6 validation, same as the helper's regex.
    function _isValidIp(s) {
        if (!s) return false
        if (/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/.test(s)) return true
        if (/^[0-9a-fA-F:]+$/.test(s) && s.indexOf(":") !== s.lastIndexOf(":")) return true
        return false
    }
    function _isValidDomain(s) {
        if (!s || s.length > 253) return false
        return /^[a-zA-Z0-9._-]+$/.test(s)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Add-entry form.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialTextField {
                id: ipField
                Layout.preferredWidth: 160
                placeholderText: "IP"
                onAccepted: addBtn.clicked()
            }
            MaterialTextField {
                id: domainField
                Layout.fillWidth: true
                placeholderText: "Domain"
                onAccepted: addBtn.clicked()
            }
            DialogButton {
                id: addBtn
                buttonText: "Add"
                enabled: !RyokuHosts.busy
                        && root._isValidIp(ipField.text)
                        && root._isValidDomain(domainField.text)
                onClicked: {
                    RyokuHosts.add(ipField.text, domainField.text)
                    ipField.text = ""
                    domainField.text = ""
                    ipField.forceActiveFocus()
                }
            }
        }

        // Inline error banner.
        Rectangle {
            visible: RyokuHosts.lastError.length > 0
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
                    text: "Error: " + RyokuHosts.lastError
                    color: Appearance.m3colors.m3error ?? "#fb4934"
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Button {
                    text: "x"
                    flat: true
                    onClicked: RyokuHosts.clearError()
                    Layout.alignment: Qt.AlignTop
                }
            }
        }

        // Header row.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "dns"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: "Managed entries"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.Bold
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                visible: RyokuHosts.entries.length > 0
                text: RyokuHosts.entries.length === 1
                      ? "1 entry"
                      : RyokuHosts.entries.length + " entries"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            Item { Layout.fillWidth: true }
        }

        // List area: empty-state hero or scrollable list.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: RyokuHosts.entries.length === 0 ? "transparent" : Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            border.width: RyokuHosts.entries.length === 0 ? 1 : 0
            border.color: RyokuHosts.entries.length === 0
                          ? ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)
                          : "transparent"

            // Empty-state hero.
            ColumnLayout {
                visible: RyokuHosts.entries.length === 0
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 320)
                spacing: 14

                MaterialSymbol {
                    text: "dns"
                    iconSize: 56
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "No managed entries yet"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.Bold
                    font.pixelSize: Appearance.font.pixelSize.larger ?? 16
                    Layout.alignment: Qt.AlignHCenter
                }
                StyledText {
                    text: "Add an IP and domain above to pin a hostname locally."
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // Entry list.
            ScrollView {
                visible: RyokuHosts.entries.length > 0
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: RyokuHosts.entries
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: modelData.ip
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace ?? "monospace"
                                Layout.preferredWidth: 160
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: modelData.domain
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: removeBtn
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: Appearance.rounding.small
                                color: removeMouse.containsPress ? ColorUtils.transparentize(root.colAccent, 0.7)
                                       : removeMouse.containsMouse ? Appearance.colors.colLayer2Hover
                                       : "transparent"
                                border.width: 1
                                border.color: ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: removeMouse.containsMouse ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                                }
                                MouseArea {
                                    id: removeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !RyokuHosts.busy
                                    onClicked: RyokuHosts.remove(modelData.ip, modelData.domain)
                                }
                                StyledToolTip {
                                    extraVisibleCondition: removeMouse.containsMouse
                                    text: "Remove"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
