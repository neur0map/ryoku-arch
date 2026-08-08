pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One colour-scheme tile: a rounded preview filled with the theme's own surface
// colour, its name, and a two-by-three grid of role swatches, matching the
// shell's theme picker. The outline lifts to the on-surface ink on hover and the
// primary accent on the pick; the applied scheme wears an on-air dot. Dimmed and
// inert while the switch follows the wallpaper (themes disabled).
Item {
    id: cell

    required property real s
    required property var item          // theme card { id, label, sw[7], dark }
    required property color bg           // stage colour, for the belt cell API
    property bool topRow: true           // unused; belt cell API
    property bool selected: false        // hovered / centred pick
    property bool active: false          // the applied scheme
    property bool interactive: true      // false while following the wallpaper
    signal entered()
    signal chosen()

    readonly property var sw: cell.item ? cell.item.sw : []
    readonly property color surface: cell.sw.length > 0 ? cell.sw[0] : Theme.surfaceContainer
    readonly property color onSurface: cell.sw.length > 1 ? cell.sw[1] : Theme.onSurface

    scale: cell.selected ? 1.03 : 1.0
    transformOrigin: Item.Center
    z: cell.selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: cell.surface
        clip: true
        border.width: Theme.borderWidth
        border.color: cell.selected ? Theme.primary : (hover.hovered ? Theme.onSurface : Theme.outline)
        Behavior on border.color { ColorAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

        // theme name, top, in its own on-surface colour.
        Text {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: Math.round(14 * cell.s)
            anchors.leftMargin: Math.round(10 * cell.s)
            anchors.rightMargin: Math.round(10 * cell.s)
            text: cell.item ? cell.item.label : ""
            color: cell.onSurface
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.fontPrimary
            font.pixelSize: Math.round(14 * cell.s)
            font.weight: Font.DemiBold
        }

        // two rows of three role swatches, centred near the bottom.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(22 * cell.s)
            spacing: Math.round(7 * cell.s)
            Row {
                spacing: Math.round(7 * cell.s)
                Repeater {
                    model: cell.sw.length >= 7 ? [cell.sw[1], cell.sw[2], cell.sw[3]] : []
                    delegate: Rectangle {
                        required property color modelData
                        width: Math.round(16 * cell.s)
                        height: width
                        radius: Math.round(3 * cell.s)
                        color: modelData
                    }
                }
            }
            Row {
                spacing: Math.round(7 * cell.s)
                Repeater {
                    model: cell.sw.length >= 7 ? [cell.sw[4], cell.sw[5], cell.sw[6]] : []
                    delegate: Rectangle {
                        required property color modelData
                        width: Math.round(16 * cell.s)
                        height: width
                        radius: Math.round(3 * cell.s)
                        color: modelData
                    }
                }
            }
        }

        // on-air dot for the applied scheme, bottom-left in the theme's own ink.
        Rectangle {
            visible: cell.active
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(8 * cell.s)
            width: Math.round(11 * cell.s)
            height: width
            radius: width / 2
            color: cell.onSurface
        }
    }

    // dim + inert while following the wallpaper: themes are disabled.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: "black"
        opacity: cell.interactive ? 0 : 0.5
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: Motion.thumbHover } }
    }

    HoverHandler {
        id: hover
        enabled: cell.interactive
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) cell.entered()
    }
    MouseArea { anchors.fill: parent; enabled: cell.interactive; cursorShape: Qt.PointingHandCursor; onClicked: cell.chosen() }
}
