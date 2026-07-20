pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// One screen's open layer: the dim scrim over the compositor-blurred desktop,
// the widget slots, the dock, and the keyboard surface. Click-out or Esc
// dismisses; slots eat their own clicks.
Item {
    id: board

    property string screenName: ""
    property bool active: false
    property bool focusHere: false
    signal requestClose()

    // instances on this screen. Rebuilt only when MEMBERSHIP changes: a
    // geometry save must not recreate the delegates mid-drag (slots own their
    // live x/y/w/h; entries feed initial placement and pin flags).
    property var entries: []
    function reload() {
        var out = [];
        var all = Config.widgets || [];
        for (var i = 0; i < all.length; i++)
            if (all[i].screen === board.screenName)
                out.push(all[i]);
        var ids = out.map(function (e) { return e.id + ":" + e.pinned + ":" + e.clickthrough; }).join(",");
        var cur = board.entries.map(function (e) { return e.id + ":" + e.pinned + ":" + e.clickthrough; }).join(",");
        if (ids !== cur)
            board.entries = out;
    }
    Component.onCompleted: reload()
    Connections {
        target: Config
        function onWidgetsChanged() { board.reload(); }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.32)
        MouseArea { anchors.fill: parent; onClicked: board.requestClose() }
    }

    // the vocabulary hint when the board is empty on this screen.
    Empty {
        anchors.centerIn: parent
        visible: board.entries.length === 0
        caption: "RYOLAYER. Add a tool from the dock below. Drag to place, drag the bracket to size, pin to keep it over the desktop."
    }

    // Task 5 replaces this stub with the RyoSlot repeater + Dock.

    Item {
        anchors.fill: parent
        focus: board.active && board.focusHere
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                board.requestClose();
                e.accepted = true;
            }
        }
    }
}
