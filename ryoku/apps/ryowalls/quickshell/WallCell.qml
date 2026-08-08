import QtQuick
import QtMultimedia
import Ryoku.Ui.Singletons
import "Singletons"

// One thumbnail in the browse grid. The image is the information, so the tile is
// hairline chrome around a full-bleed thumb: hover lifts the border, the picked
// tile takes the gallery grammar (1px ink border + a corner ink dot), no wash
// and no coloured frame. Local clips loop on hover; remote clips never stream
// here. Right-click opens the source page.
Rectangle {
    id: cell

    property var item
    property bool active: false
    signal picked()
    signal opened()
    // Local source: mark this tile for deletion without stealing the pick click.
    property bool selectable: false
    property bool selected: false
    signal toggledSelect()

    readonly property bool isVideo: !!(cell.item && cell.item.video && ("" + cell.item.video).length > 0)
    readonly property bool hasThumb: !!(cell.item && cell.item.thumb && ("" + cell.item.thumb).length > 0)
    readonly property bool isLocal: cell.isVideo && !("" + cell.item.video).startsWith("http")
    readonly property bool playing: cell.isLocal && (ma.containsMouse || !cell.hasThumb)
    readonly property string resText: (cell.item && cell.item.resolution) ? ("" + cell.item.resolution) : ""
    readonly property int resH: {
        var p = cell.resText.split("x");
        return p.length === 2 ? (parseInt(p[1]) || 0) : 0;
    }
    // media that would upscale-blur on a 1080p+ screen: exactly what Enhance is for.
    readonly property bool lowRes: cell.resH > 0 && cell.resH < 1080

    radius: Tokens.radius
    color: "transparent"
    border.width: Tokens.border
    // selected → ink; marked-for-delete → bone; hover → lineStrong; rest → line.
    border.color: cell.active ? Tokens.ink
        : (cell.selected ? Tokens.bone
        : (ma.containsMouse ? Tokens.lineStrong : Tokens.line))
    clip: true
    Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(cell.width * 1.6), Math.ceil(cell.height * 1.6))
        source: cell.hasThumb ? cell.item.thumb : ""
        visible: !vout.visible
        // a slight zoom on hover: the image is clipped to the tile, so it reads
        // as the thumbnail leaning toward you -- the store's one interactivity tell.
        scale: ma.containsMouse ? 1.06 : 1.0
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: Tokens.swap; easing.type: Easing.OutCubic } }
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

    // video marker: a paper plate with an ink triangle, never a circled play.
    Rectangle {
        visible: cell.isVideo && !vout.visible
        anchors.centerIn: parent
        width: 26; height: 20
        radius: Tokens.radius
        color: Tokens.paper
        border.width: Tokens.border
        border.color: Tokens.line
        // a triangle drawn as a glyph so it stays crisp and mono.
        Text {
            anchors.centerIn: parent
            text: "▶"
            color: Tokens.ink
            font.pixelSize: 10
        }
    }

    // resolution badge: a solid paper plate, mono. A low-res pick inverts to bone
    // and says so (amendment 5): inversion is the emphasis, a warning is emphasis.
    Rectangle {
        visible: cell.resText.length > 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 6
        height: 16
        width: resLabel.implicitWidth + 10
        radius: Tokens.radius
        color: cell.lowRes ? Tokens.bone : Tokens.paper
        border.width: Tokens.border
        border.color: cell.lowRes ? Tokens.bone : Tokens.line
        Text {
            id: resLabel
            anchors.centerIn: parent
            text: {
                var base = cell.resH >= 2160 ? "4K" : (cell.resH > 0 ? cell.resH + "P" : cell.resText.toUpperCase());
                return cell.lowRes ? base + " · SOFT" : base;
            }
            color: cell.lowRes ? Tokens.inkOnBone : Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: 9
        }
    }

    // the picked tile: a corner ink dot, the gallery grammar. No tick, no frame.
    Rectangle {
        visible: cell.active
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 6; height: 6; radius: 3
        color: Tokens.ink
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => { if (e.button === Qt.RightButton) cell.opened(); else cell.picked(); }
    }

    // selection checkbox (Local source): a hairline square, bone-filled with a
    // black check when marked. It sits above the pick MouseArea so a tap here
    // marks instead of previewing.
    Rectangle {
        visible: cell.selectable
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 6
        width: 16; height: 16
        radius: Tokens.radius
        color: cell.selected ? Tokens.bone : Tokens.paper
        border.width: Tokens.border
        border.color: cell.selected ? Tokens.bone : Tokens.line
        Text {
            anchors.centerIn: parent
            visible: cell.selected
            text: "✓"
            color: Tokens.inkOnBone
            font.family: Tokens.ui
            font.pixelSize: 10
            font.weight: Font.Bold
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cell.toggledSelect() }
    }
}
