import QtQuick
import Quickshell
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Every settings page, once. A page supplies its schema, its draft and its
// defaults; this draws the tabs its schema declares and hands the rows to a
// SettingsSheet. There is no per-page layout to write, which is the point:
// 30 pages that differ only in data should not be 30 files that differ in
// code.
//
// Surfaces that are not settings (a preview, a console, a drag-arrange) do not
// belong in a cell and are not forced into one: a page passes them in as
// `extras` and they sit full width inside the sheet's grid.
Item {
    id: page

    property var schema: []
    property var draft: null
    property var defaults: ({})
    property string title: ""
    property string eyebrow: "DESKTOP"
    property string blurb: ""
    property string query: ""
    property alias tab: sheet.tab
    default property alias extras: extraSlot.data

    signal edited(string key, var value)
    signal pickRequested(var row)

    readonly property var tabs: {
        var t = [];
        for (var i = 0; i < schema.length; i++) {
            var x = schema[i].tab;
            if (x && t.indexOf(x) < 0) t.push(x);
        }
        return t;
    }

    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: page.eyebrow; color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: page.title
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fTitle
        }
        Text {
            visible: page.blurb !== ""
            width: Math.min(parent.width, 720)
            text: page.blurb
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.WordWrap
        }
        Item { width: 1; height: Tokens.s1 }

        // a page with one tab does not need a tab bar
        Item {
            width: page.tabs.length * 118
            height: page.tabs.length > 1 ? 34 : 0
            visible: page.tabs.length > 1
            Rectangle {
                width: 118; height: 34; radius: Tokens.radius; color: Tokens.bone
                x: Math.max(0, page.tabs.indexOf(sheet.tab)) * 118
                Behavior on x { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
            }
            Row {
                spacing: 0
                Repeater {
                    model: page.tabs
                    Rectangle {
                        required property string modelData
                        width: 118; height: 34; radius: Tokens.radius
                        color: "transparent"
                        border.width: Tokens.border
                        border.color: Tokens.line
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.toUpperCase()
                            color: sheet.tab === parent.modelData ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.ui; font.pixelSize: 11
                            font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        }
                        TapHandler { onTapped: sheet.tab = parent.modelData }
                    }
                }
            }
        }
    }

    Item {
        id: extraSlot
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.s4 }
        height: childrenRect.height
        visible: children.length > 0
    }

    SettingsSheet {
        id: sheet
        anchors {
            left: parent.left; right: parent.right
            top: extraSlot.visible ? extraSlot.bottom : head.bottom
            bottom: parent.bottom
            topMargin: Tokens.s5
        }
        schema: page.schema
        draft: page.draft
        defaults: page.defaults
        query: page.query
        tab: page.tabs.length ? page.tabs[0] : ""
        onEdited: (k, v) => page.edited(k, v)
        onPickRequested: (r) => page.pickRequested(r)
    }
}
