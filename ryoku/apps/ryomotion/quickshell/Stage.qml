pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtMultimedia
import "Singletons"

// The live preview: the recording framed on its background exactly as it will
// export. The video sits in a "camera" that scales + pans LIVE to follow the
// active zoom region at the current playhead (mirrors the ffmpeg crop-zoom), so
// every look/zoom/text change is visible immediately, not just on render.
Item {
    id: stage

    property alias player: mp
    readonly property real vAspect: mp.metaData !== null && vout.sourceRect.height > 0
        ? vout.sourceRect.width / vout.sourceRect.height : 16 / 9

    // the canvas (bg + video) takes the chosen aspect, centred + letterboxed
    // in whatever room the stage has.
    readonly property real canvasAR: {
        var a = Project.aspectRatios[Project.aspect];
        return a > 0 ? a : vAspect;
    }
    readonly property real _fitW: Math.min(width, height * canvasAR)
    readonly property real _fitH: Math.min(height, width / canvasAR)

    MediaPlayer {
        id: mp
        videoOutput: vout
        source: Project.clipPath ? "file://" + Project.clipPath : ""
        onDurationChanged: Project.durationMs = duration
        onPositionChanged: if (!seekGuard.running) Project.positionMs = position
        onPlaybackStateChanged: Project.playing = (playbackState === MediaPlayer.PlayingState)
    }
    // while the user scrubs the timeline we drive the player, not the reverse.
    Timer { id: seekGuard; interval: 120 }
    Connections {
        target: Project
        function onPositionMsChanged() {
            if (Math.abs(Project.positionMs - mp.position) > 40) {
                seekGuard.restart();
                mp.position = Project.positionMs;
            }
        }
    }

    // ---------- the framed canvas ----------
    Item {
        id: canvas
        width: stage._fitW
        height: stage._fitH
        anchors.centerIn: parent

        // background (gradient / solid / image), ported from Beautify.
        Rectangle {
            anchors.fill: parent
            visible: Project.bgKind !== "image"
            gradient: Project.bgKind === "gradient" ? grad : null
            color: Project.bgKind === "solid" ? Project.bgSolid : "transparent"
            Gradient {
                id: grad
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Project.bgA }
                GradientStop { position: 1.0; color: Project.bgB }
            }
        }
        Image {
            anchors.fill: parent
            visible: Project.bgKind === "image" && Project.bgImage !== ""
            source: Project.bgImage ? "file://" + Project.bgImage : ""
            fillMode: Image.PreserveAspectCrop
        }

        // the video box: canvas inset by padding.
        readonly property real pad: Project.padding * Math.min(width, height)
        readonly property real dispScale: (width - 2 * pad) / 1280

        Item {
            id: box
            x: canvas.pad; y: canvas.pad
            width: canvas.width - 2 * canvas.pad
            height: canvas.height - 2 * canvas.pad

            // live zoom transform (scale + pan to focus, clamped to edges).
            readonly property var zt: Project.zoomAt(Project.positionMs)
            readonly property real zs: zt.scale
            readonly property real tx: Math.max(width - width * zs, Math.min(0, width / 2 - zt.cx * width * zs))
            readonly property real ty: Math.max(height - height * zs, Math.min(0, height / 2 - zt.cy * height * zs))

            VideoOutput {
                id: vout
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                visible: false          // rendered through the effect below
                transform: [
                    Scale { xScale: box.zs; yScale: box.zs },
                    Translate { x: box.tx; y: box.ty }
                ]
            }
            // rounded corners + drop shadow in one pass (cheap, no Canvas).
            MultiEffect {
                anchors.fill: vout
                source: vout
                maskEnabled: Project.roundness > 0
                maskSource: maskRect
                maskThresholdMin: 0.5
                shadowEnabled: Project.shadow > 0
                shadowBlur: 1.0
                shadowColor: Qt.rgba(0, 0, 0, Project.shadow)
                shadowVerticalOffset: 10 * canvas.dispScale
                shadowHorizontalOffset: 0
                autoPaddingEnabled: true
            }
            Rectangle {
                id: maskRect
                anchors.fill: parent
                visible: false
                layer.enabled: true
                radius: Math.min(width, height) / 2 * 0 + Project.roundness * canvas.dispScale
                color: "black"
            }
            // border, if any.
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Project.roundness * canvas.dispScale
                border.width: Project.borderW * canvas.dispScale
                border.color: Project.borderColor
                visible: Project.borderW > 0
            }
        }

        // ---------- live text overlays ----------
        Repeater {
            model: Project.textsAt(Project.positionMs)
            delegate: Text {
                required property var modelData
                x: canvas.width * modelData.x - width / 2
                y: canvas.height * modelData.y - height / 2
                text: modelData.text
                color: modelData.color
                font.family: Theme.fontJp
                font.pixelSize: Math.round(Math.max(8, canvas.height * modelData.size))
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        // ---------- live video overlays (clip-in-clip) ----------
        Repeater {
            model: Project.overlays
            delegate: Item {
                id: ov
                required property var modelData
                readonly property real ar: ovout.sourceRect.width > 0 ? ovout.sourceRect.width / ovout.sourceRect.height : 16 / 9
                width: canvas.width * modelData.scale
                height: width / ar
                x: canvas.width * modelData.x - width / 2
                y: canvas.height * modelData.y - height / 2
                visible: Project.positionMs >= modelData.startMs && Project.positionMs <= modelData.endMs
                onVisibleChanged: visible ? omp.play() : omp.pause()
                MediaPlayer {
                    id: omp
                    source: "file://" + ov.modelData.path
                    videoOutput: ovout
                    loops: MediaPlayer.Infinite
                }
                VideoOutput { id: ovout; anchors.fill: parent }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 6
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.75)
                }
            }
        }
    }

    // empty state
    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: !Project.hasClip
        Icon { name: "film"; size: 44; tint: Theme.dim; anchors.horizontalCenter: parent.horizontalCenter }
        Text {
            text: "Record a demo or open a clip"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 15
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
