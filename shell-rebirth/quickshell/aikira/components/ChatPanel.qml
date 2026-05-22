import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root
    signal sendMessage(string text)
    signal rerollMessage()

    Item {
        anchors.fill: parent
        visible: AppState.activeCharacter === null

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "aikira"
                font { family: "monospace"; pixelSize: 36; letterSpacing: 6; weight: Font.Light }
                color: ColorsModule.Colors.primary
                opacity: 0.3
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "select a character to begin"
                font { pixelSize: 13; letterSpacing: 0.5 }
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.5
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: AppState.activeCharacter !== null

        // Header bar
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: ColorsModule.Colors.surface_container

            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                spacing: 12

                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: ColorsModule.Colors.primary_container

                    Text {
                        anchors.centerIn: parent
                        text: AppState.activeCharacter
                            ? AppState.activeCharacter.name.charAt(0).toUpperCase() : ""
                        font { pixelSize: 15; weight: Font.Medium }
                        color: ColorsModule.Colors.on_primary_container
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: AppState.activeCharacter ? AppState.activeCharacter.name : ""
                        font { pixelSize: 14; weight: Font.Medium }
                        color: ColorsModule.Colors.on_surface
                    }
                    Text {
                        text: AppState.activeConversation
                            ? AppState.activeConversation.title : "no chat selected"
                        font.pixelSize: 11
                        color: ColorsModule.Colors.on_surface_variant
                        opacity: 0.7
                    }
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 4
                    visible: AppState.streaming
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            width: 5; height: 5; radius: 3
                            color: ColorsModule.Colors.primary

                            SequentialAnimation on opacity {
                                running: AppState.streaming
                                loops: Animation.Infinite
                                PauseAnimation  { duration: index * 160 }
                                NumberAnimation { to: 0.2; duration: 380; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 380; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                // Scenario peek
                Rectangle {
                    width: 30; height: 30; radius: 8
                    visible: AppState.activeCharacter !== null &&
                        AppState.activeCharacter.scenario !== undefined &&
                        AppState.activeCharacter.scenario.length > 0
                    color: scenHov.containsMouse
                        ? ColorsModule.Colors.surface_container_high : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "◎"; font.pixelSize: 14
                        color: ColorsModule.Colors.on_surface_variant }
                    MouseArea { id: scenHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scenarioPopup.visible = !scenarioPopup.visible }
                }
            }
        }


        ListView {
            id: msgList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            topMargin: 16
            bottomMargin: 8

            model: AppState.messages || []

            // Smart auto-scroll: stick to bottom unless user scrolled up
            property bool stickToBottom: true

            onCountChanged: Qt.callLater(() => {
                stickToBottom = true
                positionViewAtEnd()
            })
            onContentHeightChanged: Qt.callLater(() => {
                if (stickToBottom) positionViewAtEnd()
            })
            onDragEnded:  stickToBottom = atYEnd
            onFlickEnded: stickToBottom = atYEnd

            delegate: MessageBubble {
                required property var modelData
                width: msgList.width
                message: modelData
                characterName: AppState.activeCharacter ? AppState.activeCharacter.name : "AI"
                personaName:   AppState.activePersona   ? AppState.activePersona.name   : "You"
                isStreaming:   modelData !== null && modelData !== undefined && modelData.id === "streaming"
                isLastAiMessage: {
                    if (!modelData || modelData.role !== "assistant" || modelData.id === "streaming") return false
                    const msgs = AppState.messages || []
                    for (let i = msgs.length - 1; i >= 0; i--) {
                        const m = msgs[i]
                        if (m && m.role === "assistant" && m.id !== "streaming") {
                            return m.id === modelData.id
                        }
                    }
                    return false
                }
                totalAlternatives: isLastAiMessage ? AppState.lastAiAlternatives.length : 1
                currentAltIndex:   isLastAiMessage ? AppState.lastAiAltIndex : 0
                onDeleteRequested: {
                    if (!AppState.activeConversation || !modelData || modelData.id === "streaming") return
                    Api.deleteMessage(AppState.activeConversation.id, modelData.id, function(err) {
                        if (err) return
                        Api.loadMessages(AppState.activeConversation.id, function(e, data) {
                            if (!e) AppState.messages = data
                        })
                    })
                }
                onRerollRequested: {
                    if (!AppState.activeConversation || AppState.streaming) return
                    root.rerollMessage()
                }
                onPrevAlternative: AppState.switchAiAlternative(AppState.lastAiAltIndex - 1)
                onNextAlternative: AppState.switchAiAlternative(AppState.lastAiAltIndex + 1)
            }
        }

        Timer {
            interval: 50
            repeat: true
            running: AppState.streaming
            onTriggered: {
                if (msgList.stickToBottom) msgList.positionViewAtEnd()
            }
        }

        // Input bar
        InputBar {
            Layout.fillWidth: true
            enabled: AppState.activeConversation !== null && !AppState.streaming
            onSend: function(text) { root.sendMessage(text) }
        }
    }

    Rectangle {
        id: scenarioPopup
        visible: false
        anchors { top: parent.top; topMargin: 60; right: parent.right; rightMargin: 16 }
        width: 320
        height: Math.min(scenText.implicitHeight + 32, 240)
        radius: 12
        color: ColorsModule.Colors.surface_container_highest
        border { width: 1; color: ColorsModule.Colors.outline_variant }
        clip: true
        z: 10

        Flickable {
            anchors { fill: parent; margins: 16 }
            contentHeight: scenText.implicitHeight
            clip: true

            Text {
                id: scenText
                width: parent.width
                text: AppState.activeCharacter ? AppState.activeCharacter.scenario : ""
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: ColorsModule.Colors.on_surface
                lineHeight: 1.5
            }
        }

        MouseArea { anchors.fill: parent; onClicked: scenarioPopup.visible = false }
    }
}
