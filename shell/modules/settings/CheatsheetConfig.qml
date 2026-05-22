import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 9
    settingsPageName: Translation.tr("Shortcuts")

    readonly property bool canEdit: CompositorService.isNiri
    readonly property string keybindConfigPath: CompositorService.isNiri
        ? NiriKeybinds.configPath
        : HyprlandKeybinds.userKeybindConfigPath

    property string _statusMsg: ""
    property string _statusType: ""
    property bool _statusVisible: false

    function openCheatsheet() {
        Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "cheatsheet", "open"])
    }

    Connections {
        target: NiriKeybinds
        function onBindSaved(keyCombo) {
            root._statusMsg = Translation.tr("Saved: ") + keyCombo
            root._statusType = "saved"
            root._statusVisible = true
            statusHideTimer.restart()
        }
        function onBindRemoved(keyCombo) {
            root._statusMsg = Translation.tr("Removed: ") + keyCombo
            root._statusType = "removed"
            root._statusVisible = true
            statusHideTimer.restart()
        }
        function onBindError(message) {
            root._statusMsg = message
            root._statusType = "error"
            root._statusVisible = true
            statusHideTimer.stop()
        }
    }

    Timer {
        id: statusHideTimer
        interval: 3000
        repeat: false
        onTriggered: root._statusVisible = false
    }

    Rectangle {
        visible: root._statusVisible
        Layout.fillWidth: true
        implicitHeight: statusBarRow.implicitHeight + 16
        radius: Appearance.rounding.small
        color: root._statusType === "error"
            ? ColorUtils.transparentize(Appearance.colors.colError, 0.82)
            : root._statusType === "removed"
            ? ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.7)
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
        border.width: 1
        border.color: root._statusType === "error"
            ? ColorUtils.transparentize(Appearance.colors.colError, 0.45)
            : root._statusType === "removed"
            ? ColorUtils.transparentize(Appearance.colors.colSubtext, 0.55)
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)

        RowLayout {
            id: statusBarRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 12
                rightMargin: 8
            }
            spacing: 8

            MaterialSymbol {
                text: root._statusType === "error" ? "error"
                    : root._statusType === "removed" ? "remove_circle"
                    : "check_circle"
                iconSize: Appearance.font.pixelSize.normal
                color: root._statusType === "error" ? Appearance.colors.colError
                    : root._statusType === "removed" ? Appearance.colors.colSubtext
                    : Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: root._statusMsg
                font.pixelSize: Appearance.font.pixelSize.small
                color: root._statusType === "error" ? Appearance.colors.colError
                    : root._statusType === "removed" ? Appearance.colors.colOnLayer1
                    : Appearance.colors.colPrimary
                wrapMode: Text.WordWrap
            }

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                releaseAction: () => { root._statusVisible = false }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: NiriKeybinds.loaded ? "check_circle" : "info"
        title: Translation.tr("Keybind source")
        sectionTabsIncludeInTabBar: false
        collapsible: false

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: root.keybindConfigPath.length > 0
                    ? root.keybindConfigPath
                    : Translation.tr("Could not parse keybind config, showing defaults")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WrapAnywhere
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "keyboard"
                mainText: Translation.tr("See all keybinds")
                releaseAction: root.openCheatsheet

                StyledToolTip {
                    text: Translation.tr("Opens the same shortcuts menu as Mod+/")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.canEdit
        Layout.fillWidth: true
        expanded: true
        icon: "add_circle"
        title: Translation.tr("Add keybind")
        sectionTabGroup: Translation.tr("Editor")
        sectionTabGroupIcon: "add_circle"
        sectionTabGroupOrder: 0

        SettingsGroup {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Key combination")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: addKeyComboField
                    Layout.fillWidth: true
                    placeholderText: "Mod+Tab"
                    enableSettingsSearch: false

                    readonly property string conflictDesc: {
                        const v = text.trim()
                        if (!v) return ""
                        const found = (NiriKeybinds.allBinds ?? []).find(b => b.key_combo === v && !b.commented)
                        return found ? (found.description ?? found.action ?? v) : ""
                    }
                }

                StyledText {
                    visible: addKeyComboField.conflictDesc !== ""
                    text: Translation.tr("Already bound to: ") + "\"" + addKeyComboField.conflictDesc + "\""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colError
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Action")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: addActionField
                    Layout.fillWidth: true
                    placeholderText: "toggle-overview"
                    enableSettingsSearch: false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Options")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                MaterialTextField {
                    id: addOptionsField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. repeat=false")
                    enableSettingsSearch: false
                }
            }

            RowLayout {
                spacing: 8

                DialogButton {
                    buttonText: Translation.tr("Add")
                    releaseAction: () => {
                        const combo = addKeyComboField.text.trim()
                        const action = addActionField.text.trim()
                        if (combo.length > 0 && action.length > 0) {
                            NiriKeybinds.setBind(combo, action, addOptionsField.text.trim())
                            addKeyComboField.text = ""
                            addActionField.text = ""
                            addOptionsField.text = ""
                        }
                    }
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    releaseAction: () => {
                        addKeyComboField.text = ""
                        addActionField.text = ""
                        addOptionsField.text = ""
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 20 }
}
