import QtQuick
import qs.services as Services
import "../../../colors" as ColorsModule
import qs.Core

Rectangle {
    radius: 13
    color: ColorsModule.Colors.surface_container
    implicitHeight: 28
    implicitWidth: temp.implicitWidth + 16

    Text {
        id: temp
        anchors.centerIn: parent

        font.pixelSize: 17
        color: tempColor

        text: tempIcon + " " + Services.System.temp + "°C"
    }

    property int t: Services.System.temp

    property string tempIcon: {
        if (t >= 85) return Icons.fire
        if (t >= 50) return Icons.temperatureMedium
        return Icons.temperature
    }

    property color tempColor: {
        if (t >= 85) return ColorsModule.Colors.error
        if (t >= 70) return ColorsModule.Colors.on_surface
        return ColorsModule.Colors.on_surface
    }
}
