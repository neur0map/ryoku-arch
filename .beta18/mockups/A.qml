import QtQuick
import Quickshell

// Ryoku Hub — mock A: "specimen" layout. Subject centred, data flanking.
// Matte grainy black paper, acid-grotesk bone ink, no accent in content.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — A"
        minimumSize: Qt.size(1200, 760)
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
                readonly property color inkFaint: "#4e4a45"
                readonly property color line: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.18)
                readonly property color lineSoft: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.07)
                readonly property color lineHard: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.5)
                readonly property int r: 1
                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "JetBrainsMono Nerd Font"
            }

            Rectangle { anchors.fill: parent; color: tk.paper }

            // the matte: grain is what stops the black going flat.
            Image {
                anchors.fill: parent
                source: "grain.png"
                fillMode: Image.Tile
                opacity: 0.055
                z: 99
            }

            // ── reusable bits ────────────────────────────────────────────
            component Label: Text {
                color: tk.inkDim
                font.family: tk.mono
                font.pixelSize: 9
                font.letterSpacing: 1.6
                text: "LABEL"
            }
            component Panel: Rectangle {
                color: "transparent"
                radius: tk.r
                border.width: 1
                border.color: tk.line
            }
            component Chip: Rectangle {
                property alias text: cl.text
                property bool on: false
                implicitWidth: cl.width + 22
                implicitHeight: 22
                radius: tk.r
                color: on ? tk.ink : "transparent"
                border.width: 1
                border.color: on ? tk.ink : tk.line
                Text {
                    id: cl
                    anchors.centerIn: parent
                    color: parent.on ? tk.paper : tk.inkDim
                    font.family: tk.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                }
            }
            // a metric card: label small + value huge. the aeonik lesson.
            component Metric: Panel {
                property string k: ""
                property string v: ""
                property string u: ""
                property string d: ""
                property var series: []
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 2
                    Row {
                        width: parent.width
                        Rectangle { width: 3; height: 3; y: 4; color: tk.ink }
                        Item { width: 5; height: 1 }
                        Label { text: k }
                    }
                    Item { width: 1; height: 4 }
                    Row {
                        spacing: 3
                        Text {
                            text: v
                            color: tk.ink
                            font.family: tk.mono
                            font.pixelSize: 30
                            font.weight: Font.Light
                        }
                        Text {
                            text: u
                            color: tk.inkFaint
                            font.family: tk.mono
                            font.pixelSize: 10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                        }
                    }
                    Item { width: 1; height: 5 }
                    // dot-plot: instrument, not chart junk. fixed box so the
                    // per-point y offsets have somewhere to live.
                    Item {
                        width: parent.width
                        height: 15
                        Repeater {
                            model: series
                            Rectangle {
                                width: 2; height: 2; radius: 1
                                x: index * 6
                                y: 13 - modelData * 12
                                color: index === series.length - 1 ? tk.ink : tk.inkFaint
                            }
                        }
                    }
                    Item { width: 1; height: 2 }
                    Text {
                        text: d
                        color: tk.inkFaint
                        font.family: tk.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.8
                    }
                }
            }

            // ── top bar ──────────────────────────────────────────────────
            Item {
                id: top
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 52
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    spacing: 12
                    Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 1; height: 14; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                    Chip { text: "CATEGORY: SUMMARY  ▾"; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Chip { text: "OVERVIEW"; on: true }
                    Chip { text: "HARDWARE" }
                    Chip { text: "DESKTOP" }
                    Chip { text: "PROTOCOL: FULL SYSTEM ▾" }
                    Chip { text: "UPDATES" }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    spacing: 6
                    Repeater {
                        model: ["", "", ""]
                        Rectangle {
                            width: 22; height: 22; radius: tk.r
                            color: "transparent"; border.width: 1; border.color: tk.line
                            Text { anchors.centerIn: parent; text: modelData; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 10 }
                        }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.line }
            }

            // ── left column: identity + record ───────────────────────────
            Item {
                id: leftCol
                anchors { left: parent.left; top: top.bottom; bottom: scrub.top }
                width: 268
                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14

                    Row {
                        spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: tk.r
                            color: "transparent"; border.width: 1; border.color: tk.line
                            Text { anchors.centerIn: parent; text: "‹"; color: tk.inkDim; font.pixelSize: 11 }
                        }
                        Column {
                            spacing: 1
                            Text { text: "Ryoku Arch"; color: tk.ink; font.family: tk.display; font.pixelSize: 22 }
                            Text { text: "ID: RY-0142 · x86_64"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 0.8 }
                        }
                    }

                    Panel {
                        width: parent.width; height: 30
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            Text { text: "RECORD: SYSTEM PROFILE"; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.4; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 190; height: 1 }
                            Text { text: "▾"; color: tk.inkDim; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // inverted card — inversion is the emphasis mechanism, not colour
                    Rectangle {
                        width: parent.width; height: 156; radius: tk.r; color: tk.ink
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 7
                            Text { text: "SPECIMEN PROFILE"; color: tk.paper; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.6 }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.25) }
                            Grid {
                                columns: 3; columnSpacing: 16; rowSpacing: 5
                                Repeater {
                                    model: [["HOST", "ryoku"], ["KERNEL", "7.1.3"], ["ARCH", "x86_64"], ["WM", "Hyprland"], ["SHELL", "fish"], ["UPTIME", "6h 12m"]]
                                    Column {
                                        spacing: 0
                                        Text { text: modelData[0]; color: Qt.rgba(0, 0, 0, 0.45); font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 0.8 }
                                        Text { text: modelData[1]; color: tk.paper; font.family: tk.mono; font.pixelSize: 12 }
                                    }
                                }
                            }
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.25) }
                            Text { text: "BUILD AGE"; color: Qt.rgba(0, 0, 0, 0.45); font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 0.8 }
                            Row {
                                spacing: 6
                                Text { text: "0.12.9"; color: tk.paper; font.family: tk.mono; font.pixelSize: 17 }
                                Text { text: "beta.17"; color: Qt.rgba(0, 0, 0, 0.5); font.family: tk.mono; font.pixelSize: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 3 }
                            }
                        }
                    }

                    Row {
                        spacing: 10
                        Repeater {
                            model: [["RASHIN", "Jul 12, 2026"], ["PROFILE", "Jun 30, 2026"]]
                            Panel {
                                width: (leftCol.width - 44 - 10) / 2; height: 84
                                Column {
                                    anchors.fill: parent; anchors.margins: 9; spacing: 4
                                    Text { text: modelData[0]; color: tk.ink; font.family: tk.mono; font.pixelSize: 10; font.letterSpacing: 1.2 }
                                    Text { text: modelData[1]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8 }
                                    // technical thumb placeholder
                                    Rectangle {
                                        width: parent.width; height: 40; color: "transparent"
                                        border.width: 1; border.color: tk.lineSoft
                                        Canvas {
                                            anchors.fill: parent
                                            onPaint: {
                                                var c = getContext("2d");
                                                c.strokeStyle = "rgba(194,185,176,0.30)";
                                                c.lineWidth = 1;
                                                for (var i = 0; i < 7; i++) {
                                                    c.beginPath();
                                                    c.moveTo(4 + i * 8, height - 4);
                                                    c.lineTo(4 + i * 8, height - 4 - (4 + ((i * 13) % 26)));
                                                    c.stroke();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ledger — density is the lesson from the reference set
                    Item { width: 1; height: 2 }
                    Row {
                        width: parent.width
                        Label { text: "LEDGER" }
                        Item { width: parent.width - 96; height: 1 }
                        Text { text: "6"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9 }
                    }
                    Rectangle { width: parent.width; height: 1; color: tk.line }
                    Column {
                        width: parent.width
                        spacing: 0
                        Repeater {
                            model: [
                                ["JUL 16", "icons · ryowalls + ryovm", "OK"],
                                ["JUL 15", "unstable 0.12.9-beta.17", "OK"],
                                ["JUL 14", "portal routing healed", "OK"],
                                ["JUL 12", "limine snapshot sync", "OK"],
                                ["JUL 09", "pipewire rt scheduling", "OK"],
                                ["JUL 02", "wallust shade() clamp", "OK"]
                            ]
                            Item {
                                width: parent.width
                                height: 26
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Text { text: modelData[0]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; width: 44 }
                                    Text { text: modelData[1]; color: tk.inkDim; font.family: tk.ui; font.pixelSize: 11; width: 150; elide: Text.ElideRight }
                                }
                                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData[2]; color: tk.ink; font.family: tk.mono; font.pixelSize: 8 }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.lineSoft }
                            }
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: tk.line }
            }

            // ── centre: the subject ──────────────────────────────────────
            Item {
                id: stage
                anchors { left: leftCol.right; right: rightCol.left; top: top.bottom; bottom: scrub.top }

                // registration crosshairs at the stage corners — poster chrome
                Repeater {
                    model: [[0, 0], [1, 0], [0, 1], [1, 1]]
                    Item {
                        x: modelData[0] ? stage.width - 34 : 18
                        y: modelData[1] ? stage.height - 34 : 18
                        width: 16; height: 16
                        Rectangle { anchors.centerIn: parent; width: 16; height: 1; color: tk.lineHard; opacity: 0.5 }
                        Rectangle { anchors.centerIn: parent; width: 1; height: 16; color: tk.lineHard; opacity: 0.5 }
                    }
                }

                // ART PLACEHOLDER — regenerated later, so it's a keyline only
                Rectangle {
                    id: art
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -8
                    width: Math.min(parent.width - 150, 392)
                    height: parent.height * 0.76
                    color: "transparent"
                    border.width: 1
                    border.color: tk.line
                    radius: tk.r

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
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "⊕"; color: tk.inkFaint; font.pixelSize: 22; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "ART · TO REGENERATE"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.8; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "1504 × 1128"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; opacity: 0.7; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    // vertical marginalia, the katakana slot
                    Text {
                        text: "力 の 器"
                        color: tk.inkFaint
                        font.family: "Noto Sans CJK JP"
                        font.pixelSize: 11
                        rotation: 90
                        transformOrigin: Item.Center
                        anchors.left: parent.right
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // callouts — leader line + label, the anatomical annotation
                Repeater {
                    model: [
                        { t: "FRAME · 57px",   x: 0.05, y: 0.16, w: 92 },
                        { t: "BAR · TOP",      x: 0.05, y: 0.40, w: 92 },
                        { t: "WIDGETS · 2",    x: 0.78, y: 0.24, w: 92 },
                        { t: "SIDEBAR · R",    x: 0.78, y: 0.62, w: 92 }
                    ]
                    Item {
                        x: stage.width * modelData.x
                        y: stage.height * modelData.y
                        Row {
                            spacing: 5
                            Rectangle { width: 4; height: 4; radius: 2; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 22; height: 1; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.t; color: tk.inkDim; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.1; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                // floating detail popover — inverted, the one loud object
                Rectangle {
                    width: 208; height: 92; radius: tk.r
                    color: tk.ink
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 68
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 5
                        Row {
                            width: parent.width
                            Text { text: "FRAME BORDER"; color: tk.paper; font.family: tk.mono; font.pixelSize: 9; font.letterSpacing: 1.3 }
                            Item { width: parent.width - 150; height: 1 }
                            Text { text: "LIVE"; color: Qt.rgba(0, 0, 0, 0.5); font.family: tk.mono; font.pixelSize: 8 }
                        }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.22) }
                        Repeater {
                            model: [["Thickness", "57 px"], ["Radius", "1 px"], ["Opacity", "100 %"]]
                            Row {
                                width: 188
                                Text { text: modelData[0]; color: Qt.rgba(0, 0, 0, 0.55); font.family: tk.ui; font.pixelSize: 10 }
                                Item { width: 188 - 62 - implicitW.width; height: 1 }
                                Text { id: implicitW; text: modelData[1]; color: tk.paper; font.family: tk.mono; font.pixelSize: 10 }
                            }
                        }
                    }
                }
            }

            // ── right column: metrics ────────────────────────────────────
            Item {
                id: rightCol
                anchors { right: parent.right; top: top.bottom; bottom: scrub.top }
                width: 300
                Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: tk.line }
                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10
                    Row {
                        spacing: 5
                        Chip { text: "+" }
                        Chip { text: "SYSTEM"; on: true }
                        Chip { text: "DESKTOP" }
                        Chip { text: "ADD-ONS" }
                    }
                    Item { width: 1; height: 2 }
                    Grid {
                        columns: 2; columnSpacing: 10; rowSpacing: 10
                        Metric { width: 123; height: 104; k: "CPU LOAD"; v: "17"; u: "%"; series: [.2, .3, .25, .5, .4, .6, .45, .3, .17]; d: "8 cores · 3.4 GHz" }
                        Metric { width: 123; height: 104; k: "MEMORY"; v: "20"; u: "%"; series: [.3, .32, .31, .35, .34, .36, .38, .37, .2]; d: "6.4 / 32 GB" }
                        Metric { width: 123; height: 104; k: "GPU"; v: "05"; u: "%"; series: [.1, .12, .4, .8, .3, .15, .1, .09, .05]; d: "amdgpu · 65 °C" }
                        Metric { width: 123; height: 104; k: "DISK"; v: "41"; u: "%"; series: [.4, .4, .41, .41, .42, .41, .41, .41, .41]; d: "418 / 1024 GB" }
                    }
                    Panel {
                        width: 256; height: 92
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 5
                            Row {
                                width: parent.width
                                Label { text: "THERMAL ENVELOPE" }
                                Item { width: parent.width - 150; height: 1 }
                                Text { text: "NOMINAL"; color: tk.ink; font.family: tk.mono; font.pixelSize: 8 }
                            }
                            Row {
                                spacing: 2
                                Repeater {
                                    model: 30
                                    Rectangle {
                                        width: 5
                                        height: 4 + ((index * 7) % 22)
                                        y: 26 - height
                                        color: index > 28 ? tk.ink : tk.inkFaint
                                    }
                                }
                            }
                            Item { width: 1; height: 2 }
                            Row {
                                width: parent.width
                                Text { text: "65 °C"; color: tk.ink; font.family: tk.mono; font.pixelSize: 15 }
                                Item { width: parent.width - 120; height: 1 }
                                Text { text: "MAX 91 °C"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8 }
                            }
                        }
                    }

                    Item { width: 1; height: 2 }
                    Row {
                        width: 256
                        Label { text: "ADVISORIES" }
                        Item { width: 256 - 128; height: 1 }
                        Text { text: "02 OPEN"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9 }
                    }
                    Rectangle { width: 256; height: 1; color: tk.line }
                    Column {
                        width: 256
                        spacing: 0
                        Repeater {
                            model: [
                                ["◆", "widgets runs two Theme singletons", "SKEW"],
                                ["◆", "reduce-motion ignored by 3 configs", "A11Y"],
                                ["○", "11 Theme.qml copies", "DEBT"],
                                ["○", "Theme.border type conflict", "DEBT"]
                            ]
                            Item {
                                width: parent.width
                                height: 30
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Text { text: modelData[0]; color: tk.ink; font.family: tk.mono; font.pixelSize: 8 }
                                    Text { text: modelData[1]; color: tk.inkDim; font.family: tk.ui; font.pixelSize: 10; width: 172; elide: Text.ElideRight }
                                }
                                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData[2]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1 }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.lineSoft }
                            }
                        }
                    }
                }
            }

            // ── bottom scrubber ──────────────────────────────────────────
            Item {
                id: scrub
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 46
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: tk.line }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    spacing: 18
                    Repeater {
                        model: [["2024", "OPTIMAL", 4], ["2025", "OPTIMAL", 3], ["2026", "CURRENT", 5]]
                        Row {
                            spacing: 7
                            Column {
                                spacing: 0
                                Text { text: modelData[0]; color: tk.ink; font.family: tk.mono; font.pixelSize: 10 }
                                Text { text: "JUL"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 7 }
                            }
                            Row {
                                spacing: 3
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: 5
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        color: index < modelData[2] ? tk.ink : "transparent"
                                        border.width: 1; border.color: tk.line
                                    }
                                }
                            }
                            Text { text: modelData[1]; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8; font.letterSpacing: 1; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 1; height: 16; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    spacing: 6
                    Chip { text: "SPEC SHEET" }
                    Chip { text: "−" }
                    Chip { text: "+" }
                }
            }
        }
    }
}
