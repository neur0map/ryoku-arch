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

    // edit mode: while editId >= 0 the field holds an existing event (loaded via
    // beginEdit) and Enter replaces it in place on editDate instead of adding a
    // new note. Esc, or losing focus mid-edit, drops back to add mode.
    property int editId: -1
    property string editDate: ""
    readonly property bool editingEntry: root.editId >= 0

    function beginEdit(ev) {
        root.editId = ev.id;
        root.editDate = ev.date;
        field.text = root.lineFor(ev);
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
    }
    function cancelEdit() {
        root.editId = -1;
        root.editDate = "";
        field.text = "";
    }
    // recompose an event into an editable line: "HH:MM text", "HH:MM-HH:MM
    // text", or just the text for an all-day note.
    function lineFor(ev) {
        var pre = "";
        if (ev.time && ev.time.length > 0)
            pre = (ev.endTime && ev.endTime.length > 0 ? ev.time + "-" + ev.endTime : ev.time) + " ";
        return pre + (ev.text || "");
    }

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
            if (root.editingEntry) {
                if (Events.update(root.editId, root.editDate, text))
                    root.cancelEdit();
            } else if (Events.addEntry(root.dateKey, text)) {
                text = "";
            }
        }
        // drop an in-progress edit when focus leaves without committing.
        onActiveFocusChanged: if (!field.activeFocus && root.editingEntry) root.cancelEdit()
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                root.cancelEdit();
                field.focus = false;
                e.accepted = true;
            }
        }
    }
}
