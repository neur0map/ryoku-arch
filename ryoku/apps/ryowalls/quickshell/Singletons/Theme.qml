pragma Singleton
import QtQuick
import Quickshell

// App palette: the hub's tokens, kept in step by hand.
Singleton {
    readonly property color brand:     "#F25623"
    readonly property color ember:     "#ff6a3d"
    readonly property color emberDeep: "#bf3c19"

    readonly property color ok:        "#7fbf6a"
    readonly property color bad:       "#e05a5a"

    readonly property color bgTop:    "#1b1612"
    readonly property color bgBot:    "#140f0c"
    readonly property color rail:     "#171210"
    readonly property color surface:  "#241c16"
    readonly property color surfaceLo:"#1c1510"
    readonly property color keyTop:   "#2a211a"
    readonly property color keyBot:   "#1d160f"
    readonly property color line:     "#322720"
    readonly property color lineSoft: Qt.rgba(236 / 255, 214 / 255, 198 / 255, 0.06)

    readonly property color cardTop:  "#241b14"
    readonly property color cardBot:  "#15100c"
    readonly property color frameBg:  Qt.rgba(242 / 255, 86 / 255, 35 / 255, 0.10)
    readonly property color hair:     Qt.rgba(236 / 255, 214 / 255, 198 / 255, 0.12)

    readonly property color bright:   "#f4ece5"
    readonly property color cream:    "#ddccc0"
    readonly property color subtle:   "#b0a197"
    readonly property color dim:      "#83766c"
    readonly property color faint:    "#5c5249"
    readonly property color onAccent: "#fdeee6"

    readonly property string font:   "Inter"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono:   "JetBrainsMono Nerd Font"

    readonly property int quick:  120
    readonly property int medium: 240
    readonly property int slow:   360
    readonly property int ease:   Easing.OutExpo
}
