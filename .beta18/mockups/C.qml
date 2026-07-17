import QtQuick
import Quickshell

// Ryoku Hub — mock C: THE SHEET. No rail, no tabs, no pages, no back button.
// Every group is a placard on one surface, sized to its weight, art centred in
// the field. The filter is the only navigation — which forces the schema.
// Composition is the acid-grotesk sticker sheet, not a settings app.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — C"
        minimumSize: Qt.size(1200, 780)
        color: "#000000"
        onClosed: Qt.quit()

        Item {
            anchors.fill: parent

            QtObject {
                id: tk
                readonly property color paper: "#000000"
                readonly property color ink: "#c2b9b0"
                readonly property color inkDim: "#8a837c"
                readonly property color inkFaint: "#4e4a45"
                readonly property color line: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.20)
                readonly property color lineSoft: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.08)
                readonly property int r: 1
                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "JetBrainsMono Nerd Font"
            }

            Rectangle { anchors.fill: parent; color: tk.paper }
            Image { anchors.fill: parent; source: "grain.png"; fillMode: Image.Tile; opacity: 0.055; z: 99 }

            // ── the one piece of chrome: the command field ────────────────
            Item {
                id: cmd
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 54
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    spacing: 10
                    Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 1; height: 15; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "RYOKU ARCH"; color: tk.ink; font.family: tk.mono; font.pixelSize: 10; font.letterSpacing: 2.4; anchors.verticalCenter: parent.verticalCenter }
                }
                // the filter IS the navigation
                Rectangle {
                    anchors.centerIn: parent
                    width: 520; height: 30
                    color: "transparent"
                    radius: tk.r
                    border.width: 1
                    border.color: tk.line
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        Text { text: "Filter 247 settings…"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Item { width: parent.width - 260; height: 1 }
                        Text { text: "27 GROUPS · 3 CHANGED"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle { x: 11; width: 1; height: 14; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    spacing: 8
                    Text { text: "SAVED · LIVE"; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.2; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 5; height: 5; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.line }
            }

            // ── the sheet ────────────────────────────────────────────────
            Item {
                id: sheet
                anchors { left: parent.left; right: parent.right; top: cmd.bottom; bottom: parent.bottom }
                anchors.margins: 22

                readonly property int cols: 6
                readonly property int gut: 9
                readonly property real cw: (width - (cols - 1) * gut) / cols
                readonly property int rh: 96
                function px(c) { return c * (cw + gut) }
                function py(r) { return r * (rh + gut) }
                function pw(s) { return s * cw + (s - 1) * gut }
                function ph(s) { return s * rh + (s - 1) * gut }

                // every placard is a group. sized by weight, like the sheet.
                Repeater {
                    model: [
                        // col, span, row, rowspan, kind, label, value, unit, sub
                        { c: 0, s: 1, r: 0, rs: 1, k: "sw",   l: "FRAME",       v: "ON",   u: "",   b: "enabled" },
                        { c: 1, s: 1, r: 0, rs: 1, k: "num",  l: "BORDER",      v: "57",   u: "px", b: "▸ 24 px" },
                        { c: 4, s: 1, r: 0, rs: 1, k: "num",  l: "CPU",         v: "17",   u: "%",  b: "8 × 3.4 GHz" },
                        { c: 5, s: 1, r: 0, rs: 1, k: "num",  l: "MEMORY",      v: "20",   u: "%",  b: "6.4 / 32 GB" },

                        { c: 0, s: 1, r: 1, rs: 1, k: "num",  l: "RADIUS",      v: "1",    u: "px", b: "▸ 10 px" },
                        { c: 1, s: 1, r: 1, rs: 1, k: "seg",  l: "BAR",         v: "TOP",  u: "",   b: "noctalia", a: "BOT" },
                        { c: 4, s: 1, r: 1, rs: 1, k: "num",  l: "GPU",         v: "05",   u: "%",  b: "amdgpu 65°" },
                        { c: 5, s: 1, r: 1, rs: 1, k: "num",  l: "DISK",        v: "41",   u: "%",  b: "418/1024" },

                        { c: 0, s: 2, r: 2, rs: 1, k: "slid", l: "OPACITY",     v: "100",  u: "%",  b: "notifications" },
                        { c: 4, s: 2, r: 2, rs: 1, k: "slid", l: "VIZ GAIN",    v: "62",   u: "%",  b: "visualizer" },

                        { c: 0, s: 1, r: 3, rs: 1, k: "sw",   l: "BLUR",        v: "OFF",  u: "",   b: "▸ on" },
                        { c: 1, s: 1, r: 3, rs: 1, k: "sw",   l: "VISUALISER",  v: "OFF",  u: "",   b: "cava" },
                        { c: 4, s: 1, r: 3, rs: 1, k: "num",  l: "UPTIME",      v: "6",    u: "h",  b: "12 m" },
                        { c: 5, s: 1, r: 3, rs: 1, k: "num",  l: "THERMAL",     v: "65",   u: "°C", b: "max 91" },

                        { c: 0, s: 2, r: 4, rs: 1, k: "seg",  l: "SIDEBAR",     v: "HOVER", u: "", b: "reveal", a: "CLICK" },
                        { c: 4, s: 2, r: 4, rs: 1, k: "num",  l: "OSD CORNER",  v: "28",   u: "px", b: "toast" },
                        { c: 2, s: 2, r: 4, rs: 1, k: "seg",  l: "WALLPAPER",   v: "FILL", u: "",   b: "wallust on", a: "FIT" },

                        { c: 0, s: 1, r: 5, rs: 1, k: "num",  l: "GAPS",        v: "8",    u: "px", b: "inner" },
                        { c: 1, s: 1, r: 5, rs: 1, k: "num",  l: "ROUNDING",    v: "10",   u: "px", b: "windows" },
                        { c: 2, s: 1, r: 5, rs: 1, k: "sw",   l: "ANIMATIONS",  v: "ON",   u: "",   b: "reduce off" },
                        { c: 3, s: 1, r: 5, rs: 1, k: "num",  l: "DISPLAYS",    v: "01",   u: "",   b: "eDP-1 · 1.25" },
                        { c: 4, s: 1, r: 5, rs: 1, k: "num",  l: "KEY REPEAT",  v: "40",   u: "ms", b: "input" },
                        { c: 5, s: 1, r: 5, rs: 1, k: "num",  l: "UPDATES",     v: "03",   u: "",   b: "unstable" }
                    ]
                    Rectangle {
                        x: sheet.px(modelData.c); y: sheet.py(modelData.r)
                        width: sheet.pw(modelData.s); height: sheet.ph(modelData.rs)
                        color: "transparent"; radius: tk.r
                        border.width: 1; border.color: tk.line

                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 1
                            Text { text: modelData.l; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.5 }
                            Row {
                                spacing: 3
                                Text { text: modelData.v; color: tk.ink; font.family: tk.mono; font.pixelSize: modelData.v.length > 3 ? 20 : 28; font.weight: Font.Light }
                                Text { text: modelData.u; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 5 }
                            }
                        }
                        // control sits at the placard's foot — every group is
                        // operable in place. no drilling in.
                        Item {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 9 }
                            height: 18
                            Text {
                                text: modelData.b
                                color: tk.inkFaint
                                font.family: tk.mono
                                font.pixelSize: 8
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            // switch
                            Rectangle {
                                visible: modelData.k === "sw"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 40; height: 17; radius: tk.r; antialiasing: false
                                color: "transparent"; border.width: 1; border.color: tk.line
                                Rectangle {
                                    width: 19; height: 12; y: 2; antialiasing: false
                                    x: modelData.v === "ON" ? parent.width - width - 2 : 2
                                    color: modelData.v === "ON" ? tk.ink : "transparent"
                                    border.width: modelData.v === "ON" ? 0 : 1
                                    border.color: tk.line
                                }
                            }
                            // stepper
                            Row {
                                visible: modelData.k === "num"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Repeater {
                                    model: ["−", "+"]
                                    Rectangle {
                                        width: 21; height: 17; radius: tk.r
                                        color: "transparent"; border.width: 1; border.color: tk.line
                                        Text { anchors.centerIn: parent; text: modelData; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 9 }
                                    }
                                }
                            }
                            // segmented
                            Row {
                                visible: modelData.k === "seg"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Repeater {
                                    model: 2
                                    Rectangle {
                                        width: 32; height: 17; radius: tk.r
                                        color: index === 0 ? tk.ink : "transparent"
                                        border.width: 1; border.color: tk.line
                                        Text {
                                            anchors.centerIn: parent
                                            text: index === 0 ? modelData.v : (modelData.a !== undefined ? modelData.a : "ALT")
                                            color: index === 0 ? tk.paper : tk.inkDim
                                            font.family: tk.mono; font.pixelSize: 7
                                        }
                                    }
                                }
                            }
                            // slider
                            Item {
                                visible: modelData.k === "slid"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 118; height: 17
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; color: "transparent"; border.width: 1; border.color: tk.line; antialiasing: false }
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * (parseInt(modelData.v) / 100); height: 3; color: tk.ink; antialiasing: false }
                                Rectangle { x: Math.min(parent.width - 5, parent.width * (parseInt(modelData.v) / 100) - 2); anchors.verticalCenter: parent.verticalCenter; width: 5; height: 13; color: tk.ink; antialiasing: false }
                            }
                        }
                    }
                }

                // ART — a placard in the field, centred. not a hero, a specimen.
                Rectangle {
                    x: sheet.px(2); y: sheet.py(0)
                    width: sheet.pw(2); height: sheet.ph(4)
                    color: "transparent"; radius: tk.r
                    border.width: 1; border.color: tk.line
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var c = getContext("2d");
                            c.strokeStyle = "rgba(194,185,176,0.09)"; c.lineWidth = 1;
                            c.beginPath(); c.moveTo(0, 0); c.lineTo(width, height);
                            c.moveTo(width, 0); c.lineTo(0, height); c.stroke();
                        }
                    }
                    Text {
                        text: "力 の 器"
                        color: tk.inkFaint
                        font.family: "Noto Sans CJK JP"
                        font.pixelSize: 11
                        rotation: 90
                        anchors.right: parent.right; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "⊕"; color: tk.inkFaint; font.pixelSize: 20; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "ART · TO REGENERATE"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.6; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "1504 × 1128"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 7; opacity: 0.7; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    // the specimen caption — inverted, the one loud object on the sheet
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
                        height: 62
                        color: tk.ink; radius: tk.r
                        Column {
                            anchors.fill: parent; anchors.margins: 8; spacing: 3
                            Text { text: "RYOKU ARCH · RY-0142"; color: tk.paper; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.3 }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.25) }
                            Row {
                                spacing: 12
                                Repeater {
                                    model: [["KERNEL", "7.1.3"], ["WM", "Hyprland"], ["BUILD", "0.12.9"]]
                                    Column {
                                        spacing: 0
                                        Text { text: modelData[0]; color: Qt.rgba(0, 0, 0, 0.45); font.family: tk.mono; font.pixelSize: 7 }
                                        Text { text: modelData[1]; color: tk.paper; font.family: tk.mono; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── the index field: all 27 groups, as marks. not a rail —
                // a field you scan, exactly like the sticker sheet.
                Item {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 106
                    Row {
                        id: idxHead
                        spacing: 8
                        Text { text: "INDEX"; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.6 }
                        Text { text: "ALL 27 GROUPS ON ONE SURFACE · NOTHING IS BEHIND A MENU"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 0.8; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle { y: 20; width: parent.width; height: 1; color: tk.line }
                    Flow {
                        y: 30
                        width: parent.width
                        spacing: 5
                        Repeater {
                            model: [
                                "PROFILE", "APPEARANCE", "SHELL", "APP LAUNCHER", "FASTFETCH", "DESKTOP WIDGETS",
                                "LOCKSCREEN", "ANIMATIONS", "DISPLAYS", "INPUT", "GPU", "PERFORMANCE",
                                "RECORDING", "DICTATION", "UPDATES", "CONNECTIONS", "AUTOSTART", "ENVIRONMENT",
                                "KEYBINDS", "WINDOW RULES", "LAYER RULES", "APP OVERRIDES", "RICES", "PLUGINS",
                                "EXTRAS", "RASHIN", "CREDITS"
                            ]
                            Rectangle {
                                implicitWidth: ixl.width + 16
                                height: 20
                                radius: tk.r
                                color: modelData === "SHELL" ? tk.ink : "transparent"
                                border.width: 1
                                border.color: modelData === "SHELL" ? tk.ink : tk.lineSoft
                                Text {
                                    id: ixl
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData === "SHELL" ? tk.paper : tk.inkFaint
                                    font.family: tk.mono
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
