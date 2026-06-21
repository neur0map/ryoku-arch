pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The navigation rail: brand header, a global search field (it searches content
// across every section, not just the open one), the grouped section list with a
// single sliding selection indicator, and a footer mark. The section list is
// data-driven from `sections` ({ key, name, icon, group }); a header is drawn
// whenever the group changes.
Rectangle {
    id: rail

    property var sections: []
    property string current: "displays"
    property alias query: search.text
    signal navigate(string section)
    signal escaped()

    function focusSearch() { search.focusInput(); }

    readonly property int navTop: 96 + 54 + 8
    readonly property int navItemH: 44
    readonly property int groupHeaderH: 30

    // Absolute y of a section's row, accounting for the group header drawn before
    // each new group. Drives the single sliding selector.
    function itemY(key) {
        var y = rail.navTop;
        var last = null;
        for (var i = 0; i < rail.sections.length; i++) {
            var s = rail.sections[i];
            if (s.group !== last) {
                y += rail.groupHeaderH;
                last = s.group;
            }
            if (s.key === key)
                return y;
            y += rail.navItemH;
        }
        return rail.navTop;
    }

    color: Theme.rail

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.line
    }

    // Sliding selection indicator (dimmed while a search is active, since the
    // content then shows results rather than the highlighted section).
    Rectangle {
        id: selector
        x: 12
        width: rail.width - 24
        height: 42
        radius: 11
        y: rail.itemY(rail.current) + (rail.navItemH - height) / 2
        color: Theme.keyTop
        border.width: 1
        border.color: Theme.line
        opacity: rail.query.length > 0 ? 0.4 : 1
        Behavior on y { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 3
            radius: 3
            color: Theme.keyBot
        }
    }

    // brand + search
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Item {
            width: parent.width
            height: 96

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.ember }
                        GradientStop { position: 1.0; color: Theme.emberDeep }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\u529b"
                        color: Theme.onAccent
                        font.family: Theme.fontJp
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Ryoku Settings"
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.2
                    }

                    Text {
                        text: "System & shell"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 54

            SearchField {
                id: search
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                placeholder: "Search everything\u2026"
                onEscaped: rail.escaped()
            }
        }
    }

    // grouped section list
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        y: rail.navTop
        spacing: 0

        Repeater {
            model: rail.sections

            delegate: Column {
                id: row
                required property int index
                required property var modelData
                readonly property bool firstOfGroup: row.index === 0 || rail.sections[row.index - 1].group !== row.modelData.group
                width: parent.width

                Item {
                    width: parent.width
                    height: row.firstOfGroup ? rail.groupHeaderH : 0
                    visible: row.firstOfGroup

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: row.modelData.group
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                        font.capitalization: Font.AllUppercase
                    }
                }

                NavButton {
                    width: parent.width
                    height: rail.navItemH
                    icon: row.modelData.icon
                    label: row.modelData.name
                    badge: row.modelData.key === "updates" ? (Updates.available ? Updates.behind : 0) : 0
                    selected: rail.current === row.modelData.key
                    onClicked: rail.navigate(row.modelData.key)
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        text: "\u529b  ryoku desktop"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
