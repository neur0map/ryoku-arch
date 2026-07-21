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

    // instances on this screen. Rebuilt only when MEMBERSHIP changes so a
    // geometry save never recreates the delegates mid-drag; the delegate then
    // reads its geometry live off Config (below), not this frozen snapshot.
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

    Empty {
        anchors.centerIn: parent
        visible: board.entries.length === 0
        caption: "RYOLAYER. Add a tool from the dock below. Drag to place, drag the bracket to size, pin to keep it over the desktop."
    }

    Repeater {
        // build the editing slots only while the board is actually open. A
        // ryolayer kept resident for a pinned widget (board closed) then holds
        // just its pins, not a full hidden slot per widget; slots read their
        // geometry live off Config, so a reopen rebuilds them in place.
        model: board.active ? board.entries : []
        delegate: RyoSlot {
            required property var modelData
            // the snapshot in board.entries goes stale after a drag/resize
            // persists (membership is unchanged, so it is not rebuilt); read the
            // live entry keyed on Config.rev so a reopened plate keeps its spot.
            entry: (Config.rev, Config.entry(modelData.id, board.screenName)) || modelData
            screenName: board.screenName
            interactive: true
            active: board.active
        }
    }

    Dock {
        screenName: board.screenName
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.s6 }
    }

    // Esc dismisses from anywhere in the board, even while a widget's text field
    // holds focus. A WindowShortcut fires for the focused window regardless of
    // which item holds focus; a focus-scoped Keys handler on a sibling Item never
    // saw an Esc that a focused composer let bubble up its own ancestor chain.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: board.active && board.focusHere
        onActivated: board.requestClose()
    }
}
