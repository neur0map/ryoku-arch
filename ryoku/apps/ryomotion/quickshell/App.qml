pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

// Ryoku Motion editor: record or open a screen clip, then shape it live -- frame
// it on a background (the Beautify look), place cursor-follow or manual zooms,
// cut + re-speed spans, drop text, add music, and export MP4/GIF. A tool rail on
// the left drives a contextual panel; the centre is a true WYSIWYG stage; the
// timeline holds the region tracks. Warm-dark Ryoku palette, borumi-soft.
Item {
    id: app
    focus: true

    // static backdrop (no per-frame Canvas -> no drag-repaint glitch).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgTop }
            GradientStop { position: 1.0; color: Theme.bgBot }
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space && Project.hasClip) {
            Project.playing ? stage.player.pause() : stage.player.play();
            e.accepted = true;
        }
    }

    // ============================ top bar ============================
    Rectangle {
        id: bar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 54
        color: Theme.bgTop

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hair }

        Image {
            id: logo
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("logo.svg")
            sourceSize.height: 26
            fillMode: Image.PreserveAspectFit
        }
        Column {
            anchors.left: logo.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text { text: "Ryoku Motion"; color: Theme.bright; font.family: Theme.display; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text {
                text: Project.hasClip ? Project.clipPath.split("/").pop() : "screen demo editor"
                color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                elide: Text.ElideRight; width: 320
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            TopBtn {
                label: "Open"
                onTapped: openSheet.open = true
            }
            TopBtn {
                label: Project.recording ? "Stop" : "Record"
                accent: true
                accentColor: Project.recording ? Theme.bad : Theme.ember
                onTapped: Project.recording ? Project.stopRecord() : Project.record(false)
            }
        }
    }

    // ============================ body ============================
    Rectangle {
        id: rail
        anchors.top: bar.bottom
        anchors.left: parent.left
        anchors.bottom: timeline.top
        width: 74
        color: "transparent"
        Rail { anchors.fill: parent }
    }

    Rectangle {
        id: inspectorPane
        anchors.top: bar.bottom
        anchors.left: rail.right
        anchors.bottom: timeline.top
        width: 258
        color: Theme.panelLo
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.hair }
        Inspector { anchors.fill: parent }
    }

    Stage {
        id: stage
        anchors.top: bar.bottom
        anchors.left: inspectorPane.right
        anchors.right: parent.right
        anchors.bottom: timeline.top
        anchors.margins: 20
    }

    // render progress veil
    Rectangle {
        anchors.fill: stage
        visible: Project.rendering
        color: Qt.rgba(0, 0, 0, 0.5)
        Column {
            anchors.centerIn: parent
            spacing: 12
            Text { text: "Rendering " + Project.format.toUpperCase() + "…"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 15; anchors.horizontalCenter: parent.horizontalCenter }
            Rectangle {
                width: 220; height: 6; radius: 3; color: Theme.field
                Rectangle { width: parent.width * Project.renderProgress; height: parent.height; radius: 3; color: Theme.ember }
            }
        }
    }

    // ============================ timeline ============================
    Timeline {
        id: timeline
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 250
        stagePlayer: stage.player
    }
    OpenSheet { id: openSheet }

}
