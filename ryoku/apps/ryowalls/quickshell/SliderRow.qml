import QtQuick
import "Singletons"

// label, slider, live mono readout. modified(value) fires as the knob moves.
// autoText shows at the low end instead of a number (for off-by-default knobs).
Item {
    id: row

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.01
    property int decimals: 2
    property bool percent: false
    property string autoText: ""

    signal modified(real value)

    implicitWidth: 320
    implicitHeight: 36

    readonly property string readout: (autoText.length > 0 && row.value <= row.from)
        ? autoText
        : (row.percent ? Math.round(row.value * 100) + "%" : row.value.toFixed(row.decimals))

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 104
        elide: Text.ElideRight
        text: row.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Text {
        id: val
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        horizontalAlignment: Text.AlignRight
        text: row.readout
        color: Theme.bright
        font.family: Theme.mono
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    Slider {
        anchors.left: lbl.right
        anchors.right: val.left
        anchors.leftMargin: 4
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        from: row.from
        to: row.to
        step: row.step
        value: row.value
        onMoved: (v) => row.modified(v)
    }
}
