pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtMultimedia
import RyoMotion

// The live stage: QtMultimedia renders the video; QML applies the effects live
// (zoom as a Scale transform about the focus point, captions as text overlays)
// and frames it on the background with padding, rounded corners, shadow and
// border. The same numbers drive the ffmpeg export, so preview matches output.
// Editing handles (zoom focus, text, overlay) sit on top for direct dragging.
Item {
    id: stage

    readonly property real vAspect: {
        var s = vout.sourceRect;
        return (s && s.width > 0 && s.height > 0) ? s.width / s.height : 16 / 9;
    }
    readonly property real canvasAR: {
        var a = Project.aspectRatios[Project.aspect];
        return a > 0 ? a : vAspect;
    }
    readonly property real fitW: Math.min(width, height * canvasAR)
    readonly property real fitH: Math.min(height, width / canvasAR)

    MediaPlayer {
        id: mp
        property bool primed: false
        property bool priming: false
        source: Project.clipUrl
        videoOutput: vout
        // the clip's own audio (screen recordings have none); muted through the
        // one-frame load prime so opening a clip never blips.
        audioOutput: AudioOutput { volume: 1.0; muted: mp.priming }
        onSourceChanged: primed = false
        onDurationChanged: if (duration > 0) Project.durationMs = duration
        // decode one frame on load so the paused preview shows frame 0, not black
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia && !primed) { primed = true; priming = true; play(); primeT.start(); }
        onPlaybackStateChanged: {
            Project.playing = (playbackState === MediaPlayer.PlayingState);
            stage.syncMusic(true);
        }
        onPositionChanged: {
            var cut = Project.cutAt(position);
            if (cut) { mp.setPosition(cut.endMs); return; }   // skip removed spans
            Project.positionMs = position;
            var sp = Project.speedAt(position);
            if (Math.abs(sp - mp.playbackRate) > 0.01)
                mp.playbackRate = sp;
            stage.syncMusic(false);
        }
    }
    // background music, positioned on the timeline: it plays only within its
    // [start, end] window, offset to the playhead. Baked for real at export.
    MediaPlayer {
        id: musicMp
        source: Project.musicPath ? "file://" + Project.musicPath : ""
        audioOutput: AudioOutput { volume: Project.musicVolume }
    }
    function syncMusic(reseek) {
        if (mp.priming || Project.musicPath === "" || mp.playbackState !== MediaPlayer.PlayingState) { musicMp.pause(); return; }
        var start = Project.musicStartMs;
        var end = Project.musicEndMs > 0 ? Project.musicEndMs : Project.durationMs;
        if (mp.position >= start && mp.position < end) {
            if (reseek || musicMp.playbackState !== MediaPlayer.PlayingState) {
                musicMp.setPosition(Math.max(0, mp.position - start));
                musicMp.play();
            }
        } else {
            musicMp.pause();
        }
    }
    Timer { id: primeT; interval: 60; onTriggered: { mp.pause(); mp.setPosition(0); mp.priming = false; } }
    // UI talks to Project; Stage owns the players and keeps the music in sync.
    Connections {
        target: Project
        function onPlayRequested() { mp.play(); }
        function onPauseRequested() { mp.pause(); }
        function onSeekRequested(ms) { mp.setPosition(ms); stage.syncMusic(true); }
    }

    Item {
        id: canvas
        width: stage.fitW
        height: stage.fitH
        anchors.centerIn: parent

        // background
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

        readonly property real pad: Project.padding * Math.min(width, height)
        readonly property real dispScale: (width - 2 * pad) / 1280

        // soft drop shadow behind the video box
        Rectangle {
            x: box.x; y: box.y + 8 * canvas.dispScale
            width: box.width; height: box.height
            radius: Project.roundness * canvas.dispScale
            color: "#000000"
            visible: Project.shadow > 0
            opacity: Project.shadow
            layer.enabled: Project.shadow > 0
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 48 }
        }

        Item {
            id: box
            x: canvas.pad; y: canvas.pad
            width: canvas.width - 2 * canvas.pad
            height: canvas.height - 2 * canvas.pad
            clip: true                                   // contain the zoomed video
            layer.enabled: Project.roundness > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskRect
                maskThresholdMin: 0.5
            }

            // live zoom: recompute on playhead move or region edit
            readonly property var zt: {
                Project.zooms; Project.positionMs;       // deps
                return Project.zoomAt(Project.positionMs);
            }

            VideoOutput {
                id: vout
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                transform: Scale {
                    origin.x: box.width * box.zt.cx
                    origin.y: box.height * box.zt.cy
                    xScale: box.zt.scale
                    yScale: box.zt.scale
                }
            }

            // captions, baked live at their normalized positions
            Repeater {
                model: {
                    Project.texts; Project.positionMs;
                    return Project.textsAt(Project.positionMs);
                }
                delegate: Text {
                    required property var modelData
                    text: modelData.text
                    color: modelData.color
                    font.family: Theme.font
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.max(8, modelData.size * box.height)
                    x: modelData.x * box.width - implicitWidth / 2
                    y: modelData.y * box.height - implicitHeight / 2
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                }
            }
        }

        Rectangle {
            id: maskRect
            x: box.x; y: box.y; width: box.width; height: box.height
            visible: false
            layer.enabled: true
            radius: Project.roundness * canvas.dispScale
            color: "black"
        }
        Rectangle {
            x: box.x; y: box.y; width: box.width; height: box.height
            color: "transparent"
            radius: Project.roundness * canvas.dispScale
            border.width: Project.borderW * canvas.dispScale
            border.color: Project.borderColor
            visible: Project.borderW > 0
        }

        // --- zoom focus handle (drag to aim the zoom on the preview) ---
        Rectangle {
            id: focusDot
            readonly property var reg: Project.selKind === "zoom" ? Project.selected() : null
            visible: reg !== null
            width: 22; height: 22; radius: 11
            color: "transparent"
            border.width: 2.5; border.color: Theme.ember
            x: box.x + (reg ? reg.cx : 0.5) * box.width - width / 2
            y: box.y + (reg ? reg.cy : 0.5) * box.height - height / 2
            Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.ember }
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                cursorShape: Qt.SizeAllCursor
                onPositionChanged: (m) => {
                    if (!pressed || !focusDot.reg) return;
                    var p = mapToItem(box, m.x, m.y);
                    Project.updateSel({ cx: Math.max(0, Math.min(1, p.x / box.width)), cy: Math.max(0, Math.min(1, p.y / box.height)) });
                }
            }
        }

        // --- text handle (drag to place the caption) ---
        Rectangle {
            id: textHandle
            readonly property var reg: Project.selKind === "text" ? Project.selected() : null
            visible: reg !== null
            color: Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.18)
            border.width: 1.5; border.color: Theme.gold
            radius: 4
            width: Math.max(60, box.width * 0.3); height: Math.max(24, box.height * (reg ? reg.size : 0.06) * 1.6)
            x: box.x + (reg ? reg.x : 0.5) * box.width - width / 2
            y: box.y + (reg ? reg.y : 0.15) * box.height - height / 2
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPositionChanged: (m) => {
                    if (!pressed || !textHandle.reg) return;
                    var p = mapToItem(box, m.x, m.y);
                    Project.updateSel({ x: Math.max(0, Math.min(1, p.x / box.width)), y: Math.max(0, Math.min(1, p.y / box.height)) });
                }
            }
        }

        // --- overlay handle (drag to place clip-in-clip) ---
        Rectangle {
            id: ovHandle
            readonly property var reg: Project.selKind === "overlay" ? Project.selected() : null
            visible: reg !== null
            color: "transparent"
            border.width: 2; border.color: "#4facfe"
            radius: 6
            width: box.width * (reg ? reg.scale : 0.34)
            height: width * 9 / 16
            x: box.x + (reg ? reg.x : 0.72) * box.width - width / 2
            y: box.y + (reg ? reg.y : 0.72) * box.height - height / 2
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPositionChanged: (m) => {
                    if (!pressed || !ovHandle.reg) return;
                    var p = mapToItem(box, m.x, m.y);
                    Project.updateSel({ x: Math.max(0, Math.min(1, p.x / box.width)), y: Math.max(0, Math.min(1, p.y / box.height)) });
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
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 15
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
