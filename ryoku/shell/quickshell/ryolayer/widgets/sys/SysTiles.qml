pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Dashboard reading of Sys: paperLift tiles, each a huge mono numeral with its
// unit, a tracked micro label, and a one-line secondary. Monochrome throughout;
// the numeral is the one thing that flips to Tokens.sun when its metric runs
// hot. Tiles reflow to the plate width and omit any metric the box lacks.
Flickable {
    id: dash
    contentWidth: width
    contentHeight: grid.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    readonly property int memPct: Sys.memTotal > 0 ? Math.round(100 * Sys.memUsed / Sys.memTotal) : -1
    readonly property int swapPct: Sys.swapTotal > 0 ? Math.round(100 * Sys.swapUsed / Sys.swapTotal) : -1
    readonly property int diskPct: Sys.diskTotal > 0 ? Math.round(100 * Sys.diskUsed / Sys.diskTotal) : -1

    component Tile: Rectangle {
        id: tile
        property string hero: ""
        property string unit: ""
        property string label: ""
        property string secondary: ""
        property bool hot: false
        Layout.fillWidth: true
        Layout.preferredHeight: body.implicitHeight + Tokens.s3 * 2
        radius: Tokens.radius
        color: Tokens.paperLift
        border { width: Tokens.border; color: Tokens.line }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Tokens.s3 }
            spacing: Tokens.s1

            Text {
                text: tile.label
                color: Tokens.inkFaint
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            Row {
                spacing: Tokens.s1
                Text {
                    id: heroText
                    text: tile.hero
                    color: tile.hot ? Tokens.sun : Tokens.ink
                    font { family: Tokens.mono; pixelSize: Tokens.fHero }
                }
                Text {
                    anchors.baseline: heroText.baseline
                    visible: tile.unit.length > 0
                    text: tile.unit
                    color: Tokens.inkMuted
                    font { family: Tokens.mono; pixelSize: Tokens.fMicro }
                }
            }
            Text {
                width: parent.width
                visible: tile.secondary.length > 0
                text: tile.secondary
                elide: Text.ElideRight
                color: Tokens.inkMuted
                font { family: Tokens.mono; pixelSize: Tokens.fTiny }
            }
        }
    }

    GridLayout {
        id: grid
        width: dash.width
        columns: Math.max(2, Math.floor(dash.width / 160))
        columnSpacing: Tokens.s2
        rowSpacing: Tokens.s2

        Tile {
            label: "CPU"
            hero: Sys.cpuLoad + ""
            unit: "%"
            secondary: Sys.cpuTemp >= 0 ? Sys.cpuTemp + "\u00b0C \u00b7 " + Sys.cores.length + "c" : Sys.cores.length + "c"
            hot: Sys.cpuTemp >= 85
        }
        Tile {
            visible: dash.memPct >= 0
            label: "RAM"
            hero: dash.memPct + ""
            unit: "%"
            secondary: Sys.memUsed.toFixed(1) + " / " + Math.round(Sys.memTotal) + "G"
            hot: dash.memPct >= 90
        }
        Tile {
            visible: dash.swapPct >= 0
            label: "SWAP"
            hero: dash.swapPct + ""
            unit: "%"
            secondary: Sys.swapUsed.toFixed(1) + " / " + Math.round(Sys.swapTotal) + "G"
        }
        Tile {
            visible: dash.diskPct >= 0
            label: "DISK"
            hero: dash.diskPct + ""
            unit: "%"
            secondary: Math.round(Sys.diskUsed) + " / " + Math.round(Sys.diskTotal) + "G" + (Sys.diskTemp >= 0 ? " \u00b7 " + Sys.diskTemp + "\u00b0C" : "")
            hot: dash.diskPct >= 90 || Sys.diskTemp >= 60
        }
        Tile {
            visible: Sys.igpuTemp >= 0 || Sys.igpuLoad >= 0
            label: "IGPU"
            hero: Sys.igpuTemp >= 0 ? Sys.igpuTemp + "" : (Sys.igpuLoad + "")
            unit: Sys.igpuTemp >= 0 ? "\u00b0C" : "%"
            secondary: Sys.igpuTemp >= 0 && Sys.igpuLoad >= 0 ? "load " + Sys.igpuLoad + "%" : ""
            hot: Sys.igpuTemp >= 85
        }
        Tile {
            label: "DGPU"
            hero: !Sys.dgpuAwake ? "\u2014" : (Sys.dgpuTemp >= 0 ? Sys.dgpuTemp + "" : "\u2014")
            unit: Sys.dgpuAwake && Sys.dgpuTemp >= 0 ? "\u00b0C" : ""
            secondary: !Sys.dgpuAwake ? "asleep"
                     : (Sys.dgpuLoad >= 0 ? "load " + Sys.dgpuLoad + "%" : "")
                       + (Sys.dgpuVramTotal > 0 ? " \u00b7 " + Sys.dgpuVramUsed.toFixed(1) + "/" + Math.round(Sys.dgpuVramTotal) + "G" : "")
            hot: Sys.dgpuAwake && Sys.dgpuTemp >= 85
        }
        Tile {
            visible: Sys.load1 >= 0
            label: "LOAD"
            hero: Sys.load1.toFixed(2)
            secondary: Sys.load5.toFixed(2) + " \u00b7 " + Sys.load15.toFixed(2)
            hot: Sys.cores.length > 0 && Sys.load1 >= Sys.cores.length
        }
        Tile {
            visible: Sys.uptime.length > 0
            label: "UPTIME"
            hero: Sys.uptime
        }
    }
}
