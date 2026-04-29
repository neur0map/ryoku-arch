import QtQuick
import QtQuick.Controls
import "../"

// Reusable scrollable page container for popup content.
// Clips content, shows a faint scrollbar when needed.
// Consistent vertical padding relative to popup height.
//
// Usage:
//   PopupPage {
//       anchors.fill: parent
//       // children go here — laid out top-to-bottom, scrollable if overflow
//   }

Item {
    id: root

    // All children go into the scroll content
    default property alias content: contentCol.data

    // Padding applied inside the scroll area
    property int padH: 6   // horizontal
    property int padV: 8   // vertical

    clip: true

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth:  width
        contentHeight: contentCol.implicitHeight + root.padV * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // Scroll with mouse wheel
        ScrollBar.vertical: ScrollBar {
            policy: contentCol.implicitHeight + root.padV * 2 > flick.height
                        ? ScrollBar.AlwaysOn
                        : ScrollBar.AlwaysOff
            contentItem: Rectangle {
                implicitWidth:  3
                implicitHeight: 40
                radius:         1.5
                color:          Qt.rgba(1, 1, 1, 0.25)
            }
            background: Item {}
        }

        Column {
            id: contentCol
            anchors {
                top:        parent.top
                topMargin:  root.padV
                left:       parent.left
                leftMargin: root.padH
                // Reserve space for scrollbar when visible
                right:      parent.right
                rightMargin: root.padH + 6
            }
            spacing: 8
        }
    }
}
