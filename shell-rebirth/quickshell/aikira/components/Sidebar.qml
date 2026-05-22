import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: ColorsModule.Colors.surface_container_low
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: ColorsModule.Colors.surface_container

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 10 }
                spacing: 4

                Text {
                    text: "aikira"
                    font { family: "monospace"; pixelSize: 14; letterSpacing: 3; weight: Font.Medium }
                    color: ColorsModule.Colors.primary
                }

                Item { Layout.fillWidth: true }

                // Proxy Manager button
                Rectangle {
                    id: pmBtn
                    width: 32; height: 32; radius: 8
                    color: AppState.view === "proxy_manager"
                        ? ColorsModule.Colors.primary_container
                        : (pmHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent")
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Text {
                        anchors.centerIn: parent; text: "⚙"; font.pixelSize: 15
                        color: AppState.view === "proxy_manager"
                            ? ColorsModule.Colors.on_primary_container
                            : ColorsModule.Colors.on_surface_variant
                    }

                    MouseArea {
                        id: pmHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.view = AppState.view === "proxy_manager" ? "chat" : "proxy_manager"
                    }

                    // Tooltip
                    Rectangle {
                        visible: pmHov.containsMouse
                        anchors { bottom: parent.top; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                        width: ttProxyText.implicitWidth + 12; height: 22; radius: 6
                        color: ColorsModule.Colors.inverse_surface
                        Text {
                            id: ttProxyText
                            anchors.centerIn: parent; text: "proxies"
                            font.pixelSize: 10; color: ColorsModule.Colors.inverse_on_surface
                        }
                    }
                }

                // Persona button
                Rectangle {
                    id: psBtn
                    width: 32; height: 32; radius: 8
                    color: AppState.view === "persona_selector"
                        ? ColorsModule.Colors.primary_container
                        : (psHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent")
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Text {
                        anchors.centerIn: parent; text: "◈"; font.pixelSize: 15
                        color: AppState.view === "persona_selector"
                            ? ColorsModule.Colors.on_primary_container
                            : ColorsModule.Colors.on_surface_variant
                    }

                    MouseArea {
                        id: psHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.view = AppState.view === "persona_selector" ? "chat" : "persona_selector"
                    }

                    // Tooltip
                    Rectangle {
                        visible: psHov.containsMouse
                        anchors { bottom: parent.top; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                        width: ttPersonaText.implicitWidth + 12; height: 22; radius: 6
                        color: ColorsModule.Colors.inverse_surface
                        Text {
                            id: ttPersonaText
                            anchors.centerIn: parent; text: "personas"
                            font.pixelSize: 10; color: ColorsModule.Colors.inverse_on_surface
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: AppState.activePersona ? 40 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 6 }
                radius: 12
                color: ColorsModule.Colors.secondary_container

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                    spacing: 6

                    Text {
                        text: "◈"; font.pixelSize: 11
                        color: ColorsModule.Colors.on_secondary_container; opacity: 0.6
                    }
                    Text {
                        Layout.fillWidth: true
                        text: AppState.activePersona ? AppState.activePersona.name : ""
                        font { pixelSize: 11; weight: Font.Medium; letterSpacing: 0.3 }
                        color: ColorsModule.Colors.on_secondary_container
                        elide: Text.ElideRight
                    }

                    // Clear persona
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: clearHov.containsMouse
                            ? ColorsModule.Colors.secondary : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "×"; font.pixelSize: 13
                            color: clearHov.containsMouse
                                ? ColorsModule.Colors.on_secondary
                                : ColorsModule.Colors.on_secondary_container
                            opacity: clearHov.containsMouse ? 1 : 0.6
                        }
                        MouseArea {
                            id: clearHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AppState.activePersona = null
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true; height: 40
            Layout.leftMargin: 10; Layout.rightMargin: 10
            Layout.topMargin: 14; Layout.bottomMargin: 4

            Rectangle {
                anchors.fill: parent; radius: 8
                color: AppState.view === "character_browser"
                    ? ColorsModule.Colors.primary_container
                    : (charBtnHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent")
                border { width: 1; color: ColorsModule.Colors.outline_variant }
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    spacing: 8
                    Text {
                        text: "✦"; font.pixelSize: 12
                        color: AppState.view === "character_browser"
                            ? ColorsModule.Colors.on_primary_container
                            : ColorsModule.Colors.primary
                    }
                    Text {
                        text: "characters"
                        font { pixelSize: 12; letterSpacing: 0.2 }
                        color: AppState.view === "character_browser"
                            ? ColorsModule.Colors.on_primary_container
                            : ColorsModule.Colors.on_surface
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: AppState.characters && AppState.characters.length > 0
                        width: charNavCount.implicitWidth + 10; height: 18; radius: 9
                        color: AppState.view === "character_browser"
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.surface_container_highest
                        Text {
                            id: charNavCount
                            anchors.centerIn: parent
                            text: AppState.characters ? String(AppState.characters.length) : "0"
                            font { pixelSize: 10; weight: Font.Medium }
                            color: AppState.view === "character_browser"
                                ? ColorsModule.Colors.on_primary
                                : ColorsModule.Colors.on_surface_variant
                        }
                    }
                }

                MouseArea {
                    id: charBtnHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.view = AppState.view === "character_browser" ? "chat" : "character_browser"
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                visible: AppState.activeCharacter !== null

                // Divider
                Rectangle {
                    Layout.fillWidth: true; height: 1
                    Layout.leftMargin: 16; Layout.rightMargin: 16
                    Layout.topMargin: 10; Layout.bottomMargin: 0
                    color: ColorsModule.Colors.outline_variant; opacity: 0.3
                }

                // Chats section header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16; Layout.rightMargin: 12
                    Layout.topMargin: 10; Layout.bottomMargin: 4
                    height: 20

                    Text {
                        text: "CHATS"
                        font { pixelSize: 10; letterSpacing: 1.8; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.55
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: AppState.conversations && AppState.conversations.length > 0
                        width: convCountText.implicitWidth + 10; height: 16; radius: 8
                        color: ColorsModule.Colors.surface_container
                        Text {
                            id: convCountText
                            anchors.centerIn: parent
                            text: AppState.conversations ? String(AppState.conversations.length) : "0"
                            font { pixelSize: 10; weight: Font.Medium }
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.5
                        }
                    }
                }

                // Conversation list
                ListView {
                    id: convList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    clip: true
                    model: AppState.conversations || []
                    spacing: 1

                    delegate: ConversationItem {
                        required property var modelData
                        width: convList.width
                        conversation: modelData
                        selected: AppState.activeConversation !== null &&
                            AppState.activeConversation !== undefined &&
                            AppState.activeConversation.id === modelData.id
                        onClicked: AppState.selectConversation(modelData)
                        onDeleteClicked: {
                            Api.deleteConversation(modelData.id, function(err) {
                                if (err) return
                                const convs = (AppState.conversations || []).filter(c => c.id !== modelData.id)
                                AppState.conversations = convs
                                if (AppState.activeConversation &&
                                    AppState.activeConversation.id === modelData.id) {
                                    AppState.activeConversation = null
                                    AppState.messages = []
                                }
                            })
                        }
                    }
                }

                // New chat button
                Item {
                    Layout.fillWidth: true; height: 44
                    Layout.leftMargin: 10; Layout.rightMargin: 10
                    Layout.topMargin: 4; Layout.bottomMargin: 10

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: newChatHov.containsMouse
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.primary_container
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text {
                                text: "＋"; font { pixelSize: 14 }
                                color: newChatHov.containsMouse
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_primary_container
                            }
                            Text {
                                text: "new chat"
                                font { pixelSize: 12; weight: Font.Medium }
                                color: newChatHov.containsMouse
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_primary_container
                            }
                        }

                        MouseArea {
                            id: newChatHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AppState.newConversation()
                        }
                    }
                }
            }
        }
    }
}
