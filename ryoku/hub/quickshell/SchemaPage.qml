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
    property alias styleKey: sheet.styleKey
    default property alias extras: extraSlot.data
    property var pendingImageRow: null

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

        Item {
            width: parent.width
            height: 14
            Row {
                id: ebrow
                spacing: Tokens.s2
                anchors.verticalCenter: parent.verticalCenter
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
            // the band runs to the page edge and closes with the sheet's marks:
            // a register cross and the /// cluster, per the reference poster.
            Rectangle {
                anchors { left: ebrow.right; right: crossMark.left; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3
                height: 1; color: Tokens.lineSoft
            }
            Text {
                id: crossMark
                anchors { right: slashMark.left; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                text: "+"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
            }
            Text {
                id: slashMark
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "///"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
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
        Tabs {
            visible: page.tabs.length > 1
            options: page.tabs
            current: sheet.tab
            onChose: (label) => sheet.tab = label
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
        onImagePickRequested: (r) => { page.pendingImageRow = r; imgPick.open(); }
    }

    // the image-mark picker: an `image` control asks for it (SettingsSheet emits
    // imagePickRequested); the chosen path lands on the row's key like any edit.
    // full-page overlay so it covers the tabs, not just the sheet.
    PickFile {
        id: imgPick
        title: "Choose an image"
        onPicked: (p) => {
            if (page.pendingImageRow) page.edited(page.pendingImageRow.key, ("" + p).replace("file://", ""));
            imgPick.active = false;
        }
        onCanceled: imgPick.active = false
    }
}
