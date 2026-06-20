import QtQuick
import "Singletons"

// A coarse "feel" control: a label, a slider, and a readout. Used for values
// tuned by eye over a continuum (opacity, shadow strength, melt) where the exact
// number matters less than the result, per the slider convention. Reports
// modified(value) live as the knob travels.
Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.01
    property int decimals: 2
    property bool percent: false

    signal modified(real value)

    implicitWidth: 320
    implicitHeight: 38

    readonly property string readout: root.percent
        ? Math.round(root.value * 100) + "%"
        : root.value.toFixed(root.decimals)

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 116
        elide: Text.ElideRight
        text: root.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Text {
        id: val
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        horizontalAlignment: Text.AlignRight
        text: root.readout
        color: Theme.bright
        font.family: Theme.mono
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Slider {
        anchors.left: lbl.right
        anchors.right: val.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        from: root.from
        to: root.to
        step: root.step
        value: root.value
        onMoved: (v) => root.modified(v)
    }
}
