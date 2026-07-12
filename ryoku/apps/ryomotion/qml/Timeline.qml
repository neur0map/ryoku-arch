pragma ComponentBehavior: Bound
import QtQuick
import RyoMotion

// The timeline. The Clip lane shows the recording as one bar; drag the in/out
// handles (Cut tool) to mark a section and the Inspector removes it -- removed
// spans show as gaps, no abstract blocks. Zoom/Speed/Text/Overlay lanes carry
// draggable range markers. Transport + scrubbable ruler + playhead on top.
Rectangle {
    id: tl
    color: Theme.bgBot

    readonly property real dur: Math.max(1, Project.durationMs)
    readonly property real labelW: 66
    property real laneW: width - labelW - 24

    function fmt(ms) {
        var s = Math.max(0, ms) / 1000, m = Math.floor(s / 60), r = (s - m * 60);
        return m + ":" + (r < 10 ? "0" : "") + r.toFixed(1);
    }
    function togglePlay() { Project.togglePlay(); }

    readonly property var regionTracks: [
        { "kind": "zoom", "label": "Zoom", "color": Theme.ember, "add": "addZoom" },
        { "kind": "speed", "label": "Speed", "color": Theme.ok, "add": "addSpeed" },
        { "kind": "text", "label": "Text", "color": Theme.gold, "add": "addText" },
        { "kind": "overlay", "label": "Overlay", "color": "#4facfe", "add": "" }
    ]

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.hair }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // transport
        Item {
            width: parent.width; height: 30
            Rectangle {
                id: playBtn
                width: 30; height: 30; radius: 15
                color: pma.containsMouse ? Theme.fieldHi : Theme.field
                opacity: Project.hasClip ? 1 : 0.4
                Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: Project.playing ? 0 : 1; name: Project.playing ? "pause" : "play"; size: 16; tint: Theme.cream }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tl.togglePlay() }
            }
            Text {
                anchors.left: playBtn.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: tl.fmt(Project.positionMs) + "  /  " + tl.fmt(Project.durationMs)
                color: Theme.idle; font.family: Theme.mono; font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: Project.tool === "cut" ? "Cut: drag the in/out handles, then Remove in the panel" : "drag markers to move · pull edges to trim · click to edit"
                color: Theme.faint; font.family: Theme.font; font.pixelSize: 11
            }
        }

        // ruler / scrub
        Item {
            width: parent.width; height: 14
            Item {
                x: tl.labelW; width: parent.width - tl.labelW; height: parent.height
                Rectangle { anchors.fill: parent; radius: 3; color: Theme.field }
                MouseArea {
                    anchors.fill: parent
                    enabled: Project.hasClip
                    onPressed: (m) => seek(m.x)
                    onPositionChanged: (m) => { if (pressed) seek(m.x); }
                    function seek(x) {
                        Project.seek(Math.max(0, Math.min(tl.dur, x / width * tl.dur)));
                    }
                }
            }
        }

        // clip lane (direct cut)
        Item {
            id: clipRow
            width: parent.width; height: 32
            Rectangle {
                width: tl.labelW - 6; height: parent.height; radius: Theme.radiusSm; color: Theme.field
                Icon { id: cIco; anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; name: "film"; size: 13; tint: Theme.cream }
                Text { anchors.left: cIco.right; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter; text: "Clip"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Medium }
            }
            Rectangle {
                id: clipLane
                anchors.left: parent.left; anchors.leftMargin: tl.labelW; anchors.right: parent.right
                height: parent.height; radius: 4
                color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.28)
                onWidthChanged: tl.laneW = width

                // cuts as gaps
                Repeater {
                    model: Project.cuts
                    delegate: Rectangle {
                        required property var modelData
                        x: modelData.startMs / tl.dur * clipLane.width
                        width: Math.max(2, (modelData.endMs - modelData.startMs) / tl.dur * clipLane.width)
                        height: parent.height; radius: 4
                        color: Theme.bgBot
                        border.width: 1; border.color: Theme.hair
                        Icon { anchors.centerIn: parent; visible: parent.width > 20; name: "scissors"; size: 12; tint: Theme.faint }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Project.removeRegion("cut", parent.modelData.id) }
                    }
                }
                // cut selection (in/out) -- only in Cut tool
                Item {
                    anchors.fill: parent
                    visible: Project.tool === "cut"
                    onVisibleChanged: if (visible && Project.selStart < 0) { Project.selStart = Project.positionMs; Project.selEnd = Math.min(tl.dur, Project.positionMs + 2000); }
                    Rectangle {
                        visible: Project.selStart >= 0
                        x: Project.selStart / tl.dur * parent.width
                        width: Math.max(2, (Project.selEnd - Project.selStart) / tl.dur * parent.width)
                        height: parent.height
                        color: Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.35)
                        border.width: 1.5; border.color: Theme.bad
                    }
                    // in handle
                    Rectangle {
                        visible: Project.selStart >= 0
                        x: Project.selStart / tl.dur * parent.width - 4; width: 8; height: parent.height; radius: 2; color: Theme.bad
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.SizeHorCursor
                            onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(clipLane, m.x, 0); Project.selStart = Math.max(0, Math.min(Project.selEnd - 100, p.x / clipLane.width * tl.dur)); }
                        }
                    }
                    // out handle
                    Rectangle {
                        visible: Project.selStart >= 0
                        x: Project.selEnd / tl.dur * parent.width - 4; width: 8; height: parent.height; radius: 2; color: Theme.bad
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.SizeHorCursor
                            onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(clipLane, m.x, 0); Project.selEnd = Math.min(tl.dur, Math.max(Project.selStart + 100, p.x / clipLane.width * tl.dur)); }
                        }
                    }
                }
            }
        }

        // region lanes
        Repeater {
            model: tl.regionTracks
            delegate: Item {
                id: trk
                required property var modelData
                readonly property string kind: modelData.kind
                readonly property color color: modelData.color
                width: parent.width; height: 28

                Rectangle {
                    id: chip
                    width: tl.labelW - 26; height: parent.height; radius: Theme.radiusSm; color: Theme.field
                    Text { anchors.centerIn: parent; text: trk.modelData.label; color: Theme.dim; font.family: Theme.font; font.pixelSize: 9; font.weight: Font.Medium }
                }
                Rectangle {
                    anchors.left: chip.right; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: ama.containsMouse ? Theme.fieldHi : "transparent"
                    opacity: Project.hasClip ? 1 : 0.35
                    Icon { anchors.centerIn: parent; name: "plus"; size: 12; tint: trk.color }
                    MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: trk.modelData.add ? Project[trk.modelData.add]() : (Project.tool = "overlay") }
                }
                Rectangle {
                    id: lane
                    anchors.left: parent.left; anchors.leftMargin: tl.labelW; anchors.right: parent.right
                    height: parent.height; radius: 4; color: Theme.hairSoft

                    Repeater {
                        model: Project.arrOf(trk.kind)
                        delegate: Rectangle {
                            id: blk
                            required property var modelData
                            readonly property real laneW: lane.width
                            readonly property bool sel: Project.selKind === trk.kind && Project.selId === modelData.id
                            property real ovX: -1
                            property real ovW: -1
                            property real _ox: 0
                            property real _ow: 0
                            y: 3; height: parent.height - 6; radius: 6
                            x: body.drag.active ? x : (ovX >= 0 ? ovX : modelData.startMs / tl.dur * laneW)
                            width: ovW >= 0 ? ovW : Math.max(8, (modelData.endMs - modelData.startMs) / tl.dur * laneW)
                            color: blk.sel ? Qt.lighter(trk.color, 1.15) : trk.color
                            opacity: blk.sel ? 1 : 0.8
                            border.width: blk.sel ? 1.5 : 0; border.color: Theme.bright

                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                text: trk.kind === "zoom" ? "×" + Project.depthScale(modelData.depth).toFixed(1)
                                    : trk.kind === "speed" ? modelData.speed.toFixed(2).replace(/\.?0+$/, "") + "×"
                                    : trk.kind === "text" ? modelData.text : modelData.name
                                color: "#1b1610"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                            }
                            Rectangle {
                                visible: blk.sel && blk.width > 40
                                anchors.right: parent.right; anchors.rightMargin: 3; anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; radius: 8; color: Qt.rgba(0, 0, 0, 0.25)
                                Icon { anchors.centerIn: parent; name: "trash"; size: 10; tint: "#1b1610" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Project.removeRegion(trk.kind, blk.modelData.id) }
                            }
                            MouseArea {
                                id: body
                                anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7
                                cursorShape: Qt.PointingHandCursor
                                drag.target: blk; drag.axis: Drag.XAxis; drag.minimumX: 0; drag.maximumX: Math.max(0, blk.laneW - blk.width)
                                onPressed: Project.selectRegion(trk.kind, blk.modelData.id)
                                onReleased: {
                                    var ns = Math.max(0, Math.round(blk.x / blk.laneW * tl.dur));
                                    var d = blk.modelData.endMs - blk.modelData.startMs;
                                    Project.updateRegion(trk.kind, blk.modelData.id, { startMs: ns, endMs: Math.min(tl.dur, ns + d) });
                                }
                            }
                            MouseArea {
                                width: 8; height: parent.height; anchors.left: parent.left; cursorShape: Qt.SizeHorCursor
                                onPressed: { blk._ox = blk.x; blk._ow = blk.width; blk.ovX = blk.x; blk.ovW = blk.width; }
                                onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(lane, m.x, 0); var nx = Math.max(0, Math.min(p.x, blk._ox + blk._ow - 12)); blk.ovX = nx; blk.ovW = blk._ox + blk._ow - nx; }
                                onReleased: { Project.updateRegion(trk.kind, blk.modelData.id, { startMs: Math.round(blk.ovX / blk.laneW * tl.dur) }); blk.ovX = -1; blk.ovW = -1; }
                            }
                            MouseArea {
                                width: 8; height: parent.height; anchors.right: parent.right; cursorShape: Qt.SizeHorCursor
                                onPressed: { blk._ox = blk.x; blk._ow = blk.width; blk.ovX = blk.x; blk.ovW = blk.width; }
                                onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(lane, m.x, 0); blk.ovW = Math.max(12, Math.min(p.x - blk._ox, blk.laneW - blk._ox)); }
                                onReleased: { Project.updateRegion(trk.kind, blk.modelData.id, { endMs: Math.round((blk.ovX + blk.ovW) / blk.laneW * tl.dur) }); blk.ovX = -1; blk.ovW = -1; }
                            }
                        }
                    }
                }
            }
        }
    }

    // playhead
    Rectangle {
        visible: Project.hasClip
        width: 2; color: Theme.bright
        y: 44; height: tl.height - 52
        x: tl.labelW + 8 + Project.positionMs / tl.dur * (tl.width - tl.labelW - 24)
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; width: 9; height: 9; radius: 2; color: Theme.bright }
    }
}
