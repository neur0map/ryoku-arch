import QtQuick
import "Singletons"

// section eyebrow, the website's `.eyebrow`: a short vermilion tick, then the
// 力 seal, then a mono uppercase label with wide tracking. the pill surfaces'
// header idiom, replacing the bare "力 LABEL" row. scales with `s`.
Row {
    id: eye

    property string label: ""
    property real s: 1
    property bool mark: true           // lead with the 力 seal after the tick
    property color tick: Theme.brand
    property color labelColor: Theme.dim

    spacing: 9 * eye.s

    Rectangle {                        // the vermilion tick
        anchors.verticalCenter: parent.verticalCenter
        width: 20 * eye.s
        height: 1.5 * eye.s
        color: eye.tick
    }

    Text {
        visible: eye.mark
        anchors.verticalCenter: parent.verticalCenter
        text: "\u529b"                 // 力
        color: eye.tick
        font.family: Theme.fontJp
        font.pixelSize: 13 * eye.s
        font.weight: Font.Medium
        opacity: 0.9
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: eye.label
        color: eye.labelColor
        font.family: Theme.mono
        font.pixelSize: 9.5 * eye.s
        font.weight: Font.DemiBold
        font.letterSpacing: 2.6 * eye.s
        font.capitalization: Font.AllUppercase
    }
}
