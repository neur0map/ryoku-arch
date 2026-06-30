import QtQuick
import QtQuick.Controls
import Quickshell
import "Singletons"

// The search row: the 力 brand glyph, the query field, a result counter, and a
// trailing Google-Lens button. The mode glyph recolors by active prefix so the
// user sees which provider a "/", "=", ";"... query is hitting.
Item {
    id: root

    property real s: 1
    property string text: ""
    property string mode: ""        // active provider id, or "" for default
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
        font.pixelSize: 20 * root.s
    }

    TextField {
        id: field
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: glyph.right
        anchors.leftMargin: 12 * root.s
        anchors.right: counter.left
        anchors.rightMargin: 10 * root.s
        background: null
        padding: 0
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: Metrics.fontSearch * root.s
        placeholderText: "Search, calculate or run"
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

    Text {
        id: counter
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: lens.left
        anchors.rightMargin: 12 * root.s
        text: root.text.length ? (root.resultCount + " / " + root.totalCount) : ""
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
        font.features: { "tnum": 1 }
    }

    Rectangle {
        id: songrec
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Metrics.padOuter * root.s
        width: 30 * root.s
        height: 30 * root.s
        radius: Metrics.radiusGlyph * root.s
        color: songrecArea.containsMouse ? Theme.frameBg : Qt.rgba(1, 1, 1, 0.04)

        Text {
            anchors.centerIn: parent
            text: "\udb83\udd1e"   // music glyph slot; nerd-font icon
            color: Theme.iconDim
            font.family: Theme.mono
            font.pixelSize: 14 * root.s
        }

        MouseArea {
            id: songrecArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["ryoku-cmd-songrec"]);
                root.dismissed();
            }
        }
    }

    Rectangle {
        id: lens
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: songrec.left
        anchors.rightMargin: 8 * root.s
        width: 30 * root.s
        height: 30 * root.s
        radius: Metrics.radiusGlyph * root.s
        color: lensArea.containsMouse ? Theme.frameBg : Qt.rgba(1, 1, 1, 0.04)

        Text {
            anchors.centerIn: parent
            text: "\udb80\udd6f"   // image-search glyph slot; nerd-font icon
            color: Theme.iconDim
            font.family: Theme.mono
            font.pixelSize: 14 * root.s
        }

        MouseArea {
            id: lensArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["ryoku-cmd-google-lens"]);
                root.dismissed();
            }
        }
    }
}
