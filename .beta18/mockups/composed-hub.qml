import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "schema/ShellSettingsPage.js" as Schema

// Composes the module into the page it is meant to make: rail, head, schema
// sheet, pinned preview, action bar. Reads the real shell.json.
ShellRoot {
    FloatingWindow {
        title: "Ryoku Hub"
        minimumSize: Qt.size(1400, 860)
        color: Tokens.paper
        onClosed: Qt.quit()

        Item {
            id: root
            anchors.fill: parent
            Grain { anchors.fill: parent }

            property int navSel: 7
            property var draft: ({})
            property var committed: ({})
            readonly property var defs: ({
                "frameRadius": 9, "roundness": 10, "frameBorder": 59, "frameEnabled": true,
                "frameSmoothing": 8, "frameOpacity": 1, "shadowStrength": 0.63, "shadowSize": 12,
                "surfaceColor": "#0f1115", "osdRadius": 28, "osdOpacity": 1,
                "barEnabled": true, "barPosition": "top", "barStyle": "noctalia", "barHeight": 30,
                "barShowTitle": true, "barShowMedia": true, "barShowStatus": true,
                "barOccupiedWorkspaces": true, "islandEdge": "top", "islandAlong": -1,
                "islandHidden": false, "islandModules": ["workspaces","clock","date","media"],
                "islandRadius": 17, "fontFamily": "JetBrainsMono Nerd Font", "fontScale": 1.3,
                "weatherLocation": "", "weatherUnit": "auto",
                "sidebarLeftEnabled": true, "sidebarRightEnabled": true,
                "sidebarLeftPanes": ["stash"],
                "sidebarRightPanes": ["notifications","calendar","media","weather","recording"],
                "sidebarClickless": true, "sidebarWidth": 340, "sidebarCornerSize": 34,
                "enabled": true, "bars": 64, "height": 0.42, "thickness": 0.58, "bloom": 0.6,
                "reflection": 0.1, "idleWave": true, "style": "bars", "shape": "rounded",
                "position": "bottom", "mirror": false, "segments": 10, "fps": 30,
                "adaptive": true, "smoothing": 0.5, "gain": 1.0, "peaks": false,
                "markText": "力", "markImage": "", "markTint": true, "name": "Ryoku"
            })
            readonly property int dirty: {
                var n = 0;
                for (var k in defs)
                    if (JSON.stringify(draft[k]) !== JSON.stringify(committed[k])) n++;
                return n;
            }
            function edit(k, v) {
                var d = {}; for (var x in draft) d[x] = draft[x];
                d[k] = v; draft = d;
            }
            function val(k) { var v = draft[k]; return v === undefined ? defs[k] : v }

            FileView {
                path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
                onLoaded: {
                    var live = JSON.parse(text());
                    var d = {};
                    for (var k in root.defs) d[k] = (live[k] !== undefined) ? live[k] : root.defs[k];
                    root.draft = d;
                    root.committed = JSON.parse(JSON.stringify(d));
                }
            }

            // ── rail ─────────────────────────────────────────────────────
            Item {
                id: rail
                anchors { left: parent.left; top: parent.top; bottom: bar.top }
                width: Tokens.railW
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tokens.line }
                Column {
                    anchors.fill: parent
                    anchors.margins: Tokens.s5
                    spacing: Tokens.s4
                    Row {
                        spacing: Tokens.s3
                        Text { text: "力"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: 22 }
                        Column {
                            spacing: 1
                            Text { text: "RYOKU ARCH"; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: 14; font.weight: Font.Medium; font.letterSpacing: 2.4 }
                            Text { text: "system and shell settings"; color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: 11 }
                        }
                    }
                    Field { width: parent.width; toolbar: true; placeholder: "Search settings…"; onEdited: (t) => page.query = t }
                    Item {
                        width: parent.width
                        height: nav.height
                        Rectangle {
                            width: parent.width; height: 34; radius: Tokens.radius; color: Tokens.bone
                            y: root.navSel * 34
                            Behavior on y { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                        }
                        Column {
                            id: nav
                            width: parent.width
                            Repeater {
                                model: [
                                    { g: 0, t: "OVERVIEW" }, { g: 1, t: "Profile" },
                                    { g: 0, t: "SYSTEM" }, { g: 1, t: "Updates" }, { g: 1, t: "Displays" }, { g: 1, t: "Input" },
                                    { g: 0, t: "DESKTOP" }, { g: 1, t: "Shell" }, { g: 1, t: "Appearance" },
                                    { g: 1, t: "App Launcher" }, { g: 1, t: "Desktop Widgets" },
                                    { g: 0, t: "ADVANCED" }, { g: 1, t: "Keybinds" }, { g: 1, t: "Window Rules" }
                                ]
                                Item {
                                    required property var modelData
                                    required property int index
                                    width: parent.width; height: 34
                                    readonly property bool sel: root.navSel === index
                                    Rectangle {
                                        visible: modelData.g > 0 && !parent.sel
                                        anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1
                                        radius: Tokens.radius
                                        color: nh.hovered ? Tokens.tint10 : "transparent"
                                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                    }
                                    Row {
                                        visible: modelData.g === 0
                                        anchors.verticalCenter: parent.verticalCenter; spacing: Tokens.s2
                                        Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.t; color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
                                        Rectangle { width: 120; height: 1; color: Tokens.lineSoft; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text {
                                        visible: modelData.g > 0
                                        text: modelData.t
                                        color: parent.sel ? Tokens.inkOnBone : Tokens.inkDim
                                        font.family: Tokens.ui; font.pixelSize: 14
                                        x: Tokens.s3; anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                    }
                                    HoverHandler { id: nh; enabled: modelData.g > 0 }
                                    TapHandler { enabled: modelData.g > 0; onTapped: root.navSel = index }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: Tokens.s5; bottom: parent.bottom; bottomMargin: Tokens.s4 }
                    text: "力  ryoku desktop"; color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: 9
                }
            }

            // ── the page ─────────────────────────────────────────────────
            SchemaPage {
                id: page
                anchors { left: rail.right; top: parent.top; bottom: bar.top }
                anchors.right: side.left
                anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s5
                anchors.topMargin: Tokens.s5; anchors.bottomMargin: Tokens.s3
                schema: Schema.rows
                draft: root.draft
                defaults: root.committed
                title: "Shell"
                eyebrow: "DESKTOP"
                blurb: "The frame, the bar, notifications, and the desktop visualiser."
                onEdited: (k, v) => root.edit(k, v)
            }

            // ── pinned: preview + the skin gallery's source of truth ─────
            Item {
                id: side
                anchors { right: parent.right; top: parent.top; bottom: bar.top }
                anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5; anchors.bottomMargin: Tokens.s3
                width: 430

                Preview {
                    id: pv
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 300
                    label: "LIVE PREVIEW · PINNED"
                    tag: "eDP-1 · 2560×1600"
                    live: root.val("frameEnabled") === true
                    offText: "FRAME OFF"
                    Canvas {
                        id: cv
                        anchors.fill: parent
                        property int bw: root.val("frameBorder")
                        property int br: root.val("frameRadius")
                        property string skin: String(root.val("barStyle"))
                        property string edge: String(root.val("islandEdge"))
                        property int mods: (root.val("islandModules") || []).length
                        onBwChanged: requestPaint(); onBrChanged: requestPaint()
                        onSkinChanged: requestPaint(); onEdgeChanged: requestPaint(); onModsChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset();
                            var t = Math.max(1, bw / 140 * 20), rr = br / 60 * 16;
                            c.strokeStyle = "rgba(205,196,186,0.9)"; c.lineWidth = t;
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
                            c.strokeStyle = "rgba(205,196,186,0.20)"; c.lineWidth = 1;
                            c.strokeRect(ix + 16.5, iy + 44.5, iw * 0.44, ih * 0.46);
                            c.strokeRect(ix + iw * 0.5, iy + 60.5, iw * 0.40, ih * 0.38);
                            if (edge !== "hidden") {
                                // the bar draws as the chosen skin, from the same
                                // source the gallery tiles read
                                c.save();
                                c.translate(ix + (iw - 132) / 2, edge === "bottom" ? iy + ih - 44 : iy + 4);
                                Silhouette.draw(c, cv.skin, 132, 32, 0.9, 0.4);
                                c.restore();
                            }
                            c.restore();
                        }
                    }
                }
                Gallery {
                    anchors { left: parent.left; right: parent.right; top: pv.bottom; topMargin: Tokens.s3 }
                    options: Silhouette.skins
                    current: String(root.val("barStyle"))
                    onChose: (k) => root.edit("barStyle", k)
                }
            }

            ActionBar {
                id: bar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                dirty: root.dirty
                onSaved: root.committed = JSON.parse(JSON.stringify(root.draft))
                onReverted: root.draft = JSON.parse(JSON.stringify(root.committed))
                onReset: { var d = {}; for (var k in root.defs) d[k] = root.defs[k]; root.draft = d }
            }
            Component.onCompleted: console.log("HUB-OK rows=" + Schema.rows.length)
        }
    }
}
