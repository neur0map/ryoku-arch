import QtQuick
import QtQuick.Controls
import "Singletons"
import "fuzzy.js" as Fuzzy

// Global results, shown whenever the sidebar search has a query. It looks across
// every section: matching section names (navigable) and fuzzy-ranked keybinds
// (tagged with their category). `sections` is [{ key, name, icon }].
Flickable {
    id: page

    property var categories: []
    property var sections: []
    property string query: ""
    signal navigate(string section)

    readonly property var bindHits: query.length > 0 ? Fuzzy.rank(query, categories) : []
    readonly property var sectionHits: {
        var out = [];
        if (query.length === 0)
            return out;
        for (var i = 0; i < sections.length; i++) {
            if (Fuzzy.score(query, sections[i].name) >= 0)
                out.push(sections[i]);
        }
        return out;
    }
    readonly property bool empty: query.length > 0 && bindHits.length === 0 && sectionHits.length === 0

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

        Column {
            visible: page.sectionHits.length > 0
            width: col.width
            spacing: 0

            Item {
                width: parent.width
                height: 32

                Text {
                    id: secLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SECTIONS"
                    color: Theme.ember
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.left: secLabel.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: Theme.lineSoft
                }
            }

            Repeater {
                model: page.sectionHits

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: col.width
                    height: 48

                    Rectangle {
                        visible: index > 0
                        width: parent.width
                        height: 1
                        color: Theme.lineSoft
                    }

                    Icon {
                        id: secIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 18
                        tint: rowHover.hovered ? Theme.ember : Theme.dim
                        Behavior on tint { ColorAnimation { duration: Theme.quick } }
                    }

                    Text {
                        anchors.left: secIcon.right
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: rowHover.hovered ? Theme.bright : Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open \u2192"
                        color: rowHover.hovered ? Theme.ember : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: page.navigate(modelData.key) }
                }
            }
        }

        KeybindGroup {
            visible: page.bindHits.length > 0
            width: col.width
            name: "Keybinds"
            binds: page.bindHits
            tagged: true
        }

        Item {
            visible: page.empty
            width: parent.width
            height: 240

            Column {
                anchors.centerIn: parent
                spacing: 14

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "search"
                    size: 32
                    weight: 1.5
                    tint: Theme.faint
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing matches"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u201c" + page.query + "\u201d"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
        }
    }
}
