import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.ambxst.modules.theme
import qs.ambxst.modules.components
import qs.ambxst.modules.globals
import qs.ambxst.config

// RYOKU PORT: the wifi / bluetooth / night-light / caffeine / game-mode toggles were
// replaced with ryoku's screen tools — Google Lens (area screenshot), color picker,
// OCR text-select, QR scanner — plus a webcam mirror (Ambxst's MirrorWindow). The four
// capture tools shell out to ryoku's bin scripts; the mirror toggles the mirror window.
StyledRect {
    id: root
    variant: "pane"
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: internalBgRect.implicitWidth + 8
    implicitHeight: internalBgRect.implicitHeight + 8
    radius: Styling.radius(4)

    StyledRect {
        id: internalBgRect
        variant: "internalbg"
        anchors.centerIn: parent
        implicitWidth: buttonRow.implicitWidth + 8
        implicitHeight: buttonRow.implicitHeight + 8
        radius: Styling.radius(0)

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 4

            ControlButton {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                iconName: Icons.glassPlus
                isActive: false
                tooltipText: "Google Lens"
                onClicked: Quickshell.execDetached(["ryoku-cmd-google-lens"])
            }

            ControlButton {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                iconName: Icons.picker
                isActive: false
                tooltipText: "Color Picker"
                onClicked: Quickshell.execDetached(["ryoku-cmd-color-picker"])
            }

            ControlButton {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                iconName: Icons.textT
                isActive: false
                tooltipText: "OCR Text"
                onClicked: Quickshell.execDetached(["ryoku-cmd-ocr"])
            }

            ControlButton {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                iconName: Icons.qrCode
                isActive: false
                tooltipText: "QR Scanner"
                onClicked: Quickshell.execDetached(["ryoku-cmd-qr-scan"])
            }

            // Webcam mirror
            ControlButton {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                iconName: GlobalStates.mirrorWindowVisible ? Icons.webcamSlash : Icons.webcam
                isActive: GlobalStates.mirrorWindowVisible
                tooltipText: "Mirror"
                onClicked: GlobalStates.mirrorWindowVisible = !GlobalStates.mirrorWindowVisible
            }
        }
    }
}
