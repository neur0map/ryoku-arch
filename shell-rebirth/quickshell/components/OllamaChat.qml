import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services
import "../colors" as ColorsModule

Item {
    id: root
    width:  520
    height: 680
    focus: true
    anchors.centerIn: parent
    property var colors: ColorsModule.Colors
    visible: false

    property var    history:       []
    property string selectedModel: ""
    property string _streamingBuffer: ""

    QtObject {
        id: theme
        readonly property color bg:           colors.background
        readonly property color surface:      colors.surface
        readonly property color surfaceHigh:  colors.surface_container_high
        readonly property color border:       colors.outline_variant
        readonly property color accent:       colors.primary
        readonly property color accentDim:    colors.primary_container
        readonly property color textPrimary:  colors.on_surface
        readonly property color textMuted:    colors.on_surface_variant
        readonly property color userBubble:   colors.surface_container
        readonly property color aiBubble:     colors.surface_container_low
        readonly property color error:        colors.error
        readonly property int   radius:       14
        readonly property int   bubbleRadius: 16
        readonly property string fontMono:    "JetBrains Mono, monospace"
        readonly property string fontSans:    "Inter, Noto Sans, sans-serif"
    }

    Connections {
        target: OllamaService

        function onModelsLoaded(models) {
            modelCombo.currentIndex = 0
            if (models.length > 0)
                root.selectedModel = models[0].name
        }

        function onTokenReceived(token) {
            // Append to the last AI bubble (the pending one)
            root._streamingBuffer += token
            if (msgModel.count > 0) {
                const last = msgModel.get(msgModel.count - 1)
                if (last.role === "assistant") {
                    msgModel.setProperty(msgModel.count - 1, "content", root._streamingBuffer)
                }
            }
            // Auto-scroll
            Qt.callLater(() => { msgList.positionViewAtEnd() })
        }

        function onResponseFinished(full) {
            // Finalise history
            root.history = root.history.concat([{ role: "assistant", content: full }])
            root._streamingBuffer = ""
            sendBtn.enabled = true
            userInput.enabled = true
            userInput.forceActiveFocus()
        }

        function onErrorOccurred(message) {
            msgModel.append({ role: "error", content: "⚠ " + message })
            root._streamingBuffer = ""
            sendBtn.enabled = true
            userInput.enabled = true
            Qt.callLater(() => { msgList.positionViewAtEnd() })
        }
    }

    ListModel { id: msgModel }

    Rectangle {
        anchors.fill: parent
        color:        theme.bg
        radius:       theme.radius
        border.color: theme.border
        border.width: 1
        clip:         true

        layer.enabled: true
        layer.effect:  MultiEffect {
            shadowEnabled: true
            shadowColor:   "#80000000"
            shadowVerticalOffset:   8
            shadowHorizontalOffset: 0
            shadowBlur:    0.6
        }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 0
            spacing:         0

            Rectangle {
                Layout.fillWidth: true
                height:           52
                color:            theme.surface
                radius:           theme.radius

                Rectangle {
                    anchors.bottom: parent.bottom
                    width:  parent.width
                    height: theme.radius
                    color:  parent.color
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                    spacing: 10

                    Rectangle {
                        id:     indicatorDot
                        width:  8; height: 8; radius: 4
                        color: OllamaService.streaming ? theme.accent : theme.textMuted

                        SequentialAnimation on opacity {
                            running: OllamaService.streaming
                            loops:   Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            onRunningChanged: if (!running) indicatorDot.opacity = 1
                        }
                    }

                    Text {
                        text:  "ollama"
                        color: theme.textPrimary
                        font { family: theme.fontMono; pixelSize: 15; weight: Font.DemiBold }
                    }

                    Text {
                        text:  "/"
                        color: theme.textMuted
                        font { family: theme.fontMono; pixelSize: 15 }
                    }

                    ComboBox {
                        id:    modelCombo
                        model: OllamaService.models.map(m => m.name)

                        Layout.fillWidth: true
                        implicitHeight:   32

                        onCurrentTextChanged: root.selectedModel = currentText

                        contentItem: Text {
                            leftPadding: 8
                            text:        modelCombo.displayText
                            color:       theme.accent
                            font { family: theme.fontMono; pixelSize: 13 }
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            color:  theme.surfaceHigh
                            radius: 6
                            border { color: theme.border; width: 1 }
                        }

                        popup: Popup {
                            y:      modelCombo.height + 4
                            width:  modelCombo.width
                            padding: 4

                            background: Rectangle {
                                color:  theme.surface
                                radius: 8
                                border { color: theme.border; width: 1 }
                            }

                            contentItem: ListView {
                                implicitHeight: contentHeight
                                model:          modelCombo.delegateModel
                                clip:           true
                            }
                        }

                        delegate: ItemDelegate {
                            width: modelCombo.width
                            contentItem: Text {
                                text:  modelData
                                color: highlighted ? theme.accent : theme.textPrimary
                                font { family: theme.fontMono; pixelSize: 13 }
                                leftPadding: 8
                                verticalAlignment: Text.AlignVCenter
                            }
                            highlighted:  modelCombo.highlightedIndex === index
                            background:   Rectangle {
                                color: highlighted ? theme.surfaceHigh : "transparent"
                                radius: 5
                            }
                        }
                    }

                    RoundButton {
                        implicitWidth:  30
                        implicitHeight: 30
                        text: "↻"
                        font { family: theme.fontMono; pixelSize: 14 }
                        onClicked: OllamaService.fetchModels()
                        ToolTip.visible: hovered
                        ToolTip.text:   "Refresh models"
                        background: Rectangle {
                            color:  parent.hovered ? theme.surfaceHigh : "transparent"
                            radius: 15
                        }
                        contentItem: Text {
                            text:             parent.text
                            color:            theme.textMuted
                            font:             parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                    }

                    // Clear conversation button
                    RoundButton {
                        implicitWidth:  30
                        implicitHeight: 30
                        text: "⌫"
                        font { family: theme.fontSans; pixelSize: 13 }
                        onClicked: {
                            msgModel.clear()
                            root.history = []
                        }
                        ToolTip.visible: hovered
                        ToolTip.text:   "Clear conversation"
                        background: Rectangle {
                            color:  parent.hovered ? theme.surfaceHigh : "transparent"
                            radius: 15
                        }
                        contentItem: Text {
                            text:             parent.text
                            color:            theme.textMuted
                            font:             parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                    }
                }
            }

            ListView {
                id:               msgList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip:             true
                spacing:          8

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius:        2
                        color:         theme.border
                    }
                    background: Rectangle { color: "transparent" }
                }

                header: Item { height: 12 }
                footer: Item { height: 8  }

                model: msgModel

                Text {
                    anchors.centerIn: parent
                    visible: msgModel.count === 0
                    text: OllamaService.models.length === 0
                        ? "Loading models…"
                        : "Select a model and start chatting."
                    color: theme.textMuted
                    font { family: theme.fontSans; pixelSize: 13 }
                }

                delegate: Item {
                    id:    bubbleItem
                    width: msgList.width
                    height: bubbleRow.implicitHeight + 16

                    readonly property bool isUser:  role === "user"
                    readonly property bool isError: role === "error"

                    Row {
                        id:           bubbleRow
                        anchors {
                            left:        isUser ? undefined : parent.left
                            right:       isUser ? parent.right : undefined
                            leftMargin:  12
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        layoutDirection: isUser ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: 8

                        // Avatar chip
                        Rectangle {
                            width:  26; height: 26; radius: 13
                            color:  bubbleItem.isUser ? theme.accentDim : theme.surfaceHigh
                            border { color: theme.border; width: 1 }
                            anchors.top: parent.top
                            anchors.topMargin: 4

                            Text {
                                anchors.centerIn: parent
                                text:  bubbleItem.isUser ? "U" : bubbleItem.isError ? "!" : "AI"
                                color: bubbleItem.isError ? theme.error : theme.accent
                                font { family: theme.fontMono; pixelSize: 9; weight: Font.Bold }
                            }
                        }

                        Rectangle {
                            width: Math.min(bubbleText.implicitWidth + 24,
                                msgList.width - 70)
                            height: bubbleText.implicitHeight + 20
                            color: bubbleItem.isError ? "#1a0e0e"
                                : bubbleItem.isUser  ? theme.userBubble
                                    :                     theme.aiBubble
                            radius: theme.bubbleRadius
                            border {
                                color: bubbleItem.isError ? theme.error
                                    : bubbleItem.isUser  ? theme.accentDim
                                        :                     theme.border
                                width: 1
                            }

                            TextEdit {
                                id:      bubbleText
                                anchors { fill: parent; margins: 12 }
                                text:    content
                                color:   bubbleItem.isError ? theme.error : theme.textPrimary
                                font {
                                    family:  theme.fontSans
                                    pixelSize: 13
                                }
                                wrapMode:        Text.WordWrap
                                readOnly:        true
                                selectByMouse:   true
                                selectByKeyboard: true
                                selectedTextColor:       theme.bg
                                selectionColor:          theme.accent
                            }
                        }
                    }
                }

                onCountChanged: Qt.callLater(() => { positionViewAtEnd() })
            }

            Item {
                Layout.fillWidth: true
                height: OllamaService.streaming ? 28 : 0
                visible: OllamaService.streaming
                Behavior on height { NumberAnimation { duration: 150 } }

                Row {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 5

                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: 6; height: 6; radius: 3
                            color: theme.accent

                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                running: OllamaService.streaming
                                NumberAnimation { to: -4; duration: 300; easing.type: Easing.InOutSine; }
                                NumberAnimation { to:  0; duration: 300; easing.type: Easing.InOutSine; }
                                PauseAnimation  { duration: index * 100 }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height:           inputRow.implicitHeight + 20
                color:            theme.surface

                Rectangle {
                    anchors.top: parent.top
                    width:  parent.width
                    height: theme.radius
                    color:  parent.color
                }

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1
                    color:  theme.border
                }

                RowLayout {
                    id:      inputRow
                    anchors { fill: parent; margins: 12 }
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: Math.min(Math.max(userInput.implicitHeight + 16, 40), 120)
                        color:  theme.surfaceHigh
                        radius: 10
                        border { color: userInput.activeFocus ? theme.accent : theme.border; width: 1 }

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TapHandler {                          // ← add this block
                            onTapped: userInput.forceActiveFocus()
                        }

                        Flickable {
                            anchors { fill: parent; margins: 8 }
                            contentWidth:  userInput.implicitWidth
                            contentHeight: userInput.implicitHeight
                            clip:          true
                            interactive:   false

                            TextEdit {
                                id:              userInput
                                width:           parent.width
                                color:           theme.textPrimary
                                font { family: theme.fontSans; pixelSize: 13 }
                                wrapMode:        TextEdit.Wrap
                                selectByMouse:   true
                                selectedTextColor:    theme.bg
                                selectionColor:       theme.accent

                                Keys.onReturnPressed: event => {
                                    if (event.modifiers & Qt.ShiftModifier) {
                                        // Shift+Enter = newline
                                        userInput.insert(userInput.cursorPosition, "\n")
                                    } else {
                                        _sendMessage()
                                    }
                                }

                                Text {
                                    anchors.fill:      parent
                                    text:              "Message… (Enter to send, Shift+Enter for newline)"
                                    color:             theme.textMuted
                                    font:              parent.font
                                    visible:           parent.text === "" && !parent.activeFocus
                                    verticalAlignment: Text.AlignTop
                                    elide:             Text.ElideRight
                                }
                            }
                        }
                    }

                    Rectangle {
                        width:  40; height: 40; radius: 10
                        color: sendBtn.enabled
                            ? (sendBtnArea.containsMouse ? Qt.lighter(theme.accent, 1.15) : theme.accent)
                            : theme.surfaceHigh
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text:  OllamaService.streaming ? "■" : "↑"
                            color: sendBtn.enabled ? "white" : theme.textMuted
                            font { family: theme.fontMono; pixelSize: 16; weight: Font.Bold }
                        }

                        Button {
                            id:             sendBtn
                            anchors.fill:   parent
                            background:     null
                            contentItem:    null
                            enabled:        root.selectedModel !== "" &&
                                (userInput.text.trim() !== "" || OllamaService.streaming)

                            onClicked: {
                                if (OllamaService.streaming) {
                                    OllamaService.cancelStreaming()
                                } else {
                                    _sendMessage()
                                }
                            }
                        }

                        MouseArea {
                            id:             sendBtnArea
                            anchors.fill:   parent
                            hoverEnabled:   true
                            onClicked:      sendBtn.clicked()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        OllamaService.fetchModels()
        userInput.forceActiveFocus()
    }

    function _sendMessage() {
        const text = userInput.text.trim()
        if (text === "" || root.selectedModel === "") return
        if (OllamaService.streaming) return

        msgModel.append({ role: "user", content: text })
        root.history = root.history.concat([{ role: "user", content: text }])
        userInput.text = ""

        root._streamingBuffer = ""
        msgModel.append({ role: "assistant", content: "" })

        sendBtn.enabled   = false
        userInput.enabled = false

        OllamaService.sendMessage(
            root.selectedModel,
            root.history.slice(0, root.history.length - 1),
            text
        )
    }
}
