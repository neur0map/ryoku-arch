pragma ComponentBehavior: Bound
import QtQuick
import RyoMotion

// Ryoku Motion editor: record or open a clip, shape it live on the stage
// (framing, zoom, cut, speed, text, overlay), export MP4/GIF. The preview
// (QtMultimedia + QML effects) and the ffmpeg export share the same numbers,
// so what you see is what you get.
Window {
    id: win
    visible: true
    width: 1320
    height: 860
    color: Theme.bgBot
    title: "Ryoku Motion"

    function doOpen(url) {
        Project.openClip(url);
        Backend.probe(Project.clipPath);
    }
    function doExport() {
        var out = Backend.videosDir() + "/export_" + Date.now() + "." + Project.format;
        Backend.exportVideo(Project.projectJson(Project.format), out);
    }

    Component.onCompleted: if (typeof startupClip !== "undefined" && startupClip.length > 0) doOpen("file://" + startupClip)

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgTop }
            GradientStop { position: 1.0; color: Theme.bgBot }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Space && Project.hasClip) { Project.togglePlay(); e.accepted = true; }
        }
    }

    // top bar
    Rectangle {
        id: bar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54
        color: Theme.bgTop
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hair }

        Text {
            id: logo
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "力"; color: Theme.ember; font.family: Theme.fontJp; font.pixelSize: 24; font.weight: Font.Bold
        }
        Column {
            anchors { left: logo.right; leftMargin: 11; verticalCenter: parent.verticalCenter }
            spacing: 0
            Text { text: "Ryoku Motion"; color: Theme.bright; font.family: Theme.display; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { text: Project.hasClip ? Backend.basename(Project.clipPath) : "screen demo editor"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight; width: 320 }
        }
        Row {
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 8
            TopBtn { label: "Open"; onTapped: openSheet.open = true }
            TopBtn {
                label: Backend.recording ? "Stop" : "Record"
                accent: true
                accentColor: Backend.recording ? Theme.bad : Theme.ember
                onTapped: Backend.recording ? Backend.stopRecord() : Backend.record(false)
            }
        }
    }

    Rail {
        id: rail
        anchors { top: bar.bottom; left: parent.left; bottom: timeline.top }
    }
    Rectangle {
        id: inspectorPane
        anchors { top: bar.bottom; left: rail.right; bottom: timeline.top }
        width: 258
        color: Theme.panelLo
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.hair }
        Inspector { anchors.fill: parent; onExportRequested: win.doExport() }
    }
    Stage {
        id: stage
        anchors { top: bar.bottom; left: inspectorPane.right; right: parent.right; bottom: timeline.top; margins: 20 }
    }
    Rectangle {
        anchors.fill: stage
        visible: Project.rendering
        color: Qt.rgba(0, 0, 0, 0.5)
        Text { anchors.centerIn: parent; text: "Rendering " + Project.format.toUpperCase() + "…"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 15 }
    }
    Timeline {
        id: timeline
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 250
    }
    OpenSheet {
        id: openSheet
        onChosen: (u) => win.doOpen(u)
    }

    // ---- wiring ----
    Connections {
        target: Backend
        function onProbed(durationMs, hasCursor) { Project.hasCursor = hasCursor; }
        function onRecorded(clip) { win.doOpen("file://" + clip); }
        function onRenderingChanged() { Project.rendering = Backend.rendering; }
        function onExportDone(ok, path) { if (ok) Project.lastExport = path; }
    }
}
