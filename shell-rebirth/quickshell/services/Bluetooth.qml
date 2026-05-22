pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root
    readonly property BluetoothAdapter defaultAdapter: Bluetooth.defaultAdapter
    readonly property list<BluetoothDevice> devices: defaultAdapter?.devices?.values ?? []
    readonly property BluetoothDevice activeDevice: devices.find(d => d.connected) ?? null
    readonly property string icon: {
        if (!defaultAdapter?.enabled) {
            return "bluetooth_disabled"
        }

        if (activeDevice) {
            return "bluetooth_connected"
        }

        return defaultAdapter.discovering ? "bluetooth_searching" : "bluetooth"
    }
}