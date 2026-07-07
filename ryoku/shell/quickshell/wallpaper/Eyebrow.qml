import QtQuick
import "Singletons"

// Section eyebrow, the website's `.eyebrow`: a short vermillion tick, the 力
// seal, then a mono uppercase label with wide tracking. The house header idiom,
// shared with the pill and hub surfaces.
Row {
    id: eye

    property string label: ""
    property real s: 1
    property color tick: Theme.brand
    property color labelColor: Theme.dim

    spacing: Math.round(9 * eye.s)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(20 * eye.s)
        height: Math.max(1, Math.round(1.5 * eye.s))
        color: eye.tick
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u529b"
        color: eye.tick
        font.family: Theme.fontJp
        font.pixelSize: Math.round(13 * eye.s)
        font.weight: Font.Medium
        opacity: 0.9
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: eye.label
        color: eye.labelColor
        font.family: Theme.mono
        font.pixelSize: Math.round(9.5 * eye.s)
        font.weight: Font.DemiBold
        font.letterSpacing: 2.6 * eye.s
        font.capitalization: Font.AllUppercase
    }
}
