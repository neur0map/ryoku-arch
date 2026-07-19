pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The source is the page's identity, so choosing it is a catalogue overlay, not
// a toolbar toggle. Built on the module Picker grammar (paperLift, lineStrong,
// radius 2, a filter field, rows that invert under the pointer, the current row
// dotted) with the two things a font list never needs: a remove affordance on
// library rows and an add-library field in the footer.
Item {
    id: picker
    property bool open: false
    property var builtins: []
    signal dismissed()

    property string filter: ""

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

    onOpenChanged: {
        if (open) { picker.filter = ""; filterField.clear(); filterField.grabFocus(); }
    }

    function allRows() {
        var out = [];
        for (var i = 0; i < builtins.length; i++)
            out.push({ kind: "builtin", key: builtins[i].key, label: builtins[i].label, sub: "" });
        var libs = Wallhaven.libraries;
        for (var j = 0; j < libs.length; j++)
            out.push({ kind: "lib", key: libs[j].repo, label: libs[j].name || libs[j].repo, sub: libs[j].repo, lib: libs[j] });
        return out;
    }
    readonly property var shown: allRows().filter(function (r) {
        return picker.filter === "" || r.label.toLowerCase().indexOf(picker.filter.toLowerCase()) >= 0
            || (r.sub && r.sub.toLowerCase().indexOf(picker.filter.toLowerCase()) >= 0);
    })
    readonly property int total: builtins.length + Wallhaven.libraries.length

    function isCurrent(r) {
        if (r.kind === "lib") return Wallhaven.source === "lib" && Wallhaven.libraryRepo === r.key;
        return Wallhaven.source === r.key;
    }
    function choose(r) {
        if (r.kind === "lib") Wallhaven.setLibrary(r.lib);
        else Wallhaven.setSource(r.key);
        picker.dismissed();
    }

    // scrim: the one translucency exception. Kept deep so the floating card
    // separates cleanly from the busy grid behind it instead of dissolving in.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.78)
        TapHandler { onTapped: picker.dismissed() }
    }

    // a drawer genuinely floats over the page, so it earns a shadow (the one
    // depth the ink-on-paper rule allows), lifting the card clear of the grid.
    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.7)
        shadowBlur: 1.0
        shadowVerticalOffset: 10
        blurMax: 48
        autoPaddingEnabled: true
    }

    Rectangle {
        id: card
        width: 360
        height: 440
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 92
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineStrong
        // swallow taps so a click inside the card does not dismiss it.
        TapHandler {}

        Column {
            anchors.fill: parent
            anchors.margins: Tokens.s3
            spacing: Tokens.s2

            Row {
                width: parent.width
                Text {
                    text: "SOURCE"
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackLabel
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: parent.width - 190; height: 1 }
                Text {
                    text: picker.shown.length + " / " + picker.total
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Field {
                id: filterField
                width: parent.width
                placeholder: "Filter sources…"
                onEdited: (v) => picker.filter = v
                onCommitted: if (picker.shown.length) picker.choose(picker.shown[0])
            }

            Flickable {
                width: parent.width
                height: parent.height - 118
                contentHeight: rows.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail {}

                Column {
                    id: rows
                    width: parent.width
                    Repeater {
                        model: picker.shown
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool current: picker.isCurrent(modelData)
                            width: rows.width
                            height: modelData.sub && modelData.sub.length > 0 ? 40 : 30
                            color: rh.hovered ? Tokens.bone : "transparent"
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.s2
                                anchors.right: rm.left
                                anchors.rightMargin: Tokens.s2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: row.modelData.label
                                    color: rh.hovered ? Tokens.inkOnBone : (row.current ? Tokens.ink : Tokens.inkDim)
                                    font.family: Tokens.ui
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    visible: row.modelData.sub && row.modelData.sub.length > 0
                                    text: row.modelData.sub
                                    color: rh.hovered ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                    font.family: Tokens.mono
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }
                            // current value: a right-aligned dot, per the pick grammar.
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.s2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.current && !(row.modelData.kind === "lib" && rh.hovered)
                                text: "●"
                                color: rh.hovered ? Tokens.inkOnBone : Tokens.ink
                                font.pixelSize: 7
                            }
                            // library rows: a remove affordance on hover.
                            Text {
                                id: rm
                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.s2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.modelData.kind === "lib" && rh.hovered
                                text: "✕"
                                color: Tokens.inkOnBone
                                font.family: Tokens.ui
                                font.pixelSize: 12
                                TapHandler { onTapped: Wallhaven.removeLibrary(row.modelData.key) }
                            }

                            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: picker.choose(row.modelData) }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Tokens.lineSoft }

            // footer: add any GitHub repo of wallpapers. mono, it is file truth.
            Field {
                id: addField
                width: parent.width
                tabular: true
                placeholder: "owner/repo@branch"
                onCommitted: (v) => { if (v.trim().length > 0) { Wallhaven.addLibrary(v); addField.clear(); picker.dismissed(); } }
            }
        }
    }
}
