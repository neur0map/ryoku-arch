import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    property string profileName: RyokuOpenVpn.activeProfile
    property bool expanded: false
    spacing: 4
    Layout.fillWidth: true
    visible: profileName.length > 0

    onProfileNameChanged: { tailLines.text = ""; if (expanded) tailLoader.active = true }
    onExpandedChanged: tailLoader.active = expanded

    Button {
        Layout.fillWidth: true
        text: (root.expanded ? "▾ " : "▸ ") + "Recent log" + (root.profileName ? "  (" + root.profileName + ")" : "")
        flat: true
        onClicked: root.expanded = !root.expanded
    }

    Rectangle {
        visible: root.expanded
        Layout.fillWidth: true
        Layout.preferredHeight: 140
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.small
        border.color: Appearance.colors.colLayer3Hover
        border.width: 1

        ScrollView {
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            TextArea {
                id: tailLines
                readOnly: true
                wrapMode: TextArea.NoWrap
                font.family: Appearance.font.family.monospace ?? "monospace"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                text: ""
                background: null
            }
        }
    }

    Loader {
        id: tailLoader
        active: false
        sourceComponent: Item {
            Process {
                id: tailProc
                running: true
                command: ["journalctl", "-fu", "openvpn-client@" + root.profileName + ".service", "-n", "20", "--no-pager"]
                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: data => {
                        // Keep at most ~200 lines.
                        const lines = (tailLines.text + data + "\n").split("\n")
                        const trimmed = lines.length > 200 ? lines.slice(lines.length - 200) : lines
                        tailLines.text = trimmed.join("\n")
                    }
                }
            }
            Component.onDestruction: tailProc.running = false
        }
    }
}
