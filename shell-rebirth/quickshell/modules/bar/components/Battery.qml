import QtQuick
import qs.services as Services
import "../../../colors" as ColorsModule
import qs.Core
Rectangle {
    radius: 13
    color: ColorsModule.Colors.surface_container
    implicitHeight: 28
    implicitWidth: battery.implicitWidth + 16

    Text {
        id: battery
        anchors.centerIn: parent

        font.pixelSize: 17
        color: ColorsModule.Colors.on_surface

        text: batteryIcon + " " + Services.Battery.percentage + "%"
    }

    property string batteryIcon: {
        const p = Services.Battery.percentage

        if (Services.Battery.charging)
            return Icons.batteryCharging

        if (p >= 95) return Icons.battery100
        if (p >= 85) return Icons.battery90
        if (p >= 75) return Icons.battery80
        if (p >= 65) return Icons.battery70
        if (p >= 55) return Icons.battery60
        if (p >= 45) return Icons.battery50
        if (p >= 35) return Icons.battery40
        if (p >= 25) return Icons.battery30
        if (p >= 15) return Icons.battery20
        if (p >= 5)  return Icons.battery10

        return Icons.battery0
    }
}
