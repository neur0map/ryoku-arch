import QtQuick
import "Singletons"

// The status header for the Updates section: an ember accent rule, a small
// eyebrow, the version bump as a current -> latest line, and a terse meta line.
// Typographic and editorial, not a boxed banner.
Item {
    id: status

    implicitHeight: textCol.implicitHeight

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.top: parent.top
        width: 3
        height: textCol.implicitHeight
        radius: 1.5
        color: Theme.ember
        opacity: Updates.available ? 0.9 : 0.3
    }

    Column {
        id: textCol
        anchors.left: bar.right
        anchors.leftMargin: 18
        anchors.top: parent.top
        spacing: 9

        Text {
            text: Updates.available ? "UPDATE AVAILABLE" : "UP TO DATE"
            color: Theme.ember
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }

        Row {
            spacing: 13

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Updates.currentVersion
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 25
                font.weight: Font.Medium
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Updates.available && Updates.latestVersion !== "" && Updates.latestVersion !== Updates.currentVersion
                text: "\u2192"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 22
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Updates.available && Updates.latestVersion !== "" && Updates.latestVersion !== Updates.currentVersion
                text: Updates.latestVersion
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 25
                font.weight: Font.DemiBold
            }
        }

        Text {
            text: Updates.available
                ? (Updates.behind + " package update" + (Updates.behind === 1 ? "" : "s") + "  \u00b7  checked " + Updates.checkedAgo)
                : ("on " + Updates.branch + "  \u00b7  checked " + Updates.checkedAgo)
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
