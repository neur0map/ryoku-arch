pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../.." as Pill
import shell.services
import "../../../../components"

// The colour-scheme picker (contract 08 sec 2.2/2.3/4.2): a horizontally
// scrolling row of theme cards. Each card is a 100-wide, 120-tall rounded
// preview (radius 6) filled with the theme's surface colour, carrying the theme
// name in its own on-surface colour, a two-by-three grid of 16x16 swatches, and
// a check badge on the selected one. A single click applies the theme live.
//
// WHERE THE CATALOG LIVES. The static-theme palettes belong to the Go theme
// layer, not to QML: Theme.qml already documents `namedScheme` as the seam the
// daemon drives with the active preset's full 30-role palette, and applying a
// theme is a single settings write (theme.theme) that the daemon's style and
// wallpaper reactors consume (contract 08 sec 3.1/4.2). This picker only needs a
// lightweight preview projection -- label, dark/light and seven swatch colours
// per theme -- to draw the cards. That projection is the sole extension point
// below (`schemeSource`). It is deliberately the ONE place the 57-row table is
// materialised on the QML side; when a Go `theme` topic serves the catalog,
// bind `schemes` to the subscribed frame and delete the literal, and nothing
// else in this file changes. The full recolour stays Go's job through
// Theme.namedScheme; the picker owns only the selection intent and its badge.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    // The preview catalog the cards render from (the extension point). A future
    // Go `theme` topic replaces this with a subscribed frame.
    readonly property var schemes: schemeSource.catalog

    // The applied scheme id. Reflected from daemon settings when the topic is
    // live (see the subscription below) and set optimistically on click so the
    // badge tracks the pick immediately.
    property string activeId: ""

    implicitHeight: col.implicitHeight

    // Apply a scheme: write theme.theme through the settings seam (contract 14).
    // The daemon validates, persists and broadcasts, then its style reactor
    // recolours the shell via Theme.namedScheme and its wallpaper reactor
    // re-tints the desktop. Selecting never dismisses the menu.
    function select(id) {
        if (id.length === 0)
            return;
        root.activeId = id;
        ctl.queued += "call settings.patch " + JSON.stringify({ path: "theme.theme", value: id }) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    // Read the applied theme from the daemon so the badge reflects real state
    // (one-way, read-only). The settings frame is owned by the settings layer;
    // parse defensively so an unexpected or absent frame leaves the optimistic
    // selection untouched rather than wedging the picker.
    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser {
            onRead: line => {
                try {
                    const frame = JSON.parse(line);
                    if (frame && frame.theme && typeof frame.theme.theme === "string")
                        root.activeId = frame.theme.theme;
                } catch (e) {
                }
            }
        }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe settings\n");
                flush();
            } else {
                retry.restart();
            }
        }
    }
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }
    Socket {
        id: ctl
        path: root.sockPath
        property string queued: ""
        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }
        onConnectionStateChanged: if (connected) flushQueued()
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // Section title (contract 08 sec 2.2).
        Text {
            text: qsTr("Color Scheme")
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontXl
            font.weight: Font.Bold
        }

        // The card strip: fixed 100-wide cards, 8px apart, inset 32px from each
        // end, scrolling horizontally (contract 08 sec 2.2).
        ListView {
            id: strip
            width: parent.width
            height: 120
            clip: true
            orientation: ListView.Horizontal
            spacing: 8
            leftMargin: 32
            rightMargin: 32
            cacheBuffer: 1200
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            model: root.schemes
            delegate: Card {}

            // Vertical wheel drives horizontal scroll, 64px per notch, matching
            // the wallpaper grid (contract 08 sec 2.2).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const step = (event.angleDelta.y / 120) * 64;
                    const max = Math.max(0, strip.contentWidth + strip.leftMargin + strip.rightMargin - strip.width);
                    strip.contentX = Math.max(0, Math.min(max, strip.contentX - step));
                }
            }
        }
    }

    // One theme card. `sw` is the seven-swatch projection in reference order
    // [surface, onSurface, primary, secondary, tertiary, error, outline];
    // dynamic themes (Default, Wallpaper) carry no palette and show a glyph.
    component Card: Rectangle {
        id: card
        required property var modelData
        readonly property bool dynamic: modelData.dynamic === true
        readonly property var sw: card.dynamic ? [] : modelData.sw

        width: 100
        height: 120
        radius: Theme.radiusWidget
        color: "transparent"
        border.width: Theme.borderWidth
        // Outline at rest, on-surface on hover (the shell's roles; contract 08
        // sec 2.3); selection shows the badge, not a border change.
        border.color: cardHov.hovered ? Theme.onSurface : Theme.outline

        // The 120-tall preview: a radius-6 rounded rect filled with the theme's
        // own surface colour (dynamic themes use the shell surface).
        Rectangle {
            id: preview
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            radius: 6
            color: card.dynamic ? Theme.surface : card.sw[0]
            clip: true

            // Theme name, top-centred, in the theme's own on-surface colour.
            Text {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: card.modelData.label
                color: card.dynamic ? Theme.onSurface : card.sw[1]
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }

            // Dynamic themes render a 60px glyph instead of swatches.
            MaterialIcon {
                visible: card.dynamic
                anchors.centerIn: parent
                text: card.dynamic ? card.modelData.icon : ""
                font.pixelSize: 60
                color: Theme.onSurface
            }

            // Two rows of three 16x16 swatches, centred and reserving 26px at the
            // bottom for the badge (contract 08 sec 2.3).
            Column {
                visible: !card.dynamic
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                spacing: 8

                Row {
                    spacing: 8
                    Repeater {
                        model: card.dynamic ? [] : [card.sw[1], card.sw[2], card.sw[3]]
                        delegate: Rectangle {
                            required property color modelData
                            width: 16; height: 16
                            color: modelData
                        }
                    }
                }
                Row {
                    spacing: 8
                    Repeater {
                        model: card.dynamic ? [] : [card.sw[4], card.sw[5], card.sw[6]]
                        delegate: Rectangle {
                            required property color modelData
                            width: 16; height: 16
                            color: modelData
                        }
                    }
                }
            }

            // Selected badge: a filled check, bottom-left, 20px, margin 6
            // (contract 08 sec 2.3), in the theme's own on-surface colour.
            MaterialIcon {
                visible: root.activeId === card.modelData.id
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 6; bottomMargin: 6 }
                text: "check_circle"
                fill: 1
                font.pixelSize: 20
                color: card.dynamic ? Theme.onSurface : card.sw[1]
            }
        }

        HoverHandler { id: cardHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.select(card.modelData.id) }
    }

    // --- extension point: the static-theme preview catalog (contract 08 sec 8.1)
    // Two dynamic variants (icon cards, excluded from any dark/light filter) then
    // the 57 static themes, each `sw` = [surface, onSurface, primary, secondary,
    // tertiary, error, outline]. Lifted verbatim from the resolved contract; the
    // Go theme layer owns the authoritative table and the full 30-role palettes.
    QtObject {
        id: schemeSource
        readonly property var catalog: [
            { id: "Default", label: "Default", dynamic: true, icon: "palette" },
            { id: "Wallpaper", label: "Wallpaper", dynamic: true, icon: "wallpaper" },
            { id: "Bauhaus", label: "Bauhaus", dark: true, sw: ["#101318", "#EAEFF5", "#E37B66", "#E0A568", "#809D9E", "#CB886D", "#98A0AE"] },
            { id: "Black Turq", label: "Black Turq", dark: true, sw: ["#0a0a0a", "#c8dcdc", "#ADF0E9", "#8FECD5", "#A9D1D7", "#D35F5F", "#485362"] },
            { id: "Blood Rust", label: "Blood Rust", dark: true, sw: ["#1F2932", "#AFB3BD", "#7C545F", "#54737C", "#547C71", "#7C545F", "#2F3E4C"] },
            { id: "Boo", label: "Boo", dark: true, sw: ["#111113", "#e4dcec", "#9c75dd", "#63b0b0", "#5786bc", "#cd749c", "#5d6f74"] },
            { id: "Catppuccin Frappe", label: "Catppuccin Frappé", dark: true, sw: ["#303446", "#c6d0f5", "#babbf1", "#eebebe", "#81c8be", "#e78284", "#a5adce"] },
            { id: "Catppuccin Latte", label: "Catppuccin Latte", dark: false, sw: ["#eff1f5", "#4c4f69", "#7287fd", "#dd7878", "#179299", "#d20f39", "#6c6f85"] },
            { id: "Catppuccin Macchiato", label: "Catppuccin Macchiato", dark: true, sw: ["#24273a", "#cad3f5", "#b7bdf8", "#f0c6c6", "#8bd5ca", "#ed8796", "#a5adcb"] },
            { id: "Catppuccin Mocha", label: "Catppuccin Mocha", dark: true, sw: ["#1e1e2e", "#cdd6f4", "#b4befe", "#f2cdcd", "#94e2d5", "#f38ba8", "#a6adc8"] },
            { id: "Crimson Moonlight", label: "Crimson Moonlight", dark: true, sw: ["#0f0e0e", "#f9f2f3", "#e15774", "#fca2ae", "#714e75", "#dd5571", "#796769"] },
            { id: "Cyberpunk", label: "Cyberpunk", dark: true, sw: ["#000000", "#FFFF00", "#00FFFF", "#FF00FF", "#00FF00", "#FF0000", "#4B0082"] },
            { id: "Desert Power", label: "Desert Power", dark: true, sw: ["#11100F", "#A1A09F", "#55504D", "#8EBABB", "#AF8F6B", "#B5745A", "#33302D"] },
            { id: "Dracula", label: "Dracula", dark: true, sw: ["#282A36", "#F8F8F2", "#BD93F9", "#FF79C6", "#8BE9FD", "#FF5555", "#6272A4"] },
            { id: "Eldritch", label: "Eldritch", dark: true, sw: ["#212337", "#ebfafa", "#37f499", "#04d1f9", "#a48cf2", "#f16c75", "#7081d0"] },
            { id: "Ethereal", label: "Ethereal", dark: true, sw: ["#060B1E", "#ffcead", "#7d82d9", "#ffcead", "#c89dc1", "#ED5B5A", "#6d7db6"] },
            { id: "Everforest Dark Hard", label: "Everforest Dark Hard", dark: true, sw: ["#1E2326", "#D3C6AA", "#A7C080", "#7FBBB3", "#83C092", "#E67E80", "#7A8478"] },
            { id: "Everforest Dark Medium", label: "Everforest Dark Medium", dark: true, sw: ["#232A2E", "#D3C6AA", "#A7C080", "#7FBBB3", "#83C092", "#E67E80", "#7A8478"] },
            { id: "Everforest Dark Soft", label: "Everforest Dark Soft", dark: true, sw: ["#293136", "#D3C6AA", "#A7C080", "#7FBBB3", "#83C092", "#E67E80", "#7A8478"] },
            { id: "Everforest Light Hard", label: "Everforest Light Hard", dark: false, sw: ["#FFFBEF", "#5C6A72", "#8DA101", "#3A94C5", "#35A77C", "#F85552", "#A6B0A0"] },
            { id: "Everforest Light Medium", label: "Everforest Light Medium", dark: false, sw: ["#FDF6E3", "#5C6A72", "#8DA101", "#3A94C5", "#35A77C", "#F85552", "#A6B0A0"] },
            { id: "Everforest Light Soft", label: "Everforest Light Soft", dark: false, sw: ["#F3EAD3", "#5C6A72", "#8DA101", "#3A94C5", "#35A77C", "#F85552", "#A6B0A0"] },
            { id: "Forest Stream", label: "Forest Stream", dark: true, sw: ["#0b0c0b", "#e3f5e7", "#41b193", "#3788a2", "#7a77cd", "#c7566f", "#3c7153"] },
            { id: "Gruvbox Dark Hard", label: "Gruvbox Dark Hard", dark: true, sw: ["#1D2021", "#EBDBB2", "#83A598", "#B8BB26", "#8EC07C", "#FB4934", "#928374"] },
            { id: "Gruvbox Dark Medium", label: "Gruvbox Dark Medium", dark: true, sw: ["#282828", "#EBDBB2", "#83A598", "#B8BB26", "#8EC07C", "#FB4934", "#928374"] },
            { id: "Gruvbox Dark Soft", label: "Gruvbox Dark Soft", dark: true, sw: ["#32302F", "#EBDBB2", "#83A598", "#B8BB26", "#8EC07C", "#FB4934", "#928374"] },
            { id: "Gruvbox Light Hard", label: "Gruvbox Light Hard", dark: false, sw: ["#F9F5D7", "#3C3836", "#076678", "#79740E", "#427B58", "#9D0006", "#928374"] },
            { id: "Gruvbox Light Medium", label: "Gruvbox Light Medium", dark: false, sw: ["#FBF1C7", "#3C3836", "#076678", "#79740E", "#427B58", "#9D0006", "#928374"] },
            { id: "Gruvbox Light Soft", label: "Gruvbox Light Soft", dark: false, sw: ["#F2E5BC", "#3C3836", "#076678", "#79740E", "#427B58", "#9D0006", "#928374"] },
            { id: "Hackerman", label: "Hackerman", dark: true, sw: ["#0B0C16", "#ddf7ff", "#4fe88f", "#7cf8f7", "#829dd4", "#50f872", "#6a6e95"] },
            { id: "InkyPinky", label: "InkyPinky", dark: true, sw: ["#13131D", "#c8c8c8", "#EA90A8", "#7c7ca8", "#9f859f", "#EA90A8", "#7c7ca8"] },
            { id: "Kanagawa Dragon", label: "Kanagawa Dragon", dark: true, sw: ["#181616", "#c5c9c5", "#8ba4b0", "#8992a7", "#8ea4a2", "#E82424", "#7a8382"] },
            { id: "Kanagawa Lotus", label: "Kanagawa Lotus", dark: false, sw: ["#f2ecbc", "#545464", "#4d699b", "#624c83", "#597b75", "#e82424", "#716e61"] },
            { id: "Kanagawa Wave", label: "Kanagawa Wave", dark: true, sw: ["#1F1F28", "#DCD7BA", "#7E9CD8", "#957FB8", "#7AA89F", "#E82424", "#938AA9"] },
            { id: "Miasma", label: "Miasma", dark: true, sw: ["#222222", "#c2c2b0", "#5f875f", "#c9a554", "#bb7744", "#685742", "#666666"] },
            { id: "Monokai Classic", label: "Monokai Classic", dark: true, sw: ["#221F22", "#FCFCFA", "#A9DC76", "#FFD866", "#FF6188", "#FF6188", "#727072"] },
            { id: "Nightfox", label: "Nightfox", dark: true, sw: ["#192330", "#cdcecf", "#719cd6", "#9d79d6", "#63cdcf", "#c94f6d", "#39506d"] },
            { id: "Nord Dark", label: "Nord Dark", dark: true, sw: ["#2E3440", "#ECEFF4", "#88C0D0", "#81A1C1", "#8FBCBB", "#BF616A", "#4C566A"] },
            { id: "Nord Light", label: "Nord Light", dark: false, sw: ["#ECEFF4", "#2E3440", "#5E81AC", "#81A1C1", "#8FBCBB", "#BF616A", "#D8DEE9"] },
            { id: "Oceanic Next", label: "Oceanic Next", dark: true, sw: ["#1B2B34", "#D8DEE9", "#6699CC", "#5FB3B3", "#99C794", "#EC5F67", "#4F5B66"] },
            { id: "One Dark", label: "One Dark", dark: true, sw: ["#282C34", "#ABB2BF", "#61AFEF", "#C678DD", "#56B6C2", "#E06C75", "#636D83"] },
            { id: "Osaka Jade", label: "Osaka Jade", dark: true, sw: ["#111c18", "#C1C497", "#509475", "#2DD5B7", "#D2689C", "#FF5345", "#53685B"] },
            { id: "Poimandres", label: "Poimandres", dark: true, sw: ["#1B1E28", "#E4F0FB", "#ADD7FF", "#5DE4C7", "#FCC5E9", "#D0679D", "#767C9D"] },
            { id: "Radioactive", label: "Radioactive", dark: true, sw: ["#1a1a14", "#d9d9cf", "#bbbc57", "#7b6c97", "#e3e3a8", "#cd749c", "#74745d"] },
            { id: "Retro 82", label: "Retro 82", dark: true, sw: ["#00172e", "#f6dcac", "#faa968", "#028391", "#f85525", "#f85525", "#3f8f8a"] },
            { id: "Rose Pine", label: "Rosé Pine", dark: true, sw: ["#191724", "#E0DEF4", "#C4A7E7", "#9CCFD8", "#EBBCBA", "#EB6F92", "#6E6A86"] },
            { id: "Rose Pine Dawn", label: "Rosé Pine Dawn", dark: false, sw: ["#FAF4ED", "#575279", "#907AA9", "#56949F", "#D7827E", "#B4637A", "#9893A5"] },
            { id: "Rose Pine Moon", label: "Rosé Pine Moon", dark: true, sw: ["#232136", "#E0DEF4", "#C4A7E7", "#9CCFD8", "#EA9A97", "#EB6F92", "#6E6A86"] },
            { id: "Saga", label: "Saga", dark: true, sw: ["#05080a", "#fff6ff", "#b2fff3", "#dfbaff", "#ff9fbc", "#ff9fbc", "#4b4c4d"] },
            { id: "Seoul", label: "Seoul", dark: true, sw: ["#333233", "#DFDEBD", "#9A7372", "#98BC99", "#98BCBD", "#BE7572", "#565656"] },
            { id: "Solarized Dark", label: "Solarized Dark", dark: true, sw: ["#002b36", "#93a1a1", "#268bd2", "#2aa198", "#b58900", "#dc322f", "#839496"] },
            { id: "Solarized Light", label: "Solarized Light", dark: false, sw: ["#fdf6e3", "#586e75", "#268bd2", "#2aa198", "#b58900", "#dc322f", "#657b83"] },
            { id: "Solitude", label: "Solitude", dark: true, sw: ["#101315", "#cacccc", "#798186", "#a8adb0", "#de6145", "#de6145", "#565d60"] },
            { id: "Sunset Cloud", label: "Sunset Cloud", dark: true, sw: ["#0e0f06", "#ffffcf", "#bbc373", "#cd6d91", "#71d17c", "#bc5050", "#5d6f74"] },
            { id: "Synthwave 84", label: "Synthwave 84", dark: true, sw: ["#18191F", "#C4C4D6", "#FF536C", "#7F9FFF", "#C080FF", "#FF536C", "#484953"] },
            { id: "Tokyo Night", label: "Tokyo Night", dark: true, sw: ["#1a1b26", "#a9b1d6", "#7aa2f7", "#bb9af7", "#73daca", "#f7768e", "#9aa5ce"] },
            { id: "Tokyo Night Storm", label: "Tokyo Night Storm", dark: true, sw: ["#24283b", "#a9b1d6", "#7aa2f7", "#bb9af7", "#73daca", "#f7768e", "#9aa5ce"] },
            { id: "Tokyo Night Light", label: "Tokyo Night Light", dark: false, sw: ["#e6e7ed", "#343b58", "#2959aa", "#5a3e8e", "#33635c", "#8c4351", "#6c6e75"] },
            { id: "Varda", label: "Varda", dark: true, sw: ["#0C0E11", "#D0EBEE", "#52677C", "#665276", "#257B76", "#733447", "#8295A9"] }
        ]
    }
}
