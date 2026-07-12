import QtQuick
import "Singletons"

Rectangle {
    id: b
    property string label: ""
    property bool accent: false
    property bool on: true          // enabled
    signal tapped()
    implicitWidth: tl.implicitWidth + 30
    implicitHeight: 34
    radius: Theme.radiusSm
    opacity: b.on ? 1 : 0.4
    color: b.accent ? (ma.containsMouse ? Qt.lighter(Theme.ember, 1.12) : Theme.ember)
                    : (ma.containsMouse ? Theme.fieldHi : "transparent")
    border.width: b.accent ? 0 : 1
    border.color: Theme.hair
    Text {
        id: tl
        anchors.centerIn: parent; text: b.label
        color: b.accent ? "#ffffff" : Theme.idle
        font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: b.on ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (b.on) b.tapped()
    }
}
