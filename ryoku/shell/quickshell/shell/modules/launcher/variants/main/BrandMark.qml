import QtQuick
import "../../shared/Singletons"

Text {
    property real size: 13
    property int weight: Font.Medium

    text: "力"
    color: Theme.brand
    font.family: Theme.font
    font.weight: weight
    font.pixelSize: size
}
