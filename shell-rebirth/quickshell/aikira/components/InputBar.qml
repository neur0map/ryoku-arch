import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root
    height: 56

    property bool enabled: true
    signal send(string text)

    Rectangle {
        anchors.fill: parent
        color: ColorsModule.Colors.surface_container

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: ColorsModule.Colors.outline_variant
            opacity: 0.4
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 18
                clip: true
                color: ColorsModule.Colors.surface_container_highest
                border {
                    width: inputField.activeFocus ? 1 : 0
                    color: ColorsModule.Colors.primary
                }

                Behavior on border.width { NumberAnimation { duration: 100 } }

                Text {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
                    text: root.enabled ? "type a message…" : "waiting for response…"
                    color: ColorsModule.Colors.on_surface_variant
                    opacity: 0.4
                    font { pixelSize: 13; family: "monospace" }
                    visible: inputField.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }

                Flickable {
                    id: inputFlickable
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
                    contentHeight: inputField.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: {
                        if (contentHeight > height) contentY = contentHeight - height
                    }

                    TextEdit {
                        id: inputField
                        width: inputFlickable.width
                        color: ColorsModule.Colors.on_surface
                        font { pixelSize: 13; family: "monospace" }
                        wrapMode: TextEdit.Wrap
                        enabled: root.enabled
                        selectByMouse: true

                        // Enter = send, Shift+Enter = newline
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                event.accepted = true
                                doSend()
                            }
                        }
                    }
                }
            }

            // Send button
            Rectangle {
                width: 36; height: 36; radius: 18
                color: root.enabled && inputField.text.trim().length > 0
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.surface_container_highest

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: AppState.streaming ? "◼" : "↑"
                    font { pixelSize: 15; weight: Font.Bold }
                    color: root.enabled && inputField.text.trim().length > 0
                        ? ColorsModule.Colors.on_primary
                        : ColorsModule.Colors.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.enabled
                    onClicked: doSend()
                }
            }
        }
    }

    function doSend() {
        const t = inputField.text.trim()
        if (!t || !root.enabled) return
        inputField.text = ""
        root.send(t)
    }
}
