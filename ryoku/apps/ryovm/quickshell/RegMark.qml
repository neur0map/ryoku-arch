import QtQuick
import Ryoku.Ui.Singletons

// Printing registration crosshair, the website's `.regmark`: a ring with a cross
// through it. Poster chrome that frames a surface like a proof. Ink only.
Item {
    id: reg
    property real size: 14
    property color tint: Tokens.inkFaint
    property real thickness: 1

    implicitWidth: size
    implicitHeight: size

    Rectangle {                        // ring
        anchors.centerIn: parent
        width: reg.size
        height: reg.size
        radius: reg.size / 2
        color: "transparent"
        border.width: reg.thickness
        border.color: reg.tint
    }
    Rectangle {                        // vertical
        anchors.centerIn: parent
        width: reg.thickness
        height: reg.size + 6
        color: reg.tint
    }
    Rectangle {                        // horizontal
        anchors.centerIn: parent
        width: reg.size + 6
        height: reg.thickness
        color: reg.tint
    }
}
