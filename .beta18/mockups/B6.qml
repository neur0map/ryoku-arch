import QtQuick
import QtQuick.Controls
import Quickshell

// Ryoku Hub — mock B5. Answers two real defects in B4:
//
//  1. POSITION. Cells were hand-placed to fill the grid — Tetris, not meaning.
//     Now: settings live in semantic SECTIONS, each section Flow-packs its own
//     cells, and a cell's span is DERIVED from what its control needs. Nothing
//     is authored by hand, so it scales past one page.
//  2. OPTIONS. `seg` could only do 2. The real Hub's histogram: 14 controls
//     with 2 options, 21 with 3, 9 with 4-6, one with 7, and a 25-entry font
//     list — plus islandModules, which is set membership, not a choice.
//     Full taxonomy below.
//
// The preview is PINNED: it is the feedback loop, so it must never scroll away
// from the control you are turning.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub — B6"
        minimumSize: Qt.size(1280, 820)
        color: "#000000"
        onClosed: Qt.quit()

        Item {
            id: root
            anchors.fill: parent

            QtObject {
                id: tk
                readonly property color paper: "#000000"
                readonly property color ink: "#cdc4ba"      // 12.0:1
                readonly property color inkDim: "#b0a9a0"   //  9.0:1  body
                readonly property color inkMuted: "#958f87" //  6.6:1  descriptions
                readonly property color inkFaint: "#7a756e" //  4.6:1  micro — AA, was 3.07 and failing
                readonly property color line: Qt.rgba(205 / 255, 196 / 255, 186 / 255, 0.26)
                readonly property color lineSoft: Qt.rgba(205 / 255, 196 / 255, 186 / 255, 0.13)
                readonly property int r: 2
                readonly property int s1: 4
                readonly property int s2: 8
                readonly property int s3: 12
                readonly property int s4: 16
                readonly property int s5: 24
                readonly property int s6: 32
                readonly property int tMicro: 11
                readonly property int tSmall: 13
                readonly property int tBody: 14
                readonly property int tRow: 15
                readonly property int tTitle: 44
                readonly property string display: "Fraunces"
                readonly property string ui: "Space Grotesk"
                readonly property string mono: "SpaceMono Nerd Font"
                readonly property int snap: 90
                readonly property int move: 170
                readonly property int cellH: 104
            }

            property int navSel: 7
            property int rev: 0
            property int openPick: -1

            // ── the real option sets, taken from the Hub ─────────────────
            readonly property var fonts: [
                "JetBrains Mono", "Fira Code", "Hack", "Cascadia Code", "Space Grotesk",
                "Inter", "IBM Plex Sans", "Source Code Pro", "Iosevka", "Victor Mono",
                "Recursive", "Departure Mono", "Berkeley Mono", "Commit Mono", "Geist Mono",
                "Martian Mono", "Space Mono", "DM Mono", "Azeret Mono", "Chivo Mono",
                "Roboto Mono", "Ubuntu Mono", "Noto Sans Mono", "Adwaita Mono", "Liberation Mono"
            ]
            readonly property var vizStyles: ["Bars", "Dots", "Wave", "Mirror", "Ring", "Spine", "Bloom"]
            // all ten, from docs/bar.md + pill/Bar.qml. a text label cannot
            // convey any of these — which is exactly why this is a gallery.
            readonly property var skins: [
                { k: "noctalia",  o: "reference", w: "Capsule modules in a row; dot workspaces" },
                { k: "caelestia", o: "reference", w: "Numbered cell strip in one pill, sliding indicator" },
                { k: "aegis",     o: "ryoku",     w: "Flat modules with hairline accent underlines" },
                { k: "stele",     o: "ryoku",     w: "Engraved bracket cells" },
                { k: "triptych",  o: "ryoku",     w: "Three rounded islands on the band" },
                { k: "delos",     o: "ryoku",     w: "The whole bar collapsed into one floating island" },
                { k: "nacre",     o: "ryoku",     w: "Three islands with concave dips, hairline top edge" },
                { k: "inir",      o: "inir",      w: "Flat TUI panel, hairline cell separators" },
                { k: "aurora",    o: "inir",      w: "Translucent glass with a soft top sheen" },
                { k: "angel",     o: "inir",      w: "Opaque brutalist panel, heavy base, bright inset top" }
            ]
            readonly property var modules: ["workspaces", "clock", "date", "media", "tray", "power", "weather"]

            ListModel {
                id: st
                // ctl taxonomy: sw | step | slid | seg | chips | pick | multi
                ListElement { sec: "FRAME"; key: "frame"; jk: "frameEnabled";  n: "Enable frame";        w: "Draw the rounded border around the screen"; v: "1"; d: "1"; u: ""; src: "shell.json"; ctl: "sw" }
                ListElement { sec: "FRAME"; key: "border"; jk: "frameThickness"; n: "Border thickness";    w: "How far the frame intrudes on each edge";   v: "57"; d: "24"; u: "px"; src: "shell.json"; ctl: "step"; lo: 0; hi: 120 }
                ListElement { sec: "FRAME"; key: "radius"; jk: "frameRadius"; n: "Frame radius";        w: "Corner rounding of the frame";              v: "2"; d: "10"; u: "px"; src: "shell.json"; ctl: "step"; lo: 0; hi: 40 }
                ListElement { sec: "FRAME"; key: "blur"; jk: "blurPopouts";   n: "Blur behind popouts"; w: "Compositor blur under popout surfaces";     v: "0"; d: "1"; u: ""; src: "shell.json"; ctl: "sw" }

                ListElement { sec: "NOTIFICATIONS"; key: "corner"; jk: "toastCorner"; n: "Toast corner"; w: "Which corner notifications grow from"; v: "TOP RIGHT"; d: "TOP RIGHT"; u: ""; src: "shell.json"; ctl: "seg"; opts: "TOP LEFT,TOP RIGHT,BOTTOM RIGHT,BOTTOM LEFT" }
                ListElement { sec: "NOTIFICATIONS"; key: "opac"; jk: "toastOpacity";   n: "Toast opacity"; w: "Surface opacity over the wallpaper";  v: "100"; d: "100"; u: "%"; src: "shell.json"; ctl: "slid"; lo: 20; hi: 100 }
                ListElement { sec: "NOTIFICATIONS"; key: "dwell"; jk: "toastDwell";  n: "Dwell";         w: "How long a toast rests before it goes"; v: "6"; d: "6"; u: "s"; src: "shell.json"; ctl: "step"; lo: 1; hi: 30 }

                // 2 options — the real skins, carried from the credited shells
                ListElement { sec: "BAR"; key: "barskin"; jk: "barStyle"; n: "Bar skin"; w: "Module vocabulary of the resting bar. Ten skins: two carried from the credited reference shells, five of ours, three flat frame-off ports."; v: "noctalia"; d: "noctalia"; u: ""; src: "shell.json"; ctl: "gallery" }
                // 3 options — the most common shape in the Hub (21 controls)
                ListElement { sec: "BAR"; key: "edge"; jk: "islandEdge";    n: "Island edge"; w: "Which frame edge the bar rides";      v: "TOP"; d: "TOP"; u: ""; src: "shell.json"; ctl: "seg"; opts: "TOP,BOTTOM,HIDDEN" }
                ListElement { sec: "BAR"; key: "along"; jk: "islandAlong";   n: "Alignment";   w: "Where the island sits along its edge"; v: "CENTRE"; d: "CENTRE"; u: ""; src: "shell.json"; ctl: "seg"; opts: "START,CENTRE,END" }
                // set membership — NOT a choice. 4 of 7 selected.
                ListElement { sec: "BAR"; key: "mods"; jk: "islandModules";    n: "Island modules"; w: "Which modules the bar carries. Order follows the strip."; v: "workspaces,clock,date,media"; d: "workspaces,clock,date,media"; u: ""; src: "shell.json"; ctl: "multi" }
                ListElement { sec: "BAR"; key: "iradius"; jk: "islandRadius"; n: "Island radius"; w: "Corner rounding of the bar itself"; v: "17"; d: "17"; u: "px"; src: "shell.json"; ctl: "step"; lo: 0; hi: 30 }

                // 25 options — a catalogue. a segmented cannot hold this.
                ListElement { sec: "TYPE"; key: "uifont"; jk: "uiFont";   n: "UI font";   w: "Body and label face across the shell"; v: "Space Grotesk"; d: "Space Grotesk"; u: ""; src: "shell.json"; ctl: "pick" }
                ListElement { sec: "TYPE"; key: "monofont"; jk: "monoFont"; n: "Mono font"; w: "Numerals, code and technical labels"; v: "JetBrains Mono"; d: "Space Mono"; u: ""; src: "shell.json"; ctl: "pick" }

                ListElement { sec: "VISUALISER"; key: "viz"; jk: "vizEnabled";   n: "Visualiser"; w: "Audio spectrum on the desktop"; v: "0"; d: "0"; u: ""; src: "visualizer.json"; ctl: "sw" }
                // 7 options — too many to segment, few enough to show as chips
                ListElement { sec: "VISUALISER"; key: "vstyle"; jk: "vizStyle"; n: "Style";   w: "How the spectrum is drawn"; v: "Bars"; d: "Bars"; u: ""; src: "visualizer.json"; ctl: "chips" }
                ListElement { sec: "VISUALISER"; key: "gain"; jk: "vizGain";  n: "Gain";     w: "Input sensitivity of the spectrum"; v: "62"; d: "50"; u: "%"; src: "visualizer.json"; ctl: "slid"; lo: 0; hi: 100 }
            }

            function idx(k) { for (var i = 0; i < st.count; i++) if (st.get(i).key === k) return i; return -1 }
            function val(k) { rev; var i = idx(k); return i < 0 ? 0 : parseInt(st.get(i).v) }
            function sval(k) { rev; var i = idx(k); return i < 0 ? "" : st.get(i).v }
            function setV(i, x) { st.setProperty(i, "v", String(x)); rev++ }
            function optsOf(m) {
                if (m.ctl === "pick") return m.key === "vstyle" ? root.vizStyles : root.fonts;
                if (m.ctl === "chips") return root.vizStyles;
                if (m.ctl === "multi") return root.modules;
                if (m.ctl === "gallery") return root.skins.map(function (x) { return x.k });
                return m.opts ? m.opts.split(",") : [];
            }
            // THE RULE: a cell's span is derived from what the control needs.
            // Nothing is hand-placed.
            function spanOf(m) {
                var o = optsOf(m).length;
                switch (m.ctl) {
                case "sw":    return 4;
                case "step":  return 4;
                case "slid":  return 6;
                case "pick":  return 5;                       // a dropdown is compact whatever the catalogue size
                case "chips": return o <= 4 ? 6 : 10;
                case "gallery": return 12;
                case "multi": return 12;   // set membership always wants the full row
                case "seg":   return o <= 2 ? 4 : (o === 3 ? 6 : 8);    // 4 fits at 8; 5+ becomes chips
                }
                return 4;
            }
            // how many rows a control needs. inline controls sit beside the
            // text; block controls (a gallery, a chip field) get their own band
            // underneath — which is what stops anything overlapping.
            function rowsOf(m) {
                switch (m.ctl) {
                case "gallery": return 3;
                case "multi": return 2;
                case "chips": return 2;
                default: return 1;
                }
            }
            function inlineW(m) {
                switch (m.ctl) {
                case "sw": return 54;
                case "step": return 58;
                case "slid": return 180;
                case "seg": return root.optsOf(m).length * 64;
                case "pick": return 190;
                }
                return 0;
            }
            // render a value as it appears in the config file
            function lit(m, raw) {
                if (m.ctl === "sw") return raw === "1" ? "true" : "false";
                if (m.ctl === "multi") return "[" + raw.split(",").filter(function (x) { return x.length }).map(function (x) { return "\"" + x + "\"" }).join(", ") + "]";
                if (m.ctl === "step" || m.ctl === "slid") return raw;
                return "\"" + raw + "\"";
            }
            // the diff, grouped by the file it lands in
            readonly property var diff: {
                rev;
                var files = {}, order = [];
                for (var i = 0; i < st.count; i++) {
                    var m = st.get(i);
                    if (m.v === m.d) continue;
                    if (!files[m.src]) { files[m.src] = []; order.push(m.src) }
                    files[m.src].push({ jk: m.jk, was: lit(m, m.d), now: lit(m, m.v) });
                }
                var rows = [];
                for (var f = 0; f < order.length; f++) {
                    rows.push({ head: true, t: order[f], n: files[order[f]].length });
                    for (var r = 0; r < files[order[f]].length; r++) {
                        var e = files[order[f]][r];
                        rows.push({ head: false, k: e.jk, was: e.was, now: e.now });
                    }
                }
                return rows;
            }
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
                width: 268
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: tk.line }
                Column {
                    anchors.fill: parent; anchors.margins: tk.s5; spacing: tk.s4
                    Row {
                        spacing: tk.s3
                        Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 22 }
                        Column {
                            spacing: 1
                            Text { text: "RYOKU ARCH"; color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tBody; font.weight: Font.Medium; font.letterSpacing: 2.4 }
                            Text { text: "system and shell settings"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 11 }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 36
                        color: "transparent"; radius: tk.r; border.width: 1; border.color: tk.line
                        Row {
                            anchors.fill: parent; anchors.leftMargin: tk.s3; anchors.rightMargin: tk.s3
                            Text { text: "Search settings…"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: tk.tSmall; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 170; height: 1 }
                            Text { text: "CTRL K"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Item {
                        width: parent.width; height: navList.height
                        Rectangle {
                            width: parent.width; height: 34; radius: tk.r; color: tk.ink
                            y: root.navSel * 34
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
                                    width: parent.width; height: 34
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
                                        Text { text: modelData.t; color: tk.inkFaint; font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle { width: 110; height: 1; color: tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text {
                                        visible: modelData.g > 0
                                        text: modelData.t
                                        color: parent.isSel ? tk.paper : tk.inkDim
                                        font.family: tk.ui; font.pixelSize: tk.tBody
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
            }

            // ── head ─────────────────────────────────────────────────────
            Column {
                id: head
                anchors { left: rail.right; right: parent.right; top: parent.top }
                anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s6; anchors.topMargin: tk.s5
                spacing: tk.s2
                Row {
                    spacing: tk.s2
                    Rectangle { width: 16; height: 1; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "力"; color: tk.ink; font.family: "Noto Sans CJK JP"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "DESKTOP"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 2.2; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: tk.s4
                    Text { text: "Shell"; color: tk.ink; font.family: tk.display; font.pixelSize: tk.tTitle; anchors.verticalCenter: parent.verticalCenter }
                    Btn { text: "EDIT CONFIG"; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // ── sections (scroll) ────────────────────────────────────────
            Flickable {
                id: flick
                anchors { left: rail.right; top: head.bottom; bottom: bar.top }
                anchors.right: side.left
                anchors.leftMargin: tk.s6; anchors.rightMargin: tk.s5; anchors.topMargin: tk.s4
                contentHeight: secCol.height + tk.s5
                clip: true
                ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 3; color: tk.line } }

                readonly property int cols: 12
                readonly property int gut: 8
                readonly property real cw: (width - (cols - 1) * gut) / cols
                function w(s) { return s * cw + (s - 1) * gut }

                Column {
                    id: secCol
                    width: flick.width
                    spacing: tk.s5

                    Repeater {
                        model: ["FRAME", "NOTIFICATIONS", "BAR", "TYPE", "VISUALISER"]
                        Column {
                            id: sect
                            required property string modelData
                            width: parent.width
                            spacing: tk.s3

                            // section header — the settings are grouped by MEANING
                            Row {
                                spacing: tk.s2
                                Rectangle { width: 4; height: 4; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: sect.modelData; color: tk.ink; font.family: tk.ui; font.pixelSize: tk.tMicro; font.weight: Font.Medium; font.letterSpacing: 2.2; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { width: secCol.width - 200; height: 1; color: tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                            }

                            // Flow packs the cells. no hand placement anywhere.
                            Flow {
                                width: parent.width
                                spacing: flick.gut

                                Repeater {
                                    model: st
                                    delegate: Loader {
                                        required property int index
                                        required property var model
                                        active: model.sec === sect.modelData
                                        visible: active
                                        width: active ? flick.w(root.spanOf(model)) : 0
                                        height: active ? (root.rowsOf(model) * tk.cellH + (root.rowsOf(model) - 1) * flick.gut) : 0
                                        sourceComponent: cellComp
                                        property int mi: index
                                        property var mm: model
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // one cell. its span came from spanOf(); it only draws itself.
            Component {
                id: cellComp
                Rectangle {
                    id: cell
                    readonly property int i: parent.mi
                    readonly property var m: { root.rev; return parent.mm }
                    readonly property bool changed: m ? m.v !== m.d : false
                    readonly property var opts: m ? root.optsOf(m) : []

                    color: hh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.05) : "transparent"
                    radius: tk.r
                    border.width: 1
                    border.color: hh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.42) : tk.line
                    Behavior on color { ColorAnimation { duration: tk.snap } }
                    Behavior on border.color { ColorAnimation { duration: tk.snap } }
                    HoverHandler { id: hh }

                    Rectangle { visible: cell.changed; x: 0; y: 8; width: 2; height: parent.height - 16; color: tk.ink }

                    // which file writes this — corner, out of the reading path
                    Text {
                        anchors { right: parent.right; top: parent.top; margins: tk.s3 }
                        text: cell.m ? cell.m.src.replace(".json", "") : ""
                        color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9
                        opacity: hh.hovered ? 1 : 0.8
                        Behavior on opacity { NumberAnimation { duration: tk.snap } }
                    }

                    // a wide cell puts its control beside the value; a narrow one
                    // stacks and drops the control to the foot. same component.
                    readonly property bool wide: m ? root.spanOf(m) >= 6 : false

                    readonly property int ctlW: m ? root.inlineW(m) : 0
                    readonly property bool block: m ? root.rowsOf(m) > 1 : false

                    Column {
                        anchors { left: parent.left; top: parent.top; margins: tk.s3 }
                        anchors.leftMargin: tk.s4
                        anchors.rightMargin: tk.s3
                        // reserve the control's footprint. nothing can overlap.
                        width: cell.width - tk.s4 - tk.s3 - (cell.block ? 0 : cell.ctlW + tk.s4) - 46
                        spacing: 0
                        Text {
                            width: parent.width
                            text: cell.m ? cell.m.n.toUpperCase() : ""
                            color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 10
                            font.weight: Font.Medium; font.letterSpacing: 1.4
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 4
                            visible: cell.m && cell.m.ctl !== "multi" && cell.m.ctl !== "chips" && cell.m.ctl !== "gallery"
                            Text {
                                text: !cell.m ? "" : (cell.m.ctl === "sw" ? (cell.m.v === "1" ? "ON" : "OFF") : cell.m.v)
                                color: tk.ink; font.family: tk.ui
                                font.pixelSize: (cell.m && cell.m.v.length > 8) ? 18 : 28
                                font.weight: Font.Light
                            }
                            Text { text: cell.m ? cell.m.u : ""; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 5 }
                            Text {
                                visible: cell.changed
                                text: cell.m ? ((cell.m.ctl === "sw" ? (cell.m.d === "1" ? "ON" : "OFF") : cell.m.d) + (cell.m.u ? " " + cell.m.u : "")) : ""
                                color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; font.strikeout: true
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            }
                        }
                        // the gallery's current value reads as a title
                        Row {
                            spacing: 6
                            visible: cell.m && cell.m.ctl === "gallery"
                            Text { text: cell.m ? cell.m.v : ""; color: tk.ink; font.family: tk.ui; font.pixelSize: 26; font.weight: Font.Light }
                            Text {
                                visible: cell.changed
                                text: cell.m ? cell.m.d : ""
                                color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; font.strikeout: true
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            }
                        }
                        Item { width: 1; height: 2 }
                        Text {
                            width: parent.width
                            text: cell.m ? cell.m.w : ""
                            color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 12
                            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        }
                    }


                    // ── gallery: ten skins you can actually SEE ──────────
                    Flow {
                        visible: cell.m && cell.m.ctl === "gallery"
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: tk.s3 }
                        anchors.leftMargin: tk.s4
                        anchors.topMargin: 84
                        spacing: 7
                        Repeater {
                            model: cell.m && cell.m.ctl === "gallery" ? root.skins : []
                            Rectangle {
                                required property var modelData
                                readonly property bool on: cell.m && cell.m.v === modelData.k
                                width: 132; height: 74
                                radius: tk.r
                                color: on ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.10) : "transparent"
                                border.width: 1
                                border.color: on ? tk.ink : (th.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.45) : tk.line)
                                Behavior on color { ColorAnimation { duration: tk.snap } }
                                Behavior on border.color { ColorAnimation { duration: tk.snap } }

                                // each skin drawn as its own silhouette
                                Canvas {
                                    id: sk
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7 }
                                    height: 32
                                    onPaint: {
                                        var c = getContext("2d"); c.reset();
                                        var W = width, H = height, k = parent.modelData.k;
                                        var fg = parent.on ? "rgba(205,196,186,0.98)" : "rgba(205,196,186,0.62)";
                                        var dim = parent.on ? "rgba(205,196,186,0.45)" : "rgba(205,196,186,0.28)";
                                        c.fillStyle = fg; c.strokeStyle = fg; c.lineWidth = 1;
                                        function pill(x, y, w, h, r) {
                                            c.beginPath();
                                            c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r);
                                            c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                                            c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r);
                                            c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y); c.closePath();
                                        }
                                        var by = 10, bh = 12;
                                        if (k === "noctalia") {
                                            for (var i = 0; i < 4; i++) { pill(4 + i * 30, by, 24, bh, 6); c.fill() }
                                        } else if (k === "caelestia") {
                                            pill(4, by, W - 8, bh, 6); c.fillStyle = dim; c.fill();
                                            c.fillStyle = fg; pill(8, by + 2, 22, bh - 4, 4); c.fill();
                                            c.fillStyle = dim; for (var j = 1; j < 4; j++) { pill(8 + j * 26, by + 2, 22, bh - 4, 4); c.stroke() }
                                        } else if (k === "aegis") {
                                            for (var a = 0; a < 4; a++) { c.fillStyle = dim; c.fillRect(4 + a * 30, by, 24, bh); c.fillStyle = fg; c.fillRect(4 + a * 30, by + bh - 2, 24, 2) }
                                        } else if (k === "stele") {
                                            for (var b = 0; b < 4; b++) {
                                                var x0 = 4 + b * 30;
                                                c.beginPath(); c.moveTo(x0 + 4, by); c.lineTo(x0, by); c.lineTo(x0, by + bh); c.lineTo(x0 + 4, by + bh); c.stroke();
                                                c.beginPath(); c.moveTo(x0 + 20, by); c.lineTo(x0 + 24, by); c.lineTo(x0 + 24, by + bh); c.lineTo(x0 + 20, by + bh); c.stroke();
                                                c.fillStyle = dim; c.fillRect(x0 + 7, by + 4, 10, 4);
                                            }
                                        } else if (k === "triptych") {
                                            var w3 = (W - 8 - 12) / 3;
                                            for (var t = 0; t < 3; t++) { pill(4 + t * (w3 + 6), by, w3, bh, 5); c.fill() }
                                        } else if (k === "delos") {
                                            pill(W / 2 - 22, by - 2, 44, bh + 4, 8); c.fill();
                                            c.fillStyle = dim; c.fillRect(4, by + 5, W - 8, 1);
                                        } else if (k === "nacre") {
                                            var w4 = (W - 8 - 10) / 3;
                                            c.fillStyle = dim; c.fillRect(2, by - 4, W - 4, 1);
                                            c.fillStyle = fg;
                                            for (var u = 0; u < 3; u++) { pill(4 + u * (w4 + 5), by, w4, bh, 5); c.fill() }
                                        } else if (k === "inir") {
                                            c.fillStyle = dim; c.fillRect(0, by, W, bh);
                                            c.strokeStyle = fg;
                                            for (var v = 1; v < 5; v++) { c.beginPath(); c.moveTo(v * W / 5, by); c.lineTo(v * W / 5, by + bh); c.stroke() }
                                        } else if (k === "aurora") {
                                            var g = c.createLinearGradient(0, by, 0, by + bh);
                                            g.addColorStop(0, parent.on ? "rgba(194,185,176,0.55)" : "rgba(194,185,176,0.3)");
                                            g.addColorStop(1, "rgba(194,185,176,0.06)");
                                            c.fillStyle = g; c.fillRect(0, by, W, bh);
                                            c.fillStyle = fg; c.fillRect(0, by, W, 1);
                                        } else if (k === "angel") {
                                            c.fillStyle = dim; c.fillRect(0, by, W, bh);
                                            c.fillStyle = fg; c.fillRect(0, by, W, 2);
                                            c.fillRect(0, by + bh - 3, W, 3);
                                        }
                                    }
                                    Component.onCompleted: requestPaint()
                                    Connections { target: cell; function onMChanged() { sk.requestPaint() } }
                                }
                                Text {
                                    anchors { left: parent.left; leftMargin: 7; bottom: parent.bottom; bottomMargin: 17 }
                                    text: parent.modelData.k
                                    color: parent.on ? tk.ink : tk.inkDim
                                    font.family: tk.ui; font.pixelSize: 12; font.weight: parent.on ? Font.DemiBold : Font.Normal
                                }
                                Text {
                                    anchors { left: parent.left; leftMargin: 7; bottom: parent.bottom; bottomMargin: 5 }
                                    text: parent.modelData.o
                                    color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9
                                }
                                Text {
                                    anchors { right: parent.right; rightMargin: 7; bottom: parent.bottom; bottomMargin: 5 }
                                    visible: parent.on
                                    text: "●"; color: tk.ink; font.pixelSize: 7
                                }
                                HoverHandler { id: th }
                                TapHandler { onTapped: root.setV(cell.i, parent.modelData.k) }
                            }
                        }
                    }

                    // ── the control taxonomy ─────────────────────────────
                    Item {
                        visible: !cell.block
                        anchors.right: parent.right; anchors.rightMargin: tk.s4
                        anchors.verticalCenter: parent.verticalCenter
                        width: cell.ctlW; height: 26



                        // bool
                        Rectangle {
                            visible: cell.m && cell.m.ctl === "sw"
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 54; height: 24; radius: tk.r; antialiasing: false
                            color: "transparent"; border.width: 1; border.color: tk.line
                            Rectangle {
                                width: 25; height: 17; y: 3; radius: tk.r; antialiasing: false
                                x: cell.m && cell.m.v === "1" ? parent.width - width - 3 : 3
                                color: cell.m && cell.m.v === "1" ? tk.ink : "transparent"
                                border.width: cell.m && cell.m.v === "1" ? 0 : 1
                                border.color: tk.line
                                Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                            }
                            TapHandler { onTapped: root.setV(cell.i, cell.m.v === "1" ? "0" : "1") }
                        }

                        // bounded int
                        Row {
                            visible: cell.m && cell.m.ctl === "step"
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Repeater {
                                model: ["−", "+"]
                                Rectangle {
                                    required property string modelData
                                    width: 29; height: 24; radius: tk.r
                                    color: bh.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.16) : "transparent"
                                    border.width: 1; border.color: tk.line
                                    Behavior on color { ColorAnimation { duration: tk.snap } }
                                    Text { anchors.centerIn: parent; text: parent.modelData; color: tk.inkDim; font.family: tk.ui; font.pixelSize: 13 }
                                    HoverHandler { id: bh }
                                    TapHandler {
                                        onTapped: {
                                            var o = st.get(cell.i);
                                            var step = (o.hi - o.lo) > 60 ? 4 : 1;
                                            root.setV(cell.i, Math.max(o.lo, Math.min(o.hi, parseInt(o.v) + (parent.modelData === "+" ? step : -step))));
                                        }
                                    }
                                }
                            }
                        }

                        // ratio
                        Item {
                            visible: cell.m && cell.m.ctl === "slid"
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: cell.width * 0.42; height: 24
                            readonly property real frac: cell.m && cell.m.hi !== undefined ? (parseInt(cell.m.v) - cell.m.lo) / Math.max(1, cell.m.hi - cell.m.lo) : 0
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: "transparent"; border.width: 1; border.color: tk.line; antialiasing: false }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * parent.frac; height: 4; color: tk.ink; antialiasing: false }
                            Rectangle { x: Math.min(parent.width - 6, Math.max(0, parent.width * parent.frac - 3)); anchors.verticalCenter: parent.verticalCenter; width: 6; height: 17; color: tk.ink; antialiasing: false }
                            TapHandler {
                                onTapped: (p) => {
                                    var o = st.get(cell.i);
                                    root.setV(cell.i, Math.round(o.lo + Math.max(0, Math.min(1, p.position.x / parent.width)) * (o.hi - o.lo)));
                                }
                            }
                            DragHandler {
                                target: null
                                onCentroidChanged: {
                                    if (!active) return;
                                    var o = st.get(cell.i);
                                    root.setV(cell.i, Math.round(o.lo + Math.max(0, Math.min(1, centroid.position.x / parent.width)) * (o.hi - o.lo)));
                                }
                            }
                        }

                        // 2–4 exclusive options — inline segmented, sized to fit
                        Row {
                            visible: cell.m && cell.m.ctl === "seg"
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Repeater {
                                model: cell.opts
                                Rectangle {
                                    required property string modelData
                                    width: Math.max(52, ml.width + 18); height: 24; radius: tk.r
                                    color: cell.m && cell.m.v === modelData ? tk.ink : "transparent"
                                    border.width: 1; border.color: tk.line
                                    Behavior on color { ColorAnimation { duration: tk.snap } }
                                    Text {
                                        id: ml
                                        anchors.centerIn: parent; text: parent.modelData
                                        color: cell.m && cell.m.v === parent.modelData ? tk.paper : tk.inkDim
                                        font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 0.6
                                    }
                                    TapHandler { onTapped: root.setV(cell.i, parent.modelData) }
                                }
                            }
                        }
                    }

                    // 5–8 exclusive options — a wrapped chip field, full cell width
                    Flow {
                        visible: cell.m && cell.m.ctl === "chips"
                        anchors.right: parent.right; anchors.rightMargin: tk.s3
                        anchors.left: parent.horizontalCenter; anchors.leftMargin: -20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Repeater {
                            model: cell.m && cell.m.ctl === "chips" ? cell.opts : []
                            Rectangle {
                                required property string modelData
                                width: cl.width + 18; height: 24; radius: tk.r
                                color: cell.m && cell.m.v === modelData ? tk.ink : "transparent"
                                border.width: 1; border.color: tk.line
                                Behavior on color { ColorAnimation { duration: tk.snap } }
                                Text {
                                    id: cl
                                    anchors.centerIn: parent; text: parent.modelData
                                    color: cell.m && cell.m.v === parent.modelData ? tk.paper : tk.inkDim
                                    font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium
                                }
                                TapHandler { onTapped: root.setV(cell.i, parent.modelData) }
                            }
                        }
                    }

                    // set membership — a chip per member, toggled. not a choice.
                    Flow {
                        visible: cell.m && cell.m.ctl === "multi"
                        anchors.right: parent.right; anchors.rightMargin: tk.s3
                        anchors.left: parent.horizontalCenter; anchors.leftMargin: -70
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Repeater {
                            model: cell.m && cell.m.ctl === "multi" ? cell.opts : []
                            Rectangle {
                                required property string modelData
                                readonly property bool on: cell.m ? cell.m.v.split(",").indexOf(modelData) >= 0 : false
                                width: mlab.width + 26; height: 24; radius: tk.r
                                color: on ? tk.ink : "transparent"
                                border.width: 1; border.color: tk.line
                                Behavior on color { ColorAnimation { duration: tk.snap } }
                                Row {
                                    anchors.centerIn: parent; spacing: 5
                                    Text { text: parent.parent.on ? "✓" : "+"; color: parent.parent.on ? tk.paper : tk.inkFaint; font.family: tk.ui; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        id: mlab
                                        text: parent.parent.modelData
                                        color: parent.parent.on ? tk.paper : tk.inkDim
                                        font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium
                                    }
                                }
                                TapHandler {
                                    onTapped: {
                                        var l = cell.m.v.split(",").filter(function (x) { return x.length });
                                        var k = l.indexOf(parent.modelData);
                                        if (k >= 0) l.splice(k, 1); else l.push(parent.modelData);
                                        root.setV(cell.i, l.join(","));
                                    }
                                }
                            }
                        }
                    }

                    // a catalogue (25 fonts) — a filterable picker, never inline
                    Rectangle {
                        visible: cell.m && cell.m.ctl === "pick"
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: tk.s3 }
                        anchors.leftMargin: tk.s4
                        height: 26
                        z: 2
                        color: ph.hovered ? Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.10) : "transparent"
                        radius: tk.r; border.width: 1; border.color: tk.line
                        Behavior on color { ColorAnimation { duration: tk.snap } }
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9
                            Text { text: cell.m ? cell.m.v : ""; color: tk.ink; font.family: tk.ui; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 120; height: 1 }
                            Text { text: cell.opts.length + " ▾"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: ph }
                        TapHandler { onTapped: root.openPick = root.openPick === cell.i ? -1 : cell.i }
                    }
                }
            }

            // ── the picker popup: a 25-entry catalogue needs filtering ────
            Rectangle {
                id: pick
                visible: root.openPick >= 0
                z: 90
                width: 330; height: 330
                x: rail.width + 150
                y: 250
                color: "#0a0a0a"; radius: tk.r
                border.width: 1; border.color: Qt.rgba(194 / 255, 185 / 255, 176 / 255, 0.5)
                property var list: root.openPick >= 0 ? root.optsOf(st.get(root.openPick)) : []
                Column {
                    anchors.fill: parent; anchors.margins: tk.s3; spacing: tk.s2
                    Row {
                        width: parent.width
                        Text { text: root.openPick >= 0 ? st.get(root.openPick).n.toUpperCase() : ""; color: tk.ink; font.family: tk.ui; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.6 }
                        Item { width: parent.width - 180; height: 1 }
                        Text { text: pick.list.length + " ENTRIES"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9 }
                    }
                    Rectangle {
                        width: parent.width; height: 30
                        color: "transparent"; radius: tk.r; border.width: 1; border.color: tk.line
                        TextInput {
                            id: pq
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            color: tk.ink; font.family: tk.ui; font.pixelSize: 12
                            Text { anchors.fill: parent; visible: pq.text === ""; text: "Filter…"; color: tk.inkMuted; font: pq.font; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Flickable {
                        width: parent.width; height: parent.height - 76
                        contentHeight: pl.height; clip: true
                        ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 3; color: tk.line } }
                        Column {
                            id: pl
                            width: parent.width; spacing: 0
                            Repeater {
                                model: pick.list
                                Rectangle {
                                    required property string modelData
                                    readonly property bool show: pq.text === "" || modelData.toLowerCase().indexOf(pq.text.toLowerCase()) >= 0
                                    width: pl.width; height: show ? 30 : 0; visible: show
                                    color: ih.hovered ? tk.ink : "transparent"
                                    Behavior on color { ColorAnimation { duration: 70 } }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter; x: 8
                                        text: parent.modelData
                                        color: ih.hovered ? tk.paper : (root.openPick >= 0 && st.get(root.openPick).v === parent.modelData ? tk.ink : tk.inkDim)
                                        font.family: tk.ui; font.pixelSize: 12
                                    }
                                    Text {
                                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                        visible: root.openPick >= 0 && st.get(root.openPick).v === parent.modelData
                                        text: "●"; color: ih.hovered ? tk.paper : tk.ink; font.pixelSize: 8
                                    }
                                    HoverHandler { id: ih }
                                    TapHandler { onTapped: { root.setV(root.openPick, parent.modelData); root.openPick = -1 } }
                                }
                            }
                        }
                    }
                }
            }

            // ── pinned preview + state ───────────────────────────────────
            Item {
                id: side
                anchors { right: parent.right; top: head.bottom; bottom: bar.top }
                anchors.rightMargin: tk.s6; anchors.topMargin: tk.s4; anchors.bottomMargin: tk.s4
                width: 430

                Rectangle {
                    id: pv
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 300
                    color: "transparent"; radius: tk.r; border.width: 1; border.color: tk.line
                    Text {
                        text: "LIVE PREVIEW · PINNED"; color: tk.inkMuted
                        font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.4
                        anchors { left: parent.left; top: parent.top; margins: tk.s3 }
                    }
                    Canvas {
                        id: prev
                        anchors.fill: parent
                        anchors.margins: tk.s4
                        anchors.topMargin: 34
                        property int bw: { root.rev; return root.val("border") }
                        property int br: { root.rev; return root.val("radius") }
                        property int op: { root.rev; return root.val("opac") }
                        property bool on: { root.rev; return root.val("frame") === 1 }
                        property bool viz: { root.rev; return root.val("viz") === 1 }
                        property int gain: { root.rev; return root.val("gain") }
                        property string edge: { root.rev; return root.sval("edge") }
                        property string mods: { root.rev; return root.sval("mods") }
                        property int irad: { root.rev; return root.val("iradius") }
                        property string skin: { root.rev; return root.sval("barskin") }
                        onSkinChanged: requestPaint()
                        onBwChanged: requestPaint(); onBrChanged: requestPaint(); onOpChanged: requestPaint()
                        onOnChanged: requestPaint(); onVizChanged: requestPaint(); onGainChanged: requestPaint()
                        onEdgeChanged: requestPaint(); onModsChanged: requestPaint(); onIradChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset();
                            c.strokeStyle = "rgba(194,185,176,0.14)"; c.lineWidth = 1;
                            c.strokeRect(0.5, 0.5, width - 1, height - 1);
                            if (!on) { c.fillStyle = "rgba(194,185,176,0.45)"; c.font = "12px sans-serif"; c.fillText("FRAME OFF", width / 2 - 30, height / 2); return }
                            var t = Math.max(1, bw / 120 * 18), rr = br / 40 * 14;
                            c.strokeStyle = "rgba(194,185,176,0.9)"; c.lineWidth = t;
                            var x = t / 2 + 2, y = t / 2 + 2, w = width - t - 4, h = height - t - 4;
                            c.beginPath();
                            c.moveTo(x + rr, y);
                            c.lineTo(x + w - rr, y); c.quadraticCurveTo(x + w, y, x + w, y + rr);
                            c.lineTo(x + w, y + h - rr); c.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
                            c.lineTo(x + rr, y + h); c.quadraticCurveTo(x, y + h, x, y + h - rr);
                            c.lineTo(x, y + rr); c.quadraticCurveTo(x, y, x + rr, y);
                            c.closePath(); c.stroke();

                            var ix = t + 2, iy = t + 2, iw = width - 2 * t - 4, ih = height - 2 * t - 4;
                            c.save(); c.beginPath(); c.rect(ix, iy, iw, ih); c.clip();
                            c.strokeStyle = "rgba(194,185,176,0.20)"; c.lineWidth = 1;
                            c.strokeRect(ix + 16.5, iy + 34.5, iw * 0.44, ih * 0.5);
                            c.strokeRect(ix + iw * 0.5, iy + 50.5, iw * 0.42, ih * 0.42);

                            // the island: edge + radius + the module set, all live
                            if (edge !== "HIDDEN") {
                                var n = Math.max(1, mods.split(",").filter(function (s) { return s.length }).length);
                                var by = edge === "BOTTOM" ? iy + ih - 8 - 14 : iy + 8;
                                var brr = Math.min(7, irad / 30 * 7);
                                function rr(x2, y2, w2, h2, r2) {
                                    c.beginPath();
                                    c.moveTo(x2 + r2, y2); c.lineTo(x2 + w2 - r2, y2); c.quadraticCurveTo(x2 + w2, y2, x2 + w2, y2 + r2);
                                    c.lineTo(x2 + w2, y2 + h2 - r2); c.quadraticCurveTo(x2 + w2, y2 + h2, x2 + w2 - r2, y2 + h2);
                                    c.lineTo(x2 + r2, y2 + h2); c.quadraticCurveTo(x2, y2 + h2, x2, y2 + h2 - r2);
                                    c.lineTo(x2, y2 + r2); c.quadraticCurveTo(x2, y2, x2 + r2, y2); c.closePath();
                                }
                                var flat = (skin === "inir" || skin === "aurora" || skin === "angel");
                                c.fillStyle = "rgba(194,185,176,0.18)";
                                if (flat) {
                                    // frame-off ports: a flush full-width strip
                                    var fy = edge === "BOTTOM" ? iy + ih - 15 : iy;
                                    if (skin === "aurora") {
                                        var g2 = c.createLinearGradient(0, fy, 0, fy + 15);
                                        g2.addColorStop(0, "rgba(194,185,176,0.34)"); g2.addColorStop(1, "rgba(194,185,176,0.05)");
                                        c.fillStyle = g2;
                                    }
                                    c.fillRect(ix, fy, iw, 15);
                                    c.fillStyle = "rgba(194,185,176,0.6)";
                                    if (skin === "inir") for (var q = 1; q < 6; q++) c.fillRect(ix + q * iw / 6, fy, 1, 15);
                                    if (skin === "angel") { c.fillRect(ix, fy, iw, 2); c.fillRect(ix, fy + 12, iw, 3) }
                                    if (skin === "aurora") c.fillRect(ix, fy, iw, 1);
                                    c.fillStyle = "rgba(194,185,176,0.5)";
                                    c.fillRect(ix + 8, fy + 5, 5, 5);
                                    for (var z = 0; z < n; z++) c.fillRect(ix + 22 + z * 18, fy + 6, 12, 4);
                                } else if (skin === "delos") {
                                    // the whole bar collapsed into one island
                                    rr(ix + (iw - 62) / 2, by - 2, 62, 18, 9); c.fill();
                                    c.fillStyle = "rgba(194,185,176,0.55)";
                                    c.fillRect(ix + (iw - 62) / 2 + 8, by + 4, 5, 5);
                                    for (var d = 0; d < Math.min(n, 3); d++) c.fillRect(ix + (iw - 62) / 2 + 22 + d * 12, by + 5, 8, 4);
                                } else if (skin === "triptych" || skin === "nacre") {
                                    // three islands on the band
                                    if (skin === "nacre") { c.fillStyle = "rgba(194,185,176,0.35)"; c.fillRect(ix, by - 5, iw, 1); c.fillStyle = "rgba(194,185,176,0.18)" }
                                    var w3 = iw * 0.24;
                                    for (var p3 = 0; p3 < 3; p3++) { rr(ix + iw * 0.06 + p3 * (w3 + iw * 0.05), by, w3, 14, 6); c.fill() }
                                    c.fillStyle = "rgba(194,185,176,0.5)";
                                    c.fillRect(ix + iw * 0.06 + 8, by + 5, 5, 5);
                                } else if (skin === "caelestia") {
                                    // one container pill with numbered cells
                                    var cw2 = Math.max(60, 26 + n * 18);
                                    rr(ix + (iw - cw2) / 2, by, cw2, 14, 6); c.fill();
                                    c.fillStyle = "rgba(194,185,176,0.6)";
                                    rr(ix + (iw - cw2) / 2 + 4, by + 2, 14, 10, 4); c.fill();
                                    c.fillStyle = "rgba(194,185,176,0.28)";
                                    for (var e2 = 1; e2 < n; e2++) { rr(ix + (iw - cw2) / 2 + 4 + e2 * 17, by + 2, 14, 10, 4); c.fill() }
                                } else if (skin === "stele") {
                                    // engraved bracket cells
                                    c.strokeStyle = "rgba(194,185,176,0.55)"; c.lineWidth = 1;
                                    for (var s2 = 0; s2 < n; s2++) {
                                        var sx = ix + (iw - n * 26) / 2 + s2 * 26;
                                        c.beginPath(); c.moveTo(sx + 3, by); c.lineTo(sx, by); c.lineTo(sx, by + 14); c.lineTo(sx + 3, by + 14); c.stroke();
                                        c.beginPath(); c.moveTo(sx + 19, by); c.lineTo(sx + 22, by); c.lineTo(sx + 22, by + 14); c.lineTo(sx + 19, by + 14); c.stroke();
                                        c.fillStyle = "rgba(194,185,176,0.32)"; c.fillRect(sx + 6, by + 5, 10, 4);
                                    }
                                } else if (skin === "aegis") {
                                    // flat modules with hairline accent underlines
                                    for (var g3 = 0; g3 < n; g3++) {
                                        var gx = ix + (iw - n * 26) / 2 + g3 * 26;
                                        c.fillStyle = "rgba(194,185,176,0.14)"; c.fillRect(gx, by, 22, 14);
                                        c.fillStyle = "rgba(194,185,176,0.65)"; c.fillRect(gx, by + 12, 22, 2);
                                    }
                                } else {
                                    // noctalia: separate capsules
                                    for (var h3 = 0; h3 < n; h3++) {
                                        var hx = ix + (iw - n * 26) / 2 + h3 * 26;
                                        c.fillStyle = "rgba(194,185,176,0.2)"; rr(hx, by, 22, 14, 7); c.fill();
                                        c.fillStyle = "rgba(194,185,176,0.55)"; c.fillRect(hx + 7, by + 5, 8, 4);
                                    }
                                }
                            }
                            if (viz) {
                                var bars = 22, bw2 = iw * 0.52 / bars;
                                for (var j = 0; j < bars; j++) {
                                    var amp = (Math.sin(j * 1.9) * 0.5 + 0.5) * (gain / 100) * ih * 0.28 + 2;
                                    c.fillStyle = "rgba(194,185,176,0.3)";
                                    c.fillRect(ix + iw * 0.24 + j * bw2, iy + ih - amp - 3, bw2 - 2, amp);
                                }
                            }
                            c.restore();
                            c.globalAlpha = op / 100;
                            c.fillStyle = "rgba(194,185,176,0.62)";
                            c.fillRect(width - t - 74, t + 8, 56, 20);
                            c.globalAlpha = 1;
                        }
                    }
                }

                Rectangle {
                    id: statecard
                    anchors { left: parent.left; right: parent.right; top: pv.bottom; topMargin: tk.s3 }
                    height: 88
                    color: root.dirty > 0 ? tk.ink : "transparent"
                    radius: tk.r
                    border.width: 1
                    border.color: root.dirty > 0 ? tk.ink : tk.line
                    Behavior on color { ColorAnimation { duration: tk.snap } }
                    Row {
                        anchors.fill: parent; anchors.margins: tk.s4; spacing: tk.s4
                        Row {
                            spacing: tk.s2; anchors.verticalCenter: parent.verticalCenter
                            Text { text: String(root.dirty); color: root.dirty > 0 ? tk.paper : tk.ink; font.family: tk.ui; font.pixelSize: 36; font.weight: Font.Light }
                            Text {
                                text: root.dirty === 1 ? "CHANGE" : "CHANGES"
                                color: root.dirty > 0 ? Qt.rgba(0, 0, 0, 0.5) : tk.inkMuted
                                font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.2
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 9
                            }
                        }
                        Rectangle { width: 1; height: parent.height * 0.55; color: root.dirty > 0 ? Qt.rgba(0, 0, 0, 0.22) : tk.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            width: 210; anchors.verticalCenter: parent.verticalCenter
                            text: root.dirty > 0 ? "Previewing live. Nothing is written until you save." : "Everything matches what is on disk."
                            color: root.dirty > 0 ? Qt.rgba(0, 0, 0, 0.62) : tk.inkMuted
                            font.family: tk.ui; font.pixelSize: 11; wrapMode: Text.WordWrap
                        }
                    }
                }

                // ── PENDING WRITE: the diff, in the config's own syntax ──
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: statecard.bottom; topMargin: tk.s3; bottom: parent.bottom }
                    color: "transparent"; radius: tk.r
                    border.width: 1; border.color: tk.line

                    Row {
                        id: dhead
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: tk.s3 }
                        Text { text: "PENDING WRITE"; color: tk.inkMuted; font.family: tk.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                        Item { width: parent.width - 190; height: 1 }
                        Text { text: root.dirty > 0 ? "DIFF" : "CLEAN"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 8 }
                    }
                    Rectangle { anchors { left: parent.left; right: parent.right; top: dhead.bottom; topMargin: 6 } height: 1; color: tk.lineSoft }

                    Text {
                        anchors.centerIn: parent
                        visible: root.dirty === 0
                        text: "nothing to write"
                        color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 10
                    }

                    Flickable {
                        anchors { left: parent.left; right: parent.right; top: dhead.bottom; bottom: parent.bottom; margins: tk.s3 }
                        anchors.topMargin: 10
                        contentHeight: dcol.height
                        clip: true
                        ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 3; color: tk.line } }

                        Column {
                            id: dcol
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: root.diff
                                Item {
                                    required property var modelData
                                    width: dcol.width
                                    height: modelData.head ? 26 : 34

                                    // a file heading
                                    Row {
                                        visible: parent.modelData.head
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Rectangle { width: 3; height: 3; color: tk.ink; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: parent.parent.modelData.t || ""; color: tk.ink; font.family: tk.mono; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: parent.parent.modelData.head ? ("· " + parent.parent.modelData.n) : ""; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                    }

                                    // a key: was -> now, in the file's own syntax
                                    Column {
                                        visible: !parent.modelData.head
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 9
                                        spacing: 1
                                        Text {
                                            text: (parent.parent.modelData.k || "") + ":"
                                            color: tk.inkDim; font.family: tk.mono; font.pixelSize: 12
                                        }
                                        Row {
                                            spacing: 6
                                            Text {
                                                text: parent.parent.parent.modelData.was || ""
                                                color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 12; font.strikeout: true
                                            }
                                            Text { text: "→"; color: tk.inkFaint; font.family: tk.mono; font.pixelSize: 10 }
                                            Text {
                                                text: parent.parent.parent.modelData.now || ""
                                                color: tk.ink; font.family: tk.mono; font.pixelSize: 12
                                            }
                                        }
                                    }
                                    Rectangle {
                                        visible: !parent.modelData.head
                                        anchors.bottom: parent.bottom; width: parent.width; height: 1; color: tk.lineSoft
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
                height: 60
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: tk.line }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: tk.s5
                    spacing: tk.s3
                    Rectangle {
                        width: 6; height: 6; color: tk.ink; anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: root.dirty > 0; loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 480 }
                            NumberAnimation { to: 1.0; duration: 480 }
                        }
                    }
                    Text {
                        text: root.dirty > 0 ? (root.dirty + (root.dirty === 1 ? " CHANGE" : " CHANGES") + " · PREVIEWING · NOT SAVED") : "SAVED · LIVE ON YOUR DESKTOP"
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
                    Btn { text: "SAVE"; solid: true; on_: root.dirty > 0; onAct: { for (var i = 0; i < st.count; i++) st.setProperty(i, "d", st.get(i).v); root.rev++ } }
                }
            }
        }
    }
}
