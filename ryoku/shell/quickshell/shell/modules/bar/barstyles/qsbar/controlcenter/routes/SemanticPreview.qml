import QtQuick
import "../kit"
import "../../modules"

// The CONFIGURE landing's right-hand preview: a compact, live semantic sketch of
// whichever route is hovered/selected, keyed by `routeId`. Ported from Shibumi's
// SemanticPreviewImage, reduced to Ryoku's five routes and re-skinned in qsbar's
// dark technical palette. Every colour/geometry value is read off `root` (the
// qsbar Theme) — no hardcoded hexes (fallbacks only apply while root is null),
// no Ryoku.Ui imports. Guards barShellStyle by value since that token lives on
// the V2 Theme only.
Item {
    id: sp
    property var root: null
    property string routeId: "bars"

    readonly property color accent: root ? root.seal : "#c4746e"
    readonly property color fg:     root ? root.ink  : "#c5c9c5"
    readonly property color muted:  root ? root.sumi : "#a6a69c"
    readonly property string mono:  root ? root.mono : "monospace"

    function paletteAt(id) { return root ? root.paletteColor(id) : sp.accent }
    function shellForm() {
        var f = root ? String(root.barShellStyle) : ""
        return (f === "full" || f === "fit" || f === "dock" || f === "notch") ? f : "full"
    }

    // ── bars: the live bar silhouette (tracks barShellStyle + palette) ──
    BarSilhouette {
        visible: sp.routeId === "bars"
        anchors.centerIn: parent
        width: Math.min(parent.width - 36, 272)
        root: sp.root
        form: sp.shellForm()
    }

    // ── appearance: a row of per-widget colour chips ──
    Row {
        id: chips
        visible: sp.routeId === "appearance"
        anchors.centerIn: parent
        spacing: 11
        readonly property var widgets: [
            { glyph: "wifi",          id: "color04" },
            { glyph: "volume_up",     id: "color06" },
            { glyph: "battery_5_bar", id: "color03" },
            { glyph: "schedule",      id: "foreground" },
            { glyph: "memory",        id: "color05" }
        ]
        Repeater {
            model: chips.widgets
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property color tint: sp.paletteAt(modelData.id)
                width: 36; height: 48
                radius: sp.root ? sp.root.tileRadius : 6
                color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)
                border.width: 1
                border.color: chip.tint
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: chip.modelData.glyph
                        color: chip.tint
                        font.pixelSize: 17
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 16; height: 4; radius: 2
                        color: chip.tint
                    }
                }
            }
        }
    }

    // ── logo: the RYOKU / 力 wordmark (emphasis follows launcherLogoMode) ──
    Column {
        id: wordmark
        visible: sp.routeId === "logo"
        anchors.centerIn: parent
        spacing: 8
        readonly property bool iconMode: sp.root && String(sp.root.launcherLogoMode) === "icon"
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "力"
            color: sp.accent
            font.pixelSize: wordmark.iconMode ? 76 : 44
            font.bold: true
            renderType: Text.QtRendering
        }
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !wordmark.iconMode
            text: "RYOKU"
            color: sp.fg
            font.family: sp.mono
            font.pixelSize: 24
            font.weight: Font.DemiBold
            font.letterSpacing: 7
        }
    }

    // ── workspaces: small markers (count from mode, glyph from style) ──
    Row {
        id: wsRow
        visible: sp.routeId === "workspaces"
        anchors.centerIn: parent
        spacing: 7
        readonly property int count: {
            var m = sp.root ? String(sp.root.workspaceMode) : "active"
            return m === "10" ? 10 : 5
        }
        readonly property string style: sp.root ? String(sp.root.workspaceStyle) : "default"
        readonly property int activeIndex: 1
        Repeater {
            model: wsRow.count
            delegate: Item {
                id: wsMark
                required property int index
                readonly property bool active: index === wsRow.activeIndex
                width: wsRow.style === "numbers" ? 20 : 13
                height: 20
                Rectangle {                                       // default: dots
                    visible: wsRow.style === "default"
                    anchors.centerIn: parent
                    width: 9; height: 9; radius: 4.5
                    color: wsMark.active ? sp.accent
                                         : Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.32)
                }
                Rectangle {                                       // magic: diamonds
                    visible: wsRow.style === "magic"
                    anchors.centerIn: parent
                    width: 9; height: 9; radius: 2; rotation: 45
                    color: wsMark.active ? sp.accent
                                         : Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.3)
                }
                Rectangle {                                       // numbers: digit badges
                    visible: wsRow.style === "numbers"
                    anchors.centerIn: parent
                    width: 18; height: 16
                    radius: sp.root ? sp.root.tileRadius : 4
                    color: wsMark.active && sp.root
                           ? Qt.rgba(sp.accent.r, sp.accent.g, sp.accent.b, sp.root.fillActiveAlpha)
                           : "transparent"
                    border.width: 1
                    border.color: wsMark.active ? sp.accent
                                                : Qt.rgba(sp.fg.r, sp.fg.g, sp.fg.b, 0.22)
                    UiText {
                        anchors.centerIn: parent
                        text: String(wsMark.index + 1)
                        color: wsMark.active ? sp.accent : sp.muted
                        font.family: sp.mono
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // ── pickers: a style-keyed thumbnail sketch ──
    Item {
        id: picker
        visible: sp.routeId === "pickers"
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        readonly property string style: sp.root ? String(sp.root.pickerStyle) : "tanzaku"
        readonly property color frame: sp.root ? sp.root.frameWeak
                                               : Qt.rgba(1, 1, 1, 0.05)
        readonly property color line:  sp.root ? sp.root.sep : Qt.rgba(1, 1, 1, 0.18)

        Row {                                                     // carousel: a strip of thumbs
            visible: picker.style === "carousel"
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 48; height: 64
                radius: sp.root ? sp.root.tileRadius : 6
                color: picker.frame; border.width: 1; border.color: picker.line
                opacity: 0.7
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 62; height: 82
                radius: sp.root ? sp.root.tileRadius : 6
                color: Qt.rgba(sp.accent.r, sp.accent.g, sp.accent.b, 0.10)
                border.width: 1; border.color: sp.accent
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 48; height: 64
                radius: sp.root ? sp.root.tileRadius : 6
                color: picker.frame; border.width: 1; border.color: picker.line
                opacity: 0.7
            }
        }

        Row {                                                     // tanzaku: vertical strips
            visible: picker.style === "tanzaku"
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index
                    readonly property bool mid: index === 2
                    width: 16; height: 96
                    radius: sp.root ? sp.root.tileRadius : 6
                    color: mid ? Qt.rgba(sp.accent.r, sp.accent.g, sp.accent.b, 0.12)
                               : picker.frame
                    border.width: 1
                    border.color: mid ? sp.accent : picker.line
                }
            }
        }

        Item {                                                    // hearthstone: fanned cards
            visible: picker.style === "hearthstone"
            anchors.centerIn: parent
            width: 120; height: 108
            Rectangle {
                anchors.centerIn: parent
                width: 78; height: 98
                radius: sp.root ? sp.root.tileRadius : 6
                rotation: 9
                color: picker.frame; border.width: 1; border.color: picker.line
                opacity: 0.6
            }
            Rectangle {
                anchors.centerIn: parent
                width: 78; height: 98
                radius: sp.root ? sp.root.tileRadius : 6
                rotation: -7
                color: Qt.rgba(sp.accent.r, sp.accent.g, sp.accent.b, 0.10)
                border.width: 1; border.color: sp.accent
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    height: 6; radius: 3
                    color: sp.accent
                }
            }
        }
    }
}
