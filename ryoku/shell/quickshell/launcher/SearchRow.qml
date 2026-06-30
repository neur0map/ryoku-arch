import QtQuick
import QtQuick.Controls
import Quickshell
import "Singletons"

// The search row: the 力 brand glyph, the query field, an active-mode chip, and a
// result counter. The mode chip names the command the current prefix routes to
// (FILE, PKG, CALC...), so it is always clear what a query will do.
Item {
    id: root

    property real s: 1
    property string text: ""
    property string modeLabel: ""   // e.g. "FILE", "PKG", "CALC"; "" at root
    property int resultCount: 0
    property int totalCount: 0
    readonly property alias input: field

    signal moved(int delta)
    signal accepted()
    signal dismissed()
    signal keyPressed(var event)

    height: Metrics.searchHeight * s

    function focusField() { field.forceActiveFocus(); }
    function clear() { field.text = ""; }

    Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Metrics.padOuter * root.s
        text: "力"
        color: Theme.brand
        font.family: Theme.fontJp
        font.weight: Font.Medium
        font.pixelSize: 19 * root.s
    }

    TextField {
        id: field
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: glyph.right
        anchors.leftMargin: 12 * root.s
        anchors.right: chip.left
        anchors.rightMargin: 10 * root.s
        background: null
        padding: 0
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: Metrics.fontSearch * root.s
        placeholderText: "Search apps, type / for commands"
        placeholderTextColor: Theme.faint
        selectByMouse: true
        selectionColor: Theme.verm
        onTextChanged: root.text = text
        Keys.onUpPressed: root.moved(-1)
        Keys.onDownPressed: root.moved(1)
        Keys.onPressed: (e) => {
            root.keyPressed(e);
            if (e.accepted)
                return;
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.accepted();
                e.accepted = true;
            } else if (e.key === Qt.Key_Escape) {
                root.dismissed();
                e.accepted = true;
            }
        }
    }

    // active-mode chip: a small vermilion-tinted pill naming the command the
    // current prefix routes to. Hidden at the root (plain app search).
    Rectangle {
        id: chip
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: counter.left
        anchors.rightMargin: root.modeLabel.length ? 10 * root.s : 0
        width: root.modeLabel.length ? chipText.implicitWidth + 16 * root.s : 0
        height: 20 * root.s
        radius: 6 * root.s
        visible: root.modeLabel.length > 0
        color: Theme.frameBg
        border.width: 1
        border.color: Theme.frameBorder

        Text {
            id: chipText
            anchors.centerIn: parent
            text: root.modeLabel
            color: Theme.vermLit
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
            font.letterSpacing: 1
        }
    }

    Text {
        id: counter
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Metrics.padOuter * root.s
        text: root.text.length ? (root.resultCount + " / " + root.totalCount) : ""
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10 * root.s
        font.features: { "tnum": 1 }
    }
}
