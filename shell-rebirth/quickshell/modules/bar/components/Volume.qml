import QtQuick
import Quickshell
import Quickshell.Io
import qs.services as Services
import "../../../colors" as ColorsModule

Rectangle {
    radius: 13
    color: ColorsModule.Colors.surface_container
    implicitHeight: 28
    implicitWidth: Math.min(label.implicitWidth + 20, 160)
    clip: true

    Text {
        id: label
        anchors.centerIn: parent
        text: " " + Math.round(Services.Volume.volume*100) + "%"
        color: ColorsModule.Colors.on_surface
        elide: Text.ElideRight
        maximumLineCount: 1
        font.pixelSize: 17
    }



}