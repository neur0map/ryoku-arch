pragma ComponentBehavior: Bound

import QtQuick

// Nested composition: a bounded, orientation-aware group of menu widgets. The
// depth cap stops a self-referential container from recursing without end.
Item {
    id: root

    property var widgets: []
    property string orientation: "vertical"
    property bool open: false
    property real scale: 1
    property int depth: 0
    readonly property int maxDepth: 3
    property real spacing: 6 * scale

    implicitWidth: layout.item ? layout.item.implicitWidth : 0
    implicitHeight: layout.item ? layout.item.implicitHeight : 0

    Loader {
        id: layout
        width: root.width
        active: root.open && root.depth < root.maxDepth
        sourceComponent: root.orientation === "horizontal" ? rowComp : colComp
    }

    Component {
        id: hostComp
        MenuHostLoader {
            required property var modelData
            width: root.orientation === "horizontal" ? implicitWidth : root.width
            widget: modelData
            scale: root.scale
            open: root.open
            depth: root.depth + 1
        }
    }

    Component { id: colComp; Column { spacing: root.spacing; Repeater { model: root.widgets; delegate: hostComp } } }
    Component { id: rowComp; Row { spacing: root.spacing; Repeater { model: root.widgets; delegate: hostComp } } }
}
