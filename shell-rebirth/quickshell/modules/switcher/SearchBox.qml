import QtQuick
import Quickshell
import "../../colors" as ColorsModule

Item {
    id: searchBar
    implicitWidth:  480
    implicitHeight: 44

    property var onTextChanged: null

    function reset() {
        searchInput.text = ""
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(
            Qt.color(ColorsModule.Colors.surface_container_high).r,
            Qt.color(ColorsModule.Colors.surface_container_high).g,
            Qt.color(ColorsModule.Colors.surface_container_high).b, 0.75)
        border.width: 1
        border.color: searchInput.activeFocus
            ? Qt.rgba(
                Qt.color(ColorsModule.Colors.primary).r,
                Qt.color(ColorsModule.Colors.primary).g,
                Qt.color(ColorsModule.Colors.primary).b, 0.6)
            : Qt.rgba(1, 1, 1, 0.10)

        Behavior on border.color { ColorAnimation { duration: 160 } }

        // search icon
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "⌕"
            font.pixelSize: 18
            color: Qt.rgba(
                Qt.color(ColorsModule.Colors.on_surface_variant).r,
                Qt.color(ColorsModule.Colors.on_surface_variant).g,
                Qt.color(ColorsModule.Colors.on_surface_variant).b, 0.55)
        }

        TextInput {
            id: searchInput
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: 16
            verticalAlignment: TextInput.AlignVCenter
            color: ColorsModule.Colors.on_surface
            font.pixelSize: 15
            font.weight: Font.Normal
            activeFocusOnTab: false
            selectByMouse: true
            focus: true

            onTextChanged: {
                if (searchBar.onTextChanged) searchBar.onTextChanged(text)
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                color: Qt.rgba(
                    Qt.color(ColorsModule.Colors.on_surface_variant).r,
                    Qt.color(ColorsModule.Colors.on_surface_variant).g,
                    Qt.color(ColorsModule.Colors.on_surface_variant).b, 0.45)
                font.pixelSize: 15
                text: "Search windows…"
                visible: !searchInput.text || searchInput.text.length === 0
            }
        }
    }
}
