import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root

    Rectangle { anchors.fill: parent; color: ColorsModule.Colors.background }

    Rectangle {
        id: cbHead
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 56
        color: ColorsModule.Colors.surface_container

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
            spacing: 12

            ColumnLayout {
                spacing: 2
                Text {
                    text: "Characters"
                    font { pixelSize: 15; weight: Font.Medium; letterSpacing: 0.3 }
                    color: ColorsModule.Colors.on_surface
                }
                Text {
                    text: "Click a card to start chatting"
                    font.pixelSize: 10
                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.45
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 140; height: 32; radius: 16
                color: newCharHov.containsMouse
                    ? ColorsModule.Colors.primary : ColorsModule.Colors.primary_container
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 5
                    Text {
                        text: "＋"
                        font.pixelSize: 13
                        color: newCharHov.containsMouse
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_primary_container
                    }
                    Text {
                        text: "new character"
                        font { pixelSize: 12; weight: Font.Medium }
                        color: newCharHov.containsMouse
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_primary_container
                    }
                }

                MouseArea {
                    id: newCharHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { AppState.editingCharacter = null; AppState.view = "character_editor" }
                }
            }
        }
    }

    Item {
        anchors { top: cbHead.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: !AppState.characters || AppState.characters.length === 0

        ColumnLayout {
            anchors.centerIn: parent; spacing: 10
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "✦"; font.pixelSize: 48
                color: ColorsModule.Colors.primary; opacity: 0.15
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "no characters yet"
                font { pixelSize: 14; letterSpacing: 0.3 }
                color: ColorsModule.Colors.on_surface_variant; opacity: 0.45
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "create a character to start chatting"
                font.pixelSize: 11
                color: ColorsModule.Colors.on_surface_variant; opacity: 0.3
            }
        }
    }

    // ── Character grid ─────────────────────────────────────────────────────
    GridView {
        id: charGrid
        anchors { top: cbHead.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        cellWidth: 300; cellHeight: 170
        clip: true
        visible: AppState.characters && AppState.characters.length > 0
        model: AppState.characters

        delegate: Item {
            width: 292; height: 162

            property bool isSelected: AppState.activeCharacter && AppState.activeCharacter.id === modelData.id
            property int  chatCount:  -1   // -1 = loading

            HoverHandler { id: cardHover }

            Component.onCompleted: {
                Api.loadConversations(modelData.id, function(err, data) {
                    chatCount = (err || !data) ? 0 : data.length
                })
            }

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: 14
                clip: true
                color: isSelected
                    ? ColorsModule.Colors.secondary_container
                    : (cardHover.hovered ? ColorsModule.Colors.surface_container_high : ColorsModule.Colors.surface_container)
                Behavior on color { ColorAnimation { duration: 130 } }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 42; height: 42; radius: 21
                            color: isSelected
                                ? ColorsModule.Colors.primary
                                : ColorsModule.Colors.primary_container

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name.charAt(0).toUpperCase()
                                font { pixelSize: 18; weight: Font.Medium }
                                color: isSelected
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font { pixelSize: 14; weight: Font.Medium }
                                color: ColorsModule.Colors.on_surface
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.personality
                                    ? modelData.personality.split(".")[0]
                                    : (modelData.description ? modelData.description : "")
                                font.pixelSize: 11
                                color: ColorsModule.Colors.on_surface_variant; opacity: 0.6
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                visible: text.length > 0
                            }
                        }

                        Row {
                            spacing: 4
                            visible: cardHover.hovered

                            Rectangle {
                                width: 28; height: 28; radius: 8
                                color: editHov.containsMouse
                                    ? ColorsModule.Colors.surface_container_highest : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent; text: "✎"; font.pixelSize: 13
                                    color: ColorsModule.Colors.on_surface_variant
                                }
                                MouseArea {
                                    id: editHov; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        AppState.editingCharacter = modelData
                                        AppState.view = "character_editor"
                                    }
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 8
                                color: delHov.containsMouse
                                    ? ColorsModule.Colors.error_container : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent; text: "×"; font.pixelSize: 16
                                    color: delHov.containsMouse
                                        ? ColorsModule.Colors.on_error_container
                                        : ColorsModule.Colors.error
                                }
                                MouseArea {
                                    id: delHov; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        deleteConfirm.targetId   = modelData.id
                                        deleteConfirm.targetName = modelData.name
                                        deleteConfirm.visible    = true
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            height: 22; radius: 11
                            width: chatBadgeRow.implicitWidth + 16
                            color: ColorsModule.Colors.surface_container_highest

                            Row {
                                id: chatBadgeRow
                                anchors.centerIn: parent; spacing: 4
                                Text {
                                    text: "💬"; font.pixelSize: 10
                                    visible: chatCount >= 0
                                }
                                Text {
                                    text: chatCount < 0 ? "…" : (chatCount + " chat" + (chatCount !== 1 ? "s" : ""))
                                    font { pixelSize: 11; weight: Font.Medium }
                                    color: ColorsModule.Colors.on_surface_variant; opacity: 0.7
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 30; radius: 15
                            width: startTxt.implicitWidth + 24
                            color: startHov.containsMouse
                                ? ColorsModule.Colors.primary
                                : ColorsModule.Colors.primary_container
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: startTxt; anchors.centerIn: parent
                                text: "start chat"
                                font { pixelSize: 12; weight: Font.Medium }
                                color: startHov.containsMouse
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_primary_container
                            }

                            MouseArea {
                                id: startHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    mouse.accepted = true
                                    AppState.selectCharacter(modelData)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent; z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.selectCharacter(modelData)
                }
            }
        }
    }

    Rectangle {
        id: deleteConfirm; visible: false
        property string targetId:   ""
        property string targetName: ""
        anchors.fill: parent; color: "#99000000"; z: 10

        Rectangle {
            anchors.centerIn: parent; width: 340; height: 164; radius: 16
            color: ColorsModule.Colors.surface_container_highest
            Column {
                anchors { fill: parent; margins: 24 }
                spacing: 12
                Text {
                    text: "Delete "+ deleteConfirm.targetName + "?"
                    font { pixelSize: 15; weight: Font.Medium }
                    color: ColorsModule.Colors.on_surface
                }
                Text {
                    text: "All conversations with this character will be permanently deleted."
                    font.pixelSize: 12; color: ColorsModule.Colors.on_surface_variant; opacity: 0.7
                    wrapMode: Text.WordWrap; width: parent.width
                }
                Item { height: 4 }
                Row {
                    spacing: 10; anchors.right: parent.right
                    Rectangle {
                        width: 72; height: 32; radius: 16
                        color: dcCxHov.containsMouse
                            ? ColorsModule.Colors.surface_container_high : "transparent"
                        Text { anchors.centerIn: parent; text: "cancel"; font.pixelSize: 13
                            color: ColorsModule.Colors.on_surface_variant }
                        MouseArea { id: dcCxHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: deleteConfirm.visible = false }
                    }
                    Rectangle {
                        width: 80; height: 32; radius: 16
                        color: ColorsModule.Colors.error_container
                        Text { anchors.centerIn: parent; text: "delete"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: ColorsModule.Colors.on_error_container }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const id = deleteConfirm.targetId
                                Api.deleteCharacter(id, function(err) {
                                    if (err) return
                                    AppState.refreshCharacters()
                                    if (AppState.activeCharacter && AppState.activeCharacter.id === id) {
                                        AppState.activeCharacter = null
                                        AppState.messages = []
                                        AppState.conversations = []
                                    }
                                    deleteConfirm.visible = false
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
