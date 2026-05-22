import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects

ShellRoot {
    property color accentColor: zyuTheme.accent
    property string activeFont: "Google Sans Flex"

    PanelWindow {
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "activate-linux-widget"
        WlrLayershell.exclusiveZone: -1
        color: "transparent"

        Rectangle {
            id: backgroundGuard
            anchors.bottom: parent.bottom
            anchors.right: parent.right

            anchors.rightMargin: 20
            anchors.bottomMargin: 20

            width: contentLayout.width + 40
            height: contentLayout.height + 25

            radius: 12
            color: "#88000000"
            border.color: "#22ffffff"
            border.width: 1

            FastBlur {
                anchors.fill: parent
                source: parent
                radius: 50
                transparentBorder: true
            }

            Column {
                id: contentLayout
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: "Activate Linux"
                    color: accentColor
                    opacity: 1.0
                    font.family: activeFont
                    font.pixelSize: 25
                    font.weight: Font.Light
                    font.letterSpacing: 1
                    renderType: Text.QtRendering
                }

                Text {
                    text: "Go to Settings to activate Linux."
                    color: "white"
                    opacity: 1.0
                    font.family: "SF Pro Display"
                    font.pixelSize: 25
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                    renderType: Text.QtRendering
                }

                Rectangle {
                    width: 20
                    height: 1
                    radius: 1
                    color: accentColor
                    opacity: 0.4
                    anchors.left: parent.left
                }
            }
        }
    }
}
