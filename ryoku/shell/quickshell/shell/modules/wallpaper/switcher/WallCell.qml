pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One wallpaper tile: a rounded thumbnail whose outline lifts to the on-surface
// ink on hover and the primary accent on the pick, matching the shell's menu
// thumbnails. Live wallpapers carry a LIVE tag and loop a small cached preview
// once they are the settled pick; the wallpaper already on screen wears an
// on-air dot. The full-res original is never decoded, so hover never hitches.
Item {
    id: cell

    required property real s
    required property var item
    required property color bg      // stage colour, for the belt edge-fade API
    property bool selected: false
    property bool topRow: true       // unused; kept for the belt cell API
    property bool live: true         // on-screen; gates the thumbnail decode
    property bool beltMoving: false  // belt drifting/scrolling; holds video off
    signal entered()
    signal chosen()

    readonly property bool isLive: cell.item && cell.item.type === "live"
    readonly property string previewPath: (cell.item && cell.item.preview) ? cell.item.preview : ""

    // play a clip only when it's the settled pick, after a short dwell, so a
    // drift or a cursor sweep never spins media pipelines up and down.
    readonly property bool wantVideo: cell.isLive && cell.previewPath.length > 0 && cell.selected && !cell.beltMoving
    property bool videoArmed: false
    onWantVideoChanged: {
        if (cell.wantVideo)
            armT.restart();
        else {
            armT.stop();
            cell.videoArmed = false;
        }
    }
    Timer { id: armT; interval: 170; onTriggered: cell.videoArmed = true }

    scale: cell.selected ? 1.03 : 1.0
    transformOrigin: Item.Center
    z: cell.selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: Theme.surfaceContainerLow
        clip: true
        border.width: Theme.borderWidth
        border.color: cell.selected ? Theme.primary : (hover.hovered ? Theme.onSurface : Theme.outline)
        Behavior on border.color { ColorAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

        Image {
            id: img
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            // Fixed decode size: binding this to the animating tile width/height
            // re-decodes the thumbnail every frame of a slide and flashes black.
            sourceSize: Qt.size(512, 512)
            source: (cell.live && cell.item && cell.item.thumb) ? "file://" + cell.item.thumb : ""
            // fade the still out once the live preview presents, so the clip
            // replaces the thumbnail cleanly instead of playing on top of it.
            opacity: (vid.item && vid.item.ready) ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.thumbHover } }
        }

        // live preview only for the picked video, so idle tiles never open a pipeline.
        Loader {
            id: vid
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            active: cell.wantVideo && cell.videoArmed
            asynchronous: true
            source: "VideoPreview.qml"
            onLoaded: item.path = cell.previewPath
        }

        // subtle scrim so the tags stay legible and the pick reads clearly.
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            radius: Theme.radiusWidget
            color: "black"
            opacity: cell.selected ? 0 : 0.14
            Behavior on opacity { NumberAnimation { duration: Motion.thumbHover } }
        }
    }

    // LIVE tag for video, bottom-right.
    Rectangle {
        visible: cell.isLive
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(8 * cell.s)
        height: Math.round(17 * cell.s)
        width: liveLabel.implicitWidth + Math.round(12 * cell.s)
        radius: Math.round(4 * cell.s)
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            id: liveLabel
            anchors.centerIn: parent
            text: "LIVE"
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Math.round(9 * cell.s)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5 * cell.s
        }
    }

    // on-air dot for the wallpaper currently set, top-left.
    Rectangle {
        visible: cell.item && cell.item.path === Walls.current
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Math.round(8 * cell.s)
        width: Math.round(11 * cell.s)
        height: width
        radius: width / 2
        color: Theme.primary
        border.width: Math.max(1, Math.round(2 * cell.s))
        border.color: Theme.surface
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) cell.entered()
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cell.chosen() }
}
