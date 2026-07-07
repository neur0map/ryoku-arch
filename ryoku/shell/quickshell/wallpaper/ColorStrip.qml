pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "Singletons"

// Colour categories as sliced swatches echoing the tiles: one muted swatch per
// group, sharp with a cut corner, dark hairline by default and a vermillion
// frame plus a small lift on the pick. A leading mono ALL clears the filter.
Item {
    id: strip

    required property real s
    required property var groups
    required property int selected
    signal picked(int g)

    readonly property int swW: Math.round(22 * s)
    readonly property int cut: Math.round(6 * s)

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(5 * strip.s)

        Item {
            id: all
            readonly property bool on: strip.selected === -1
            width: allTxt.implicitWidth + Math.round(16 * strip.s)
            height: strip.height

            Text {
                id: allTxt
                anchors.centerIn: parent
                text: "ALL"
                color: all.on ? Theme.brand : Theme.dim
                font.family: Theme.mono
                font.pixelSize: Math.round(9.5 * strip.s)
                font.weight: Font.DemiBold
                font.letterSpacing: 2 * strip.s
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Math.round(18 * strip.s)
                height: Math.max(1, Math.round(2 * strip.s))
                color: Theme.brand
                visible: all.on
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: strip.picked(-1) }
        }

        Repeater {
            model: strip.groups
            delegate: Item {
                id: sw
                required property var modelData
                readonly property bool on: strip.selected === sw.modelData
                readonly property bool dimmed: strip.selected !== -1 && !sw.on
                width: strip.swW
                height: strip.height

                Shape {
                    id: shp
                    anchors.fill: parent
                    y: sw.on ? -Math.round(2 * strip.s) : 0
                    opacity: sw.dimmed ? 0.4 : 1
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    Behavior on y { NumberAnimation { duration: Motion.highlight; easing.type: Motion.easeStandard } }

                    ShapePath {
                        fillColor: hh.hovered ? Qt.lighter(Colors.swatch(sw.modelData), 1.15) : Colors.swatch(sw.modelData)
                        strokeColor: sw.on ? Theme.brand : Qt.rgba(0, 0, 0, 0.4)
                        strokeWidth: sw.on ? Math.max(1, Math.round(1.6 * strip.s)) : 1
                        startX: strip.cut
                        startY: 0
                        PathLine { x: sw.width; y: 0 }
                        PathLine { x: sw.width; y: sw.height }
                        PathLine { x: 0; y: sw.height }
                        PathLine { x: 0; y: strip.cut }
                        PathLine { x: strip.cut; y: 0 }
                    }
                }

                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: strip.picked(sw.modelData) }
            }
        }
    }
}
