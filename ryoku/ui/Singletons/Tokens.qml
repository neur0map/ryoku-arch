pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The one place Ryoku's look is defined. Everything that draws imports this;
// nothing hardcodes a hex, a size or a duration.
//
// Dynamically watches theme.json and colors.json so when Matugen/wallust app
// theming is enabled, Ryoku apps (Hub, Ryowalls, etc.) seamlessly adopt the palette.
Singleton {
    id: t

    readonly property bool matchWallpaper: themeAdapter.followWallpaper

    // ── default signature constants ──────────────────────────────────────
    readonly property color defaultPaper: "#000000"
    readonly property color defaultPaperLift: "#0a0a0a"
    readonly property color defaultInk: "#cdc4ba"
    readonly property color defaultInkDim: "#b0a9a0"
    readonly property color defaultInkMuted: "#958f87"
    readonly property color defaultInkFaint: "#7a756e"

    // ── paper ────────────────────────────────────────────────────────────
    readonly property color paper: matchWallpaper ? wallustAdapter.background : defaultPaper
    readonly property color paperLift: matchWallpaper ? wallustAdapter.color0 : defaultPaperLift

    // ── ink, on paper ────────────────────────────────────────────────────
    readonly property color ink: matchWallpaper ? wallustAdapter.foreground : defaultInk
    readonly property color inkDim: matchWallpaper ? wallustAdapter.color7 : defaultInkDim
    readonly property color inkMuted: matchWallpaper ? wallustAdapter.color8 : defaultInkMuted
    readonly property color inkFaint: matchWallpaper ? wallustAdapter.color8 : defaultInkFaint

    // ── bone stock (inverted) ────────────────────────────────────────────
    readonly property color bone: matchWallpaper ? (wallustAdapter.color4.hsvValue > 0.01 ? wallustAdapter.color4 : t.ink) : t.ink
    readonly property color inkOnBone: "#000000"                 // 12.0:1
    readonly property color inkOnBoneDim: Qt.rgba(0, 0, 0, 0.62) //  5.4:1
    readonly property color lineOnBone: Qt.rgba(0, 0, 0, 0.26)

    // ── hairlines and tints ──────────────────────────────────────────────
    readonly property color line: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.26)
    readonly property color lineSoft: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.13)
    readonly property color lineStrong: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.42)
    readonly property color tint5: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.05)   // surface hover
    readonly property color tint10: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.10)  // control hover
    readonly property color tint16: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.16)  // pressed

    // ── colour ───────────────────────────────────────────────────────────
    readonly property color sun: matchWallpaper ? (wallustAdapter.color1.hsvValue > 0.01 ? wallustAdapter.color1 : "#e2342a") : "#e2342a"
    readonly property color sunDeep: matchWallpaper ? (wallustAdapter.color9.hsvValue > 0.01 ? wallustAdapter.color9 : "#b81f19") : "#b81f19"

    // ── type ─────────────────────────────────────────────────────────────
    readonly property string display: "Fraunces"
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "SpaceMono Nerd Font"
    readonly property string jp: "Noto Sans CJK JP"

    readonly property int fTitle: 46    // page title, Fraunces
    readonly property int fHero: 34     // a headline readout
    readonly property int fValue: 26    // a cell's value
    readonly property int fRow: 15      // a row name
    readonly property int fBody: 14
    readonly property int fSmall: 13    // descriptions
    readonly property int fMicro: 11    // tracked labels
    readonly property int fTiny: 9      // corner tags, struck defaults

    readonly property real trackLabel: 1.4   // letter-spacing for micro labels
    readonly property real trackMark: 2.2    // for eyebrows and section marks

    // ── space ────────────────────────────────────────────────────────────
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32
    readonly property int s7: 48

    // ── geometry ─────────────────────────────────────────────────────────
    readonly property int radius: 2
    readonly property real border: 1
    readonly property int rowH: 48
    readonly property int cellH: 104
    readonly property int railW: 268
    readonly property int ctlH: 26

    // ── motion ───────────────────────────────────────────────────────────
    readonly property int snap: 90     // hover, press, state flip
    readonly property int move: 170    // a selector travelling
    readonly property int swap: 210    // content exchanging
    readonly property int flap: 110    // a value changing
    readonly property int ease: Easing.OutCubic
    readonly property int easeSnap: Easing.OutQuad

    // ── grain ────────────────────────────────────────────────────────────
    readonly property real grainOpacity: 0.10

    // ── Dynamic theme & wallust palette readers ──────────────────────────
    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: themeAdapter
            property bool followWallpaper: false
        }
    }

    FileView {
        id: wallustFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/wallust/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: wallustAdapter
            property color background: "#000000"
            property color foreground: "#cdc4ba"
            property color color0: "#0a0a0a"
            property color color1: "#e2342a"
            property color color2: "#7a756e"
            property color color3: "#958f87"
            property color color4: "#b0a9a0"
            property color color5: "#8a857c"
            property color color6: "#a89f95"
            property color color7: "#b0a9a0"
            property color color8: "#958f87"
            property color color9: "#b81f19"
            property color color10: "#b0a9a0"
            property color color14: "#958f87"
            property color color15: "#cdc4ba"
        }
    }
}
