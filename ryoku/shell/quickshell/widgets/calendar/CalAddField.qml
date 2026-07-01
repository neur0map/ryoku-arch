pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../Singletons"

// the one add-a-note input, shared by every editable calendar face. writes to
// the shared Events store (which the pill's calendar reads too), splitting an
// optional leading HH:MM off the line. `editing` is true while it holds focus,
// so the host can grab the keyboard for typing on the wallpaper layer.
Rectangle {
    id: root

    property string dateKey: ""
    property real s: 1
    property color accent: Theme.ink
    readonly property alias editing: field.activeFocus

    height: Math.round(28 * root.s)
    radius: Math.round(8 * root.s)
    color: field.activeFocus
        ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08)
        : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04)
    border.width: 1
    border.color: field.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5) : Theme.hair
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    TextField {
        id: field
        anchors.fill: parent
        anchors.leftMargin: Math.round(10 * root.s)
        anchors.rightMargin: Math.round(10 * root.s)
        verticalAlignment: TextInput.AlignVCenter
        background: null
        padding: 0
        color: Theme.ink
        font.family: Theme.font
        font.pixelSize: Math.round(11 * root.s)
        placeholderText: "Add a note (e.g. 09:30 standup)"
        placeholderTextColor: Theme.faint
        selectByMouse: true
        selectionColor: root.accent
        onAccepted: {
            if (Events.addEntry(root.dateKey, text))
                text = "";
        }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                field.text = "";
                field.focus = false;
                e.accepted = true;
            }
        }
    }
}
