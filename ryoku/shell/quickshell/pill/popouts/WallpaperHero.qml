import QtQuick
import QtMultimedia

// The current wallpaper, shown as the power panel's hero: a still image renders
// straight, a live clip plays muted-and-looping through QtMultimedia over its own
// extracted still. The lone splash of colour on a bone-on-black blob, and the
// reason it earns the room: it is data (the desktop's skin).
//
// Performance: the video decoder is the one heavy thing, so it is armed only a
// beat AFTER the open animation settles (Motion.spatial is 500ms) -- QtMultimedia's
// cold start never janks the reveal, the poster covers the gap -- and it is
// dropped the instant the popout closes, so a closed popout holds no decoder and
// does no decode work.
Item {
    id: root

    property string path: ""
    property bool isVideo: false
    property string poster: ""
    property bool active: false   // the popout is open (or animating open/closed)

    // a live clip is presenting frames: the poster can fade out beneath it.
    readonly property bool videoReady: clip.item ? clip.item.videoReady : false

    // ── still image wallpaper ──────────────────────────────────────────────
    Image {
        anchors.fill: parent
        visible: !root.isVideo
        source: (!root.isVideo && root.path.length) ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    // ── live wallpaper: poster (instant) + decoder (deferred) ────────────────
    Image {
        id: posterImg
        anchors.fill: parent
        visible: root.isVideo
        source: (root.isVideo && root.poster.length) ? "file://" + root.poster : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: root.videoReady ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    property bool videoArmed: false
    onActiveChanged: {
        if (root.active)
            settle.restart();
        else {
            settle.stop();
            root.videoArmed = false;
        }
    }
    Timer { id: settle; interval: 520; onTriggered: root.videoArmed = root.active }
    Loader {
        id: clip
        anchors.fill: parent
        active: root.videoArmed && root.isVideo && root.path.length > 0
        sourceComponent: Item {
            readonly property bool videoReady: player.playbackState === MediaPlayer.PlayingState && player.hasVideo
            MediaPlayer {
                id: player
                source: "file://" + root.path
                loops: MediaPlayer.Infinite
                videoOutput: vout
                audioOutput: AudioOutput { muted: true }
                Component.onCompleted: play()
            }
            VideoOutput {
                id: vout
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                opacity: parent.videoReady ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }
    }
}
