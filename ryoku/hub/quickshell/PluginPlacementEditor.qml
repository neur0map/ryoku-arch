pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// frame-popout placement editor for one plugin. mirrors the Visualizer hub
// section: a screen-proportioned preview, pick an edge for the popout to grow
// from and slide it along that edge (start | end; centre of every edge is
// reserved for island/mixer/power and shown struck out). edits write live to
// plugins.json via ryoku-plugins-place so the running shell retunes as you drag.
//
// desktop-widget plugins (clock, weather) do NOT come through here. those get
// dragged on the wallpaper directly (left-drag to move, right-click for menu).
// so this editor only renders for the framePopout host.
//
//   PluginPlacementEditor { pluginId: "wallhaven"; place: {...}
//                           onChanged: (field, args) => page.place(pluginId, field, ...args) }
Item {
    id: ed

    property string pluginId: ""
    property var place: ({})
    // fires on a settled edit. field = ryoku-plugins-place verb, args = values.
    signal changed(string field, var args)

    readonly property string edge: (place && place.framePopout && place.framePopout.edge) ? place.framePopout.edge : "right"
    readonly property string align: (place && place.framePopout && place.framePopout.align) ? place.framePopout.align : "start"
    readonly property bool vertical: edge === "left" || edge === "right"
    function hoverW() { return (place && place.framePopout && place.framePopout.hoverW) ? place.framePopout.hoverW : 320; }
    function hoverH() { return (place && place.framePopout && place.framePopout.hoverH) ? place.framePopout.hoverH : 16; }

    implicitHeight: 230

    // screen-proportioned stage (~16:10), the canvas the user places within.
    Rectangle {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.min(ed.width, ed.height * 1.6)
        height: ed.height - 28
        radius: 14
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#191320" }
            GradientStop { position: 1.0; color: "#241a16" }
        }
        border.width: 1
        border.color: Theme.line
        clip: true

        // faint screen frame so it reads as "your display".
        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: 8
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
        }

        Text {
            anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 10
            text: "LIVE PLACEMENT"
            color: Theme.dim
            font.family: Theme.mono; font.pixelSize: 9; font.weight: Font.DemiBold
            font.letterSpacing: 2
        }

        // shell pre-reserves the centre of every edge (top = island, left =
        // mixer, right = power menu, bottom = clear for symmetry), so a plugin
        // can't dock there. band makes the reservation visible while dragging;
        // release snap collapses the middle third to start/end.
        Rectangle {
            id: reservedBand
            readonly property real m: 10
            readonly property real bandThickness: ed.vertical ? 64 : 60
            x: ed.edge === "left" ? m
             : ed.edge === "right" ? parent.width - bandThickness - m
             : parent.width / 3
            y: ed.edge === "top" ? m
             : ed.edge === "bottom" ? parent.height - bandThickness - m
             : parent.height / 3
            width: ed.vertical ? bandThickness : parent.width / 3
            height: ed.vertical ? parent.height / 3 : bandThickness
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.03)
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Theme.dim.toString();
                    ctx.lineWidth = 1;
                    ctx.setLineDash([4, 3]);
                    ctx.strokeRect(0.5, 0.5, width - 1, height - 1);
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
            Text {
                anchors.centerIn: parent
                text: "reserved"
                color: Theme.dim
                font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 1.5
            }
        }

        // popout body preview: a rounded chip docked to the chosen edge,
        // positioned by align. drag it along the edge to flip align (start/end).
        Rectangle {
            id: body
            width: ed.vertical ? 64 : 96
            height: ed.vertical ? 96 : 60
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.5)
            border.width: 1
            border.color: Theme.ember

            readonly property real m: 10
            x: ed.edge === "left" ? m
             : ed.edge === "right" ? parent.width - width - m
             : alignPos(parent.width, width)
            y: ed.edge === "top" ? m
             : ed.edge === "bottom" ? parent.height - height - m
             : alignPos(parent.height, height)

            function alignPos(span, sz) {
                return ed.align === "end" ? span - sz - m : m;  // start | end (never centre)
            }

            Text {
                anchors.centerIn: parent
                text: "popout"
                color: Theme.ember
                font.family: Theme.mono; font.pixelSize: 10
            }

            // drag along the edge to set align. middle (reserved) third
            // collapses to whichever of start/end is nearer, so centre is never
            // a value.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                drag.target: parent
                drag.axis: ed.vertical ? Drag.YAxis : Drag.XAxis
                onReleased: {
                    var pos, span;
                    if (ed.vertical) { pos = parent.y + parent.height / 2; span = parent.parent.height; }
                    else { pos = parent.x + parent.width / 2; span = parent.parent.width; }
                    var a = (pos / span) < 0.5 ? "start" : "end";
                    ed.changed("framePopout", [ed.edge, a, ed.hoverW(), ed.hoverH()]);
                }
            }
        }
    }

    // edge selector.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 6
        Repeater {
            model: [{ k: "top", l: "Top" }, { k: "right", l: "Right" }, { k: "bottom", l: "Bottom" }, { k: "left", l: "Left" }]
            delegate: Rectangle {
                id: edgeCell
                required property var modelData
                readonly property bool active: ed.edge === edgeCell.modelData.k
                width: el.implicitWidth + 18; height: 24; radius: 7
                color: active ? Theme.keyTop : Theme.surfaceLo
                border.width: 1; border.color: Theme.line
                Text {
                    id: el; anchors.centerIn: parent; text: edgeCell.modelData.l
                    color: edgeCell.active ? Theme.bright : Theme.dim
                    font.family: Theme.font; font.pixelSize: 11; font.weight: edgeCell.active ? Font.DemiBold : Font.Medium
                }
                TapHandler {
                    onTapped: ed.changed("framePopout", [edgeCell.modelData.k, ed.align, ed.hoverW(), ed.hoverH()])
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
