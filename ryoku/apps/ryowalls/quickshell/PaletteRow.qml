import QtQuick
import "Singletons"

// The wallust scheme as a row of 16 swatches. Empty cells while a palette loads.
Row {
    id: pr
    property var colors: []
    readonly property int n: 16
    spacing: 4

    Repeater {
        model: pr.n
        delegate: Rectangle {
            required property int index
            width: (pr.width - (pr.n - 1) * pr.spacing) / pr.n
            height: pr.height
            radius: 4
            color: (pr.colors && pr.colors.length > index && pr.colors[index]) ? pr.colors[index] : Theme.surfaceLo
            border.width: 1
            border.color: Qt.alpha(Theme.cream, 0.08)
            Behavior on color { ColorAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }
    }
}
