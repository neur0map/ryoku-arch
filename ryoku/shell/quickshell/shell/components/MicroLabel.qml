import QtQuick
import shell.services

// section eyebrow, dossier idiom: small vermilion registration dot, then a
// mono uppercase letterspaced label. scales with `s`.
Row {
    id: ml

    property string label: ""
    property real s: 1

    spacing: 8 * s

    Rectangle {
        width: 5 * ml.s
        height: 5 * ml.s
        radius: Theme.radiusWidget
        color: Theme.primary
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ml.label
        color: Theme.onSurfaceVariant
        font.family: Theme.mono
        font.pixelSize: 10 * ml.s
        font.weight: Font.DemiBold
        font.letterSpacing: 2.4 * ml.s
        font.capitalization: Font.AllUppercase
    }
}
