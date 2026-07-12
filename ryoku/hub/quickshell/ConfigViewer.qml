pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// Modal read-only viewer for a rice's manifest JSON, so users can see the exact
// config a rice carries before applying it. The scrim dismisses; the panel
// scrolls the mono text, which stays selectable for copying.
Item {
    id: viewer

    property bool active: false
    property string title: "Rice config"
    property string configText: ""

    function open(t) {
        viewer.configText = t;
        viewer.active = true;
    }

    anchors.fill: parent
    visible: viewer.active
    z: 100

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: viewer.active = false }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 760)
        height: Math.min(parent.height - 60, 620)
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
            id: vtitle
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 22
            anchors.topMargin: 18
            text: viewer.title
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 16
            anchors.topMargin: 16
            width: 30
            height: 30
            radius: Theme.radius
            color: closeHov.hovered ? Theme.surfaceLo : "transparent"
            Icon { anchors.centerIn: parent; name: "close"; size: 15; tint: closeHov.hovered ? Theme.bright : Theme.dim }
            HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: viewer.active = false }
        }

        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: vtitle.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 12
            anchors.topMargin: 16
            anchors.bottomMargin: 18
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }

            TextEdit {
                id: body
                width: flick.width - 10
                text: viewer.configText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 12
                selectionColor: Theme.ember
            }
        }
    }
}
