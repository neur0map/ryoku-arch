pragma ComponentBehavior: Bound
import QtQuick
import RyoMotion

// The timeline: a labelled time ruler, one track row per concern (clip, zoom,
// speed, text, overlay, music), and a playhead. Every block is draggable and
// trimmable; the music track carries a waveform and can be positioned and
// trimmed anywhere under the video. Transport sits on top.
Rectangle {
    id: tl
    color: Theme.bgBot

    readonly property real dur: Math.max(1, Project.durationMs)
    readonly property real durSec: dur / 1000
    readonly property real headW: 90
    readonly property real laneW: Math.max(1, width - 16 - headW)

    function msToX(ms) { return ms / dur * laneW; }
    function xToMs(x) { return Math.max(0, Math.min(dur, x / laneW * dur)); }
    function fmt(ms) { var s = Math.max(0, ms) / 1000, m = Math.floor(s / 60), r = Math.floor(s - m * 60); return m + ":" + (r < 10 ? "0" : "") + r; }
    function fmtD(ms) { var s = Math.max(0, ms) / 1000, m = Math.floor(s / 60), r = (s - m * 60); return m + ":" + (r < 10 ? "0" : "") + r.toFixed(1); }

    // seconds between major ruler labels, chosen so roughly seven fit
    readonly property real tickStep: {
        var steps = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600];
        var target = durSec / 7;
        for (var i = 0; i < steps.length; i++)
            if (steps[i] >= target)
                return steps[i];
        return steps[steps.length - 1];
    }

    readonly property var regionTracks: [
        { "kind": "zoom",    "label": "Zoom",    "color": Theme.ember, "icon": "zoom",  "add": "addZoom" },
        { "kind": "speed",   "label": "Speed",   "color": "#d9a441",   "icon": "speed", "add": "addSpeed" },
        { "kind": "text",    "label": "Text",    "color": "#4facfe",   "icon": "text",  "add": "addText" },
        { "kind": "overlay", "label": "Overlay", "color": "#b07de0",   "icon": "image", "add": "" }
    ]

    // reusable track header: icon + name + an optional add button.
    component TrackHead: Rectangle {
        id: th
        property string label: ""
        property string icon: ""
        property color tint: Theme.dim
        property bool canAdd: false
        signal addClicked()
        width: tl.headW - 8; height: parent.height; radius: Theme.radiusSm; color: Theme.panelLo
        Icon { id: hIco; anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; name: th.icon; size: 13; tint: th.tint }
        Text {
            anchors.left: hIco.right; anchors.leftMargin: 7; anchors.right: addBtn.left; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
            text: th.label; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
        }
        Rectangle {
            id: addBtn
            visible: th.canAdd; width: th.canAdd ? 18 : 0; height: 18; radius: 9
            anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
            color: addMa.containsMouse ? Theme.fieldHi : Theme.field
            opacity: Project.hasClip ? 1 : 0.35
            Icon { anchors.centerIn: parent; name: "plus"; size: 11; tint: th.tint }
            MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: th.addClicked() }
        }
    }

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.hair }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 8
        spacing: 5

        // transport
        Item {
            width: parent.width; height: 28
            Rectangle {
                id: playBtn
                width: 28; height: 28; radius: 14
                color: pma.containsMouse ? Theme.fieldHi : Theme.field
                opacity: Project.hasClip ? 1 : 0.4
                Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: Project.playing ? 0 : 1; name: Project.playing ? "pause" : "play"; size: 15; tint: Theme.cream }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Project.togglePlay() }
            }
            Text {
                anchors.left: playBtn.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: tl.fmtD(Project.positionMs) + "  /  " + tl.fmtD(Project.durationMs)
                color: Theme.bright; font.family: Theme.mono; font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: Project.tool === "cut" ? "Cut: drag the in/out handles, then Remove in the panel" : "drag to move · pull edges to trim · click a block to edit"
                color: Theme.faint; font.family: Theme.font; font.pixelSize: 11
            }
        }

        // time ruler
        Item {
            width: parent.width; height: 20
            Item {
                x: tl.headW; width: tl.laneW; height: parent.height
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hair }
                Repeater {
                    model: Math.max(0, Math.floor(tl.durSec / (tl.tickStep / 5)) + 1)
                    delegate: Rectangle {
                        required property int index
                        x: (index * (tl.tickStep / 5)) / tl.durSec * tl.laneW
                        anchors.bottom: parent.bottom; width: 1
                        height: (index % 5 === 0) ? 8 : 4
                        color: (index % 5 === 0) ? Theme.dim : Theme.hairSoft
                    }
                }
                Repeater {
                    model: Math.floor(tl.durSec / tl.tickStep) + 1
                    delegate: Text {
                        required property int index
                        x: Math.min(tl.laneW - 26, (index * tl.tickStep) / tl.durSec * tl.laneW + 3)
                        text: tl.fmt(index * tl.tickStep * 1000)
                        color: Theme.faint; font.family: Theme.mono; font.pixelSize: 9
                    }
                }
                MouseArea {
                    anchors.fill: parent; enabled: Project.hasClip
                    onPressed: (m) => Project.seek(tl.xToMs(m.x))
                    onPositionChanged: (m) => { if (pressed) Project.seek(tl.xToMs(m.x)); }
                }
            }
        }

        // clip track (direct cut)
        Item {
            width: parent.width; height: 34
            TrackHead { label: "Clip"; icon: "film"; tint: "#8fb0d8" }
            Rectangle {
                id: clipLane
                anchors.left: parent.left; anchors.leftMargin: tl.headW; anchors.right: parent.right
                height: parent.height; radius: 5; clip: true
                color: Qt.rgba(0.24, 0.33, 0.45, 0.5)
                border.width: 1; border.color: Qt.rgba(0.55, 0.69, 0.85, 0.3)
                Icon { id: clIco; anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; visible: Project.hasClip; name: "film"; size: 13; tint: "#cfe0f2" }
                Text { anchors.left: clIco.right; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; visible: Project.hasClip; text: "Recording"; color: "#cfe0f2"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium }
                Repeater {
                    model: Project.cuts
                    delegate: Rectangle {
                        required property var modelData
                        x: tl.msToX(modelData.startMs); width: Math.max(2, tl.msToX(modelData.endMs - modelData.startMs))
                        height: parent.height; color: Theme.bgBot
                        border.width: 1; border.color: Theme.hair
                        Icon { anchors.centerIn: parent; visible: parent.width > 20; name: "scissors"; size: 12; tint: Theme.faint }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Project.removeRegion("cut", parent.modelData.id) }
                    }
                }
                Item {
                    anchors.fill: parent; visible: Project.tool === "cut"
                    onVisibleChanged: if (visible && Project.selStart < 0) { Project.selStart = Project.positionMs; Project.selEnd = Math.min(tl.dur, Project.positionMs + 2000); }
                    Rectangle {
                        visible: Project.selStart >= 0
                        x: tl.msToX(Project.selStart); width: Math.max(2, tl.msToX(Project.selEnd - Project.selStart))
                        height: parent.height; color: Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.35); border.width: 1.5; border.color: Theme.bad
                    }
                    Rectangle {
                        visible: Project.selStart >= 0
                        x: tl.msToX(Project.selStart) - 4; width: 8; height: parent.height; radius: 2; color: Theme.bad
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.SizeHorCursor
                            onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(clipLane, m.x, 0); Project.selStart = Math.max(0, Math.min(Project.selEnd - 100, tl.xToMs(p.x))); } }
                    }
                    Rectangle {
                        visible: Project.selStart >= 0
                        x: tl.msToX(Project.selEnd) - 4; width: 8; height: parent.height; radius: 2; color: Theme.bad
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.SizeHorCursor
                            onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(clipLane, m.x, 0); Project.selEnd = Math.min(tl.dur, Math.max(Project.selStart + 100, tl.xToMs(p.x))); } }
                    }
                }
            }
        }

        // region tracks (zoom / speed / text / overlay)
        Repeater {
            model: tl.regionTracks
            delegate: Item {
                id: trk
                required property var modelData
                readonly property string kind: modelData.kind
                readonly property color color: modelData.color
                width: parent.width; height: 30
                TrackHead {
                    label: trk.modelData.label; icon: trk.modelData.icon; tint: trk.color; canAdd: true
                    onAddClicked: trk.modelData.add ? Project[trk.modelData.add]() : (Project.tool = "overlay")
                }
                Rectangle {
                    id: lane
                    anchors.left: parent.left; anchors.leftMargin: tl.headW; anchors.right: parent.right
                    height: parent.height; radius: 5; color: Theme.hairSoft; clip: true
                    Repeater {
                        model: Project.arrOf(trk.kind)
                        delegate: Rectangle {
                            id: blk
                            required property var modelData
                            readonly property bool sel: Project.selKind === trk.kind && Project.selId === modelData.id
                            property real ovX: -1
                            property real ovW: -1
                            property real _ox: 0
                            property real _ow: 0
                            y: 3; height: parent.height - 6; radius: 5
                            x: body.drag.active ? x : (ovX >= 0 ? ovX : tl.msToX(modelData.startMs))
                            width: ovW >= 0 ? ovW : Math.max(10, tl.msToX(modelData.endMs - modelData.startMs))
                            color: blk.sel ? Qt.lighter(trk.color, 1.18) : trk.color
                            opacity: blk.sel ? 1 : 0.85
                            border.width: blk.sel ? 1.5 : 0; border.color: Theme.bright
                            Icon { id: bIco; anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter; visible: blk.width > 34; name: trk.modelData.icon; size: 11; tint: "#141210" }
                            Text {
                                anchors.left: blk.width > 34 ? bIco.right : parent.left; anchors.leftMargin: blk.width > 34 ? 5 : 7
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                text: trk.kind === "zoom" ? "×" + Project.depthScale(modelData.depth).toFixed(1)
                                    : trk.kind === "speed" ? modelData.speed.toFixed(2).replace(/\.?0+$/, "") + "×"
                                    : trk.kind === "text" ? modelData.text : modelData.name
                                color: "#141210"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                            }
                            Rectangle {
                                visible: blk.sel && blk.width > 44
                                anchors.right: parent.right; anchors.rightMargin: 3; anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; radius: 8; color: Qt.rgba(0, 0, 0, 0.28)
                                Icon { anchors.centerIn: parent; name: "trash"; size: 10; tint: "#141210" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Project.removeRegion(trk.kind, blk.modelData.id) }
                            }
                            MouseArea {
                                id: body
                                anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; cursorShape: Qt.PointingHandCursor
                                drag.target: blk; drag.axis: Drag.XAxis; drag.minimumX: 0; drag.maximumX: Math.max(0, tl.laneW - blk.width)
                                onPressed: Project.selectRegion(trk.kind, blk.modelData.id)
                                onReleased: { var ns = Math.max(0, Math.round(tl.xToMs(blk.x))); var d = blk.modelData.endMs - blk.modelData.startMs; Project.updateRegion(trk.kind, blk.modelData.id, { startMs: ns, endMs: Math.min(tl.dur, ns + d) }); }
                            }
                            MouseArea {
                                width: 8; height: parent.height; anchors.left: parent.left; cursorShape: Qt.SizeHorCursor
                                onPressed: { blk._ox = blk.x; blk._ow = blk.width; blk.ovX = blk.x; blk.ovW = blk.width; }
                                onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(lane, m.x, 0); var nx = Math.max(0, Math.min(p.x, blk._ox + blk._ow - 12)); blk.ovX = nx; blk.ovW = blk._ox + blk._ow - nx; }
                                onReleased: { Project.updateRegion(trk.kind, blk.modelData.id, { startMs: Math.round(tl.xToMs(blk.ovX)) }); blk.ovX = -1; blk.ovW = -1; }
                            }
                            MouseArea {
                                width: 8; height: parent.height; anchors.right: parent.right; cursorShape: Qt.SizeHorCursor
                                onPressed: { blk._ox = blk.x; blk._ow = blk.width; blk.ovX = blk.x; blk.ovW = blk.width; }
                                onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(lane, m.x, 0); blk.ovW = Math.max(12, Math.min(p.x - blk._ox, tl.laneW - blk._ox)); }
                                onReleased: { Project.updateRegion(trk.kind, blk.modelData.id, { endMs: Math.round(tl.xToMs(blk.ovX + blk.ovW)) }); blk.ovX = -1; blk.ovW = -1; }
                            }
                        }
                    }
                }
            }
        }

        // music track: a single positioned + trimmable audio block with a waveform
        Item {
            width: parent.width; height: 34
            TrackHead { label: "Music"; icon: "music"; tint: "#46b17f"; canAdd: true; onAddClicked: if (Project.hasClip) Project.chooseMusicRequested() }
            Rectangle {
                id: musicLane
                anchors.left: parent.left; anchors.leftMargin: tl.headW; anchors.right: parent.right
                height: parent.height; radius: 5; color: Theme.hairSoft; clip: true
                Text {
                    visible: Project.musicPath === ""
                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    text: Project.hasClip ? "Add a music track, then drag to place it" : ""
                    color: Theme.faint; font.family: Theme.font; font.pixelSize: 10
                }
                Rectangle {
                    id: mblk
                    visible: Project.musicPath !== ""
                    readonly property real endMs: Project.musicEndMs > 0 ? Project.musicEndMs : tl.dur
                    property real ovX: -1
                    property real ovW: -1
                    property real _ox: 0
                    property real _ow: 0
                    y: 3; height: parent.height - 6; radius: 5
                    x: mbody.drag.active ? x : (ovX >= 0 ? ovX : tl.msToX(Project.musicStartMs))
                    width: ovW >= 0 ? ovW : Math.max(28, tl.msToX(endMs - Project.musicStartMs))
                    color: "#46b17f"
                    // waveform (behind the label), a fixed set of bars spread to fit
                    Row {
                        id: wave
                        anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 20; anchors.topMargin: 7; anchors.bottomMargin: 7
                        spacing: Math.max(1, (width - 80) / 39)
                        clip: true
                        Repeater {
                            model: 40
                            delegate: Rectangle {
                                required property int index
                                width: 2; anchors.verticalCenter: parent.verticalCenter
                                height: Math.max(2, (0.18 + 0.82 * Math.abs(Math.sin(index * 0.7) * 0.6 + Math.sin(index * 1.9 + 1.1) * 0.4)) * wave.height)
                                radius: 1; color: Qt.rgba(0.05, 0.13, 0.08, 0.5)
                            }
                        }
                    }
                    Icon { id: mIco; anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter; name: "music"; size: 12; tint: "#0e1a12" }
                    Text {
                        anchors.left: mIco.right; anchors.leftMargin: 5; anchors.right: parent.right; anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        text: ("" + Project.musicPath).split("/").pop()
                        color: "#0e1a12"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: mblk.width > 46
                        anchors.right: parent.right; anchors.rightMargin: 3; anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8; color: Qt.rgba(0, 0, 0, 0.28)
                        Icon { anchors.centerIn: parent; name: "trash"; size: 10; tint: "#0e1a12" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Project.musicPath = "" }
                    }
                    MouseArea {
                        id: mbody
                        anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; cursorShape: Qt.PointingHandCursor
                        drag.target: mblk; drag.axis: Drag.XAxis; drag.minimumX: 0; drag.maximumX: Math.max(0, tl.laneW - mblk.width)
                        onReleased: { var ns = Math.max(0, Math.round(tl.xToMs(mblk.x))); var d = mblk.endMs - Project.musicStartMs; Project.setMusicRange(ns, ns + d); }
                    }
                    MouseArea {
                        width: 8; height: parent.height; anchors.left: parent.left; cursorShape: Qt.SizeHorCursor
                        onPressed: { mblk._ox = mblk.x; mblk._ow = mblk.width; mblk.ovX = mblk.x; mblk.ovW = mblk.width; }
                        onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(musicLane, m.x, 0); var nx = Math.max(0, Math.min(p.x, mblk._ox + mblk._ow - 16)); mblk.ovX = nx; mblk.ovW = mblk._ox + mblk._ow - nx; }
                        onReleased: { Project.setMusicRange(Math.round(tl.xToMs(mblk.ovX)), Math.round(tl.xToMs(mblk.ovX + mblk.ovW))); mblk.ovX = -1; mblk.ovW = -1; }
                    }
                    MouseArea {
                        width: 8; height: parent.height; anchors.right: parent.right; cursorShape: Qt.SizeHorCursor
                        onPressed: { mblk._ox = mblk.x; mblk._ow = mblk.width; mblk.ovX = mblk.x; mblk.ovW = mblk.width; }
                        onPositionChanged: (m) => { if (!pressed) return; var p = mapToItem(musicLane, m.x, 0); mblk.ovW = Math.max(16, Math.min(p.x - mblk._ox, tl.laneW - mblk._ox)); }
                        onReleased: { Project.setMusicRange(Math.round(tl.xToMs(mblk.ovX)), Math.round(tl.xToMs(mblk.ovX + mblk.ovW))); mblk.ovX = -1; mblk.ovW = -1; }
                    }
                }
            }
        }
    }

    // playhead spanning the ruler and every track
    Rectangle {
        visible: Project.hasClip
        width: 2; color: Theme.bright
        x: 8 + tl.headW + tl.msToX(Project.positionMs)
        y: 41; height: tl.height - 49
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; width: 10; height: 10; radius: 3; color: Theme.bright }
    }
}
