pragma ComponentBehavior: Bound
import QtQuick
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Instrument-sheet reading of Sys: one hairline row per metric, a tracked label
// left, a 2px ratio bar in the middle where a ratio exists, a mono value right.
// The one accent is a hot value flipping to Tokens.sun. Per-core load rides as
// a strip of vertical ticks under the CPU row. Missing sensors drop their row.
Flickable {
    id: sheet
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    readonly property int memPct: Sys.memTotal > 0 ? Math.round(100 * Sys.memUsed / Sys.memTotal) : -1
    readonly property int diskPct: Sys.diskTotal > 0 ? Math.round(100 * Sys.diskUsed / Sys.diskTotal) : -1

    component MetricRow: Item {
        id: mr
        property string label: ""
        property real ratio: -1
        property string value: ""
        property bool hot: false
        width: parent ? parent.width : 0
        height: Math.max(lab.implicitHeight, val.implicitHeight)

        Text {
            id: lab
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: Tokens.s6 + Tokens.s2
            text: mr.label
            color: Tokens.inkMuted
            font { family: Tokens.mono; pixelSize: Tokens.fMicro; letterSpacing: Tokens.trackLabel }
        }
        Rectangle {
            id: track
            anchors { left: lab.right; right: val.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s3; rightMargin: Tokens.s3 }
            height: 2
            radius: 1
            visible: mr.ratio >= 0
            color: Tokens.lineSoft
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: parent.width * Math.max(0, Math.min(1, mr.ratio))
                height: parent.height
                radius: 1
                color: mr.hot ? Tokens.sun : Tokens.ink
            }
        }
        Text {
            id: val
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: mr.value
            color: mr.hot ? Tokens.sun : Tokens.ink
            font { family: Tokens.mono; pixelSize: Tokens.fMicro }
        }
    }

    Column {
        id: col
        width: sheet.width
        spacing: Tokens.s2

        MetricRow {
            label: "CPU"
            ratio: Sys.cpuLoad / 100
            value: Sys.cpuLoad + "%" + (Sys.cpuTemp >= 0 ? " \u00b7 " + Sys.cpuTemp + "\u00b0C" : "")
            hot: Sys.cpuTemp >= 85
        }
        Row {
            width: parent.width
            height: 14
            spacing: 2
            visible: Sys.cores.length > 0
            Repeater {
                model: Sys.cores
                delegate: Item {
                    required property var modelData
                    width: (col.width - (Sys.cores.length - 1) * 2) / Sys.cores.length
                    height: 14
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: Math.max(1, parent.height * modelData / 100)
                        color: Tokens.inkDim
                    }
                }
            }
        }

        MetricRow {
            visible: Sys.memTotal > 0
            label: "RAM"
            ratio: Sys.memUsed / Sys.memTotal
            value: Sys.memUsed.toFixed(1) + "/" + Math.round(Sys.memTotal) + "G \u00b7 " + sheet.memPct + "%"
            hot: sheet.memPct >= 90
        }
        MetricRow {
            visible: Sys.swapTotal > 0
            label: "SWAP"
            ratio: Sys.swapUsed / Sys.swapTotal
            value: Sys.swapUsed.toFixed(1) + "/" + Math.round(Sys.swapTotal) + "G"
        }
        MetricRow {
            visible: Sys.diskTotal > 0
            label: "DISK"
            ratio: Sys.diskUsed / Sys.diskTotal
            value: Math.round(Sys.diskUsed) + "/" + Math.round(Sys.diskTotal) + "G" + (Sys.diskTemp >= 0 ? " \u00b7 " + Sys.diskTemp + "\u00b0C" : "")
            hot: sheet.diskPct >= 90 || Sys.diskTemp >= 60
        }
        MetricRow {
            visible: Sys.igpuTemp >= 0 || Sys.igpuLoad >= 0
            label: "IGPU"
            ratio: Sys.igpuLoad >= 0 ? Sys.igpuLoad / 100 : -1
            value: (Sys.igpuLoad >= 0 ? Sys.igpuLoad + "%" : "") + (Sys.igpuTemp >= 0 ? (Sys.igpuLoad >= 0 ? " \u00b7 " : "") + Sys.igpuTemp + "\u00b0C" : "")
            hot: Sys.igpuTemp >= 85
        }
        MetricRow {
            label: "DGPU"
            ratio: Sys.dgpuAwake && Sys.dgpuLoad >= 0 ? Sys.dgpuLoad / 100 : -1
            value: !Sys.dgpuAwake ? "asleep"
                 : (Sys.dgpuLoad >= 0 ? Sys.dgpuLoad + "% \u00b7 " : "") + (Sys.dgpuTemp >= 0 ? Sys.dgpuTemp + "\u00b0C" : "")
                   + (Sys.dgpuVramTotal > 0 ? " \u00b7 " + Sys.dgpuVramUsed.toFixed(1) + "/" + Math.round(Sys.dgpuVramTotal) + "G" : "")
            hot: Sys.dgpuAwake && Sys.dgpuTemp >= 85
        }
        MetricRow {
            visible: Sys.load1 >= 0
            label: "LOAD"
            ratio: Sys.cores.length > 0 ? Sys.load1 / Sys.cores.length : -1
            value: Sys.load1.toFixed(2) + "  " + Sys.load5.toFixed(2) + "  " + Sys.load15.toFixed(2)
            hot: Sys.cores.length > 0 && Sys.load1 >= Sys.cores.length
        }
        MetricRow {
            visible: Sys.uptime.length > 0
            label: "UP"
            value: Sys.uptime
        }
    }
}
