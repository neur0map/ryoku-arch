import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland
import QtQuick
import QtQuick.Layouts

// Blue pill with CAVA waveform + scrolling track title. Click toggles play/pause.
// Right-click opens BarMediaPopup (handled by Media.qml separately).
Item {
    id: root
    implicitWidth: row.implicitWidth + 28
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
            GradientStop { position: 1.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.20) }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        CavaWaveform {
            Layout.alignment: Qt.AlignVCenter
            barColor: root.colPrimary
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 160
            elide: Text.ElideRight
            text: {
                const t = MprisController.activeTrack?.title ?? ""
                const a = MprisController.activeTrack?.artist ?? ""
                return a.length > 0 ? (t + " - " + a) : t
            }
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                MprisController.togglePlaying()
            }
        }

        StyledToolTip {
            text: {
                const t = MprisController.activeTrack;
                if (!t) return "";
                return (t.title || "") + (t.artist ? "\n" + t.artist : "") + (t.album ? "\n" + t.album : "");
            }
        }
    }
}
