import QtQuick
import Quickshell
import "Singletons"

// The page title block at the top of the content area. When the section maps to a
// real config file (configPaths), a ghost CONFIG chip sits next to the name and
// opens those files in nvim, side by side, in a kitty window.
Item {
    id: header

    property string title: ""
    property string subtitle: ""
    // Absolute paths the CONFIG button opens (empty hides the button). Hub.qml
    // resolves these per section; the base module is the real config to read, and
    // user.lua (or monitors_user.lua) the file edits actually persist in.
    property var configPaths: []

    implicitHeight: 80

    function openConfig() {
        if (!header.configPaths || header.configPaths.length === 0)
            return;
        Quickshell.execDetached(["kitty", "-e", "nvim", "-O"].concat(header.configPaths));
    }

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Row {
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: header.title
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 27
                font.weight: Font.DemiBold
                font.letterSpacing: 0.2
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: header.configPaths.length > 0
                icon: "terminal"
                label: "config"
                onClicked: header.openConfig()
            }
        }

        Text {
            text: header.subtitle
            visible: header.subtitle !== ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
