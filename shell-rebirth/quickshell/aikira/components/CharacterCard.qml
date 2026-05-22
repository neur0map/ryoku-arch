import QtQuick
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root
    height: 56

    property var character: null
    property bool selected: false
    signal clicked()
    signal editClicked()

    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: 10
        color: selected
            ? ColorsModule.Colors.primary_container
            : (hover.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent")

        Behavior on color { ColorAnimation { duration: 130 } }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 10

            // Avatar circle
            Rectangle {
                width: 34; height: 34
                radius: 17
                color: selected
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.surface_container_highest

                Text {
                    anchors.centerIn: parent
                    text: character ? character.name.charAt(0).toUpperCase() : "?"
                    font { pixelSize: 14; weight: Font.Medium }
                    color: selected
                        ? ColorsModule.Colors.on_primary
                        : ColorsModule.Colors.on_surface_variant
                }
            }

            // Name + description
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: character ? character.name : ""
                    font { pixelSize: 13; weight: Font.Medium }
                    color: selected
                        ? ColorsModule.Colors.on_primary_container
                        : ColorsModule.Colors.on_surface
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: character && character.personality ? character.personality.split(".")[0] : ""
                    font.pixelSize: 10
                    color: ColorsModule.Colors.on_surface_variant
                    opacity: 0.7
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Edit button — only on hover
            Rectangle {
                width: 26; height: 26; radius: 7
                visible: hover.containsMouse
                color: editHov.containsMouse
                    ? ColorsModule.Colors.surface_container_highest : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "✎"; font.pixelSize: 12
                    color: ColorsModule.Colors.on_surface_variant
                }

                MouseArea {
                    id: editHov
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => { mouse.accepted = true; root.editClicked() }
                }
            }
        }
    }
}
