pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import ".."
import qs.components
import qs.components.controls
import qs.services

// RYOKU: draggable gaming-overlay widget exposing screen-recording controls and
// a screenshot button. Reuses the shared Recorder service (gpu-screen-recorder
// via ryoku-cmd-screenrecord) for record / pause / stop, and the area-picker IPC
// (target "picker", openFreeze) for screenshots so nothing is reimplemented.
OverlayWidget {
    id: root

    widgetId: "recorder"

    StyledRect {
        anchors.fill: parent

        implicitWidth: row.implicitWidth + Tokens.padding.large * 2
        implicitHeight: row.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3surface, 0.7)

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            // Record / Stop. Starts a fullscreen recording with desktop audio
            // when idle, stops the active recording otherwise.
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Recorder.running ? "stop" : "screen_record"
                font.pointSize: Tokens.font.size.large
                inactiveColour: Recorder.running ? Colours.palette.m3error : Colours.palette.m3primary
                inactiveOnColour: Recorder.running ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                onClicked: {
                    if (Recorder.running)
                        Recorder.stop();
                    else
                        Recorder.start(["--fullscreen", "--with-desktop-audio"]);
                }
            }

            // Pause / Resume. Only meaningful while a recording is active.
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Recorder.running
                label.animate: true
                icon: Recorder.paused ? "play_arrow" : "pause"
                toggle: true
                checked: Recorder.paused
                type: IconButton.Tonal
                font.pointSize: Tokens.font.size.large
                onClicked: {
                    Recorder.togglePause();
                    internalChecked = Recorder.paused;
                }
            }

            // Elapsed time, formatted from the service's seconds counter.
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: Recorder.running
                font.family: Tokens.font.family.mono
                text: {
                    const elapsed = Recorder.elapsed;
                    const hours = Math.floor(elapsed / 3600);
                    const mins = Math.floor((elapsed % 3600) / 60);
                    const secs = Math.floor(elapsed % 60).toString().padStart(2, "0");
                    if (hours > 0)
                        return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
                    return `${mins}:${secs}`;
                }
            }

            // Screenshot. Delegates to the area-picker (freeze mode) over IPC.
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "screenshot_region"
                type: IconButton.Tonal
                font.pointSize: Tokens.font.size.large
                onClicked: Quickshell.execDetached(["sh", "-lc", "$HOME/.local/bin/ryoku-shell ipc picker openFreeze"])
            }
        }
    }
}
