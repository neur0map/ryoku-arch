pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import ".."
import "../Singletons"

// resources popout content: the CPU / memory / temperature readout behind the
// Nacre stats module, grown from the bar edge. each metric is an eyebrow + hero
// value with a bar sparkline from the SysStats history, then the top processes
// by CPU. a bare transparent Item -- the Popout blob behind it IS the surface;
// this panel only reports its implicit size. pointer-driven, no keyboard focus.
Item {
    id: root

    property real s: 1
    // popout open: gates the process sampler so `ps` never spins while closed.
    property bool open: false

    anchors.fill: parent

    implicitWidth: 260 * s
    implicitHeight: body.implicitHeight + 27 * s

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    // one metric: eyebrow label + hero value on its baseline, then a bar
    // sparkline of the recent history (newest at the right).
    component Metric: Column {
        id: metric
        property string label: ""
        property string value: ""
        property var series: []
        property real max: 100
        property bool warn: false

        width: parent ? parent.width : 0
        spacing: 6 * root.s

        Item {
            width: parent.width
            height: mLabel.implicitHeight
            Text {
                id: mLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: metric.label
                color: Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2 * root.s
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: mLabel.baseline
                text: metric.value
                color: metric.warn ? Theme.vermLit : Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }

        Row {
            id: spark
            width: parent.width
            height: 18 * root.s
            spacing: 1.5 * root.s

            readonly property int shown: Math.min(metric.series.length, 44)
            readonly property real barW: shown > 0 ? (width - (shown - 1) * spacing) / shown : 0

            Repeater {
                model: spark.shown
                delegate: Rectangle {
                    required property int index
                    readonly property real v: metric.series[metric.series.length - spark.shown + index]
                    width: spark.barW
                    height: Math.max(1, spark.height * Math.min(1, v / metric.max))
                    y: spark.height - height
                    radius: width / 2
                    color: metric.warn ? Theme.vermLit : Theme.verm
                    opacity: 0.35 + 0.65 * (index / Math.max(1, spark.shown - 1))
                }
            }
        }
    }

    // top processes by CPU, one row each: tabular percent + command.
    component ProcRow: Item {
        id: procRow
        property string pct: ""
        property string name: ""
        width: parent ? parent.width : 0
        height: pctText.implicitHeight
        Text {
            id: pctText
            anchors.left: parent.left
            width: 40 * root.s
            text: procRow.pct + "%"
            color: Theme.subtle
            font.family: Theme.mono
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.left: pctText.right
            anchors.right: parent.right
            anchors.baseline: pctText.baseline
            text: procRow.name
            elide: Text.ElideRight
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 11 * root.s

        // header: brand glyph + RESOURCES eyebrow, the popout idiom.
        Row {
            spacing: 8 * root.s
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "monitor_heart"
                fill: 1
                color: Theme.brand
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "RESOURCES"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Metric { label: "CPU"; value: SysStats.cpu + "%"; series: SysStats.cpuHistory; warn: SysStats.cpu > 85 }
        Metric { label: "Memory"; value: SysStats.mem + "%"; series: SysStats.memHistory; warn: SysStats.mem > 90 }
        Metric {
            visible: SysStats.tempAvailable
            label: "Temp"
            value: SysStats.temp + "\u00b0C"
            series: SysStats.tempHistory
            warn: SysStats.temp > 80
        }

        Divider {}

        Text {
            text: "TOP PROCESSES"
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4 * root.s
        }

        Column {
            id: procList
            property var rows: []
            width: parent.width
            spacing: 5 * root.s

            Repeater {
                model: procList.rows
                delegate: ProcRow {
                    required property var modelData
                    pct: modelData.pct
                    name: modelData.name
                }
            }
        }
    }

    // sample the top processes only while the popout is mounted and open.
    Process {
        id: psProc
        command: ["sh", "-c", "ps -eo pcpu,comm --sort=-pcpu --no-headers | head -5"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                (this.text || "").trim().split("\n").forEach(function (ln) {
                    var m = ln.trim().match(/^([\d.]+)\s+(.*)$/);
                    if (m)
                        out.push({ pct: m[1], name: m[2] });
                });
                procList.rows = out;
            }
        }
    }
    Timer {
        interval: 2500
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: psProc.running = true
    }
}
