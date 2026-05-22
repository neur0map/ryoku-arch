import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.services as Services
import "../../../colors" as ColorsModule

Rectangle {
    radius: 13
    color: ColorsModule.Colors.surface_container
    implicitHeight: 28
    z: 100

    implicitWidth: Math.min(label.implicitWidth + 20, 200)

    clip: true

    MouseArea {
        anchors.fill: parent
        onClicked: toggleProc.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent

        text: Icons.bluetooth  + " " + bluetoothLabel
        color: ColorsModule.Colors.on_surface

        elide: Text.ElideRight
        maximumLineCount: 1
        font.pixelSize: 17
    }

    property string bluetoothLabel: {
        const adapter = Services.Bluetooth.defaultAdapter
        const device = Services.Bluetooth.activeDevice

        if (!adapter?.enabled)
        return "Off"

        if (device)
            return device.name

        return "Bluetooth"
    }

    Process {
        id: toggleProc
        command: ["qs", "ipc", "call", "networkPanel", "changeVisible", "bluetooth"]
    }
}
