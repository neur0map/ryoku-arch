pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The layer's quick-note instrument, editor-first: one note fills the body, a
// nav carousel steps between notes, and Shift+Enter continues a list while
// Enter commits (with a debounced autosave net so nothing is lost). Format
// chips toggle a prefix on the current line. State lives in Notes.
Item {
    id: notes

    property var slot: null
    property bool active: false

    // which note the editor currently holds; reload the buffer only when the
    // identity changes (navigation / new / trash), never on a plain keystroke.
    property double shownId: -1
    property bool flashOn: false
    property bool copyFlash: false
    property bool allArmed: false

    function stamp(ms) {
        var d = new Date(ms);
        var now = new Date();
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "HH:mm");
        return Qt.formatDate(d, "MMM d");
    }

    function syncEditor() {
        if (Notes.currentId !== notes.shownId) {
            editor.text = Notes.currentText;
            notes.shownId = Notes.currentId;
        }
    }
    // save the buffer back to the note it was loaded from, never the live
    // current: a debounced autosave firing after a navigation must not overwrite
    // the newly-shown note with the previous one's text.
    function flush() {
        autosave.stop();
        Notes.saveNote(notes.shownId, editor.text);
    }
    function commit() {
        notes.flush();
        notes.flashOn = true;
        stampFlashT.restart();
    }

    // Shift+Enter list continuation (Whisp's handle_return, reimplemented):
    // continue the current line's list marker onto the next, or terminate an
    // empty item into a plain line. Indent is preserved verbatim.
    function continueList() {
        var full = editor.text;
        var pos = editor.cursorPosition;
        var lineStart = full.lastIndexOf("\n", pos - 1) + 1;
        var lineEnd = full.indexOf("\n", pos);
        if (lineEnd < 0)
            lineEnd = full.length;
        var line = full.substring(lineStart, lineEnd);
        var ins = "\n";
        var m;
        if ((m = line.match(/^(\s*)- (.*)$/)) !== null) {
            if (m[2].length === 0) { notes.terminateList(lineStart, lineEnd, m[1]); return; }
            ins = "\n" + m[1] + "- ";
        } else if ((m = line.match(/^(\s*)(\d+)\. (.*)$/)) !== null) {
            if (m[3].length === 0) { notes.terminateList(lineStart, lineEnd, m[1]); return; }
            ins = "\n" + m[1] + (parseInt(m[2], 10) + 1) + ". ";
        } else if ((m = line.match(/^(\s*)\[([ x])\] (.*)$/)) !== null) {
            if (m[3].length === 0) { notes.terminateList(lineStart, lineEnd, m[1]); return; }
            ins = "\n" + m[1] + "[ ] ";
        }
        editor.text = full.substring(0, pos) + ins + full.substring(pos);
        editor.cursorPosition = pos + ins.length;
    }
    function terminateList(lineStart, lineEnd, indent) {
        var full = editor.text;
        editor.text = full.substring(0, lineStart) + indent + full.substring(lineEnd);
        editor.cursorPosition = lineStart + indent.length;
    }

    // toggle a line prefix on the line holding the cursor. Bullet/todo are
    // literal; a number takes the line above's ordinal + 1 (else 1).
    function applyPrefix(kind) {
        var full = editor.text;
        var pos = editor.cursorPosition;
        var lineStart = full.lastIndexOf("\n", pos - 1) + 1;
        var lineEnd = full.indexOf("\n", pos);
        if (lineEnd < 0)
            lineEnd = full.length;
        var line = full.substring(lineStart, lineEnd);
        var out;
        if (kind === "bullet") {
            out = line.substring(0, 2) === "- " ? line.substring(2) : "- " + line;
        } else if (kind === "todo") {
            out = line.substring(0, 4) === "[ ] " ? line.substring(4) : "[ ] " + line;
        } else {
            var nm = line.match(/^\d+\. /);
            if (nm) {
                out = line.substring(nm[0].length);
            } else {
                var n = 1;
                if (lineStart > 0) {
                    var prevStart = full.lastIndexOf("\n", lineStart - 2) + 1;
                    var pm = full.substring(prevStart, lineStart - 1).match(/^\s*(\d+)\. /);
                    if (pm)
                        n = parseInt(pm[1], 10) + 1;
                }
                out = n + ". " + line;
            }
        }
        var delta = out.length - line.length;
        editor.text = full.substring(0, lineStart) + out + full.substring(lineEnd);
        editor.cursorPosition = Math.max(lineStart, pos + delta);
        editor.forceActiveFocus();
    }

    Connections {
        target: Notes
        function onChanged() { notes.syncEditor(); }
    }
    Component.onCompleted: notes.syncEditor()
    onActiveChanged: if (!active) notes.flush()

    Timer { id: autosave; interval: 1000; onTriggered: notes.flush() }
    Timer { id: stampFlashT; interval: Motion.fast; onTriggered: notes.flashOn = false }
    Timer { id: copyFlashT; interval: Motion.fast; onTriggered: notes.copyFlash = false }
    Timer { id: allT; interval: 2000; onTriggered: notes.allArmed = false }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool bone: false
        signal act()
        width: ct.implicitWidth + Tokens.s2 * 2
        height: Tokens.ctlH - 6
        radius: Tokens.radius
        color: bone ? Tokens.bone : (hh.hovered ? Tokens.tint10 : "transparent")
        border { width: Tokens.border; color: bone ? Tokens.bone : Tokens.line }
        Text {
            id: ct
            anchors.centerIn: parent
            text: chip.label
            color: chip.bone ? Tokens.inkOnBone : Tokens.inkDim
            font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
        }
        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.act() }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    // ── nav carousel ─────────────────────────────────────────────────────
    Item {
        id: navRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Tokens.ctlH - 6

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2
            Chip { label: "\u2039"; onAct: { notes.flush(); Notes.prev(); } }
            Chip { label: "\u203a"; onAct: { notes.flush(); Notes.next(); } }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (Notes.rev, (Notes.index + 1) + "/" + Notes.count)
                color: Tokens.inkFaint
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            Chip { label: "+"; onAct: { notes.flush(); Notes.newNote(); } }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (Notes.rev, Notes.currentCreated ? notes.stamp(Notes.currentCreated) : "")
                color: notes.flashOn ? Tokens.bone : Tokens.inkFaint
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            Chip {
                label: "COPY"
                bone: notes.copyFlash
                onAct: {
                    Quickshell.execDetached(["wl-copy", editor.text]);
                    notes.copyFlash = true;
                    copyFlashT.restart();
                }
            }
            Chip { label: "TRASH"; onAct: { autosave.stop(); Notes.removeCurrent(); } }
            Chip {
                label: notes.allArmed ? "SURE?" : "ALL"
                bone: notes.allArmed
                onAct: {
                    if (notes.allArmed) {
                        autosave.stop();
                        Notes.removeAll();
                        notes.allArmed = false;
                        allT.stop();
                    } else {
                        notes.allArmed = true;
                        allT.restart();
                    }
                }
            }
        }
    }

    // ── format chips ─────────────────────────────────────────────────────
    Row {
        id: formatRow
        anchors { top: navRow.bottom; left: parent.left; right: parent.right; topMargin: Tokens.s3 }
        spacing: Tokens.s2
        Chip { label: "BULLET"; onAct: notes.applyPrefix("bullet") }
        Chip { label: "NUMBER"; onAct: notes.applyPrefix("number") }
        Chip { label: "TODO"; onAct: notes.applyPrefix("todo") }
    }

    // ── the editor: one note, filling the body ───────────────────────────
    Rectangle {
        id: editorBox
        anchors { top: formatRow.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Tokens.s3 }
        radius: Tokens.radius
        color: Tokens.paper
        border { width: Tokens.border; color: editor.activeFocus ? Tokens.lineStrong : Tokens.line }

        Flickable {
            id: eflick
            anchors { fill: parent; margins: Tokens.s4 }
            clip: true
            contentWidth: width
            contentHeight: editor.height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            TextEdit {
                id: editor
                width: eflick.width
                // fill the viewport so the whole body is a click target and the
                // cursor lands anywhere the user taps; grow past it to scroll.
                height: Math.max(implicitHeight, eflick.height)
                wrapMode: TextEdit.Wrap
                color: Tokens.ink
                selectByMouse: true
                selectionColor: Tokens.bone
                selectedTextColor: Tokens.inkOnBone
                font { family: Tokens.ui; pixelSize: Tokens.fBody }

                onTextChanged: autosave.restart()

                // Enter commits; Shift+Enter continues the list; copy/paste are
                // left to the control.
                Keys.onPressed: (e) => {
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter)
                        return;
                    e.accepted = true;
                    if (e.modifiers & Qt.ShiftModifier)
                        notes.continueList();
                    else
                        notes.commit();
                }

                onCursorRectangleChanged: {
                    if (cursorRectangle.y < eflick.contentY)
                        eflick.contentY = cursorRectangle.y;
                    else if (cursorRectangle.y + cursorRectangle.height > eflick.contentY + eflick.height)
                        eflick.contentY = cursorRectangle.y + cursorRectangle.height - eflick.height;
                }

                Text {
                    anchors.fill: parent
                    visible: editor.text.length === 0
                    text: "Quick note\u2026"
                    color: Tokens.inkFaint
                    font: editor.font
                }

                // Toggle a todo checkbox when its leading [ ]/[x] token is
                // clicked; every other press falls through untouched so cursor
                // placement and selection keep working. Editing just the state
                // character (remove+insert) preserves cursor, scroll, selection
                // and undo, and the textChanged->autosave path persists it.
                MouseArea {
                    anchors.fill: parent
                    onPressed: (mouse) => {
                        var pos = editor.positionAt(mouse.x, mouse.y);
                        var full = editor.text;
                        var lineStart = full.lastIndexOf("\n", pos - 1) + 1;
                        var lineEnd = full.indexOf("\n", pos);
                        if (lineEnd < 0)
                            lineEnd = full.length;
                        var m = full.substring(lineStart, lineEnd).match(/^(\s*)\[([ x])\]/);
                        if (m) {
                            var tokEnd = lineStart + m[0].length;
                            if (full.charAt(tokEnd) === " ")
                                tokEnd += 1;
                            if (pos >= lineStart && pos <= tokEnd) {
                                var statePos = lineStart + m[1].length + 1;
                                editor.remove(statePos, statePos + 1);
                                editor.insert(statePos, m[2] === " " ? "x" : " ");
                                mouse.accepted = true;
                                return;
                            }
                        }
                        mouse.accepted = false;
                    }
                }
            }
        }
    }
}
