pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "Singletons"

// One wallpaper tile. Not a plain square: two opposite corners are sliced off
// (mirrored between the two rows) with a hairline along each cut, a colour chip
// marking its group, a LIVE tag for video and an on-air dot for the wallpaper
// already set. The pick brightens, lifts and wears a vermillion accent; live
// tiles loop muted once picked.
Item {
    id: cell

    required property real s
    required property var item
    required property color bg      // rows-stage colour the cuts blend into
    property bool selected: false
    property bool topRow: true      // which pair of corners to slice
    signal entered()
    signal chosen()

    readonly property bool isLive: cell.item && cell.item.type === "live"
    readonly property int cut: Math.round(16 * s)
    readonly property int inset: cut + Math.round(6 * s)
    readonly property color accent: cell.selected ? Theme.brand : Qt.alpha(Theme.cream, 0.45)

    scale: cell.selected ? 1.05 : 1.0
    transformOrigin: Item.Center
    z: cell.selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: Motion.highlight; easing.type: Motion.easeStandard } }

    Image {
        id: img
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(cell.width * 1.4), Math.ceil(cell.height * 1.4))
        source: (cell.item && cell.item.thumb) ? "file://" + cell.item.thumb : ""
    }

    // live preview only for the picked video, so idle tiles never open a pipeline.
    Loader {
        anchors.fill: parent
        active: cell.isLive && cell.selected
        asynchronous: true
        source: "VideoPreview.qml"
        onLoaded: item.path = cell.item.path
    }

    // unpicked tiles sit back a touch so the pick reads clearly.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: cell.selected ? 0 : 0.22
        Behavior on opacity { NumberAnimation { duration: Motion.highlight } }
    }

    // bottom scrim so the tags stay legible over bright wallpapers.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(38 * cell.s)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
        }
    }

    // selection frame (its cut corners are trimmed by the chamfer above it).
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: cell.selected ? 2 : 1
        border.color: cell.selected ? Theme.brand : Theme.hair
        Behavior on border.color { ColorAnimation { duration: Motion.highlight } }
    }

    // sliced corners: fill the two corner triangles with the stage colour so the
    // silhouette is cut, and trace each cut with a hairline.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: cell.bg
            strokeWidth: 0
            startX: cell.topRow ? 0 : cell.width
            startY: 0
            PathLine { x: cell.topRow ? cell.cut : cell.width - cell.cut; y: 0 }
            PathLine { x: cell.topRow ? 0 : cell.width; y: cell.cut }
            PathLine { x: cell.topRow ? 0 : cell.width; y: 0 }
            PathMove { x: cell.topRow ? cell.width : 0; y: cell.height }
            PathLine { x: cell.topRow ? cell.width - cell.cut : cell.cut; y: cell.height }
            PathLine { x: cell.topRow ? cell.width : 0; y: cell.height - cell.cut }
            PathLine { x: cell.topRow ? cell.width : 0; y: cell.height }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: cell.accent
            strokeWidth: Math.max(1, Math.round(1.6 * cell.s))
            capStyle: ShapePath.FlatCap
            startX: cell.topRow ? cell.cut : cell.width - cell.cut
            startY: 0
            PathLine { x: cell.topRow ? 0 : cell.width; y: cell.cut }
            PathMove { x: cell.topRow ? cell.width - cell.cut : cell.cut; y: cell.height }
            PathLine { x: cell.topRow ? cell.width : 0; y: cell.height - cell.cut }
        }
    }

    // colour-group chip, bottom-left, clear of the cuts.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: cell.inset
        anchors.bottomMargin: Math.round(8 * cell.s)
        width: Math.round(12 * cell.s)
        height: width
        color: cell.item ? Colors.swatch(cell.item.group) : "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.4)
    }

    // LIVE tag for video, bottom-right, clear of the cuts.
    Rectangle {
        visible: cell.isLive
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: cell.inset
        anchors.bottomMargin: Math.round(8 * cell.s)
        height: Math.round(15 * cell.s)
        width: liveLabel.implicitWidth + Math.round(10 * cell.s)
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            id: liveLabel
            anchors.centerIn: parent
            text: "LIVE"
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: Math.round(8.5 * cell.s)
            font.weight: Font.DemiBold
        }
    }

    // on-air dot for the wallpaper currently set, on an uncut corner.
    Rectangle {
        visible: cell.item && cell.item.path === Walls.current
        anchors.top: parent.top
        anchors.right: cell.topRow ? parent.right : undefined
        anchors.left: cell.topRow ? undefined : parent.left
        anchors.margins: cell.inset
        width: Math.round(9 * cell.s)
        height: width
        radius: width / 2
        color: Theme.brand
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.4)
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) cell.entered()
    }
    TapHandler { onTapped: cell.chosen() }
}
