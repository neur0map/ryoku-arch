import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland
import QtQuick
import QtQuick.Layouts

// Compact music indicator: subtle gradient pill + CAVA waveform. The full
// title / artist / album live in the hover tooltip + the media controls
// popup that opens on left-click. Keeps the idle bar from getting bloated
// by a scrolling marquee.
Item {
    id: root
    implicitWidth: content.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colPrimary: Appearance.ryokuEverywhere
        ? (Appearance.ryoku.colPrimary ?? Appearance.colors.colPrimary)
        : Appearance.colors.colPrimary

    Component.onCompleted: Cava.start()
    Component.onDestruction: Cava.stop()

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.22) }
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // Small note glyph that toggles between music_note (idle / paused
        // glance) and pause (when actively playing). Same trick the legacy
        // bar Media.qml uses to give the user a quick-glance state.
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: MprisController.isPlaying ? "graphic_eq" : "music_note"
            iconSize: Appearance.font.pixelSize.normal
            color: root.colPrimary
            fill: 1
        }

        // CAVA waveform. Only renders bars while audio plays (Cava.bars stay
        // at 0 when paused, so the bars sit at minBarHeight which still
        // looks intentional, like a flatlined visualizer waiting to react).
        CavaWaveform {
            Layout.alignment: Qt.AlignVCenter
            barColor: root.colPrimary
            maxBarHeight: 18
            minBarHeight: 2
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                // Open the existing floating media controls overlay. Same
                // flag the legacy bar Media.qml uses for its non-bar mode.
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            } else if (event.button === Qt.MiddleButton) {
                MprisController.togglePlaying()
            } else if (event.button === Qt.RightButton) {
                MprisController.next()
            }
        }
    }

    StyledToolTip {
        text: {
            const t = MprisController.activeTrack;
            if (!t) return "";
            const lines = [];
            if (t.title)  lines.push(t.title);
            if (t.artist) lines.push(t.artist);
            if (t.album)  lines.push(t.album);
            return lines.join("\n");
        }
        extraVisibleCondition: mouseArea.containsMouse
    }
}
