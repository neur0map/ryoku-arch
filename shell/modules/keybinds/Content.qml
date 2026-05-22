pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    signal close

    readonly property string query: search.text.toLowerCase()
    readonly property var filteredEntries: Keybinds.entries.filter(entry => {
            if (!query)
                return true;

            return [entry.combo, entry.description, entry.dispatcher, entry.arg].some(value => String(value ?? "").toLowerCase().includes(query));
        })
    readonly property bool hasConflict: Keybinds.entries.some(entry => entry.combo === formCombo && formCombo)
    readonly property string formCombo: {
        const mods = modsField.text.trim().split(/\s+/).filter(part => part).map(part => part.slice(0, 1).toUpperCase() + part.slice(1).toLowerCase());
        const key = keyField.text.trim();
        if (!key)
            return "";
        return mods.length ? `${mods.join("+")}+${key}` : key;
    }

    Keys.onEscapePressed: root.close()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + Tokens.padding.large * 2
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: headerRow

                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.larger
                anchors.rightMargin: Tokens.padding.large
                spacing: Tokens.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "keyboard"
                    fill: 1
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.extraLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    StyledText {
                        text: qsTr("Keybinds")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.larger
                        font.weight: 600
                    }

                    StyledText {
                        text: Keybinds.loading ? qsTr("Refreshing Hyprland binds") : Keybinds.status || qsTr("Live Hyprland binds")
                        color: Keybinds.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                    }
                }

                IconButton {
                    icon: "refresh"
                    type: IconButton.Text
                    onClicked: Keybinds.refresh()
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: root.close()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(470, parent.width * 0.52)
                color: Colours.tPalette.m3surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.normal

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight) + Tokens.padding.normal
                        radius: Tokens.rounding.full
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                        MaterialIcon {
                            id: searchIcon

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.large
                            text: "search"
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledTextField {
                            id: search

                            anchors.left: searchIcon.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.spacing.small
                            anchors.rightMargin: Tokens.padding.large
                            placeholderText: qsTr("Search keybinds")
                            Component.onCompleted: forceActiveFocus()
                        }
                    }

                    StyledFlickable {
                        id: flick

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: list.implicitHeight
                        clip: true

                        Column {
                            id: list

                            width: flick.width
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: root.filteredEntries

                                KeybindRow {
                                    required property var modelData

                                    width: list.width
                                    entry: modelData
                                }
                            }
                        }

                        ScrollBar.vertical: StyledScrollBar {
                            flickable: flick
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.larger
                    spacing: Tokens.spacing.normal

                    StyledText {
                        text: qsTr("Add Keybind")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.large
                        font.weight: 600
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Saved to the Ryoku user bind include, then Hyprland reloads.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    Field {
                        id: modsField

                        label: qsTr("Modifiers")
                        text: "SUPER"
                    }

                    Field {
                        id: keyField

                        label: qsTr("Key")
                    }

                    Field {
                        id: dispatcherField

                        label: qsTr("Action")
                        text: "exec"
                    }

                    Field {
                        id: argField

                        label: qsTr("Command / Argument")
                    }

                    Field {
                        id: descriptionField

                        label: qsTr("Label")
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        visible: root.hasConflict || !!Keybinds.error
                        implicitHeight: warningText.implicitHeight + Tokens.padding.normal * 2
                        color: Qt.alpha(root.hasConflict ? Colours.palette.m3tertiaryContainer : Colours.palette.m3errorContainer, 0.8)
                        radius: Tokens.rounding.small

                        StyledText {
                            id: warningText

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.normal
                            text: Keybinds.error || qsTr("%1 is already in use").arg(root.formCombo)
                            color: root.hasConflict ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onErrorContainer
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    IconTextButton {
                        Layout.alignment: Qt.AlignRight
                        icon: "add"
                        text: qsTr("Add keybind")
                        onClicked: Keybinds.addBind(modsField.text, keyField.text, dispatcherField.text || "exec", argField.text, descriptionField.text)
                    }
                }
            }
        }
    }

    component Field: ColumnLayout {
        required property string label
        property alias text: input.text

        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        StyledText {
            text: label
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            font.weight: 500
        }

        StyledInputField {
            id: input

            Layout.fillWidth: true
            implicitWidth: 220
            horizontalAlignment: TextInput.AlignLeft
        }
    }

    component KeybindRow: StyledRect {
        required property var entry

        implicitHeight: Math.max(comboPill.implicitHeight, textColumn.implicitHeight) + Tokens.padding.normal * 2
        radius: Tokens.rounding.small
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            StyledRect {
                id: comboPill

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: comboText.implicitWidth + Tokens.padding.normal * 2
                implicitHeight: comboText.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.small
                color: Colours.palette.m3secondaryContainer

                StyledText {
                    id: comboText

                    anchors.centerIn: parent
                    text: entry.combo
                    color: Colours.palette.m3onSecondaryContainer
                    font.family: Tokens.font.family.mono
                    font.pointSize: Tokens.font.size.small
                    font.weight: 600
                }
            }

            ColumnLayout {
                id: textColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: entry.description || entry.dispatcher
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: entry.arg || entry.dispatcher
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    font.pointSize: Tokens.font.size.small
                    font.family: Tokens.font.family.mono
                }
            }

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: sourceText.implicitWidth + Tokens.padding.normal
                implicitHeight: sourceText.implicitHeight + Tokens.padding.smaller
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3primaryContainer, 0.65)

                StyledText {
                    id: sourceText

                    anchors.centerIn: parent
                    text: entry.source === "live" ? qsTr("live") : qsTr("file")
                    color: Colours.palette.m3onPrimaryContainer
                    font.pointSize: Tokens.font.size.smaller
                }
            }
        }
    }
}
