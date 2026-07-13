import QtQuick
import QtMultimedia

// The live preview for the picked video cell. Its own file so the grid only
// spins up QtMultimedia (and a decode pipeline) when a clip actually plays, not
// once per thumbnail. Loops muted and starts as soon as it loads.
Item {
    id: root
    property string path
    // true once the clip is actually presenting frames, so the cell can fade its
    // still thumbnail out underneath instead of leaving a photo peeking around
    // the video.
    readonly property bool ready: player.playbackState === MediaPlayer.PlayingState && player.hasVideo

    MediaPlayer {
        id: player
        source: root.path.length > 0 ? "file://" + root.path : ""
        loops: MediaPlayer.Infinite
        videoOutput: vout
        audioOutput: AudioOutput { muted: true }
        onSourceChanged: source.toString().length > 0 ? play() : stop()
    }
    VideoOutput {
        id: vout
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
