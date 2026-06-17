pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

Column {
    id: root
    property real s: 1
    property int current: 0
    property bool showDot: false
    signal select(int idx)

    spacing: 5 * s

    component EdgeTab: Item {
        id: tab
        property int idx: 0
        property string icon: ""
        property bool dot: false
        readonly property bool on: root.current === idx

        width: 34 * root.s
        height: 40 * root.s

        Rectangle {
            anchors.fill: parent
            topLeftRadius: 9 * root.s
            bottomLeftRadius: 9 * root.s
            color: tab.on ? Theme.cardTop : Theme.trackBg
            border.width: 1
            border.color: tab.on ? Theme.border : "#2c2018"
        }

        Rectangle {
            visible: tab.on
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: -2 * root.s
            width: 3 * root.s
            color: Theme.cardTop
        }

        Rectangle {
            visible: tab.on
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 7 * root.s
            anchors.rightMargin: 2 * root.s
            height: 1
            color: Theme.hair
        }

        Rectangle {
            visible: !tab.on
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            width: 3 * root.s
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.3) }
            }
        }

        Image {
            id: glyph
            anchors.centerIn: parent
            width: 14 * root.s
            height: 14 * root.s
            source: Qt.resolvedUrl("assets/icons/" + tab.icon + ".svg")
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: glyph
            source: glyph
            colorization: 1.0
            colorizationColor: tab.on ? Theme.vermLit : Theme.faint
        }

        Rectangle {
            visible: tab.dot
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 5 * root.s
            anchors.topMargin: 5 * root.s
            width: 5 * root.s
            height: 5 * root.s
            radius: width / 2
            color: Theme.vermLit
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.select(tab.idx)
        }
    }

    EdgeTab { idx: 0; icon: "sliders" }
    EdgeTab { idx: 1; icon: "bell-plain"; dot: root.showDot }
}
