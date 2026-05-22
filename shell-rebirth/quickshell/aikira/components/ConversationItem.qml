import QtQuick
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root
    height: 36

    property var conversation: null
    property bool selected: false
    signal clicked()
    signal deleteClicked()

    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: 7
        color: selected
            ? ColorsModule.Colors.secondary_container
            : (area.containsMouse ? ColorsModule.Colors.surface_container : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
            spacing: 6

            Text {
                text: "›"
                font.pixelSize: 14
                color: selected
                    ? ColorsModule.Colors.on_secondary_container
                    : ColorsModule.Colors.on_surface_variant
                opacity: selected ? 1 : 0.5
            }

            Text {
                Layout.fillWidth: true
                text: conversation ? conversation.title : ""
                font { pixelSize: 12 }
                color: selected
                    ? ColorsModule.Colors.on_secondary_container
                    : ColorsModule.Colors.on_surface
                elide: Text.ElideRight
            }

            Rectangle {
                width: 22; height: 22; radius: 6
                visible: area.containsMouse
                color: delHov.containsMouse
                    ? ColorsModule.Colors.error_container : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                    color: delHov.containsMouse
                        ? ColorsModule.Colors.on_error_container
                        : ColorsModule.Colors.error
                    opacity: delHov.containsMouse ? 1 : 0.7
                }

                MouseArea {
                    id: delHov
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => { mouse.accepted = true; root.deleteClicked() }
                }
            }
        }
    }
}
