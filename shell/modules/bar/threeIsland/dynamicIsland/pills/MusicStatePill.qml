import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland
import QtQuick
import QtQuick.Layouts

// Compact music indicator inspired by Brain_Shell's PlayerCard waveform:
// 32 dense bars rooted to the bottom, each bar's height + opacity scaling
// with its band amplitude. No title text in the pill, no leading icon.
// Title / artist / album are in the hover tooltip and the floating media
// controls popup (left-click).
Item {
    id: root
    implicitWidth: waveform.implicitWidth + 24
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
            GradientStop { position: 0.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.20) }
        }
    }

    CavaWaveform {
        id: waveform
        anchors.centerIn: parent
        barColor: root.colPrimary
        barWidth: 2
        spacing: 1
        maxBarHeight: 18
        minBarHeight: 2
        // Flatline the bars when paused so the row stops jittering on
        // background pulse noise.
        active: MprisController.isPlaying
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
