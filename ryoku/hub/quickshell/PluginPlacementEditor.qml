pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

/**
 * Interactive placement editor for one plugin, mirroring the Desktop Widgets and
 * Visualizer hub sections: a screen-proportioned preview where the user sets
 * where the plugin lives. For a frame popout, pick the edge and drag the position
 * along it, and size the hover band; for a desktop widget, drag the tile to a
 * free position. Edits write live to plugins.json via ryoku-plugins-place, so the
 * running shell retunes as you drag.
 *
 *   PluginPlacementEditor { pluginId: "wallhaven"; host: "framePopout"; place: {...}
 *                           onChanged: (field, args) => page.place(pluginId, field, ...args) }
 */
Item {
    id: ed

    property string pluginId: ""
    property string host: "framePopout"
    property var place: ({})
    // Emitted on a settled edit: field is the ryoku-plugins-place verb, args its values.
    signal changed(string field, var args)

    implicitHeight: 230

    // Screen-proportioned stage (16:10-ish), the canvas the user places within.
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

        // A faint screen frame so it reads as "your display".
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

        // ---- frame popout: an edge band + a draggable position marker --------
        Item {
            anchors.fill: parent
            visible: ed.host === "framePopout"

            readonly property string edge: (ed.place && ed.place.framePopout && ed.place.framePopout.edge) ? ed.place.framePopout.edge : "right"
            readonly property string align: (ed.place && ed.place.framePopout && ed.place.framePopout.align) ? ed.place.framePopout.align : "center"
            readonly property bool vertical: edge === "left" || edge === "right"
            id: fp

            // The popout body preview: a rounded chip docked to the chosen edge,
            // positioned by align. Drag it along the edge to change align.
            Rectangle {
                id: body
                width: fp.vertical ? 64 : 96
                height: fp.vertical ? 96 : 60
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.5)
                border.width: 1
                border.color: Theme.ember

                readonly property real m: 10
                x: fp.edge === "left" ? m
                 : fp.edge === "right" ? parent.width - width - m
                 : alignPos(parent.width, width)
                y: fp.edge === "top" ? m
                 : fp.edge === "bottom" ? parent.height - height - m
                 : alignPos(parent.height, height)

                function alignPos(span, sz) {
                    return fp.align === "start" ? m
                         : fp.align === "end" ? span - sz - m
                         : (span - sz) / 2;
                }

                Text {
                    anchors.centerIn: parent
                    text: "popout"
                    color: Theme.ember
                    font.family: Theme.mono; font.pixelSize: 10
                }

                // Drag along the edge to set align (start/center/end by thirds).
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    drag.target: parent
                    drag.axis: fp.vertical ? Drag.YAxis : Drag.XAxis
                    onReleased: {
                        var pos, span;
                        if (fp.vertical) { pos = parent.y + parent.height / 2; span = parent.parent.height; }
                        else { pos = parent.x + parent.width / 2; span = parent.parent.width; }
                        var t = pos / span;
                        var a = t < 0.34 ? "start" : t > 0.66 ? "end" : "center";
                        ed.changed("framePopout", [fp.edge, a, fp.hoverW(), fp.hoverH()]);
                    }
                }
            }

            function hoverW() { return (ed.place && ed.place.framePopout && ed.place.framePopout.hoverW) ? ed.place.framePopout.hoverW : 320; }
            function hoverH() { return (ed.place && ed.place.framePopout && ed.place.framePopout.hoverH) ? ed.place.framePopout.hoverH : 16; }
        }

        // ---- desktop widget: a freely draggable tile ------------------------
        Rectangle {
            visible: ed.host === "desktopWidget"
            id: dw
            width: 96; height: 60; radius: 8
            color: Qt.rgba(0, 0, 0, 0.5)
            border.width: 1
            border.color: Theme.ember
            readonly property real px: (ed.place && ed.place.desktopWidget && ed.place.desktopWidget.x !== undefined) ? ed.place.desktopWidget.x : 80
            readonly property real py: (ed.place && ed.place.desktopWidget && ed.place.desktopWidget.y !== undefined) ? ed.place.desktopWidget.y : 80
            // Map the real (1920x1080-ish) position into the stage proportionally.
            x: Math.max(0, Math.min(parent.width - width, px / 1920 * parent.width))
            y: Math.max(0, Math.min(parent.height - height, py / 1080 * parent.height))
            Text { anchors.centerIn: parent; text: "widget"; color: Theme.ember; font.family: Theme.mono; font.pixelSize: 10 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                drag.target: parent
                drag.minimumX: 0; drag.maximumX: parent.parent.width - parent.width
                drag.minimumY: 0; drag.maximumY: parent.parent.height - parent.height
                onReleased: {
                    var rx = Math.round(parent.x / parent.parent.width * 1920);
                    var ry = Math.round(parent.y / parent.parent.height * 1080);
                    ed.changed("desktopWidget", [rx, ry]);
                }
            }
        }
    }

    // ---- frame popout: edge selector ----------------------------------------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 6
        visible: ed.host === "framePopout"
        Repeater {
            model: [{ k: "top", l: "Top" }, { k: "right", l: "Right" }, { k: "bottom", l: "Bottom" }, { k: "left", l: "Left" }]
            delegate: Rectangle {
                id: edgeCell
                required property var modelData
                readonly property string cur: (ed.place && ed.place.framePopout && ed.place.framePopout.edge) ? ed.place.framePopout.edge : "right"
                readonly property bool active: cur === edgeCell.modelData.k
                width: el.implicitWidth + 18; height: 24; radius: 7
                color: active ? Theme.ember : Theme.surfaceLo
                border.width: 1; border.color: active ? Theme.ember : Theme.line
                Text {
                    id: el; anchors.centerIn: parent; text: edgeCell.modelData.l
                    color: edgeCell.active ? Theme.onAccent : Theme.dim
                    font.family: Theme.font; font.pixelSize: 11; font.weight: edgeCell.active ? Font.DemiBold : Font.Medium
                }
                TapHandler {
                    onTapped: {
                        var a = (ed.place && ed.place.framePopout && ed.place.framePopout.align) ? ed.place.framePopout.align : "center";
                        var hw = (ed.place && ed.place.framePopout && ed.place.framePopout.hoverW) ? ed.place.framePopout.hoverW : 320;
                        var hh = (ed.place && ed.place.framePopout && ed.place.framePopout.hoverH) ? ed.place.framePopout.hoverH : 16;
                        ed.changed("framePopout", [edgeCell.modelData.k, a, hw, hh]);
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
