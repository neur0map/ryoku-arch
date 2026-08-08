pragma ComponentBehavior: Bound
import QtQuick
import shell.services

// One wallpaper tile for the wallpaper belt: a rounded thumbnail whose outline
// lifts to the on-surface ink on hover and the primary accent on the pick,
// matching the shell's menu thumbnails. Live wallpapers carry a LIVE tag and
// loop a small cached preview once they are the settled pick; the wallpaper
// already on screen wears an on-air dot. The full-res original is never decoded.
Item {
    id: cell

    required property var item          // { type, path, name, thumb, preview, group }
    property string current: ""          // path of the wallpaper on screen (on-air dot)
    property bool selected: false        // hovered / centred pick
    property bool live: true             // on-screen; gates the thumbnail decode
    property bool beltMoving: false      // belt drifting/scrolling; holds video off
    signal entered()
    signal chosen()

    readonly property bool isLive: cell.item && cell.item.type === "live"
    readonly property string previewPath: (cell.item && cell.item.preview) ? cell.item.preview : ""

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
            sourceSize: Qt.size(Math.ceil(cell.width * 1.4), Math.ceil(cell.height * 1.4))
            source: (cell.live && cell.item && cell.item.thumb) ? "file://" + cell.item.thumb : ""
            opacity: (vid.item && vid.item.ready) ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.thumbHover } }
        }

        Loader {
            id: vid
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            active: cell.wantVideo && cell.videoArmed
            asynchronous: true
            source: "WallVideo.qml"
            onLoaded: item.path = cell.previewPath
        }

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
        anchors.margins: 8
        height: 17
        width: liveLabel.implicitWidth + 12
        radius: 4
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            id: liveLabel
            anchors.centerIn: parent
            text: "LIVE"
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }
    }

    // on-air dot for the wallpaper currently set, top-left.
    Rectangle {
        visible: cell.item && cell.current.length > 0 && cell.item.path === cell.current
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 8
        width: 11
        height: 11
        radius: 5.5
        color: Theme.primary
        border.width: 2
        border.color: Theme.surface
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) cell.entered()
    }
    TapHandler { onTapped: cell.chosen() }
}
