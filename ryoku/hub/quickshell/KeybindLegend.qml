import QtQuick
import QtQuick.Controls
import "Singletons"

// shortcut legend, read live. each category = ember header + hairline rule,
// then binds separated by faint dividers. search is global (sidebar, via
// SearchResults), so this view only renders the full grouped legend.
// categories = JSON from the ryoku-hub backend (parsed from the live binds.lua,
// so it never drifts from what's actually bound).
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
            radius: Theme.radius
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

        Text {
            width: col.width
            wrapMode: Text.WordWrap
            text: "Read live from Ryoku's binds plus your Hub custom shortcuts. Binds added by hand in ~/.config/hypr/user.lua don't appear here and aren't conflict-checked, so add custom shortcuts in the Custom tab."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.3
        }
    }
}
