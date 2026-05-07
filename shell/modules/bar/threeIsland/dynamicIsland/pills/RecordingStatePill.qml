import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Red gradient pill with pulsing dot and elapsed time. Click stops recording,
// right-click opens the Recorder overlay.
Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colError: Appearance.ryokuEverywhere
        ? Appearance.ryoku.colError ?? Appearance.colors.colError
        : Appearance.colors.colError

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.colError.r, root.colError.g, root.colError.b, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(root.colError.r, root.colError.g, root.colError.b, 0.20) }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            id: dot
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: root.colError

            SequentialAnimation on opacity {
                running: RecorderStatus.isRecording && Appearance.animationsEnabled
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "REC"
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: root.colError
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: {
                const s = RecorderStatus.elapsedSeconds
                const mm = String(Math.floor(s / 60)).padStart(2, "0")
                const ss = String(s % 60).padStart(2, "0")
                return mm + ":" + ss
            }
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: "monospace"
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
            } else if (event.button === Qt.RightButton) {
                GlobalStates.overlayOpen = true
            }
        }

        StyledToolTip { text: Translation.tr("Recording - click to stop, right-click for options") }
    }
}
