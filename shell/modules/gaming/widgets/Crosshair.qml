pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import ".."

// RYOKU: screen-centered, drag-exempt crosshair drawn in pure QML. Sized and
// styled entirely from GlobalConfig.gaming.crosshair. When outline is on, an
// outline pass (slightly larger, behind) is drawn first, then the colored pass
// on top. Default style "dot" shows only the center dot (no arms).
OverlayWidget {
    id: root

    widgetId: "crosshair"
    centered: true

    readonly property var cfg: GlobalConfig.gaming.crosshair
    readonly property bool showCross: cfg.style === "cross" || cfg.style === "dot-cross"
    readonly property bool showDot: cfg.style === "dot" || cfg.style === "dot-cross"

    implicitWidth: 2 * (cfg.gap + cfg.lineLength) + cfg.lineThickness
    implicitHeight: implicitWidth

    Repeater {
        model: root.cfg.outline ? 2 : 1

        delegate: Item {
            id: pass

            required property int index
            readonly property bool isOutline: root.cfg.outline && index === 0
            readonly property color col: isOutline ? root.cfg.outlineColor : root.cfg.color
            readonly property int grow: isOutline ? 2 : 0

            anchors.fill: parent

            // Center dot.
            Rectangle {
                visible: root.showDot
                anchors.centerIn: parent
                width: root.cfg.size + pass.grow
                height: width
                radius: width / 2
                color: pass.col
            }

            // Four arms (left, right, top, bottom).
            Repeater {
                model: root.showCross ? 4 : 0

                delegate: Rectangle {
                    id: arm

                    required property int index
                    readonly property bool horiz: index < 2

                    color: pass.col
                    width: horiz ? root.cfg.lineLength + pass.grow : root.cfg.lineThickness + pass.grow
                    height: horiz ? root.cfg.lineThickness + pass.grow : root.cfg.lineLength + pass.grow
                    x: horiz ? (index === 0 ? pass.width / 2 - root.cfg.gap - width : pass.width / 2 + root.cfg.gap) : (pass.width - width) / 2
                    y: horiz ? (pass.height - height) / 2 : (index === 2 ? pass.height / 2 - root.cfg.gap - height : pass.height / 2 + root.cfg.gap)
                }
            }
        }
    }
}
