import QtQuick
import Quickshell

// Ryoku Hub — mock B: desktop layout. Rail + content, 1px corners.
// Same paper/ink as A. Settings render as a TABLE (the aeonik lesson), and
// the values are the heroes — that is what kills the void.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — B"
        minimumSize: Qt.size(1100, 720)
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
                readonly property color line: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.18)
                readonly property color lineSoft: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.07)
                readonly property int r: 1
                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "JetBrainsMono Nerd Font"
            }

            Rectangle { anchors.fill: parent; color: tk.paper }
            Image { anchors.fill: parent; source: "grain.png"; fillMode: Image.Tile; opacity: 0.055; z: 99 }

            component Label: Text {
                color: tk.inkDim
                font.family: tk.mono
                font.pixelSize: 9
                font.letterSpacing: 1.6
            }
            component Panel: Rectangle {
                color: "transparent"
                radius: tk.r
                border.width: 1
                border.color: tk.line
            }
            component Btn: Rectangle {
                property alias text: bl.text
                property bool solid: false
                implicitWidth: bl.width + 24
                implicitHeight: 26
                radius: tk.r
                color: solid ? tk.ink : "transparent"
                border.width: 1
                border.color: solid ? tk.ink : tk.line
                Text {
                    id: bl
                    anchors.centerIn: parent
                    color: parent.solid ? tk.paper : tk.inkDim
                    font.family: tk.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.3
                }
            }
            // square machine switch — ryovm's physics, no colour, ON/OFF spelled out
            component Sw: Rectangle {
                property bool on: false
                width: 46; height: 20; radius: tk.r
                color: "transparent"
                border.width: 1
                border.color: tk.line
                antialiasing: false
                Rectangle {
                    width: 22; height: 14; radius: tk.r
                    y: 2
                    x: parent.on ? parent.width - width - 3 : 3
                    color: parent.on ? tk.ink : "transparent"
                    border.width: parent.on ? 0 : 1
                    border.color: tk.line
                    antialiasing: false
                }
                Text {
                    text: parent.on ? "ON" : "OFF"
                    color: tk.inkFaint
                    font.family: tk.mono
                    font.pixelSize: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.on ? 7 : parent.width - width - 7
                }
            }

            // ── nav rail ─────────────────────────────────────────────────
            Item {
                id: rail
                anchors { left: parent.left; top: parent.top; bottom: bar.top }
                width: 232
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: tk.line }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Row {
                        spacing: 8
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 17 }
                        Column {
                            spacing: 0
                            Text { text: "RYOKU ARCH"; color: tk.ink; font.family: tk.mono; font.pixelSize: 11; font.letterSpacing: 2 }
                            Text { text: "system and shell settings"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 9 }
                        }
                    }

                    Panel {
                        width: parent.width; height: 28
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            Text { text: "Search…"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 120; height: 1 }
                            Text { text: "CTRL K"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 0
                        Repeater {
                            model: [
                                { g: 1, t: "PROFILE" },
                                { g: 0, t: "SYSTEM" },
                                { g: 1, t: "Updates" },
                                { g: 1, t: "Displays" },
                                { g: 0, t: "DESKTOP" },
                                { g: 1, t: "Appearance" },
                                { g: 2, t: "Shell" },
                                { g: 1, t: "App Launcher" },
                                { g: 1, t: "Fastfetch" },
                                { g: 1, t: "Desktop Widgets" },
                                { g: 1, t: "Lockscreen" },
                                { g: 1, t: "Animations" },
                                { g: 0, t: "ADD-ONS" },
                                { g: 1, t: "Store" },
                                { g: 1, t: "Plugins" },
                                { g: 0, t: "ADVANCED" },
                                { g: 1, t: "Keybinds" },
                                { g: 1, t: "Window Rules" }
                            ]
                            Item {
                                width: parent.width
                                height: modelData.g === 0 ? 26 : 24

                                // group header
                                Row {
                                    visible: modelData.g === 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 7
                                    Rectangle { width: 3; height: 3; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.t; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.8; anchors.verticalCenter: parent.verticalCenter }
                                    Rectangle { width: 96; height: 1; color: tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                                }

                                // selected row = inverted. no accent.
                                Rectangle {
                                    visible: modelData.g === 2
                                    anchors.fill: parent
                                    anchors.topMargin: 1
                                    anchors.bottomMargin: 1
                                    color: tk.ink
                                    radius: tk.r
                                }
                                Text {
                                    visible: modelData.g > 0
                                    text: modelData.t
                                    color: modelData.g === 2 ? tk.paper : tk.inkDim
                                    font.family: tk.ui
                                    font.pixelSize: 12
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 18; bottom: parent.bottom; bottomMargin: 14 }
                    text: "力  ryoku desktop"
                    color: tk.inkFaint
                    font.family: tk.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1
                }
            }

            // ── content ──────────────────────────────────────────────────
            Item {
                anchors { left: rail.right; right: parent.right; top: parent.top; bottom: bar.top }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 26
                    anchors.rightMargin: 26
                    anchors.topMargin: 16
                    anchors.bottomMargin: 10
                    spacing: 10

                    // eyebrow
                    Row {
                        spacing: 7
                        Rectangle { width: 14; height: 1; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "DESKTOP"; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.8; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        spacing: 14
                        Text { text: "Shell"; color: tk.ink; font.family: tk.display; font.pixelSize: 34; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "EDIT CONFIG"; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "REVEAL"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "Tune the Ryoku shell: the frame, the bar, notifications, and the desktop visualiser."; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11 }

                    Item { width: 1; height: 1 }

                    Row {
                        spacing: 0
                        Repeater {
                            model: ["FRAME", "GLOBAL", "BAR", "SIDEBAR", "VISUALIZER"]
                            Rectangle {
                                width: 92; height: 26
                                color: index === 0 ? tk.ink : "transparent"
                                border.width: 1
                                border.color: tk.line
                                radius: tk.r
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: index === 0 ? tk.paper : tk.inkDim
                                    font.family: tk.mono
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.2
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 2 }

                    // hero cards — diagram + label/value stack, straight from aeonik
                    Row {
                        spacing: 12
                        Panel {
                            width: 300; height: 158
                            Row {
                                anchors.fill: parent; anchors.margins: 13; spacing: 14
                                Column {
                                    width: 108
                                    spacing: 3
                                    Text { text: "FRAME"; color: tk.ink; font.family: tk.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
                                    Text { text: "Enabled"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 9 }
                                    Item { width: 1; height: 5 }
                                    // line diagram: the frame, drawn
                                    Canvas {
                                        width: 100; height: 78
                                        onPaint: {
                                            var c = getContext("2d");
                                            c.strokeStyle = "rgba(194,185,176,0.55)";
                                            c.lineWidth = 1;
                                            c.strokeRect(4.5, 6.5, 91, 62);
                                            c.strokeStyle = "rgba(194,185,176,0.22)";
                                            c.strokeRect(11.5, 13.5, 77, 48);
                                            c.fillStyle = "rgba(194,185,176,0.5)";
                                            c.fillRect(30, 9, 40, 4);
                                        }
                                    }
                                }
                                Column {
                                    spacing: 7
                                    Repeater {
                                        model: [["BORDER", "57", "px"], ["RADIUS", "1", "px"], ["OPACITY", "100", "%"]]
                                        Column {
                                            spacing: 0
                                            Text { text: modelData[0]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1 }
                                            Row {
                                                spacing: 3
                                                Text { text: modelData[1]; color: tk.ink; font.family: tk.mono; font.pixelSize: 24; font.weight: Font.Light }
                                                Text { text: modelData[2]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            width: 300; height: 158
                            Row {
                                anchors.fill: parent; anchors.margins: 13; spacing: 14
                                Column {
                                    width: 108
                                    spacing: 3
                                    Text { text: "NOTIFICATIONS"; color: tk.ink; font.family: tk.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
                                    Text { text: "Top right"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 9 }
                                    Item { width: 1; height: 5 }
                                    Canvas {
                                        width: 100; height: 78
                                        onPaint: {
                                            var c = getContext("2d");
                                            c.strokeStyle = "rgba(194,185,176,0.22)";
                                            c.lineWidth = 1;
                                            c.strokeRect(4.5, 6.5, 91, 62);
                                            c.strokeStyle = "rgba(194,185,176,0.55)";
                                            c.strokeRect(52.5, 12.5, 38, 17);
                                            c.strokeStyle = "rgba(194,185,176,0.25)";
                                            c.strokeRect(52.5, 33.5, 38, 17);
                                            for (var i = 0; i < 3; i++) {
                                                c.fillStyle = "rgba(194,185,176,0.30)";
                                                c.fillRect(56, 17 + i * 4, 26 - i * 7, 2);
                                            }
                                        }
                                    }
                                }
                                Column {
                                    spacing: 7
                                    Repeater {
                                        model: [["CORNER", "28", "px"], ["TIMEOUT", "6", "s"], ["OPACITY", "100", "%"]]
                                        Column {
                                            spacing: 0
                                            Text { text: modelData[0]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1 }
                                            Row {
                                                spacing: 3
                                                Text { text: modelData[1]; color: tk.ink; font.family: tk.mono; font.pixelSize: 24; font.weight: Font.Light }
                                                Text { text: modelData[2]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // live preview slot — the art/preview is a keyline for now
                        Panel {
                            width: 300; height: 158
                            Column {
                                anchors.fill: parent; anchors.margins: 13; spacing: 5
                                Row {
                                    width: parent.width
                                    Text { text: "LIVE PREVIEW"; color: tk.ink; font.family: tk.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
                                    Item { width: parent.width - 158; height: 1 }
                                    Text { text: "eDP-1"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8 }
                                }
                                Rectangle {
                                    width: parent.width; height: 112
                                    color: "transparent"
                                    border.width: 1
                                    border.color: tk.lineSoft
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var c = getContext("2d");
                                            c.strokeStyle = "rgba(194,185,176,0.10)";
                                            c.lineWidth = 1;
                                            c.beginPath(); c.moveTo(0, 0); c.lineTo(width, height);
                                            c.moveTo(width, 0); c.lineTo(0, height); c.stroke();
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "PREVIEW · TO REGENERATE"
                                        color: tk.inkFaint
                                        font.family: tk.mono
                                        font.pixelSize: 8
                                        font.letterSpacing: 1.4
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 4 }

                    // ── the table ────────────────────────────────────────
                    Row {
                        spacing: 8
                        Text { text: "+ADD"; color: tk.ink; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.4 }
                        Text { text: "12 SETTINGS · 3 CHANGED"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width
                        spacing: 0

                        Item {
                            width: parent.width; height: 22
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "SETTING"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.4; width: 300 }
                                Text { text: "VALUE"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.4; width: 120 }
                                Text { text: "RANGE"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.4; width: 130 }
                                Text { text: "DEFAULT"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.4; width: 110 }
                                Text { text: "SOURCE"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.4; width: 190 }
                                Text { text: "CONTROL"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1.4; width: 140 }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.line }
                        }

                        Repeater {
                            model: [
                                { n: "Enable frame", v: "ON", r: "—", d: "ON", s: "shell.json", t: "sw", on: true },
                                { n: "Border thickness", v: "57", u: "px", r: "0 – 120", d: "24 px", s: "shell.json", t: "step", hot: true },
                                { n: "Frame radius", v: "1", u: "px", r: "0 – 40", d: "10 px", s: "shell.json", t: "step", hot: true },
                                { n: "OSD & toast corner", v: "28", u: "px", r: "0 – 64", d: "28 px", s: "shell.json", t: "step" },
                                { n: "Notification opacity", v: "100", u: "%", r: "20 – 100", d: "100 %", s: "shell.json", t: "slider", fill: 1.0 },
                                { n: "Bar position", v: "TOP", r: "top | bottom", d: "TOP", s: "shell.json", t: "seg" },
                                { n: "Bar skin", v: "NOCT", r: "noct | cael", d: "NOCT", s: "shell.json", t: "seg2" },
                                { n: "Sidebar reveal", v: "HOVER", r: "hover | click", d: "HOVER", s: "shell.json", t: "seg3" },
                                { n: "Blur behind popouts", v: "OFF", r: "—", d: "ON", s: "shell.json", t: "sw", on: false, hot: true },
                                { n: "Visualiser", v: "OFF", r: "—", d: "OFF", s: "visualizer.json", t: "sw", on: false },
                                { n: "Visualiser gain", v: "62", u: "%", r: "0 – 100", d: "50 %", s: "visualizer.json", t: "slider", fill: 0.62 },
                                { n: "Brand mark", v: "力", r: "glyph", d: "力", s: "brand.json", t: "step" }
                            ]
                            Item {
                                width: parent.width
                                height: 35
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: modelData.n
                                        color: modelData.hot ? tk.ink : tk.inkDim
                                        font.family: tk.ui
                                        font.pixelSize: 12
                                        font.weight: modelData.hot ? Font.DemiBold : Font.Normal
                                        width: 300
                                    }
                                    Row {
                                        width: 120
                                        spacing: 3
                                        Text { text: modelData.v; color: tk.ink; font.family: tk.mono; font.pixelSize: 17; font.weight: Font.Light }
                                        Text { text: modelData.u !== undefined ? modelData.u : ""; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 3 }
                                    }
                                    Text { text: modelData.r; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; width: 130 }
                                    // changed-from-default is marked by a tick, not a colour
                                    Row {
                                        width: 110
                                        spacing: 5
                                        Text { text: modelData.hot === true ? "▸" : " "; color: tk.ink; font.family: tk.mono; font.pixelSize: 8 }
                                        Text { text: modelData.d; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9 }
                                    }
                                    Text { text: modelData.s; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; width: 190 }
                                }
                                // control lives at the row's right edge
                                Item {
                                    x: 850
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 140; height: 22
                                    Sw { visible: modelData.t === "sw"; on: modelData.on === true; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                                    Row {
                                        visible: modelData.t === "step"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0
                                        Repeater {
                                            model: ["−", "+"]
                                            Rectangle {
                                                width: 24; height: 20; radius: tk.r
                                                color: "transparent"; border.width: 1; border.color: tk.line
                                                Text { anchors.centerIn: parent; text: modelData; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 10 }
                                            }
                                        }
                                    }
                                    // slider: a machined track + a square stop, no glow
                                    Item {
                                        visible: modelData.t === "slider"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 116; height: 20
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; color: "transparent"; border.width: 1; border.color: tk.line; antialiasing: false }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * (modelData.fill !== undefined ? modelData.fill : 1)
                                            height: 3; color: tk.ink; antialiasing: false
                                        }
                                        Rectangle {
                                            x: Math.min(parent.width - 5, parent.width * (modelData.fill !== undefined ? modelData.fill : 1) - 2)
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 5; height: 14; color: tk.ink; antialiasing: false
                                        }
                                    }
                                    Row {
                                        visible: modelData.t === "seg" || modelData.t === "seg2" || modelData.t === "seg3"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0
                                        Repeater {
                                            model: modelData.t === "seg" ? ["TOP", "BOT"] : (modelData.t === "seg2" ? ["NOCT", "CAEL"] : ["HOVER", "CLICK"])
                                            Rectangle {
                                                width: 40; height: 20; radius: tk.r
                                                color: index === 0 ? tk.ink : "transparent"
                                                border.width: 1; border.color: tk.line
                                                Text { anchors.centerIn: parent; text: modelData; color: index === 0 ? tk.paper : tk.inkDim; font.family: tk.mono; font.pixelSize: 8 }
                                            }
                                        }
                                    }
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.lineSoft }
                            }
                        }
                    }
                }
            }

            // ── action bar ───────────────────────────────────────────────
            Item {
                id: bar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 52
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: tk.line }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    spacing: 8
                    Rectangle { width: 5; height: 5; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "SAVED · LIVE ON YOUR DESKTOP"; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.3; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 26
                    spacing: 8
                    Btn { text: "RESET TO DEFAULTS" }
                    Btn { text: "REVERT" }
                    Btn { text: "SAVE"; solid: true }
                }
            }
        }
    }
}
