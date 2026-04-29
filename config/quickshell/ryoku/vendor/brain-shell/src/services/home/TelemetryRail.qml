import QtQuick
import "../../"
import "../../services/"

Item {
    id: root

    readonly property int railRadius: Theme.cornerRadius + 6
    readonly property int sampleCount: 28
    readonly property int contentMargin: 12
    readonly property int sectionSpacing: 10
    readonly property int cpuSectionH: 122
    readonly property int memorySectionH: 58
    readonly property int thermalsSectionH: 76
    readonly property int networkSectionH: 82
    readonly property int summarySectionH: 74

    property var  _cpuHistory: []
    property real _upBps:      0
    property real _downBps:    0
    property real _netPeak:    65536

    CpuService         { id: cpu;     active: root.visible }
    MemService         { id: mem;     active: root.visible }
    NetService         { id: net;     active: root.visible }
    ThermalService     { id: thermal; active: root.visible }
    DiskService        { id: disk;    active: root.visible }
    EnvyControlService { id: envy }
    CpuFreqService     { id: cpuFreq }
    GpuService {
        id:       gpu
        active:   root.visible
        envyMode: envy.currentMode
    }

    readonly property var rootDisk: {
        var list = disk.disks
        for (var i = 0; i < list.length; i++) {
            if (list[i].mount === "/") return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    readonly property bool usingDgpu: gpu.dgpu.active
    readonly property string gpuLabel: usingDgpu ? "dGPU" : "iGPU"
    readonly property string gpuValue: usingDgpu
        ? (Math.round(gpu.dgpu.usagePercent) + "%  ·  " + gpu.dgpu.usedVram + " / " + gpu.dgpu.totalVram)
        : gpu.igpu.curMhz
    readonly property real gpuFill: usingDgpu
        ? Math.max(0, Math.min(1, gpu.dgpu.usagePercent / 100))
        : Math.max(0, Math.min(1, gpu.igpu.freqPercent / 100))

    readonly property string fanSummary: {
        if (thermal.fanCount === 0) return "Fans unavailable"
        if (thermal.fanCount === 1) return "Fan " + thermal.fan1Str
        return "Fans " + thermal.fan1Str + " / " + thermal.fan2Str
    }

    function _appendSeries(series, value) {
        var next = series.slice()
        next.push(Math.max(0, Math.min(1, value)))
        while (next.length > root.sampleCount) next.shift()
        return next
    }

    function _seedSeries() {
        if (root._cpuHistory.length > 0) return
        var seed = []
        for (var i = 0; i < root.sampleCount; i++) seed.push(0)
        root._cpuHistory = seed
    }

    function _parseBps(text) {
        var m = text.match(/([0-9.]+)\s*([KMG]?B)\/s/)
        if (!m) return 0
        var n = parseFloat(m[1])
        var unit = m[2]
        if (unit === "GB") return n * 1024 * 1024 * 1024
        if (unit === "MB") return n * 1024 * 1024
        if (unit === "KB") return n * 1024
        return n
    }

    function _tempColor(temp) {
        if (temp >= 85) return "#f38ba8"
        if (temp >= 70) return "#f5c47a"
        if (temp >= 60) return "#fab387"
        return "#8bd5ca"
    }

    Component.onCompleted: root._seedSeries()

    Timer {
        interval: 1000
        running:  root.visible
        repeat:   true
        onTriggered: {
            root._seedSeries()
            root._upBps = root._parseBps(net.upSpeed)
            root._downBps = root._parseBps(net.downSpeed)
            root._netPeak = Math.max(65536, root._upBps, root._downBps, root._netPeak * 0.92)
            root._cpuHistory = root._appendSeries(root._cpuHistory, cpu.usagePercent / 100)
            cpuGraph.requestPaint()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius:       root.railRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06) }
        }
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        radius:       root.railRadius
        color:        Qt.rgba(8/255, 12/255, 18/255, 0.55)
    }

    Column {
        anchors {
            fill:    parent
            margins: root.contentMargin
        }
        spacing: root.sectionSpacing

        Item {
            width:  parent.width
            height: root.cpuSectionH

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                text:           "Telemetry"
                font.pixelSize: 11
                font.weight:    Font.DemiBold
                color:          Qt.rgba(1, 1, 1, 0.45)
            }

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                anchors.topMargin: 20
                text:           Math.round(cpu.usagePercent) + "%"
                font.pixelSize: 34
                font.weight:    Font.Bold
                color:          Theme.active
            }

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                anchors.topMargin: 62
                text:           "CPU  ·  " + cpuFreq.curFreqStr
                font.pixelSize: 11
                color:          Qt.rgba(1, 1, 1, 0.55)
            }

            Canvas {
                id: cpuGraph
                anchors {
                    left:   parent.left
                    right:  parent.right
                    bottom: parent.bottom
                }
                height: 54

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    if (root._cpuHistory.length < 2) return

                    var pts = root._cpuHistory
                    var step = width / Math.max(1, pts.length - 1)

                    ctx.beginPath()
                    ctx.moveTo(0, height)
                    for (var i = 0; i < pts.length; i++) {
                        var yFill = height - Math.max(6, pts[i] * (height - 10))
                        ctx.lineTo(i * step, yFill)
                    }
                    ctx.lineTo(width, height)
                    ctx.closePath()

                    var fill = ctx.createLinearGradient(0, 0, 0, height)
                    fill.addColorStop(0.0, "rgba(166,208,247,0.34)")
                    fill.addColorStop(1.0, "rgba(166,208,247,0.02)")
                    ctx.fillStyle = fill
                    ctx.fill()

                    ctx.beginPath()
                    for (var j = 0; j < pts.length; j++) {
                        var y = height - Math.max(6, pts[j] * (height - 10))
                        if (j === 0) ctx.moveTo(0, y)
                        else ctx.lineTo(j * step, y)
                    }
                    ctx.strokeStyle = "rgba(166,208,247,0.95)"
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }

        Item {
            width:  parent.width
            height: root.memorySectionH

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                text:           "Memory"
                font.pixelSize: 11
                font.weight:    Font.DemiBold
                color:          Qt.rgba(1, 1, 1, 0.45)
            }

            Text {
                anchors.right: parent.right
                anchors.top:   parent.top
                text:           mem.usedStr + " / " + mem.totalStr
                font.pixelSize: 11
                color:          Qt.rgba(1, 1, 1, 0.65)
            }

            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                height:         16
                radius:         8
                color:          Qt.rgba(1, 1, 1, 0.08)
                border.color:   Qt.rgba(1, 1, 1, 0.08)
                border.width:   1

                Rectangle {
                    anchors.left:   parent.left
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          parent.width * Math.max(0, Math.min(1, mem.usagePercent / 100))
                    radius:         parent.radius
                    color:          "#cba6f7"
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }

                Text {
                    anchors.centerIn: parent
                    text:           mem.usagePercent + "%"
                    font.pixelSize: 10
                    font.weight:    Font.DemiBold
                    color:          "#0b0f14"
                }
            }
        }

        Item {
            width:  parent.width
            height: root.thermalsSectionH

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    text:           "Thermals"
                    font.pixelSize: 11
                    font.weight:    Font.DemiBold
                    color:          Qt.rgba(1, 1, 1, 0.45)
                }

                Repeater {
                    model: [
                        { label: "CPU", temp: thermal.cpuTemp, text: thermal.cpuTempStr },
                        { label: "GPU", temp: thermal.gpuTemp, text: root.usingDgpu ? thermal.gpuTempStr : "idle" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width:  parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.label
                            font.pixelSize: 10
                            color:          Qt.rgba(1, 1, 1, 0.42)
                        }

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.leftMargin: 34
                            anchors.right:  valueLabel.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height:         8
                            radius:         4
                            color:          Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                anchors.left:   parent.left
                                anchors.top:    parent.top
                                anchors.bottom: parent.bottom
                                width:          parent.width * Math.max(0, Math.min(1, modelData.temp / 100))
                                radius:         parent.radius
                                color:          root._tempColor(modelData.temp)
                                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }

                        Text {
                            id: valueLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.text
                            font.pixelSize: 10
                            color:          Qt.rgba(1, 1, 1, 0.68)
                        }
                    }
                }

                Text {
                    text:           root.fanSummary
                    font.pixelSize: 9
                    color:          Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }

        Item {
            width:  parent.width
            height: root.networkSectionH

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    text:           "Network"
                    font.pixelSize: 11
                    font.weight:    Font.DemiBold
                    color:          Qt.rgba(1, 1, 1, 0.45)
                }

                Repeater {
                    model: [
                        { label: "UP", color: "#90ef90", value: net.upSpeed, fill: Math.max(0, Math.min(1, root._upBps / root._netPeak)) },
                        { label: "DOWN", color: "#a6d0f7", value: net.downSpeed, fill: Math.max(0, Math.min(1, root._downBps / root._netPeak)) }
                    ]
                    delegate: Item {
                        required property var modelData
                        width:  parent.width
                        height: 22

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.label
                            font.pixelSize: 10
                            font.weight:    Font.DemiBold
                            color:          modelData.color
                        }

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.leftMargin: 42
                            anchors.right:  speedLabel.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height:         8
                            radius:         4
                            color:          Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                anchors.left:   parent.left
                                anchors.top:    parent.top
                                anchors.bottom: parent.bottom
                                width:          parent.width * modelData.fill
                                radius:         parent.radius
                                color:          modelData.color
                                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            }
                        }

                        Text {
                            id: speedLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.value
                            font.pixelSize: 10
                            color:          Qt.rgba(1, 1, 1, 0.68)
                        }
                    }
                }

                Text {
                    text:           net.iface !== "—" ? ("Interface  " + net.iface) : "Interface unavailable"
                    font.pixelSize: 9
                    color:          Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }

        Item {
            width:  parent.width
            height: root.summarySectionH

            Column {
                anchors.fill: parent
                spacing: 8

                Item {
                    width:  parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.gpuLabel
                        font.pixelSize: 10
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.gpuValue
                        font.pixelSize: 10
                        color:          root.usingDgpu ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.42)
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height:         6
                        radius:         3
                        color:          Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.top:    parent.top
                            anchors.bottom: parent.bottom
                            width:          parent.width * root.gpuFill
                            radius:         parent.radius
                            color:          root.usingDgpu ? "#a6e3a1" : Qt.rgba(1, 1, 1, 0.24)
                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Item {
                    width:  parent.width
                    height: 28
                    visible: root.rootDisk !== null

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.rootDisk ? ("Disk " + root.rootDisk.mount) : "Disk"
                        font.pixelSize: 10
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.rootDisk ? (root.rootDisk.usedStr + " / " + root.rootDisk.totalStr) : "—"
                        font.pixelSize: 10
                        color:          Qt.rgba(1, 1, 1, 0.68)
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height:         6
                        radius:         3
                        color:          Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.top:    parent.top
                            anchors.bottom: parent.bottom
                            width:          root.rootDisk ? parent.width * Math.max(0, Math.min(1, root.rootDisk.usedPct / 100)) : 0
                            radius:         parent.radius
                            color:          root.rootDisk && root.rootDisk.usedPct >= 85 ? "#f38ba8" : Theme.active
                            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
