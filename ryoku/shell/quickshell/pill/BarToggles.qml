pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// a cluster of quick-toggles, laid out like the status glyphs. `kinds` names the
// toggles it carries in order, so a skin (or the modular layout) picks the set.
// `vertical` stacks them for a side bar.
Grid {
    id: cluster

    property real s: 1
    property bool vertical: false
    property var kinds: ["caffeine", "dnd", "nightlight"]

    readonly property real glyphPx: 14 * s

    columns: vertical ? 1 : kinds.length
    columnSpacing: 9 * s
    rowSpacing: 7 * s
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    Repeater {
        model: cluster.kinds
        delegate: BarToggle {
            required property string modelData
            kind: modelData
            s: cluster.s
        }
    }
}
