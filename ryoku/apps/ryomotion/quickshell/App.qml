pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import "Singletons"

// Ryoku Motion editor: record or open a screen clip, frame it on a gradient
// background (the Beautify look), let cursor-follow zoom do the rest, and export.
// Layout mirrors borumi -- a big framed canvas, a soft control panel, one
// friendly timeline -- in Ryoku's warm-dark palette.
Item {
    id: app
    focus: true

    readonly property real durS: Project.durationMs / 1000
    readonly property real posFrac: Project.durationMs > 0 ? Project.positionMs / Project.durationMs : 0

    function fmtTime(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        return (Math.floor(s / 60)) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }

    // ============================ backdrop ============================
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgTop }
            GradientStop { position: 1.0; color: Theme.bgBot }
        }
    }
    Canvas {
        anchors.fill: parent
        opacity: 0.5
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = "rgba(245, 239, 228, 0.035)";
            ctx.lineWidth = 1;
            for (var x = 0; x <= width; x += 34) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
            for (var y = 0; y <= height; y += 34) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke(); }
        }
        Component.onCompleted: requestPaint()
    }

    // ============================ media ============================
    MediaPlayer {
        id: player
        source: Project.hasClip ? Qt.resolvedUrl("file://" + Project.clipPath) : ""
        videoOutput: vout
        loops: MediaPlayer.Infinite
        onDurationChanged: Project.durationMs = duration
        onPositionChanged: Project.positionMs = position
    }

    // ============================ top bar ============================
    Rectangle {
        id: topbar
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 56
        color: Theme.panel
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.hair }

        Row {
            anchors.left: parent.left; anchors.leftMargin: 22; anchors.verticalCenter: parent.verticalCenter
            spacing: 11
            Text { anchors.verticalCenter: parent.verticalCenter; text: "\u529b"; color: Theme.ember; font.family: Theme.fontJp; font.pixelSize: 22; font.weight: Font.Bold }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Ryoku Motion"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text { anchors.verticalCenter: parent.verticalCenter; text: Project.recording ? "recording\u2026" : (Project.rendering ? "exporting\u2026" : "screen demos, framed"); color: Project.recording ? Theme.ember : Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            TopBtn { label: Project.recording ? "Stop" : "Record"; accent: Project.recording; onTapped: Project.recording ? Project.stopRecord() : Project.record(true) }
            TopBtn { label: "Open"; onTapped: openProc.running = true }
        }
    }

    // ============================ right panel ============================
    Rectangle {
        id: panel
        anchors.right: parent.right; anchors.top: topbar.bottom; anchors.bottom: parent.bottom
        width: 322
        color: Theme.panel
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: Theme.hair }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.leftMargin: 22; anchors.rightMargin: 16; anchors.topMargin: 20; anchors.bottomMargin: 18
            contentHeight: col.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: sb; policy: QQC.ScrollBar.AsNeeded; width: 7
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.idle; opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4) }
            }

            Column {
                id: col
                width: flick.width
                spacing: 22

                Group {
                    title: "BACKGROUND"
                    Grid {
                        width: parent.width; columns: 5; columnSpacing: 8; rowSpacing: 8
                        Repeater {
                            model: Project.presets
                            Rectangle {
                                required property int index
                                required property var modelData
                                width: (parent.width - 4 * 8) / 5; height: 30; radius: Theme.radiusSm
                                readonly property bool sel: Project.bgKind === "gradient" && Project.bgPreset === index
                                border.color: sel ? "#ffffff" : Theme.hair
                                border.width: sel ? 2 : 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: modelData.a }
                                    GradientStop { position: 1.0; color: modelData.b }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Project.bgKind = "gradient"; Project.bgPreset = index; } }
                            }
                        }
                    }
                    Segmented {
                        width: parent.width
                        options: ["Gradient", "Solid"]
                        current: Project.bgKind === "solid" ? 1 : 0
                        onPicked: (i) => Project.bgKind = (i === 1 ? "solid" : "gradient")
                    }
                }

                Group {
                    title: "FRAME"
                    Slider { width: parent.width; label: "Padding"; from: 0; to: 0.18; decimals: 2; value: Project.padding; onMoved: (v) => Project.padding = v }
                    Slider { width: parent.width; label: "Roundness"; from: 0; to: 48; value: Project.roundness; onMoved: (v) => Project.roundness = v }
                    Slider { width: parent.width; label: "Shadow"; from: 0; to: 1; decimals: 2; value: Project.shadow; onMoved: (v) => Project.shadow = v }
                }

                Group {
                    title: "MOTION"
                    Item {
                        width: parent.width; height: 26
                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Cursor-follow zoom"; color: Theme.idle; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                        Toggle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: Project.zoomEnabled; onToggled: (v) => Project.zoomEnabled = v }
                    }
                    Slider { width: parent.width; label: "Zoom depth"; from: 1; to: 6; value: Project.zoomDepth; suffix: "  \u00d7" + Project.depthScale.toFixed(2); onMoved: (v) => Project.zoomDepth = Math.round(v) }
                    Slider { width: parent.width; label: "Speed"; from: 0.5; to: 3; decimals: 1; suffix: "\u00d7"; value: Project.speed; onMoved: (v) => Project.speed = v }
                }

                Group {
                    title: "EXPORT"
                    Segmented {
                        width: parent.width
                        options: ["MP4", "GIF"]
                        current: Project.format === "gif" ? 1 : 0
                        onPicked: (i) => Project.format = (i === 1 ? "gif" : "mp4")
                    }
                    TopBtn {
                        width: parent.width
                        label: Project.rendering ? "Exporting\u2026" : "Export " + (Project.format === "gif" ? "GIF" : "MP4")
                        accent: true
                        on: Project.hasClip && !Project.rendering
                        onTapped: Project.exportVideo(Project.format)
                    }
                    Text {
                        width: parent.width; visible: Project.lastExport !== ""
                        text: "Saved: " + Project.lastExport.replace(/^.*\//, "")
                        color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11; elide: Text.ElideMiddle
                    }
                }
            }
        }
    }

    // ============================ timeline ============================
    Rectangle {
        id: timeline
        anchors.left: parent.left; anchors.right: panel.left; anchors.bottom: parent.bottom
        height: 92
        color: Theme.panelLo
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.hair }

        Row {
            id: transport
            anchors.left: parent.left; anchors.leftMargin: 22; anchors.top: parent.top; anchors.topMargin: 16
            spacing: 14
            Rectangle {
                width: 34; height: 34; radius: 17
                color: playMa.containsMouse ? Theme.fieldHi : Theme.field
                border.width: 1; border.color: Theme.hair
                Text {
                    anchors.centerIn: parent
                    text: player.playbackState === MediaPlayer.PlayingState ? "\u23f8" : "\u25b6"
                    color: Theme.bright; font.pixelSize: 14
                }
                MouseArea {
                    id: playMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: app.fmtTime(Project.positionMs) + " / " + app.fmtTime(Project.durationMs)
                color: Theme.idle; font.family: Theme.mono; font.pixelSize: 12
            }
        }

        // scrub + trim bar
        Item {
            id: bar
            anchors.left: transport.right; anchors.leftMargin: 20
            anchors.right: parent.right; anchors.rightMargin: 22
            anchors.verticalCenter: transport.verticalCenter
            height: 34
            Rectangle {
                id: track
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                height: 22; radius: 6; color: Theme.field; border.width: 1; border.color: Theme.hair
                // trimmed-out shading
                Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; width: (Project.durationMs > 0 ? Project.trimStartMs / Project.durationMs : 0) * parent.width; color: Qt.rgba(0, 0, 0, 0.4) }
                Rectangle { anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; width: (Project.durationMs > 0 && Project.trimEndMs > 0 ? (Project.durationMs - Project.trimEndMs) / Project.durationMs : 0) * parent.width; color: Qt.rgba(0, 0, 0, 0.4) }
                // playhead
                Rectangle { width: 2; height: parent.height + 8; y: -4; x: Math.max(0, Math.min(parent.width - 2, app.posFrac * parent.width)); color: Theme.ember }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; preventStealing: true
                enabled: Project.hasClip
                function seek(mx) { var f = Math.max(0, Math.min(1, mx / width)); player.position = f * Project.durationMs; }
                onPressed: (e) => seek(e.x)
                onPositionChanged: (e) => { if (pressed) seek(e.x); }
            }
        }
    }

    // ============================ canvas (framed preview) ============================
    Item {
        id: canvas
        anchors.left: parent.left; anchors.top: topbar.bottom; anchors.right: panel.left; anchors.bottom: timeline.top

        // empty state
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: !Project.hasClip
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\u529b"; color: Theme.ember; font.family: Theme.fontJp; font.pixelSize: 46; font.weight: Font.Bold; opacity: 0.9 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Record your screen, or open a clip"; color: Theme.cream; font.family: Theme.display; font.pixelSize: 20 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12; topPadding: 4
                TopBtn { label: "Record a demo"; accent: true; onTapped: Project.record(true) }
                TopBtn { label: "Open a clip"; onTapped: openProc.running = true }
            }
        }

        // framed video
        Item {
            id: stage
            anchors.centerIn: parent
            visible: Project.hasClip
            readonly property real ar: vout.sourceRect.height > 0 ? vout.sourceRect.width / vout.sourceRect.height : 1.7778
            readonly property real avail: Math.min(canvas.width - 80, (canvas.height - 80) * ar)
            width: Math.max(120, avail)
            height: width / ar
            readonly property real padPx: Math.max(width, height) * Project.padding
            readonly property real rPx: vout.sourceRect.width > 0 ? Project.roundness * (vout.width / vout.sourceRect.width) : Project.roundness * 0.5

            // background
            Rectangle {
                anchors.fill: parent
                radius: 10
                clip: true
                Rectangle {
                    visible: Project.bgKind !== "solid"
                    anchors.centerIn: parent
                    width: Math.max(parent.width, parent.height) * 1.5; height: width
                    rotation: Project.bgAngle - 90
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Project.bgA }
                        GradientStop { position: 1.0; color: Project.bgB }
                    }
                }
                Rectangle { visible: Project.bgKind === "solid"; anchors.fill: parent; color: Project.bgSolid }
            }

            // shadow under the video
            Rectangle {
                x: stage.padPx; y: stage.padPx + 6
                width: parent.width - 2 * stage.padPx; height: parent.height - 2 * stage.padPx
                radius: stage.rPx
                color: "#000000"; visible: Project.shadow > 0; opacity: Project.shadow
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 28; autoPaddingEnabled: true }
            }

            // the video, rounded
            VideoOutput {
                id: vout
                x: stage.padPx; y: stage.padPx
                width: parent.width - 2 * stage.padPx; height: parent.height - 2 * stage.padPx
                fillMode: VideoOutput.Stretch
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: voutMask }
            }
            Rectangle {
                id: voutMask
                x: stage.padPx; y: stage.padPx
                width: parent.width - 2 * stage.padPx; height: parent.height - 2 * stage.padPx
                radius: stage.rPx; visible: false; layer.enabled: true
            }

            // auto-zoom badge
            Rectangle {
                visible: Project.zoomEnabled
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: stage.padPx + 6
                width: zl.implicitWidth + 18; height: 24; radius: 12
                color: Qt.rgba(0, 0, 0, 0.45)
                Text { id: zl; anchors.centerIn: parent; text: "\u2318 auto-zoom"; color: "#ffffff"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium }
            }
        }
    }

    // ============================ open dialog ============================
    Process {
        id: openProc
        command: ["sh", "-c",
            "zenity --file-selection --title='Open a clip' --file-filter='Video | *.mp4 *.mkv *.webm *.mov' 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { var p = this.text.trim(); if (p) Project.openClip(p); } }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space) { player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play(); e.accepted = true; }
    }
}
