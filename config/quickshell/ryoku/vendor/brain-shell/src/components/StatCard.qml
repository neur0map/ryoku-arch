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
    property real backgroundAlpha: 0.04
    property real borderAlpha: 0.07

    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        color:        Qt.rgba(1, 1, 1, root.backgroundAlpha)
        border.color: Qt.rgba(1, 1, 1, root.borderAlpha)
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
