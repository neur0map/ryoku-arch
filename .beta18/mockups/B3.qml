import QtQuick
import QtQuick.Controls
import Quickshell

// Ryoku Hub — mock B3. B2's language, but the UX actually closes:
//   edit -> row marks dirty -> preview redraws -> action bar changes state -> save/revert.
// Search filters live. Space Grotesk + Space Mono (same foundry, a true pairing);
// Aeonik Fono / Acid Grotesk are retail fonts, so these are the free equivalents.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — B3"
        minimumSize: Qt.size(1280, 820)
        color: "#000000"
        onClosed: Qt.quit()

        Item {
            id: root
            anchors.fill: parent
            focus: true

            QtObject {
                id: tk
                readonly property color paper: "#000000"
                readonly property color ink: "#c2b9b0"
                readonly property color inkDim: "#8a837c"
                readonly property color inkFaint: "#565049"
                readonly property color line: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.20)
                readonly property color lineSoft: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.08)
                readonly property int r: 2

                // ONE spacing scale. every gap in this file is from it.
                readonly property int s1: 4
                readonly property int s2: 8
                readonly property int s3: 12
                readonly property int s4: 16
                readonly property int s5: 24
                readonly property int s6: 32
                readonly property int s7: 48
                // ONE type scale.
                readonly property int tMicro: 10
                readonly property int tSmall: 12
                readonly property int tBody: 14
                readonly property int tRow: 15
                readonly property int tValue: 24
                readonly property int tHero: 34
                readonly property int tTitle: 46
                // rhythm
                readonly property int rowH: 48
                readonly property int railRowH: 36
                readonly property int ctlH: 26

                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "SpaceMono Nerd Font"

                readonly property int snap: 90
                readonly property int move: 170
            }

            // ── state ────────────────────────────────────────────────────
            property int tab: 0
            readonly property var tabs: ["FRAME", "GLOBAL", "BAR", "SIDEBAR", "VISUALIZER"]
            property int navSel: 7
            property string query: ""
            property int rev: 0

            ListModel {
                id: settings
                ListElement { n: "Enable frame";        w: "Draw the rounded border around the screen"; v: "1";   d: "1";   u: "";   rg: "on | off";    src: "shell.json";      ctl: "sw" }
                ListElement { n: "Border thickness";    w: "How far the frame intrudes on each edge";   v: "57";  d: "24";  u: "px"; rg: "0 – 120";     src: "shell.json";      ctl: "step"; lo: 0; hi: 120 }
                ListElement { n: "Frame radius";        w: "Corner rounding of the frame itself";       v: "2";   d: "10";  u: "px"; rg: "0 – 40";      src: "shell.json";      ctl: "step"; lo: 0; hi: 40 }
                ListElement { n: "OSD & toast corner";  w: "Where notifications grow from";             v: "28";  d: "28";  u: "px"; rg: "0 – 64";      src: "shell.json";      ctl: "step"; lo: 0; hi: 64 }
                ListElement { n: "Notification opacity";w: "Toast surface opacity over the wallpaper";  v: "100"; d: "100"; u: "%";  rg: "20 – 100";    src: "shell.json";      ctl: "slid"; lo: 20; hi: 100 }
                ListElement { n: "Bar position";        w: "Which frame edge the module bar rides";     v: "TOP"; d: "TOP"; u: "";   rg: "top | bottom";src: "shell.json";      ctl: "seg";  alt: "BOT" }
                ListElement { n: "Bar skin";            w: "Module vocabulary carried from the refs";   v: "NOCT"; d: "NOCT"; u: ""; rg: "noct | cael"; src: "shell.json";      ctl: "seg";  alt: "CAEL" }
                ListElement { n: "Blur behind popouts"; w: "Compositor blur under popout surfaces";     v: "0";   d: "1";   u: "";   rg: "on | off";    src: "shell.json";      ctl: "sw" }
                ListElement { n: "Sidebar reveal";      w: "How the side panels are summoned";          v: "HOVER"; d: "HOVER"; u: ""; rg: "hover|click"; src: "shell.json";    ctl: "seg";  alt: "CLICK" }
                ListElement { n: "Visualiser";          w: "Audio spectrum painted on the desktop";     v: "0";   d: "0";   u: "";   rg: "on | off";    src: "visualizer.json"; ctl: "sw" }
                ListElement { n: "Visualiser gain";     w: "Input sensitivity of the spectrum";         v: "62";  d: "50";  u: "%";  rg: "0 – 100";     src: "visualizer.json"; ctl: "slid"; lo: 0; hi: 100 }
                ListElement { n: "Brand mark opacity";  w: "The 力 seal behind the rail masthead";      v: "15";  d: "15";  u: "%";  rg: "0 – 100";     src: "brand.json";      ctl: "slid"; lo: 0; hi: 100 }
            }

            readonly property int dirty: {
                rev;
                var n = 0;
                for (var i = 0; i < settings.count; i++)
                    if (settings.get(i).v !== settings.get(i).d) n++;
                return n;
            }
            function setV(i, val) { settings.setProperty(i, "v", String(val)); rev++ }
            function revertAll() { for (var i = 0; i < settings.count; i++) settings.setProperty(i, "v", settings.get(i).d); rev++ }
            function matches(o) {
                if (query === "") return true;
                var q = query.toLowerCase();
                return o.n.toLowerCase().indexOf(q) >= 0 || o.w.toLowerCase().indexOf(q) >= 0 || o.src.toLowerCase().indexOf(q) >= 0;
            }
            Component.onCompleted: rev++   // force every vOf() binding to re-read once the model is live
            function vOf(name) { for (var i = 0; i < settings.count; i++) if (settings.get(i).n === name) return parseInt(settings.get(i).v); return 0 }

            Rectangle { anchors.fill: parent; color: tk.paper }
            Image { anchors.fill: parent; source: "grain.png"; fillMode: Image.Tile; opacity: 0.055; z: 99 }

            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) { search.forceActiveFocus(); e.accepted = true }
                if (e.key === Qt.Key_Escape) { search.text = ""; root.forceActiveFocus(); e.accepted = true }
            }

            component Btn: Rectangle {
                id: btn
                signal act()
                property alias text: bl.text
                property bool solid: false
                property bool enabled_: true
                property bool danger: false
                implicitWidth: bl.width + 30
                implicitHeight: 32
                radius: tk.r
                opacity: enabled_ ? 1 : 0.32
                color: solid && enabled_ ? tk.ink : (ma.containsMouse && enabled_ ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.10) : "transparent")
                border.width: 1
                border.color: solid && enabled_ ? tk.ink : tk.line
                Behavior on color { ColorAnimation { duration: tk.snap } }
                Behavior on opacity { NumberAnimation { duration: tk.snap } }
                Text {
                    id: bl
                    anchors.centerIn: parent
                    color: parent.solid && parent.enabled_ ? tk.paper : tk.ink
                    font.family: tk.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1.4
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: btn.enabled_
                    cursorShape: btn.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: btn.act()
                }
            }

            // ── rail ─────────────────────────────────────────────────────
            Item {
                id: rail
                anchors { left: parent.left; top: parent.top; bottom: bar.top }
                width: 300
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: tk.line }

                Column {
                    anchors.fill: parent
                    anchors.margins: tk.s5
                    spacing: tk.s4

                    Row {
                        spacing: tk.s3
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 23 }
                        Column {
                            spacing: 1
                            Text { text: "RYOKU ARCH"; color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tRow; font.weight: Font.Medium; font.letterSpacing: 2.6 }
                            Text { text: "system and shell settings"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tSmall }
                        }
                    }

                    // search: the most important control in a 247-setting app.
                    Rectangle {
                        width: parent.width; height: 38
                        color: "transparent"; radius: tk.r
                        border.width: search.activeFocus ? 2 : 1
                        border.color: search.activeFocus ? tk.ink : tk.line
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: tk.s3; anchors.rightMargin: tk.s3
                            spacing: tk.s2
                            TextInput {
                                id: search
                                width: parent.width - 76
                                anchors.verticalCenter: parent.verticalCenter
                                color: tk.ink
                                font.family: tk.ui; font.pixelSize: tk.tBody
                                selectByMouse: true
                                onTextChanged: root.query = text
                                Text {
                                    anchors.fill: parent
                                    visible: parent.text === ""
                                    text: "Search settings…"
                                    color: tk.inkFaint
                                    font: parent.font
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Text {
                                text: search.activeFocus ? "ESC" : "CTRL K"
                                color: tk.inkFaint; font.family: tk.mono; font.pixelSize: tk.tMicro
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: navList.height
                        Rectangle {
                            width: parent.width; height: tk.railRowH; radius: tk.r
                            color: tk.ink
                            y: root.navSel * tk.railRowH
                            Behavior on y { NumberAnimation { duration: tk.move; easing.type: Easing.OutCubic } }
                        }
                        Column {
                            id: navList
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: [
                                    { g: 0, t: "OVERVIEW" },
                                    { g: 1, t: "Profile" },
                                    { g: 0, t: "SYSTEM" },
                                    { g: 1, t: "Updates" },
                                    { g: 1, t: "Displays" },
                                    { g: 1, t: "Input" },
                                    { g: 0, t: "DESKTOP" },
                                    { g: 1, t: "Shell" },
                                    { g: 1, t: "Appearance" },
                                    { g: 1, t: "App Launcher" },
                                    { g: 1, t: "Fastfetch" },
                                    { g: 1, t: "Desktop Widgets" },
                                    { g: 0, t: "ADVANCED" },
                                    { g: 1, t: "Keybinds" },
                                    { g: 1, t: "Window Rules" }
                                ]
                                Item {
                                    width: parent.width
                                    height: tk.railRowH
                                    property bool isSel: root.navSel === index
                                    Rectangle {
                                        visible: modelData.g > 0 && !parent.isSel
                                        anchors.fill: parent
                                        anchors.topMargin: 1; anchors.bottomMargin: 1
                                        radius: tk.r
                                        color: nma.containsMouse ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.09) : "transparent"
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    Row {
                                        visible: modelData.g === 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: tk.s2
                                        Rectangle { width: 4; height: 4; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.t; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle { width: 130; height: 1; color: tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text {
                                        visible: modelData.g > 0
                                        text: modelData.t
                                        color: parent.isSel ? tk.paper : tk.inkDim
                                        font.family: tk.ui; font.pixelSize: tk.tRow
                                        x: tk.s3
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; enabled: modelData.g > 0; onClicked: root.navSel = index }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: tk.s5; bottom: parent.bottom; bottomMargin: tk.s4 }
                    text: "力  ryoku desktop"
                    color: tk.inkFaint; font.family: tk.mono; font.pixelSize: tk.tMicro
                }
            }

            // ── content ──────────────────────────────────────────────────
            Item {
                id: content
                anchors { left: rail.right; right: parent.right; top: parent.top; bottom: bar.top }
                clip: true

                Column {
                    id: head
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s6; anchors.topMargin: tk.s5
                    spacing: tk.s3

                    Row {
                        spacing: tk.s2
                        Rectangle { width: 18; height: 1; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: tk.tSmall; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "DESKTOP"; color: tk.inkDim; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 2.2; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: tk.s4
                        Text { text: "Shell"; color: tk.ink; font.family: tk.display; font.pixelSize: tk.tTitle; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "EDIT CONFIG"; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "REVEAL"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "Tune the Ryoku shell: the frame, the bar, notifications, and the desktop visualiser."; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tBody }
                    Item { width: 1; height: tk.s1 }
                    Item {
                        width: 5 * 118; height: 34
                        Rectangle {
                            width: 118; height: 34; radius: tk.r; color: tk.ink
                            x: root.tab * 118
                            Behavior on x { NumberAnimation { duration: tk.move; easing.type: Easing.OutCubic } }
                        }
                        Row {
                            spacing: 0
                            Repeater {
                                model: root.tabs
                                Rectangle {
                                    width: 118; height: 34; color: "transparent"; radius: tk.r
                                    border.width: 1; border.color: tk.line
                                    Text {
                                        anchors.centerIn: parent; text: modelData
                                        color: root.tab === index ? tk.paper : tk.inkDim
                                        font.family: tk.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1.4
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.tab = index }
                                }
                            }
                        }
                    }
                }

                // ── hero: the preview is the feedback loop, so it is live ──
                Row {
                    id: cards
                    anchors { left: parent.left; right: parent.right; top: head.bottom }
                    anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s6; anchors.topMargin: tk.s5
                    spacing: tk.s4

                    // LIVE PREVIEW is the frame card. no separate card restating
                    // rows the table already shows — the readouts annotate the
                    // drawing, the way a callout annotates a specimen.
                    Rectangle {
                        width: 700; height: 190
                        color: "transparent"; radius: tk.r
                        border.width: 1; border.color: tk.line
                        Column {
                            anchors.fill: parent; anchors.margins: tk.s4; spacing: tk.s3
                            Row {
                                width: parent.width
                                Text { text: "LIVE PREVIEW"; color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tSmall; font.weight: Font.Medium; font.letterSpacing: 1.6 }
                                Item { width: parent.width - 210; height: 1 }
                                Text { text: "eDP-1 · 2560×1600"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: tk.tMicro }
                            }
                            Row {
                                spacing: tk.s5
                                Canvas {
                                    id: prev
                                    width: 400; height: 132
                                    property int bw: { root.rev; return root.vOf("Border thickness") }
                                    property int br: { root.rev; return root.vOf("Frame radius") }
                                    property int op: { root.rev; return root.vOf("Notification opacity") }
                                    property bool on: { root.rev; return root.vOf("Enable frame") === 1 }
                                    onBwChanged: requestPaint()
                                    onBrChanged: requestPaint()
                                    onOpChanged: requestPaint()
                                    onOnChanged: requestPaint()
                                    onPaint: {
                                        var c = getContext("2d");
                                        c.reset();
                                        c.strokeStyle = "rgba(194,185,176,0.16)"; c.lineWidth = 1;
                                        c.strokeRect(0.5, 0.5, width - 1, height - 1);
                                        if (!on) {
                                            c.fillStyle = "rgba(194,185,176,0.35)";
                                            c.font = "11px sans-serif";
                                            c.fillText("FRAME OFF", width / 2 - 28, height / 2);
                                            return;
                                        }
                                        var t = Math.max(1, bw / 120 * 20);
                                        var rr = br / 40 * 16;
                                        c.strokeStyle = "rgba(194,185,176,0.88)";
                                        c.lineWidth = t;
                                        var x = t / 2 + 4, y = t / 2 + 4, w = width - t - 8, h = height - t - 8;
                                        c.beginPath();
                                        c.moveTo(x + rr, y);
                                        c.lineTo(x + w - rr, y); c.quadraticCurveTo(x + w, y, x + w, y + rr);
                                        c.lineTo(x + w, y + h - rr); c.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
                                        c.lineTo(x + rr, y + h); c.quadraticCurveTo(x, y + h, x, y + h - rr);
                                        c.lineTo(x, y + rr); c.quadraticCurveTo(x, y, x + rr, y);
                                        c.closePath(); c.stroke();
                                        c.globalAlpha = op / 100;
                                        c.fillStyle = "rgba(194,185,176,0.6)";
                                        c.fillRect(width - t - 78, t + 12, 60, 22);
                                        c.globalAlpha = 1;
                                    }
                                }
                                Column {
                                    spacing: tk.s2
                                    Repeater {
                                        model: [["BORDER", "Border thickness", "px"], ["RADIUS", "Frame radius", "px"], ["TOAST", "Notification opacity", "%"]]
                                        Row {
                                            spacing: tk.s2
                                            Rectangle { width: 4; height: 4; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                            Column {
                                                spacing: 0
                                                Text { text: modelData[0]; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                                                Row {
                                                    spacing: 3
                                                    Text {
                                                        text: { root.rev; return String(root.vOf(modelData[1])) }
                                                        color: tk.ink; font.family: tk.ui; font.pixelSize: 26; font.weight: Font.Light
                                                    }
                                                    Text { text: modelData[2]; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 5 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 300; height: 190
                        color: "transparent"; radius: tk.r
                        border.width: 1; border.color: tk.line
                        Column {
                            anchors.fill: parent; anchors.margins: tk.s4; spacing: tk.s2
                            Text { text: "STATE"; color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tSmall; font.weight: Font.Medium; font.letterSpacing: 1.6 }
                            Row {
                                spacing: tk.s2
                                Text { text: String(root.dirty); color: tk.ink; font.family: tk.ui; font.pixelSize: 46; font.weight: Font.Light }
                                Text { text: root.dirty === 1 ? "CHANGE" : "CHANGES"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tMicro; font.letterSpacing: 1.4; anchors.bottom: parent.bottom; anchors.bottomMargin: 10 }
                            }
                            Rectangle { width: parent.width; height: 1; color: tk.lineSoft }
                            Text {
                                width: parent.width
                                text: root.dirty > 0 ? "Previewing on your desktop. Nothing is written until you save."
                                                     : "Everything matches what is on disk."
                                color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tSmall
                                wrapMode: Text.WordWrap
                            }
                            Item { width: 1; height: tk.s1 }
                            Text {
                                width: parent.width
                                text: root.query !== "" ? ("FILTER · " + root.query.toUpperCase()) : "NO FILTER"
                                color: tk.inkFaint; font.family: tk.mono; font.pixelSize: tk.tMicro
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // ── table ────────────────────────────────────────────────
                Item {
                    id: tbl
                    anchors { left: parent.left; right: parent.right; top: cards.bottom; bottom: parent.bottom }
                    anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s6; anchors.topMargin: tk.s5

                    // columns, distributed. no 400px canyon between a setting
                    // and the control that operates it.
                    readonly property int cName: 226
                    readonly property int cWhat: Math.max(180, width - 226 - 116 - 104 - 132 - 176 - 5 * tk.s4)
                    readonly property int cVal: 116
                    readonly property int cRange: 104
                    readonly property int cSrc: 132
                    readonly property int cCtl: 176

                    Item {
                        id: thead
                        width: parent.width; height: 26
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: tk.s4
                            Repeater {
                                model: [["SETTING", tbl.cName], ["WHAT IT DOES", tbl.cWhat], ["VALUE", tbl.cVal], ["RANGE", tbl.cRange], ["SOURCE", tbl.cSrc], ["CONTROL", tbl.cCtl]]
                                Text {
                                    text: modelData[0]; width: modelData[1]
                                    color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tMicro
                                    font.weight: Font.Medium; font.letterSpacing: 1.6
                                    horizontalAlignment: modelData[0] === "CONTROL" ? Text.AlignRight : Text.AlignLeft
                                }
                            }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.line }
                    }

                    Flickable {
                        anchors { left: parent.left; right: parent.right; top: thead.bottom; bottom: parent.bottom }
                        contentHeight: col.height
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            contentItem: Rectangle { implicitWidth: 3; color: tk.line; radius: 0 }
                        }

                        Column {
                            id: col
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: settings
                                Item {
                                    id: row
                                    width: col.width
                                    readonly property bool changed: { root.rev; return model.v !== model.d }
                                    readonly property bool shown: { root.query; return root.matches(model) }
                                    height: shown ? tk.rowH : 0
                                    visible: height > 0
                                    clip: true
                                    Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    property bool hov: rhh.hovered

                                    Rectangle {
                                        anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1
                                        radius: tk.r
                                        color: row.hov ? tk.ink : "transparent"
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    // changed marker: a solid edge. unmissable, no colour.
                                    Rectangle {
                                        x: 0; width: 2; height: parent.height - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: row.hov ? tk.paper : tk.ink
                                        visible: row.changed
                                    }

                                    Row {
                                        x: tk.s3
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: tk.s4

                                        Text {
                                            width: tbl.cName - tk.s3
                                            text: model.n
                                            color: row.hov ? tk.paper : (row.changed ? tk.ink : tk.inkDim)
                                            font.family: tk.ui; font.pixelSize: tk.tRow
                                            font.weight: row.changed ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: tk.snap } }
                                        }
                                        Text {
                                            width: tbl.cWhat
                                            text: model.w
                                            color: row.hov ? Qt.rgba(0, 0, 0, 0.6) : tk.inkFaint
                                            font.family: tk.ui; font.pixelSize: tk.tSmall
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        // value + the default it departed from, struck.
                                        Item {
                                            width: tbl.cVal; height: 34
                                            Row {
                                                spacing: 3
                                                Text {
                                                    text: model.ctl === "sw" ? (model.v === "1" ? "ON" : "OFF") : model.v
                                                    color: row.hov ? tk.paper : tk.ink
                                                    font.family: tk.ui; font.pixelSize: tk.tValue; font.weight: Font.Light
                                                }
                                                Text { text: model.u; color: row.hov ? Qt.rgba(0, 0, 0, 0.5) : tk.inkFaint; font.family: tk.ui; font.pixelSize: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 }
                                            }
                                            Text {
                                                visible: row.changed
                                                anchors.bottom: parent.bottom
                                                text: (model.ctl === "sw" ? (model.d === "1" ? "ON" : "OFF") : model.d) + " " + model.u
                                                color: row.hov ? Qt.rgba(0, 0, 0, 0.5) : tk.inkFaint
                                                font.family: tk.mono; font.pixelSize: 9; font.strikeout: true
                                            }
                                        }
                                        Text { width: tbl.cRange; text: model.rg; color: row.hov ? Qt.rgba(0, 0, 0, 0.55) : tk.inkFaint; font.family: tk.mono; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                        Text { width: tbl.cSrc; text: model.src; color: row.hov ? Qt.rgba(0, 0, 0, 0.55) : tk.inkFaint; font.family: tk.mono; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    }

                                    // control — right edge, but the row inverts as one
                                    // object so the association is never lost.
                                    Item {
                                        anchors.right: parent.right; anchors.rightMargin: tk.s3
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: tbl.cCtl; height: tk.ctlH

                                        Rectangle {
                                            visible: model.ctl === "sw"
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: 58; height: 25; radius: tk.r; antialiasing: false
                                            color: "transparent"
                                            border.width: 1; border.color: row.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                            Rectangle {
                                                width: 27; height: 18; y: 3; radius: tk.r; antialiasing: false
                                                x: model.v === "1" ? parent.width - width - 3 : 3
                                                color: model.v === "1" ? (row.hov ? tk.paper : tk.ink) : "transparent"
                                                border.width: model.v === "1" ? 0 : 1
                                                border.color: row.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                                Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setV(row.idx, model.v === "1" ? "0" : "1") }
                                        }
                                        Row {
                                            visible: model.ctl === "step"
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0
                                            Repeater {
                                                model: ["−", "+"]
                                                Rectangle {
                                                    width: 30; height: 25; radius: tk.r
                                                    color: sma.containsMouse ? (row.hov ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.15)) : "transparent"
                                                    border.width: 1; border.color: row.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                                    Behavior on color { ColorAnimation { duration: tk.snap } }
                                                    Text { anchors.centerIn: parent; text: modelData; color: row.hov ? tk.paper : tk.inkDim; font.family: tk.ui; font.pixelSize: 13 }
                                                    MouseArea {
                                                        id: sma
                                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var o = settings.get(row.idx);
                                                            var step = (o.hi - o.lo) > 60 ? 4 : 1;
                                                            var nv = parseInt(o.v) + (modelData === "+" ? step : -step);
                                                            root.setV(row.idx, Math.max(o.lo, Math.min(o.hi, nv)));
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Item {
                                            visible: model.ctl === "slid"
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: 168; height: 25
                                            property real frac: (parseInt(model.v) - model.lo) / Math.max(1, model.hi - model.lo)
                                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: "transparent"; border.width: 1; border.color: row.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line; antialiasing: false }
                                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * parent.frac; height: 4; color: row.hov ? tk.paper : tk.ink; antialiasing: false }
                                            Rectangle {
                                                x: Math.min(parent.width - 6, Math.max(0, parent.width * parent.frac - 3))
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 6; height: 18; antialiasing: false
                                                color: row.hov ? tk.paper : tk.ink
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onPositionChanged: if (pressed) apply(mouse.x)
                                                onPressed: apply(mouse.x)
                                                function apply(mx) {
                                                    var o = settings.get(row.idx);
                                                    var f = Math.max(0, Math.min(1, mx / width));
                                                    root.setV(row.idx, Math.round(o.lo + f * (o.hi - o.lo)));
                                                }
                                            }
                                        }
                                        Row {
                                            visible: model.ctl === "seg"
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0
                                            Repeater {
                                                model: 2
                                                Rectangle {
                                                    readonly property string lbl: index === 0 ? settings.get(row.idx).d : settings.get(row.idx).alt
                                                    width: 56; height: 25; radius: tk.r
                                                    color: settings.get(row.idx).v === lbl ? (row.hov ? tk.paper : tk.ink) : "transparent"
                                                    border.width: 1; border.color: row.hov ? Qt.rgba(0, 0, 0, 0.4) : tk.line
                                                    Behavior on color { ColorAnimation { duration: tk.snap } }
                                                    Text {
                                                        anchors.centerIn: parent; text: parent.lbl
                                                        color: settings.get(row.idx).v === parent.lbl ? (row.hov ? tk.ink : tk.paper) : (row.hov ? tk.paper : tk.inkDim)
                                                        font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium
                                                    }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setV(row.idx, parent.lbl) }
                                                }
                                            }
                                        }
                                    }
                                    property int idx: index
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.lineSoft }
                                    HoverHandler { id: rhh }
                                }
                            }
                        }
                    }

                    // empty state — a filter that finds nothing must say so
                    Column {
                        anchors.centerIn: parent
                        spacing: tk.s2
                        visible: {
                            root.query; root.rev;
                            if (root.query === "") return false;
                            for (var i = 0; i < settings.count; i++) if (root.matches(settings.get(i))) return false;
                            return true;
                        }
                        Text { text: "NO MATCH"; color: tk.inkDim; font.family: tk.ui; font.pixelSize: tk.tRow; font.letterSpacing: 2; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "nothing in 247 settings matches “" + root.query + "”"; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tSmall; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // ── action bar: a state machine, not a decoration ────────────
            Item {
                id: bar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 62
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: tk.line }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: tk.s5
                    spacing: tk.s3
                    Rectangle {
                        width: 6; height: 6; anchors.verticalCenter: parent.verticalCenter
                        color: tk.ink
                        SequentialAnimation on opacity {
                            running: root.dirty > 0
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 480 }
                            NumberAnimation { to: 1.0; duration: 480 }
                        }
                        opacity: root.dirty > 0 ? opacity : 1
                    }
                    Text {
                        text: root.dirty > 0
                              ? (root.dirty + (root.dirty === 1 ? " CHANGE" : " CHANGES") + " · PREVIEWING · NOT SAVED")
                              : "SAVED · LIVE ON YOUR DESKTOP"
                        color: root.dirty > 0 ? tk.ink : tk.inkDim
                        font.family: tk.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1.6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: tk.s6
                    spacing: tk.s3
                    // destructive: pushed away from SAVE and kept quiet.
                    Btn { text: "RESET TO DEFAULTS"; onAct: root.revertAll() }
                    Rectangle { width: 1; height: 22; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                    Btn { text: "REVERT"; enabled_: root.dirty > 0; onAct: root.revertAll() }
                    Btn {
                        text: "SAVE"; solid: true; enabled_: root.dirty > 0
                        onAct: { for (var i = 0; i < settings.count; i++) settings.setProperty(i, "d", settings.get(i).v); root.rev++ }
                    }
                }
            }
        }
    }
}
