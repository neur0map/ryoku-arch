import QtQuick
import Quickshell

// Ryoku Hub — mock B4. Settings as a BENTO, not a straight-down table: the
// berserk poster is a modular grid of framed panels at varied size, and so is
// the acid-grotesk sheet. The preview is the hero cell and its readouts are
// callouts ON the drawing, not a column parked beside it.
// Ink ramp is contrast-solved: the old inkFaint was 2.64:1 and failed AA.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — B4"
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
                readonly property color ink: "#c2b9b0"      // 10.9:1
                readonly property color inkDim: "#9a948c"   //  7.0:1  body
                readonly property color inkMuted: "#7a756f" //  4.6:1  descriptions — AA
                readonly property color inkFaint: "#5e5a55" //  3.1:1  micro labels only
                readonly property color line: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.22)
                readonly property color lineSoft: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.10)
                readonly property int r: 2

                readonly property int s1: 4
                readonly property int s2: 8
                readonly property int s3: 12
                readonly property int s4: 16
                readonly property int s5: 24
                readonly property int s6: 32
                readonly property int tMicro: 10
                readonly property int tSmall: 12
                readonly property int tBody: 14
                readonly property int tRow: 15
                readonly property int tHero: 34
                readonly property int tTitle: 46
                readonly property int railRowH: 36

                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "SpaceMono Nerd Font"
                readonly property int snap: 90
                readonly property int move: 170
            }

            property int tab: 0
            readonly property var tabs: ["FRAME", "GLOBAL", "BAR", "SIDEBAR", "VISUALIZER"]
            property int navSel: 7
            property int rev: 0

            ListModel {
                id: st
                ListElement { key: "frame";  n: "Enable frame";         w: "Draw the rounded border around the screen"; v: "1";   d: "1";   u: "";   src: "shell.json";      ctl: "sw" }
                ListElement { key: "border"; n: "Border thickness";     w: "How far the frame intrudes on each edge";   v: "57";  d: "24";  u: "px"; src: "shell.json";      ctl: "step"; lo: 0; hi: 120 }
                ListElement { key: "radius"; n: "Frame radius";         w: "Corner rounding of the frame";              v: "2";   d: "10";  u: "px"; src: "shell.json";      ctl: "step"; lo: 0; hi: 40 }
                ListElement { key: "blur";   n: "Blur behind popouts";  w: "Compositor blur under popout surfaces";     v: "0";   d: "1";   u: "";   src: "shell.json";      ctl: "sw" }
                ListElement { key: "corner"; n: "OSD & toast corner";   w: "Where notifications grow from";             v: "28";  d: "28";  u: "px"; src: "shell.json";      ctl: "step"; lo: 0; hi: 64 }
                ListElement { key: "opac";   n: "Notification opacity"; w: "Toast surface opacity over the wallpaper";  v: "100"; d: "100"; u: "%";  src: "shell.json";      ctl: "slid"; lo: 20; hi: 100 }
                ListElement { key: "barpos"; n: "Bar position";         w: "Which frame edge the module bar rides";     v: "TOP"; d: "TOP"; u: "";   src: "shell.json";      ctl: "seg";  alt: "BOT" }
                ListElement { key: "barskin";n: "Bar skin";             w: "Module vocabulary of the resting bar";      v: "NOCT"; d: "NOCT"; u: ""; src: "shell.json";      ctl: "seg";  alt: "CAEL" }
                ListElement { key: "side";   n: "Sidebar reveal";       w: "How the side panels are summoned";          v: "HOVER"; d: "HOVER"; u: ""; src: "shell.json";    ctl: "seg";  alt: "CLICK" }
                ListElement { key: "viz";    n: "Visualiser";           w: "Audio spectrum on the desktop";             v: "0";   d: "0";   u: "";   src: "visualizer.json"; ctl: "sw" }
                ListElement { key: "gain";   n: "Visualiser gain";      w: "Input sensitivity of the spectrum";         v: "62";  d: "50";  u: "%";  src: "visualizer.json"; ctl: "slid"; lo: 0; hi: 100 }
            }

            function idx(k) { for (var i = 0; i < st.count; i++) if (st.get(i).key === k) return i; return -1 }
            function val(k) { rev; var i = idx(k); return i < 0 ? 0 : parseInt(st.get(i).v) }
            function setV(i, x) { st.setProperty(i, "v", String(x)); rev++ }
            readonly property int dirty: { rev; var n = 0; for (var i = 0; i < st.count; i++) if (st.get(i).v !== st.get(i).d) n++; return n }
            function revertAll() { for (var i = 0; i < st.count; i++) st.setProperty(i, "v", st.get(i).d); rev++ }
            Component.onCompleted: rev++

            Rectangle { anchors.fill: parent; color: tk.paper }
            Image { anchors.fill: parent; source: "grain.png"; fillMode: Image.Tile; opacity: 0.055; z: 99 }

            component Btn: Rectangle {
                id: btn
                signal act()
                property alias text: bl.text
                property bool solid: false
                property bool on_: true
                implicitWidth: bl.width + 30
                implicitHeight: 32
                radius: tk.r
                opacity: on_ ? 1 : 0.3
                color: solid && on_ ? tk.ink : (ma.containsMouse && on_ ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.10) : "transparent")
                border.width: 1
                border.color: solid && on_ ? tk.ink : tk.line
                Behavior on color { ColorAnimation { duration: tk.snap } }
                Text { id: bl; anchors.centerIn: parent; color: btn.solid && btn.on_ ? tk.paper : tk.ink; font.family: tk.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: btn.on_; cursorShape: Qt.PointingHandCursor; onClicked: btn.act() }
            }

            // ── rail ─────────────────────────────────────────────────────
            Item {
                id: rail
                anchors { left: parent.left; top: parent.top; bottom: bar.top }
                width: 300
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: tk.line }
                Column {
                    anchors.fill: parent; anchors.margins: tk.s5; spacing: tk.s4
                    Row {
                        spacing: tk.s3
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 23 }
                        Column {
                            spacing: 1
                            Text { text: "RYOKU ARCH"; color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tRow; font.weight: Font.Medium; font.letterSpacing: 2.6 }
                            Text { text: "system and shell settings"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: tk.tSmall }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 38
                        color: "transparent"; radius: tk.r; border.width: 1; border.color: tk.line
                        Row {
                            anchors.fill: parent; anchors.leftMargin: tk.s3; anchors.rightMargin: tk.s3
                            Text { text: "Search settings…"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: tk.tBody; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 190; height: 1 }
                            Text { text: "CTRL K"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: tk.tMicro; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Item {
                        width: parent.width; height: navList.height
                        Rectangle {
                            width: parent.width; height: tk.railRowH; radius: tk.r; color: tk.ink
                            y: root.navSel * tk.railRowH
                            Behavior on y { NumberAnimation { duration: tk.move; easing.type: Easing.OutCubic } }
                        }
                        Column {
                            id: navList
                            width: parent.width; spacing: 0
                            Repeater {
                                model: [
                                    { g: 0, t: "OVERVIEW" }, { g: 1, t: "Profile" },
                                    { g: 0, t: "SYSTEM" }, { g: 1, t: "Updates" }, { g: 1, t: "Displays" }, { g: 1, t: "Input" },
                                    { g: 0, t: "DESKTOP" }, { g: 1, t: "Shell" }, { g: 1, t: "Appearance" }, { g: 1, t: "App Launcher" },
                                    { g: 1, t: "Fastfetch" }, { g: 1, t: "Desktop Widgets" },
                                    { g: 0, t: "ADVANCED" }, { g: 1, t: "Keybinds" }, { g: 1, t: "Window Rules" }
                                ]
                                Item {
                                    width: parent.width; height: tk.railRowH
                                    property bool isSel: root.navSel === index
                                    Rectangle {
                                        visible: modelData.g > 0 && !parent.isSel
                                        anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1
                                        radius: tk.r
                                        color: nh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.09) : "transparent"
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    Row {
                                        visible: modelData.g === 0
                                        anchors.verticalCenter: parent.verticalCenter; spacing: tk.s2
                                        Rectangle { width: 4; height: 4; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.t; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle { width: 130; height: 1; color: tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text {
                                        visible: modelData.g > 0
                                        text: modelData.t
                                        color: parent.isSel ? tk.paper : tk.inkDim
                                        font.family: tk.ui; font.pixelSize: tk.tRow
                                        x: tk.s3; anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                    }
                                    HoverHandler { id: nh; enabled: modelData.g > 0 }
                                    TapHandler { enabled: modelData.g > 0; onTapped: root.navSel = index }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: tk.s5; bottom: parent.bottom; bottomMargin: tk.s4 }
                    text: "力  ryoku desktop"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: tk.tMicro
                }
            }

            // ── content ──────────────────────────────────────────────────
            Item {
                anchors { left: rail.right; right: parent.right; top: parent.top; bottom: bar.top }

                Column {
                    id: head
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s6; anchors.topMargin: tk.s5
                    spacing: tk.s3
                    Row {
                        spacing: tk.s2
                        Rectangle { width: 18; height: 1; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: tk.tSmall; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "DESKTOP"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 2.2; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: tk.s4
                        Text { text: "Shell"; color: tk.ink; font.family: tk.display; font.pixelSize: tk.tTitle; anchors.verticalCenter: parent.verticalCenter }
                        Btn { text: "EDIT CONFIG"; anchors.verticalCenter: parent.verticalCenter }
                    }
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
                                    TapHandler { onTapped: root.tab = index }
                                }
                            }
                        }
                    }
                }

                // ── THE BENTO ────────────────────────────────────────────
                Item {
                    id: grid
                    anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
                    anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s6
                    anchors.topMargin: tk.s5; anchors.bottomMargin: tk.s3

                    readonly property int cols: 12
                    readonly property int rows: 5
                    readonly property int gut: 10
                    readonly property real cw: (width - (cols - 1) * gut) / cols
                    readonly property real rh: (height - (rows - 1) * gut) / rows
                    function px(c) { return c * (cw + gut) }
                    function py(r) { return r * (rh + gut) }
                    function pw(s) { return s * cw + (s - 1) * gut }
                    function ph(s) { return s * rh + (s - 1) * gut }

                    // a bento cell bound to one setting
                    component Cell: Rectangle {
                        id: cell
                        property string k: ""
                        property int c: 0
                        property int s: 2
                        property int r_: 0
                        property int rs: 1
                        readonly property int i: root.idx(k)
                        readonly property var m: { root.rev; return i < 0 ? null : st.get(i) }
                        readonly property bool changed: m ? m.v !== m.d : false

                        x: grid.px(c); y: grid.py(r_)
                        width: grid.pw(s); height: grid.ph(rs)
                        color: hh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.05) : "transparent"
                        radius: tk.r
                        border.width: 1
                        border.color: hh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.42) : tk.line
                        Behavior on color { ColorAnimation { duration: tk.snap } }
                        Behavior on border.color { ColorAnimation { duration: tk.snap } }
                        HoverHandler { id: hh }

                        // changed: a solid edge on the cell. no colour needed.
                        Rectangle {
                            visible: cell.changed
                            x: 0; y: 8; width: 2; height: parent.height - 16
                            color: tk.ink
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: tk.s3
                            anchors.leftMargin: tk.s4
                            spacing: 1
                            Text { text: cell.m ? cell.m.n.toUpperCase() : ""; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                            Row {
                                spacing: 3
                                Text {
                                    text: !cell.m ? "" : (cell.m.ctl === "sw" ? (cell.m.v === "1" ? "ON" : "OFF") : cell.m.v)
                                    color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tHero; font.weight: Font.Light
                                }
                                Text { text: cell.m ? cell.m.u : ""; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 11; anchors.bottom: parent.bottom; anchors.bottomMargin: 6 }
                                Text {
                                    visible: cell.changed
                                    text: cell.m ? ((cell.m.ctl === "sw" ? (cell.m.d === "1" ? "ON" : "OFF") : cell.m.d) + (cell.m.u ? " " + cell.m.u : "")) : ""
                                    color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; font.strikeout: true
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                }
                            }
                            Text {
                                width: cell.width - tk.s4 - tk.s3
                                text: cell.m ? cell.m.w : ""
                                color: tk.inkMuted; font.family: tk.ui; font.pixelSize: tk.tSmall
                                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            }
                        }

                        // control at the cell's foot
                        Item {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: tk.s3 }
                            anchors.leftMargin: tk.s4
                            height: 26
                            Text {
                                text: cell.m ? cell.m.src : ""
                                color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                visible: cell.m && cell.m.ctl === "sw"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 56; height: 24; radius: tk.r; antialiasing: false
                                color: "transparent"; border.width: 1; border.color: tk.line
                                Rectangle {
                                    width: 26; height: 17; y: 3; radius: tk.r; antialiasing: false
                                    x: cell.m && cell.m.v === "1" ? parent.width - width - 3 : 3
                                    color: cell.m && cell.m.v === "1" ? tk.ink : "transparent"
                                    border.width: cell.m && cell.m.v === "1" ? 0 : 1
                                    border.color: tk.line
                                    Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                                }
                                TapHandler { onTapped: root.setV(cell.i, cell.m.v === "1" ? "0" : "1") }
                            }
                            Row {
                                visible: cell.m && cell.m.ctl === "step"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Repeater {
                                    model: ["−", "+"]
                                    Rectangle {
                                        required property string modelData
                                        width: 30; height: 24; radius: tk.r
                                        color: bh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.16) : "transparent"
                                        border.width: 1; border.color: tk.line
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                        Text { anchors.centerIn: parent; text: parent.modelData; color: tk.inkDim; font.family: tk.ui; font.pixelSize: 13 }
                                        HoverHandler { id: bh }
                                        TapHandler {
                                            onTapped: {
                                                var o = st.get(cell.i);
                                                var step = (o.hi - o.lo) > 60 ? 4 : 1;
                                                var nv = parseInt(o.v) + (parent.modelData === "+" ? step : -step);
                                                root.setV(cell.i, Math.max(o.lo, Math.min(o.hi, nv)));
                                            }
                                        }
                                    }
                                }
                            }
                            Item {
                                visible: cell.m && cell.m.ctl === "slid"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(190, cell.width * 0.5); height: 24
                                readonly property real frac: cell.m ? (parseInt(cell.m.v) - cell.m.lo) / Math.max(1, cell.m.hi - cell.m.lo) : 0
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: "transparent"; border.width: 1; border.color: tk.line; antialiasing: false }
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * parent.frac; height: 4; color: tk.ink; antialiasing: false }
                                Rectangle { x: Math.min(parent.width - 6, Math.max(0, parent.width * parent.frac - 3)); anchors.verticalCenter: parent.verticalCenter; width: 6; height: 17; color: tk.ink; antialiasing: false }
                                TapHandler {
                                    onTapped: (p) => {
                                        var o = st.get(cell.i);
                                        var f = Math.max(0, Math.min(1, p.position.x / parent.width));
                                        root.setV(cell.i, Math.round(o.lo + f * (o.hi - o.lo)));
                                    }
                                }
                                DragHandler {
                                    target: null
                                    onCentroidChanged: {
                                        if (!active) return;
                                        var o = st.get(cell.i);
                                        var f = Math.max(0, Math.min(1, centroid.position.x / parent.width));
                                        root.setV(cell.i, Math.round(o.lo + f * (o.hi - o.lo)));
                                    }
                                }
                            }
                            Row {
                                visible: cell.m && cell.m.ctl === "seg"
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Repeater {
                                    model: 2
                                    Rectangle {
                                        required property int index
                                        readonly property string lbl: !cell.m ? "" : (index === 0 ? cell.m.d : cell.m.alt)
                                        width: 56; height: 24; radius: tk.r
                                        color: cell.m && cell.m.v === lbl ? tk.ink : "transparent"
                                        border.width: 1; border.color: tk.line
                                        Behavior on color { ColorAnimation { duration: tk.snap } }
                                        Text { anchors.centerIn: parent; text: parent.lbl; color: cell.m && cell.m.v === parent.lbl ? tk.paper : tk.inkDim; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium }
                                        TapHandler { onTapped: root.setV(cell.i, parent.lbl) }
                                    }
                                }
                            }
                        }
                    }

                    // ── hero cell: the preview, with its readouts as CALLOUTS
                    Rectangle {
                        id: hero
                        x: grid.px(0); y: grid.py(0)
                        width: grid.pw(7); height: grid.ph(3)
                        color: "transparent"; radius: tk.r
                        border.width: 1; border.color: tk.line

                        Text {
                            text: "LIVE PREVIEW"; color: tk.inkMuted
                            font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 1.4
                            anchors { left: parent.left; top: parent.top; margins: tk.s4 }
                        }
                        Text {
                            text: "eDP-1 · 2560×1600 · 1.25×"; color: tk.inkFaint
                            font.family: tk.mono; font.pixelSize: 9
                            anchors { right: parent.right; top: parent.top; margins: tk.s4 }
                        }

                        Canvas {
                            id: prev
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 6
                            width: parent.width - 200
                            height: parent.height - 96
                            property int bw: { root.rev; return root.val("border") }
                            property int br: { root.rev; return root.val("radius") }
                            property int op: { root.rev; return root.val("opac") }
                            property int cor: { root.rev; return root.val("corner") }
                            property bool on: { root.rev; return root.val("frame") === 1 }
                            property bool barTop: { root.rev; var i = root.idx("barpos"); return i < 0 || st.get(i).v === "TOP" }
                            property bool viz: { root.rev; return root.val("viz") === 1 }
                            property int gain: { root.rev; return root.val("gain") }
                            onBarTopChanged: requestPaint()
                            onVizChanged: requestPaint()
                            onGainChanged: requestPaint()
                            onBwChanged: requestPaint()
                            onBrChanged: requestPaint()
                            onOpChanged: requestPaint()
                            onCorChanged: requestPaint()
                            onOnChanged: requestPaint()
                            onPaint: {
                                var c = getContext("2d");
                                c.reset();
                                c.strokeStyle = "rgba(194,185,176,0.16)"; c.lineWidth = 1;
                                c.strokeRect(0.5, 0.5, width - 1, height - 1);
                                if (!on) {
                                    c.fillStyle = "rgba(194,185,176,0.45)";
                                    c.font = "12px sans-serif";
                                    c.fillText("FRAME OFF", width / 2 - 30, height / 2);
                                    return;
                                }
                                var t = Math.max(1, bw / 120 * 26);
                                var rr = br / 40 * 20;
                                c.strokeStyle = "rgba(194,185,176,0.9)";
                                c.lineWidth = t;
                                var x = t / 2 + 2, y = t / 2 + 2, w = width - t - 4, h = height - t - 4;
                                c.beginPath();
                                c.moveTo(x + rr, y);
                                c.lineTo(x + w - rr, y); c.quadraticCurveTo(x + w, y, x + w, y + rr);
                                c.lineTo(x + w, y + h - rr); c.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
                                c.lineTo(x + rr, y + h); c.quadraticCurveTo(x, y + h, x, y + h - rr);
                                c.lineTo(x, y + rr); c.quadraticCurveTo(x, y, x + rr, y);
                                c.closePath(); c.stroke();

                                // ---- the desktop the frame surrounds ----
                                var ix = t + 2, iy = t + 2, iw = width - 2 * t - 4, ih = height - 2 * t - 4;
                                c.save();
                                c.beginPath(); c.rect(ix, iy, iw, ih); c.clip();

                                // two windows
                                c.strokeStyle = "rgba(194,185,176,0.22)"; c.lineWidth = 1;
                                c.strokeRect(ix + 26.5, iy + 40.5, iw * 0.42, ih * 0.52);
                                c.strokeRect(ix + iw * 0.5, iy + 62.5, iw * 0.40, ih * 0.44);
                                c.fillStyle = "rgba(194,185,176,0.05)";
                                c.fillRect(ix + 26, iy + 40, iw * 0.42, ih * 0.52);

                                // the module bar, on whichever edge it rides
                                var barY = barTop ? iy + 10 : iy + ih - 10 - 16;
                                c.fillStyle = "rgba(194,185,176,0.16)";
                                c.fillRect(ix + iw * 0.24, barY, iw * 0.52, 16);
                                c.fillStyle = "rgba(194,185,176,0.5)";
                                c.fillRect(ix + iw * 0.24 + 8, barY + 5, 6, 6);          // the 力 seal slot
                                for (var k = 0; k < 4; k++)
                                    c.fillRect(ix + iw * 0.24 + 24 + k * 12, barY + 6, 8, 4);
                                c.fillRect(ix + iw * 0.76 - 30, barY + 6, 22, 4);        // clock slot

                                // the visualiser, if it is on
                                if (viz) {
                                    var bars = 26, bw2 = iw * 0.5 / bars;
                                    for (var j = 0; j < bars; j++) {
                                        var amp = (Math.sin(j * 1.7) * 0.5 + 0.5) * (gain / 100) * ih * 0.3 + 3;
                                        c.fillStyle = "rgba(194,185,176,0.28)";
                                        c.fillRect(ix + iw * 0.25 + j * bw2, iy + ih - amp - 4, bw2 - 2, amp);
                                    }
                                }
                                c.restore();

                                // the toast, at its live corner offset + opacity
                                var off = cor / 64 * 26;
                                c.globalAlpha = op / 100;
                                c.fillStyle = "rgba(194,185,176,0.62)";
                                c.fillRect(width - t - 86 - off * 0.4, t + 8 + off * 0.4, 66, 24);
                                c.globalAlpha = 1;
                            }
                        }

                        // callouts — the readout sits ON the drawing it describes
                        component Callout: Row {
                            property string lab: ""
                            property string v: ""
                            property string u: ""
                            property bool flip: false
                            spacing: 6
                            Column {
                                visible: !parent.flip
                                spacing: -2
                                Text { text: parent.parent.lab; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.2; horizontalAlignment: Text.AlignRight; width: 62 }
                                Row {
                                    spacing: 2
                                    anchors.right: parent.right
                                    Text { text: parent.parent.parent.v; color: tk.ink; font.family: tk.ui; font.pixelSize: 22; font.weight: Font.Light }
                                    Text { text: parent.parent.parent.u; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 }
                                }
                            }
                            Rectangle { width: 20; height: 1; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 4; height: 4; radius: 2; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                visible: parent.flip
                                spacing: -2
                                Text { text: parent.parent.lab; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.2 }
                                Row {
                                    spacing: 2
                                    Text { text: parent.parent.parent.v; color: tk.ink; font.family: tk.ui; font.pixelSize: 22; font.weight: Font.Light }
                                    Text { text: parent.parent.parent.u; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 4 }
                                }
                            }
                        }

                        Callout {
                            lab: "BORDER"; u: "px"
                            v: { root.rev; return String(root.val("border")) }
                            anchors { right: prev.left; rightMargin: -10; top: prev.top; topMargin: 8 }
                        }
                        Callout {
                            lab: "RADIUS"; u: "px"
                            v: { root.rev; return String(root.val("radius")) }
                            anchors { right: prev.left; rightMargin: -10; bottom: prev.bottom; bottomMargin: 8 }
                        }
                        Callout {
                            flip: true
                            lab: "TOAST"; u: "%"
                            v: { root.rev; return String(root.val("opac")) }
                            anchors { left: prev.right; leftMargin: -10; top: prev.top; topMargin: 8 }
                        }
                        Callout {
                            flip: true
                            lab: "CORNER"; u: "px"
                            v: { root.rev; return String(root.val("corner")) }
                            anchors { left: prev.right; leftMargin: -10; bottom: prev.bottom; bottomMargin: 8 }
                        }
                    }

                    // ── the bento cells ──────────────────────────────────
                    Cell { k: "border"; c: 7; s: 3; r_: 0 }
                    Cell { k: "radius"; c: 10; s: 2; r_: 0 }
                    Cell { k: "frame";  c: 7; s: 2; r_: 1 }
                    Cell { k: "blur";   c: 9; s: 3; r_: 1 }
                    Cell { k: "opac";   c: 7; s: 5; r_: 2 }

                    Cell { k: "corner";  c: 0; s: 3; r_: 3 }
                    Cell { k: "barpos";  c: 3; s: 3; r_: 3 }
                    Cell { k: "barskin"; c: 6; s: 3; r_: 3 }
                    Cell { k: "side";    c: 9; s: 3; r_: 3 }

                    Cell { k: "viz";  c: 0; s: 3; r_: 4 }
                    Cell { k: "gain"; c: 3; s: 5; r_: 4 }

                    // STATE — inverted. the one loud object on the sheet.
                    Rectangle {
                        x: grid.px(8); y: grid.py(4)
                        width: grid.pw(4); height: grid.ph(1)
                        color: tk.ink; radius: tk.r
                        Row {
                            anchors.fill: parent; anchors.margins: tk.s4; spacing: tk.s4
                            Row {
                                spacing: tk.s2
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: String(root.dirty); color: tk.paper; font.family: tk.ui; font.pixelSize: 40; font.weight: Font.Light }
                                Text {
                                    text: root.dirty === 1 ? "CHANGE" : "CHANGES"
                                    color: Qt.rgba(0, 0, 0, 0.5); font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.2
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                                }
                            }
                            Rectangle { width: 1; height: parent.height * 0.6; color: Qt.rgba(0, 0, 0, 0.22); anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                width: 190
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.dirty > 0 ? "Previewing live. Nothing is written until you save."
                                                     : "Everything matches what is on disk."
                                color: Qt.rgba(0, 0, 0, 0.62); font.family: tk.ui; font.pixelSize: tk.tSmall
                                wrapMode: Text.WordWrap
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
                    anchors.left: parent.left; anchors.leftMargin: tk.s5
                    spacing: tk.s3
                    Rectangle {
                        width: 6; height: 6; color: tk.ink; anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: root.dirty > 0
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 480 }
                            NumberAnimation { to: 1.0; duration: 480 }
                        }
                    }
                    Text {
                        text: root.dirty > 0 ? (root.dirty + (root.dirty === 1 ? " CHANGE" : " CHANGES") + " · PREVIEWING · NOT SAVED")
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
                    Btn { text: "RESET TO DEFAULTS"; onAct: root.revertAll() }
                    Rectangle { width: 1; height: 22; color: tk.line; anchors.verticalCenter: parent.verticalCenter }
                    Btn { text: "REVERT"; on_: root.dirty > 0; onAct: root.revertAll() }
                    Btn {
                        text: "SAVE"; solid: true; on_: root.dirty > 0
                        onAct: { for (var i = 0; i < st.count; i++) st.setProperty(i, "d", st.get(i).v); root.rev++ }
                    }
                }
            }
        }
    }
}
