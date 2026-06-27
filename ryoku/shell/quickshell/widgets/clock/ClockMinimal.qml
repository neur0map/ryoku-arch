pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// minimal face. thin airy Inter time, wide tracking, a short accent rule
// below it. earns its place through type + spacing, no ornament. seconds /
// AM-PM (when on) sit as a quiet caption.
Item {
    id: face

    readonly property var t: Clk.parts(Now.date, Config.clock24h)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Wallust.accent, Theme.brand, Theme.ink)
    readonly property real px: Math.round(82 * Config.clockScale)
    readonly property string caption: (Config.clockSeconds ? face.t.ss : "")
        + (Config.clockSeconds && !Config.clock24h ? "  " : "")
        + (!Config.clock24h ? face.t.ampm.toLowerCase() : "")

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: Math.round(10 * Config.clockScale)

        Text {
            id: time
            text: face.t.hh + ":" + face.t.mm
            color: Theme.ink
            font.family: Theme.font
            font.pixelSize: face.px
            font.weight: Font.Light
            font.letterSpacing: Math.round(2 * Config.clockScale)
        }

        Rectangle {
            width: Math.round(time.implicitWidth * 0.34)
            height: Math.max(2, Math.round(3 * Config.clockScale))
            radius: height / 2
            color: face.accent
        }

        Text {
            visible: face.caption.length > 0
            text: face.caption
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Math.round(face.px * 0.22)
            font.weight: Font.Medium
            font.letterSpacing: Math.round(3 * Config.clockScale)
        }
    }
}
