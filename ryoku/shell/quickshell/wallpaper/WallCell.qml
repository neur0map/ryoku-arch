pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One wallpaper in the grid. Images show their thumbnail; live (video) ones show
// a poster with a LIVE badge and loop, muted, once picked. The pick wears a
// vermillion frame and lifts; the wallpaper on screen wears a small accent dot.
Rectangle {
    id: cell

    required property real s
    required property var item
    required property bool selected
    required property bool current
    signal entered()
    signal chosen()

    readonly property bool isLive: cell.item && cell.item.type === "live"
    readonly property bool playing: cell.isLive && cell.selected

    radius: Theme.radius
    color: Theme.tileBg
    clip: true
    border.width: cell.selected ? 3 : 1
    border.color: cell.selected ? Theme.brand : Theme.hair
    scale: cell.selected ? 1.04 : 1.0
    z: cell.selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: Motion.highlight; easing.type: Motion.easeStandard } }
    Behavior on border.color { ColorAnimation { duration: Motion.highlight } }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(cell.width * 1.5), Math.ceil(cell.height * 1.5))
        source: (cell.item && cell.item.thumb) ? "file://" + cell.item.thumb : ""
    }

    // live preview built only for the picked video, so image cells never spin up
    // a media pipeline (and QtMultimedia loads only once a clip plays).
    Loader {
        anchors.fill: parent
        anchors.margins: 1
        active: cell.playing
        source: "VideoPreview.qml"
        onLoaded: item.path = cell.item.path
    }

    // dim the cells that aren't the pick, so the selection reads clearly.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: "black"
        opacity: cell.selected ? 0 : 0.4
        Behavior on opacity { NumberAnimation { duration: Motion.highlight } }
    }

    // LIVE badge for videos.
    Rectangle {
        visible: cell.isLive
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(6 * cell.s)
        height: Math.round(16 * cell.s)
        width: liveLabel.implicitWidth + Math.round(12 * cell.s)
        radius: Theme.radius
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            id: liveLabel
            anchors.centerIn: parent
            text: "LIVE"
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: Math.round(9 * cell.s)
            font.weight: Font.DemiBold
        }
    }

    // accent dot on the wallpaper that's currently on screen.
    Rectangle {
        visible: cell.current
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(6 * cell.s)
        width: Math.round(10 * cell.s)
        height: Math.round(10 * cell.s)
        radius: width / 2
        color: Theme.brand
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.4)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: cell.entered()
        onClicked: cell.chosen()
    }
}
