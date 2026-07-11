pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// keybinds page = live legend (every desktop bind, parsed from binds.lua) plus
// a custom editor. legend is the source of truth; custom binds layer on top,
// show up once saved + reloaded.
Item {
    id: page

    property var categories: []
    property string tab: "all"

    Segmented {
        id: tabs
        anchors.left: parent.left
        anchors.top: parent.top
        model: [
            { "key": "all", "label": "Shortcuts" },
            { "key": "custom", "label": "Custom" }
        ]
        current: page.tab
        onSelected: (k) => page.tab = k
    }

    Loader {
        id: loader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.topMargin: 18
        anchors.bottom: parent.bottom
        sourceComponent: page.tab === "all" ? legendComp : customComp
        onLoaded: {
            if (!item)
                return;
            item.opacity = 0;
            fade.restart();
        }
    }

    NumberAnimation { id: fade; target: loader.item; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Theme.ease }

    Component {
        id: legendComp
        KeybindLegend { categories: page.categories }
    }

    Component {
        id: customComp
        KeybindsEditor { categories: page.categories }
    }
}
