import QtQuick
import "../../"
import "../../components"

Item {
    id: root

    required property var  service
    property bool          dgpuActive: false
    property string        fanMode:    "quiet"
    property int           maxFanRpm:  5500

    function tempColor(t) {
        if (t >= 90) return "#f38ba8"
        if (t >= 75) return "#f5c47a"
        if (t >= 60) return "#fab387"
        return Theme.active
    }

    readonly property real s: 0.60

    // ── Speedometers — anchored left ──────────────────────────────────────────
    Row {
        id: speedoRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: parent.width * 0.05

        Speedometer {
            size:        root.s
            label:       ""
            percent:     Math.min(100, service.cpuTemp)
            centerText:  service.cpuTempStr
            bottomText:  "CPU"
            active:      true
            accentColor: root.tempColor(service.cpuTemp)
        }

        Speedometer {
            size:        root.s
            label:       ""
            percent:     root.dgpuActive ? Math.min(100, service.gpuTemp) : 0
            centerText:  root.dgpuActive ? service.gpuTempStr : "—"
            bottomText:  "GPU"
            active:      root.dgpuActive
            accentColor: root.tempColor(service.gpuTemp)
        }

        Rectangle {
            width:  1
            height: parent.height * 0.7
            anchors.verticalCenter: parent.verticalCenter
            color:  Qt.rgba(1, 1, 1, 0.08)
        }

        Speedometer {
            visible:     service.fanCount >= 1
            size:        root.s
            label:       ""
            percent:     Math.min(100, service.fan1Rpm / root.maxFanRpm * 100)
            centerText:  service.fan1Rpm > 999
                             ? (service.fan1Rpm / 1000).toFixed(1) + "k"
                             : service.fan1Rpm + ""
            bottomText:  "Fan 1"
            active:      service.fan1Rpm > 0
            accentColor: "#89dceb"
        }

        Speedometer {
            visible:     service.fanCount >= 2
            size:        root.s
            label:       ""
            percent:     Math.min(100, service.fan2Rpm / root.maxFanRpm * 100)
            centerText:  service.fan2Rpm > 999
                             ? (service.fan2Rpm / 1000).toFixed(1) + "k"
                             : service.fan2Rpm + ""
            bottomText:  "Fan 2"
            active:      service.fan2Rpm > 0
            accentColor: "#89dceb"
        }
    }
}
