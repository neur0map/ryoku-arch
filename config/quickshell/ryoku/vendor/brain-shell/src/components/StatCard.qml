import QtQuick
import "../"

// Reusable card background. Wrap any stats panel in this for
// a consistent surface across the stats tab and future dashboard panels.
//
// Usage:
//   StatCard {
//       width: ...; height: ...
//       SomeContent { anchors.fill: parent }
//   }

Item {
    id: root

    default property alias content: inner.data
    property int padding: 12

    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        color:        Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
    }

    Item {
        id: inner
        anchors {
            fill:         parent
            margins:      root.padding
        }
    }
}
