import QtQuick
import Quickshell.Services.UPower
import "../"

// Config:
//showPercentage: bool — always show % beside icon (default: false = hover only)

Item {
    id: root

    property bool showPercentage: false

    // ── UPower data ──────────────────────────────────────────────────────────
    readonly property var  bat:      UPower.displayDevice
    readonly property real pct:      bat.ready ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: bat.ready
                                     ? (bat.state === UPowerDeviceState.Charging ||
                                        bat.state === UPowerDeviceState.PendingCharge ||
                                        bat.state === UPowerDeviceState.FullyCharged)
                                     : false
    readonly property bool full:     bat.ready
                                     ? bat.state === UPowerDeviceState.FullyCharged
                                     : false

    implicitWidth:  statusRow.implicitWidth + 16
    implicitHeight: Theme.notchHeight

    // ── Warning tracker ──────────────────────────────────────────────────────
    // warnedLevels stores which thresholds have fired this discharge cycle.
    // Resets when charging begins.
    property var warnedLevels: []

    function checkWarning() {
        if (charging) {
            warnedLevels = []
            return
        }
        var thresholds = [5, 10, 20,30]
        for (var i = 0; i < thresholds.length; i++) {
            var lvl = thresholds[i]
            if (pct <= lvl && warnedLevels.indexOf(lvl) < 0) {
                warnedLevels = warnedLevels.concat([lvl])
                warningWindow.warnLevel = lvl
                warningWindow.visible   = true
                break
            }
        }
    }

    onPctChanged:      checkWarning()
    onChargingChanged: {
        if (charging) warnedLevels = []
        checkWarning()
    }

    // ── Nerd Font icons ──────────────────────────────────────────────────────
    function staticIcon(p) {
        if (p > 90) return "󰁹"
        if (p > 80) return "󰂂"
        if (p > 70) return "󰂁"
        if (p > 60) return "󰂀"
        if (p > 50) return "󰁿"
        if (p > 40) return "󰁾"
        if (p > 30) return "󰁽"
        if (p > 20) return "󰁼"
        if (p > 10) return "󰁻"
        return "󰁺"
    }

    // Charging animation frames (low → full)
    readonly property var chargeFrames: ["󰢜","󰂆","󰂇","󰂈","󰂉","󰂊","󰂋","󰂅"]
    property int chargeFrame: 0

    Timer {
        interval: 650
        running:  root.charging && !root.full
        repeat:   true
        onTriggered: root.chargeFrame = (root.chargeFrame + 1) % root.chargeFrames.length
    }

    readonly property string icon: {
        if (full)     return "󰂄"
        if (charging) return chargeFrames[chargeFrame % chargeFrames.length]
        return staticIcon(pct)
    }

    // ── Color ─────────────────────────────────────────────────────────────────
    readonly property color iconColor: {
        if (full)      return Theme.active
        if (charging)  return Theme.active
        if (pct <= 5)  return "#ff4444"
        if (pct <= 10) return "#ff6b00"
        if (pct <= 20) return "#ffcc00"
        if (pct <= 30) return "#ff9900"
        return Theme.text
    }

    // ── Display ───────────────────────────────────────────────────────────────
    Row {
        id: statusRow
        spacing: 4
        anchors.centerIn: parent

        Text {
            id: iconText
            text:                   root.icon
            color:                  root.iconColor
            font.pixelSize:         13
            anchors.verticalCenter: parent.verticalCenter

            // Ryoku: smooth color transition on hover.
            Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuart } }

            // Pulse when critically low and discharging
            SequentialAnimation on opacity {
                id: pulseAnim
                running:  root.pct <= 10 && !root.charging
                loops:    Animation.Infinite
                NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }

            // Snap back when animation stops
            Connections {
                target: pulseAnim
                function onRunningChanged() {
                    if (!pulseAnim.running) iconText.opacity = 1.0
                }
            }
        }

        Text {
            text:                   root.pct + "%"
            color:                  root.iconColor
            font.pixelSize:         11
            anchors.verticalCenter: parent.verticalCenter
            visible:                root.showPercentage || hov.hovered
            Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuart } }
        }
    }

    HoverHandler { id: hov }

    // Ryoku: subtle background highlight on hover, animates cleanly.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius:  6
        color:   hov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.0)
        Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutQuart } }
        z: -1
    }

    // ── Warning window ────────────────────────────────────────────────────────
    BatteryWarning {
        id:      warningWindow
        visible: false
    }
}
