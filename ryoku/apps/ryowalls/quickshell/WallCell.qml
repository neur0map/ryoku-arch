import QtQuick
import QtMultimedia
import "Singletons"

// One thumbnail in the browse grid. Images show a still; live/moewalls videos
// show a poster with a play badge and loop the clip on hover (local clips, which
// have no poster, loop straight away). Hover lifts the border and shows the
// resolution; the picked one wears an ember frame + corner tick.
Rectangle {
    id: cell

    property var item
    property bool active: false
    signal picked()
    signal opened()

    readonly property bool isVideo: !!(cell.item && cell.item.video && ("" + cell.item.video).length > 0)
    readonly property bool hasThumb: !!(cell.item && cell.item.thumb && ("" + cell.item.thumb).length > 0)
    // local clips have no poster, so they loop always; moewalls loops on hover.
    readonly property bool playing: cell.isVideo && (ma.containsMouse || !cell.hasThumb)

    radius: Theme.radius
    color: Theme.surfaceLo
    border.width: cell.active ? 1.6 : 1
    border.color: cell.active ? Theme.ember : (ma.containsMouse ? Qt.alpha(Theme.cream, 0.35) : Theme.line)
    clip: true
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(cell.width * 1.6), Math.ceil(cell.height * 1.6))
        source: cell.hasThumb ? cell.item.thumb : ""
        visible: !vout.visible
    }

    MediaPlayer {
        id: mp
        source: cell.playing ? cell.item.video : ""
        loops: MediaPlayer.Infinite
        videoOutput: vout
        onSourceChanged: source != "" ? play() : stop()
    }
    VideoOutput {
        id: vout
        anchors.fill: parent
        anchors.margins: 1
        fillMode: VideoOutput.PreserveAspectCrop
        visible: cell.isVideo && mp.playbackState === MediaPlayer.PlayingState
    }

    // play badge on a video cell that isn't currently looping.
    Rectangle {
        visible: cell.isVideo && !vout.visible
        anchors.centerIn: parent
        width: 32; height: 32; radius: 16
        color: Qt.rgba(0, 0, 0, 0.42)
        Icon { anchors.centerIn: parent; name: "play"; size: 14; weight: 2; tint: Theme.bright }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: ma.containsMouse && !cell.active
        color: Qt.rgba(0, 0, 0, 0.3)
    }

    Text {
        visible: ma.containsMouse
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 6
        text: cell.item ? (cell.item.resolution || cell.item.name || "") : ""
        color: Theme.bright
        font.family: Theme.mono
        font.pixelSize: 10
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.5)
    }

    // ember corner tick on the active cell.
    Rectangle {
        visible: cell.active
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 16
        height: 16
        radius: 8
        color: Theme.ember
        Icon { anchors.centerIn: parent; name: "check"; size: 11; weight: 2.2; tint: Theme.onAccent }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => { if (e.button === Qt.RightButton) cell.opened(); else cell.picked(); }
    }
}
