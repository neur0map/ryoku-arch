import QtQuick
import "Singletons"

// A section eyebrow in the dossier idiom: a small vermilion registration dot
// before a mono, uppercase, letterspaced label. Scales with `s`.
Row {
    id: ml

    property string label: ""
    property real s: 1

    spacing: 8 * s

    Rectangle {
        width: 5 * ml.s
        height: 5 * ml.s
        radius: 1 * ml.s
        color: Theme.brand
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ml.label
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10 * ml.s
        font.weight: Font.DemiBold
        font.letterSpacing: 2.4 * ml.s
        font.capitalization: Font.AllUppercase
    }
}
