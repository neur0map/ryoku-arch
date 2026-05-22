import QtQuick
import QtQuick.Layouts

Text {
    id: root

    property string icon: ""

    text: icon
    font.family: "Symbols Nerd Font"
    font.pixelSize: 16
    Layout.alignment: Qt.AlignBaseline
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}