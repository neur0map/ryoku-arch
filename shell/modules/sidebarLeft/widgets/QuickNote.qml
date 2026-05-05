pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: card.implicitHeight

    property bool editing: false
    property string draft: ""

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (!GlobalStates.sidebarLeftOpen && root.editing) {
                root.editing = false
                textArea.focus = false
            }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 16
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.ryokuEverywhere ? Appearance.ryoku.roundingNormal
            : Appearance.rounding.normal
        color: "transparent"

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "edit_note"
                    iconSize: 16
                    color: Appearance.ryokuEverywhere ? Appearance.ryoku.colText : Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: Translation.tr("Quick Note")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.ryokuEverywhere ? Appearance.ryoku.colText : Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitWidth: 24; implicitHeight: 24
                    buttonRadius: Appearance.ryokuEverywhere ? Appearance.ryoku.roundingSmall : Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                    opacity: Notepad.text.trim() !== "" ? 1 : 0
                    visible: opacity > 0
                    onClicked: Notepad.setTextValue("")

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete_outline"
                            iconSize: 14
                            color: Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip { text: Translation.tr("Clear") }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(120, Math.max(60, textArea.implicitHeight + 12))
                radius: Appearance.ryokuEverywhere ? Appearance.ryoku.roundingSmall : Appearance.rounding.small
                color: Appearance.ryokuEverywhere 
                    ? (root.editing ? Appearance.ryoku.colLayer2Hover : Appearance.ryoku.colLayer2)
                    : (root.editing ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
                border.width: Appearance.ryokuEverywhere ? 1 : (root.editing ? 2 : 0)
                border.color: Appearance.ryokuEverywhere ? Appearance.ryoku.colBorder : Appearance.colors.colPrimary

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentHeight: textArea.implicitHeight
                    clip: true

                    TextArea {
                        id: textArea
                        width: parent.width
                        text: root.editing ? root.draft : Notepad.text
                        placeholderText: Translation.tr("Type something...")
                        renderType: Text.NativeRendering
                        wrapMode: TextEdit.Wrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: Appearance.ryokuEverywhere ? Appearance.ryoku.colText : Appearance.colors.colOnLayer2
                        placeholderTextColor: Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary : Appearance.colors.colOutline
                        background: null
                        padding: 0

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.draft = Notepad.text
                                root.editing = true
                            }
                        }

                        onTextChanged: {
                            if (root.editing) root.draft = text
                        }

                        Keys.onEscapePressed: {
                            root.editing = false
                            focus = false
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return && event.modifiers & Qt.ControlModifier) {
                                Notepad.setTextValue(root.draft)
                                root.editing = false
                                focus = false
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                opacity: root.editing ? 1 : 0
                visible: opacity > 0
                spacing: 4

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                StyledText {
                    text: root.draft.length > 0 ? `${root.draft.length} ${Translation.tr("chars")}` : Translation.tr("Ctrl+Enter to save")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary : Appearance.colors.colOutline
                }

                Item { Layout.fillWidth: true }

                // Cancel button
                RippleButton {
                    implicitWidth: 24; implicitHeight: 24
                    buttonRadius: Appearance.ryokuEverywhere ? Appearance.ryoku.roundingSmall : Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                    onClicked: {
                        root.draft = Notepad.text
                        root.editing = false
                        textArea.focus = false
                    }

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 14
                            color: Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip { text: Translation.tr("Cancel") }
                }

                // Save button
                RippleButton {
                    implicitWidth: saveRow.implicitWidth + 12
                    implicitHeight: 24
                    buttonRadius: Appearance.ryokuEverywhere ? Appearance.ryoku.roundingSmall : Appearance.rounding.small
                    colBackground: Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary : Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimaryHover : Appearance.colors.colPrimaryHover
                    colRipple: Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimaryActive : Appearance.colors.colPrimaryActive
                    onClicked: {
                        Notepad.setTextValue(root.draft)
                        root.editing = false
                        textArea.focus = false
                    }

                    contentItem: RowLayout {
                        id: saveRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "check"
                            iconSize: 12
                            color: Appearance.ryokuEverywhere ? Appearance.ryoku.colOnPrimary : Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            text: Translation.tr("Save")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.ryokuEverywhere ? Appearance.ryoku.colOnPrimary : Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }
}
