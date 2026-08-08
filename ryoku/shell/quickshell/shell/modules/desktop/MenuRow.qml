pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One action / value row in a desktop context menu: a label on the left, an
// optional value or live state on the right, a full-width hover wash and a
// press dip. The quiet tile idiom of the quick-settings sidebar rows. A row
// that opens something closes the menu on trigger; a toggle sets
// closeOnTrigger false to stay put while the state flips.
Item {
    id: row

    property string label: ""
    property string value: ""
    property bool on: false          // accent the value (a live / active state)
    property bool accent: false      // accent the label (a primary action)
    property bool closeOnTrigger: true
    signal triggered()

    width: parent ? parent.width : 0
    implicitHeight: 34

    // find the enclosing DesktopMenu so a triggered row can dismiss it.
    function closeMenu() {
        var p = row.parent;
        while (p) {
            if (p.ryoMenu === true) {
                p.close();
                return;
            }
            p = p.parent;
        }
    }

    scale: ma.pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusTile
        color: ma.pressed ? Theme.tilePress : (ma.containsMouse ? Theme.tileHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: row.label
        color: row.accent ? Theme.accent : (ma.containsMouse ? Theme.ink : Theme.inkSoft)
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        visible: row.value.length > 0
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: row.value
        color: row.on ? Theme.accent : Theme.inkDim
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            row.triggered();
            if (row.closeOnTrigger)
                row.closeMenu();
        }
    }
}
