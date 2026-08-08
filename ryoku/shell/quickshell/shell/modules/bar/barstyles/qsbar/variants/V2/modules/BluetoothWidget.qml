import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root
    readonly property color contentColor: root.widgetContentColor("G15", root.ink)

    property bool btOn:       false
    property bool connected:  false
    property int  numConnected: 0
    // Whether a Bluetooth controller physically exists (see btProc). Drives the
    // auto-show below so the pill only ever appears on hardware it can control.
    property bool hasAdapter: false

    readonly property string iconN: !btOn
        ? "bluetooth_disabled"
        : (connected ? "bluetooth_connected" : "bluetooth")

    readonly property string tooltipText: connected
        ? "Bluetooth · " + numConnected + " connected"
        : (btOn ? "Bluetooth on" : "Bluetooth off")

    // Show whenever a controller is present, even if the user never enabled the
    // pill via modBluetooth -- mirrors NetworkWidget staying visible on Wi-Fi. This
    // guarantees a working entry point to the Bluetooth panel on every machine
    // that has Bluetooth, while machines with no adapter keep a clean bar.
    readonly property bool shown: root.modBluetooth || hasAdapter
    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: IconMap.icon(rootMod.iconN)
            color: rootMod.connected
                ? (root.widgetHasFill("G15") ? rootMod.contentColor : root.seal)
                : Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, rootMod.btOn ? 0.7 : 0.3)
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.connected && !root.iconOnly("G15")
            text: String(rootMod.numConnected)
            color: root.widgetHasFill("G15") ? rootMod.contentColor : root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    Process {
        id: btProc
        command: ["bash", "-c",
            "SHOW=$(bluetoothctl show 2>/dev/null); " +
            "if [ -z \"$SHOW\" ]; then echo NONE; " +
            "elif printf '%s' \"$SHOW\" | grep -q 'Powered: yes'; then " +
            "  COUNT=$(bluetoothctl devices Connected 2>/dev/null | wc -l); " +
            "  printf 'ON\\t%s\\n' \"$COUNT\"; " +
            "else echo OFF; fi"
        ]
        running: false
        stdout: SplitParser {
            onRead: function(line) { btProc.result = line.trim() }
        }
        onExited: {
            var r = btProc.result
            if (r === "NONE" || r === "") {
                rootMod.hasAdapter = false; rootMod.btOn = false
                rootMod.connected = false; rootMod.numConnected = 0
            } else if (r === "OFF") {
                rootMod.hasAdapter = true; rootMod.btOn = false
                rootMod.connected = false; rootMod.numConnected = 0
            } else if (r.startsWith("ON\t")) {
                rootMod.hasAdapter = true; rootMod.btOn = true
                var count = parseInt(r.split("\t")[1]) || 0
                rootMod.numConnected = count
                rootMod.connected = count > 0
            }
            btProc.result = ""
        }
        property string result: ""
    }

    // Poll fast while the pill is shown or the panel is open; slowly otherwise so
    // an adapter added later (e.g. a USB dongle) still surfaces the pill without a
    // shell reload. Always running so the initial detection happens even while hidden.
    Timer {
        interval: rootMod.shown ? 5000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { btProc.result = ""; btProc.running = false; btProc.running = true }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process { id: clickRunner; command: ["bash", "-c", root.launchBtCmd] }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) { clickRunner.running = false; clickRunner.running = true }
            else root.bluetoothVisible = !root.bluetoothVisible
        }
    }
}
