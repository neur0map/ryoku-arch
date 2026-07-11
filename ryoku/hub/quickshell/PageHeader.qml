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
    property string eyebrow: "RYOKU"
    // The section's config files for the header buttons, split by ownership.
    // editPaths are the durable files you can hand-edit and keep across an
    // update (user.lua, monitors_user.lua, or a Hub-owned JSON), opened
    // writable; viewPaths are Ryoku's shipped defaults, opened read-only since
    // an update replaces them. editTip/viewTip are the hover explanations.
    property var editPaths: []
    property var viewPaths: []
    property string editLabel: "Edit user.lua"
    property string editTip: ""
    property string viewTip: ""

    // Height follows the content (eyebrow + title + subtitle), so a one or
    // two line subtitle both sit right. A fixed height with a centred column
    // let taller pages overflow upward and shove the eyebrow into the top edge.
    implicitHeight: col.height

    function openEdit() {
        if (!header.editPaths || header.editPaths.length === 0)
            return;
        Quickshell.execDetached(["kitty", "-e", "nvim", "-O"].concat(header.editPaths));
    }
    function openView() {
        if (!header.viewPaths || header.viewPaths.length === 0)
            return;
        // -R opens read-only: these are Ryoku defaults or generated files an
        // update overwrites, so edits here would be lost. Look, do not touch.
        Quickshell.execDetached(["kitty", "-e", "nvim", "-R", "-O"].concat(header.viewPaths));
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 10

        // editorial kicker
        Eyebrow {
            text: header.eyebrow
        }

        Row {
            spacing: 14

            // Fraunces editorial display title, the website's headline face.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: header.title
                color: Theme.bright
                font.family: Theme.display
                font.pixelSize: 40
                font.weight: Font.DemiBold
                font.letterSpacing: -0.5
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: header.editPaths.length > 0
                icon: "terminal"
                label: header.editLabel
                tooltip: header.editTip
                onClicked: header.openEdit()
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: header.viewPaths.length > 0
                icon: "lock"
                label: "View defaults"
                tooltip: header.viewTip
                onClicked: header.openView()
            }
        }

        Text {
            text: header.subtitle
            visible: header.subtitle !== ""
            width: header.width * 0.62
            wrapMode: Text.WordWrap
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            lineHeight: 1.35
        }
    }
}
