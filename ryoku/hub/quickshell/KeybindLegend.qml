import QtQuick
import QtQuick.Controls
import "Singletons"

// The read-live shortcut legend: each category is an ember header with a trailing
// hairline rule, then its binds as rows split by faint dividers. Searching is
// global (the sidebar, handled by SearchResults), so this view only renders the
// full grouped legend. `categories` is the JSON from the ryoku-hub backend, parsed
// from the live binds.lua so it never drifts from what is actually bound.
Flickable {
    id: page

    property var categories: []

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        id: sb
        policy: ScrollBar.AsNeeded
        width: 7
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Theme.line
            opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }
    }

    Column {
        id: col
        width: page.width - 10
        spacing: 30
        topPadding: 6
        bottomPadding: 18

        Repeater {
            model: page.categories

            delegate: KeybindGroup {
                width: col.width
                name: modelData.name
                binds: modelData.binds
            }
        }
    }
}
