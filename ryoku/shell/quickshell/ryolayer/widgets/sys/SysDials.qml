pragma ComponentBehavior: Bound
import QtQuick
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Gauge reading of Sys: circular dials, a hairline full ring with a value arc
// swept from twelve o'clock, the number centered in mono and a tracked micro
// label beneath. The arc and number flip to Tokens.sun past the hot threshold;
// a suspended dGPU shows a bare ring reading "asleep". True circles are the one
// sanctioned round geometry here.
Flickable {
    id: board
    contentWidth: width
    contentHeight: flow.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    readonly property int memPct: Sys.memTotal > 0 ? Math.round(100 * Sys.memUsed / Sys.memTotal) : -1
    readonly property int diskPct: Sys.diskTotal > 0 ? Math.round(100 * Sys.diskUsed / Sys.diskTotal) : -1

    component Dial: Item {
        id: dial
        property string label: ""
        property real ratio: 0
        property string value: ""
        property bool hot: false
        property bool available: true
        width: 92
        height: 108

        onRatioChanged: ring.requestPaint()
        onHotChanged: ring.requestPaint()
        onAvailableChanged: ring.requestPaint()

        Canvas {
            id: ring
            width: 78
            height: 78
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2, cy = height / 2, r = width / 2 - 5;
                ctx.lineWidth = 3;
                ctx.lineCap = "round";
                ctx.strokeStyle = Tokens.line;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.stroke();
                if (dial.available && dial.ratio > 0) {
                    ctx.strokeStyle = dial.hot ? Tokens.sun : Tokens.ink;
                    ctx.beginPath();
                    var s = -Math.PI / 2;
                    ctx.arc(cx, cy, r, s, s + 2 * Math.PI * Math.min(1, dial.ratio));
                    ctx.stroke();
                }
            }
        }
        Text {
            anchors.centerIn: ring
            text: dial.available ? dial.value : "asleep"
            color: dial.hot ? Tokens.sun : (dial.available ? Tokens.ink : Tokens.inkFaint)
            font { family: Tokens.mono; pixelSize: dial.available ? Tokens.fValue : Tokens.fMicro }
        }
        Text {
            anchors { top: ring.bottom; topMargin: Tokens.s1; horizontalCenter: parent.horizontalCenter }
            text: dial.label
            color: Tokens.inkFaint
            font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
        }
    }

    Flow {
        id: flow
        width: board.width
        spacing: Tokens.s2

        Dial {
            label: "CPU %"
            ratio: Sys.cpuLoad / 100
            value: Sys.cpuLoad + ""
        }
        Dial {
            visible: Sys.cpuTemp >= 0
            label: "CPU \u00b0C"
            ratio: Sys.cpuTemp / 100
            value: Sys.cpuTemp + ""
            hot: Sys.cpuTemp >= 85
        }
        Dial {
            visible: board.memPct >= 0
            label: "RAM %"
            ratio: board.memPct / 100
            value: board.memPct + ""
            hot: board.memPct >= 90
        }
        Dial {
            visible: board.diskPct >= 0
            label: "DISK %"
            ratio: board.diskPct / 100
            value: board.diskPct + ""
            hot: board.diskPct >= 90
        }
        Dial {
            visible: Sys.igpuTemp >= 0
            label: "IGPU \u00b0C"
            ratio: Sys.igpuTemp / 100
            value: Sys.igpuTemp + ""
            hot: Sys.igpuTemp >= 85
        }
        Dial {
            label: "DGPU \u00b0C"
            available: Sys.dgpuAwake && Sys.dgpuTemp >= 0
            ratio: Sys.dgpuTemp / 100
            value: Sys.dgpuTemp + ""
            hot: Sys.dgpuAwake && Sys.dgpuTemp >= 85
        }
    }
}
