import QtQuick
import Quickshell

// Ryoku Hub — mock B2. B's layout at a normal desktop scale, 2px corners.
// Type: Space Grotesk carries labels + numerals (it is the nearest thing to the
// acid-grotesk reference); mono is demoted to tabular data only — that is what
// stops it reading as a terminal. Motion is mechanical, never eased-floaty.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — B2"
        minimumSize: Qt.size(1280, 820)
        color: "#000000"
        onClosed: Qt.quit()

        Item {
            id: root
            anchors.fill: parent

            QtObject {
                id: tk
                readonly property color paper: "#000000"
                readonly property color ink: "#c2b9b0"
                readonly property color inkDim: "#8a837c"
                readonly property color inkFaint: "#565049"
                readonly property color line: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.20)
                readonly property color lineSoft: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.08)
                readonly property int r: 2
                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "JetBrainsMono Nerd Font"
                // motion: short, mechanical. a machine snaps, it does not drift.
                readonly property int snap: 90
                readonly property int move: 170
                readonly property int swap: 210
            }

            property int tab: 0
            readonly property var tabs: ["FRAME", "GLOBAL", "BAR", "SIDEBAR", "VISUALIZER"]
            property int navSel: 7

            Rectangle { anchors.fill: parent; color: tk.paper }
            Image { anchors.fill: parent; source: "grain.png"; fillMode: Image.Tile; opacity: 0.055; z: 99 }

            // value that flips when it changes — the flap idiom, 110ms
            component Flap: Item {
                property string text: ""
                property int size: 34
                implicitWidth: t.width
                implicitHeight: t.height
                Text {
                    id: t
                    text: parent.text
                    color: tk.ink
                    font.family: tk.ui
                    font.pixelSize: parent.size
                    font.weight: Font.Light
                }
                onTextChanged: flip.restart()
                SequentialAnimation {
                    id: flip
                    NumberAnimation { target: t; property: "opacity"; from: 0; to: 1; duration: 110 }
                }
                Behavior on text { enabled: false }
            }

            component Btn: Rectangle {
                property alias text: bl.text
                property bool solid: false
                implicitWidth: bl.width + 30
                implicitHeight: 32
                radius: tk.r
                color: solid ? tk.ink : (ma.containsMouse ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.10) : "transparent")
                border.width: 1
                border.color: solid ? tk.ink : tk.line
                Behavior on color { ColorAnimation { duration: tk.snap } }
                Text {
                    id: bl
                    anchors.centerIn: parent
                    color: parent.solid ? tk.paper : tk.ink
                    font.family: tk.ui
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 1.4
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true }
            }

            // ── nav rail ─────────────────────────────────────────────────
            Item {
                id: rail
                anchors { left: parent.left; top: parent.top; bottom: bar.top }
                width: 300
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: tk.line }

                Column {
                    id: railCol
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    Row {
                        spacing: 11
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 23 }
                        Column {
                            spacing: 1
                            Text { text: "RYOKU ARCH"; color: tk.ink; font.family: tk.ui; font.pixelSize: 15; font.weight: Font.Medium; font.letterSpacing: 2.6 }
                            Text { text: "system and shell settings"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 12 }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 38
                        color: "transparent"; radius: tk.r
                        border.width: 1; border.color: tk.line
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            Text { text: "Search…"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 150; height: 1 }
                            Text { text: "CTRL K"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Item {
                        width: parent.width
                        height: navList.height

                        // the one moving selector — inverted, slides. no accent.
                        Rectangle {
                            id: sel
                            width: parent.width
                            height: 32
                            radius: tk.r
                            color: tk.ink
                            y: root.navSel * 32
                            Behavior on y { NumberAnimation { duration: tk.move; easing.type: Easing.OutCubic } }
                        }

                        Column {
                            id: navList
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: [
                                    { g: 1, t: "Profile" },
                                    { g: 0, t: "SYSTEM" },
                                    { g: 1, t: "Updates" },
                                    { g: 1, t: "Displays" },
                                    { g: 1, t: "Input" },
                                    { g: 0, t: "DESKTOP" },
                                    { g: 1, t: "Appearance" },
                                    { g: 1, t: "Shell" },
                                    { g: 1, t: "App Launcher" },
                                    { g: 1, t: "Fastfetch" },
                                    { g: 1, t: "Desktop Widgets" },
                                    { g: 1, t: "Lockscreen" },
                                    { g: 1, t: "Animations" },
                                    { g: 0, t: "ADVANCED" },
                                    { g: 1, t: "Keybinds" },
                                    { g: 1, t: "Window Rules" }
                                ]
                                Item {
                                    width: parent.width
                                    height: 32
                                    property bool sel: root.navSel === index
                                    Rectangle {
                                        visible: modelData.g > 0 && !parent.sel
                                        anchors.fill: parent
                                        anchors.topMargin: 1; anchors.bottomMargin: 1
                                        radius: tk.r
                                        color: nma.containsMouse ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.09) : "transparent"
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    Row {
                                        visible: modelData.g === 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 9
                                        Rectangle { width: 4; height: 4; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.t; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle { width: 120; height: 1; color: tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text {
                                        visible: modelData.g > 0
                                        text: modelData.t
                                        color: parent.sel ? tk.paper : tk.inkDim
                                        font.family: tk.ui
                                        font.pixelSize: 15
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    MouseArea {
                                        id: nma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: modelData.g > 0
                                        onClicked: root.navSel = index
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 24; bottom: parent.bottom; bottomMargin: 18 }
                    text: "力  ryoku desktop"
                    color: tk.inkFaint
                    font.family: tk.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }

            // ── content ──────────────────────────────────────────────────
            Item {
                anchors { left: rail.right; right: parent.right; top: parent.top; bottom: bar.top }
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    anchors.topMargin: 24
                    anchors.bottomMargin: 12
                    spacing: 14

                    Row {
                        spacing: 9
                        Rectangle { width: 18; height: 1; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "DESKTOP"; color: tk.inkDim; font.family: tk.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 2.2; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        spacing: 18
                        Text { text: "Shell"; color: tk.ink; font.family: tk.display; font.pixelSize: 46; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "EDIT CONFIG"; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "REVEAL"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "Tune the Ryoku shell: the frame, the bar, notifications, and the desktop visualiser."; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 14 }

                    // ── tabs: one sliding inverted pill ──────────────────
                    Item {
                        width: 5 * 118
                        height: 34
                        Rectangle {
                            id: pill
                            width: 118; height: 34; radius: tk.r
                            color: tk.ink
                            x: root.tab * 118
                            Behavior on x { NumberAnimation { duration: tk.move; easing.type: Easing.OutCubic } }
                        }
                        Row {
                            spacing: 0
                            Repeater {
                                model: root.tabs
                                Rectangle {
                                    width: 118; height: 34
                                    color: "transparent"
                                    radius: tk.r
                                    border.width: 1
                                    border.color: tk.line
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: root.tab === index ? tk.paper : tk.inkDim
                                        font.family: tk.ui
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        font.letterSpacing: 1.4
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.tab = index }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 2 }

                    // ── hero cards ───────────────────────────────────────
                    Row {
                        id: cards
                        spacing: 16
                        opacity: 1

                        Rectangle {
                            width: 372; height: 190
                            color: "transparent"; radius: tk.r
                            border.width: 1; border.color: tk.line
                            Row {
                                anchors.fill: parent; anchors.margins: 17; spacing: 18
                                Column {
                                    width: 130
                                    spacing: 4
                                    Text { text: root.tabs[root.tab]; color: tk.ink; font.family: tk.ui; font.pixelSize: 13; font.weight: Font.Medium; font.letterSpacing: 1.6 }
                                    Text { text: "Enabled"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11 }
                                    Item { width: 1; height: 7 }
                                    Canvas {
                                        width: 126; height: 96
                                        onPaint: {
                                            var c = getContext("2d");
                                            c.strokeStyle = "rgba(194,185,176,0.55)"; c.lineWidth = 1;
                                            c.strokeRect(5.5, 8.5, 114, 78);
                                            c.strokeStyle = "rgba(194,185,176,0.22)";
                                            c.strokeRect(14.5, 17.5, 96, 60);
                                            c.fillStyle = "rgba(194,185,176,0.5)";
                                            c.fillRect(38, 11, 50, 5);
                                        }
                                    }
                                }
                                Column {
                                    spacing: 11
                                    Repeater {
                                        model: [
                                            ["BORDER", ["57", "12", "34", "20", "48"], "px"],
                                            ["RADIUS", ["2", "8", "4", "6", "10"], "px"],
                                            ["OPACITY", ["100", "92", "88", "96", "74"], "%"]
                                        ]
                                        Column {
                                            spacing: 0
                                            Text { text: modelData[0]; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                                            Row {
                                                spacing: 4
                                                Flap { text: modelData[1][root.tab]; size: 34; anchors.bottom: parent.bottom }
                                                Text { text: modelData[2]; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 372; height: 190
                            color: "transparent"; radius: tk.r
                            border.width: 1; border.color: tk.line
                            Row {
                                anchors.fill: parent; anchors.margins: 17; spacing: 18
                                Column {
                                    width: 130
                                    spacing: 4
                                    Text { text: "NOTIFICATIONS"; color: tk.ink; font.family: tk.ui; font.pixelSize: 13; font.weight: Font.Medium; font.letterSpacing: 1.6 }
                                    Text { text: "Top right"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11 }
                                    Item { width: 1; height: 7 }
                                    Canvas {
                                        width: 126; height: 96
                                        onPaint: {
                                            var c = getContext("2d");
                                            c.strokeStyle = "rgba(194,185,176,0.22)"; c.lineWidth = 1;
                                            c.strokeRect(5.5, 8.5, 114, 78);
                                            c.strokeStyle = "rgba(194,185,176,0.55)";
                                            c.strokeRect(66.5, 15.5, 48, 22);
                                            c.strokeStyle = "rgba(194,185,176,0.25)";
                                            c.strokeRect(66.5, 42.5, 48, 22);
                                            for (var i = 0; i < 3; i++) {
                                                c.fillStyle = "rgba(194,185,176,0.30)";
                                                c.fillRect(71, 21 + i * 5, 34 - i * 9, 2);
                                            }
                                        }
                                    }
                                }
                                Column {
                                    spacing: 11
                                    Repeater {
                                        model: [
                                            ["CORNER", ["28", "28", "16", "40", "28"], "px"],
                                            ["TIMEOUT", ["6", "4", "8", "6", "10"], "s"],
                                            ["OPACITY", ["100", "100", "90", "100", "82"], "%"]
                                        ]
                                        Column {
                                            spacing: 0
                                            Text { text: modelData[0]; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                                            Row {
                                                spacing: 4
                                                Flap { text: modelData[1][root.tab]; size: 34; anchors.bottom: parent.bottom }
                                                Text { text: modelData[2]; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 372; height: 190
                            color: "transparent"; radius: tk.r
                            border.width: 1; border.color: tk.line
                            Column {
                                anchors.fill: parent; anchors.margins: 17; spacing: 7
                                Row {
                                    width: parent.width
                                    Text { text: "LIVE PREVIEW"; color: tk.ink; font.family: tk.ui; font.pixelSize: 13; font.weight: Font.Medium; font.letterSpacing: 1.6 }
                                    Item { width: parent.width - 200; height: 1 }
                                    Text { text: "eDP-1"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 10 }
                                }
                                Rectangle {
                                    width: parent.width; height: 129
                                    color: "transparent"
                                    border.width: 1; border.color: tk.lineSoft
                                    radius: tk.r
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var c = getContext("2d");
                                            c.strokeStyle = "rgba(194,185,176,0.10)"; c.lineWidth = 1;
                                            c.beginPath(); c.moveTo(0, 0); c.lineTo(width, height);
                                            c.moveTo(width, 0); c.lineTo(0, height); c.stroke();
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "PREVIEW · TO REGENERATE"
                                        color: tk.inkFaint
                                        font.family: tk.ui
                                        font.pixelSize: 10
                                        font.letterSpacing: 1.6
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 4 }

                    // ── the table ────────────────────────────────────────
                    Column {
                        width: parent.width
                        spacing: 0

                        Item {
                            width: parent.width; height: 26
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "SETTING"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.6; width: 340 }
                                Text { text: "VALUE"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.6; width: 140 }
                                Text { text: "RANGE"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.6; width: 150 }
                                Text { text: "DEFAULT"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.6; width: 130 }
                                Text { text: "SOURCE"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.6; width: 190 }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.line }
                        }

                        Repeater {
                            id: rows
                            model: [
                                { n: "Enable frame", v: "ON", r: "—", d: "ON", s: "shell.json", t: "sw", on: true },
                                { n: "Border thickness", v: "57", u: "px", r: "0 – 120", d: "24 px", s: "shell.json", t: "step", hot: true },
                                { n: "Frame radius", v: "2", u: "px", r: "0 – 40", d: "10 px", s: "shell.json", t: "step", hot: true },
                                { n: "OSD & toast corner", v: "28", u: "px", r: "0 – 64", d: "28 px", s: "shell.json", t: "step" },
                                { n: "Notification opacity", v: "100", u: "%", r: "20 – 100", d: "100 %", s: "shell.json", t: "slider", fill: 1.0 },
                                { n: "Bar position", v: "TOP", r: "top | bottom", d: "TOP", s: "shell.json", t: "seg", a: "BOT" },
                                { n: "Blur behind popouts", v: "OFF", r: "—", d: "ON", s: "shell.json", t: "sw", on: false, hot: true },
                                { n: "Visualiser gain", v: "62", u: "%", r: "0 – 100", d: "50 %", s: "visualizer.json", t: "slider", fill: 0.62 },
                                { n: "Bar skin", v: "NOCT", r: "noct | cael", d: "NOCT", s: "shell.json", t: "seg", a: "CAEL" },
                                { n: "Sidebar reveal", v: "HOVER", r: "hover | click", d: "HOVER", s: "shell.json", t: "seg", a: "CLICK" },
                                { n: "Island modules", v: "04", r: "0 – 7", d: "04", s: "shell.json", t: "step" },
                                { n: "Visualiser", v: "OFF", r: "—", d: "OFF", s: "visualizer.json", t: "sw", on: false },
                                { n: "Brand mark opacity", v: "15", u: "%", r: "0 – 100", d: "15 %", s: "brand.json", t: "slider", fill: 0.15 }
                            ]
                            Item {
                                id: rowItem
                                width: parent.width
                                height: 46
                                property bool hov: rma.containsMouse
                                property var rowData: modelData

                                // hover inverts the row. inversion is the emphasis
                                // mechanism everywhere in this system.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 1; anchors.bottomMargin: 1
                                    radius: tk.r
                                    color: rowItem.hov ? tk.ink : "transparent"
                                    Behavior on color { ColorAnimation { duration: tk.snap } }
                                }

                                Row {
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: modelData.n
                                        color: rowItem.hov ? tk.paper : (modelData.hot ? tk.ink : tk.inkDim)
                                        font.family: tk.ui
                                        font.pixelSize: 15
                                        font.weight: modelData.hot ? Font.DemiBold : Font.Normal
                                        width: 332
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    Row {
                                        width: 140
                                        spacing: 4
                                        Text {
                                            text: modelData.v
                                            color: rowItem.hov ? tk.paper : tk.ink
                                            font.family: tk.ui
                                            font.pixelSize: 24
                                            font.weight: Font.Light
                                            Behavior on color { ColorAnimation { duration: tk.snap } }
                                        }
                                        Text { text: modelData.u !== undefined ? modelData.u : ""; color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.5) : tk.inkFaint; font.family: tk.ui; font.pixelSize: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 }
                                    }
                                    Text { text: modelData.r; color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.55) : tk.inkFaint; font.family: tk.mono; font.pixelSize: 11; width: 150 }
                                    Row {
                                        width: 130
                                        spacing: 6
                                        Text { text: modelData.hot === true ? "▸" : " "; color: rowItem.hov ? tk.paper : tk.ink; font.family: tk.ui; font.pixelSize: 10 }
                                        Text { text: modelData.d; color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.55) : tk.inkFaint; font.family: tk.mono; font.pixelSize: 11 }
                                    }
                                    Text { text: modelData.s; color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.55) : tk.inkFaint; font.family: tk.mono; font.pixelSize: 11; width: 190 }
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 150; height: 26
                                    // switch
                                    Rectangle {
                                        visible: modelData.t === "sw"
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 58; height: 25; radius: tk.r; antialiasing: false
                                        color: "transparent"
                                        border.width: 1
                                        border.color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                        Rectangle {
                                            width: 27; height: 18; y: 3; radius: tk.r; antialiasing: false
                                            x: modelData.on ? parent.width - width - 3 : 3
                                            color: modelData.on ? (rowItem.hov ? tk.paper : tk.ink) : "transparent"
                                            border.width: modelData.on ? 0 : 1
                                            border.color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                            Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                                        }
                                        Text {
                                            text: modelData.on ? "ON" : "OFF"
                                            color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.5) : tk.inkFaint
                                            font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: modelData.on ? 8 : parent.width - width - 8
                                        }
                                    }
                                    // stepper
                                    Row {
                                        visible: modelData.t === "step"
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0
                                        Repeater {
                                            model: ["−", "+"]
                                            Rectangle {
                                                width: 30; height: 25; radius: tk.r
                                                color: sma.containsMouse ? (rowItem.hov ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.14)) : "transparent"
                                                border.width: 1
                                                border.color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                                Behavior on color { ColorAnimation { duration: tk.snap } }
                                                Text { anchors.centerIn: parent; text: modelData; color: rowItem.hov ? tk.paper : tk.inkDim; font.family: tk.ui; font.pixelSize: 13 }
                                                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true }
                                            }
                                        }
                                    }
                                    // slider
                                    Item {
                                        visible: modelData.t === "slider"
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 148; height: 25
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: "transparent"; border.width: 1; border.color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line; antialiasing: false }
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * (modelData.fill !== undefined ? modelData.fill : 1); height: 4; color: rowItem.hov ? tk.paper : tk.ink; antialiasing: false }
                                        Rectangle {
                                            x: Math.min(parent.width - 6, parent.width * (modelData.fill !== undefined ? modelData.fill : 1) - 3)
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 6; height: 18; antialiasing: false
                                            color: rowItem.hov ? tk.paper : tk.ink
                                        }
                                    }
                                    // segmented
                                    Row {
                                        visible: modelData.t === "seg"
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0
                                        Repeater {
                                            model: 2
                                            Rectangle {
                                                width: 50; height: 25; radius: tk.r
                                                color: index === 0 ? (rowItem.hov ? tk.paper : tk.ink) : "transparent"
                                                border.width: 1
                                                border.color: rowItem.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: index === 0 ? rowItem.rowData.v : (rowItem.rowData.a !== undefined ? rowItem.rowData.a : "")
                                                    color: index === 0 ? (rowItem.hov ? tk.ink : tk.paper) : (rowItem.hov ? tk.paper : tk.inkDim)
                                                    font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.lineSoft }
                                MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true }

                                // stagger in — the flap-board cascade, 30ms apart
                                opacity: 0
                                Component.onCompleted: intro.start()
                                SequentialAnimation {
                                    id: intro
                                    PauseAnimation { duration: 90 + index * 32 }
                                    ParallelAnimation {
                                        NumberAnimation { target: rowItem; property: "opacity"; from: 0; to: 1; duration: 150 }
                                        NumberAnimation { target: rowItem; property: "x"; from: -10; to: 0; duration: 190; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── action bar ───────────────────────────────────────────────
            Item {
                id: bar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 62
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: tk.line }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    spacing: 10
                    Rectangle {
                        width: 6; height: 6; anchors.verticalCenter: parent.verticalCenter
                        color: tk.ink
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 900 }
                            NumberAnimation { to: 1.0; duration: 900 }
                        }
                    }
                    Text { text: "SAVED · LIVE ON YOUR DESKTOP"; color: tk.inkDim; font.family: tk.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1.6; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 32
                    spacing: 10
                    Btn { text: "RESET TO DEFAULTS" }
                    Btn { text: "REVERT" }
                    Btn { text: "SAVE"; solid: true }
                }
            }
        }
    }
}
