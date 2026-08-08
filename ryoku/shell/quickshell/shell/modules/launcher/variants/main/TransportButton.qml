import QtQuick
import QtQuick.Shapes
import "../../shared/Singletons"

// Compact transport control using the shell's 24-unit media glyphs.
Item {
    id: root

    property real s: 1
    property string glyph: ""
    property bool active: true
    property bool lit: false

    signal tapped()

    implicitWidth: 26 * s
    implicitHeight: 26 * s
    opacity: active ? 1 : 0.35

    readonly property var paths: ({
        "play": "M8 5l11 7-11 7z",
        "pause": "M8 5h3v14H8z M13 5h3v14h-3z",
        "next": "M6 5l9 7-9 7z M16 5h2v14h-2z",
        "prev": "M18 5l-9 7 9 7z M6 5h2v14H6z",
        "shuffle": "M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z"
    })

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: hover.containsMouse && root.active ? Theme.hair : "transparent"
    }

    Item {
        anchors.centerIn: parent
        width: 16 * root.s
        height: 16 * root.s

        Shape {
            width: 24
            height: 24
            scale: parent.width / 24
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: root.lit ? Theme.vermLit : Theme.bright
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.paths[root.glyph] || "" }
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.active) root.tapped()
    }
}
