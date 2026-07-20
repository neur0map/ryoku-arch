pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The layer's quick-note instrument: format chips that toggle a prefix on the
// composer's current line, a growing multi-line composer where Enter saves and
// Shift+Enter breaks the line, and the saved notes below as a scrolling list of
// selectable rows, each copyable and trashable. State lives in Notes.
Item {
    id: notes

    property var slot: null
    property bool active: false

    function stamp(ms) {
        var d = new Date(ms);
        var now = new Date();
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "HH:mm");
        return Qt.formatDate(d, "MMM d");
    }

    // ── format chips ─────────────────────────────────────────────────────
    Row {
        id: formatRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: Tokens.s2

        component FmtChip: Rectangle {
            id: chip
            property string label: ""
            signal act()
            width: ct.implicitWidth + Tokens.s3 * 2
            height: Tokens.ctlH - 6
            radius: Tokens.radius
            color: hh.hovered ? Tokens.tint10 : "transparent"
            border { width: Tokens.border; color: Tokens.line }
            Text {
                id: ct
                anchors.centerIn: parent
                text: chip.label
                color: Tokens.inkDim
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: chip.act() }
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        FmtChip { label: "BULLET"; onAct: composer.applyPrefix("bullet") }
        FmtChip { label: "NUMBER"; onAct: composer.applyPrefix("number") }
        FmtChip { label: "TODO"; onAct: composer.applyPrefix("todo") }
    }

    // ── composer ─────────────────────────────────────────────────────────
    Rectangle {
        id: composer
        anchors { top: formatRow.bottom; left: parent.left; right: parent.right; topMargin: Tokens.s3 }
        height: flick.height + Tokens.s2 * 2
        radius: Tokens.radius
        color: Tokens.paper
        border { width: Tokens.border; color: ta.activeFocus ? Tokens.lineStrong : Tokens.line }

        // toggle a line prefix on the line holding the cursor. Bullet/todo are
        // literal; a number takes the next ordinal across the whole composer.
        function applyPrefix(kind) {
            var full = ta.text;
            var pos = ta.cursorPosition;
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
                var m = line.match(/^\d+\. /);
                if (m) {
                    out = line.substring(m[0].length);
                } else {
                    var count = (full.match(/^\d+\. /gm) || []).length;
                    out = (count + 1) + ". " + line;
                }
            }
            var delta = out.length - line.length;
            ta.text = full.substring(0, lineStart) + out + full.substring(lineEnd);
            ta.cursorPosition = Math.max(lineStart, pos + delta);
            ta.forceActiveFocus();
        }

        FontMetrics { id: fm; font: ta.font }

        Flickable {
            id: flick
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s2 }
            // grows with content up to five lines, then scrolls.
            height: Math.min(Math.max(ta.contentHeight, fm.height), fm.height * 5)
            clip: true
            contentWidth: width
            contentHeight: ta.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            TextEdit {
                id: ta
                width: flick.width
                wrapMode: TextEdit.Wrap
                color: Tokens.ink
                selectByMouse: true
                selectionColor: Tokens.bone
                selectedTextColor: Tokens.inkOnBone
                font { family: Tokens.ui; pixelSize: Tokens.fBody }

                // Enter saves and clears; Shift+Enter falls through to the
                // native newline; copy/paste are left to the control.
                Keys.onPressed: (e) => {
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                        Notes.add(ta.text);
                        ta.clear();
                        e.accepted = true;
                    }
                }

                onCursorRectangleChanged: {
                    if (cursorRectangle.y < flick.contentY)
                        flick.contentY = cursorRectangle.y;
                    else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                        flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                }

                Text {
                    anchors.fill: parent
                    visible: ta.text.length === 0
                    text: "Quick note\u2026"
                    color: Tokens.inkFaint
                    font: ta.font
                }
            }
        }
    }

    // ── saved notes ──────────────────────────────────────────────────────
    Text {
        anchors { top: composer.bottom; left: parent.left; topMargin: Tokens.s4 }
        visible: Notes.notes.length === 0
        text: "Enter saves a note."
        color: Tokens.inkFaint
        font { family: Tokens.ui; pixelSize: Tokens.fSmall }
    }

    ListView {
        id: list
        anchors { top: composer.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Tokens.s3 }
        clip: true
        spacing: Tokens.s2
        model: (Notes.rev, Notes.notes)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        delegate: Rectangle {
            id: row
            required property var modelData
            width: ListView.view.width
            height: rowCol.implicitHeight + Tokens.s2 * 2
            radius: Tokens.radius
            color: rowHover.hovered ? Tokens.tint5 : "transparent"
            border { width: Tokens.border; color: Tokens.line }

            HoverHandler { id: rowHover }

            component MicroBtn: Rectangle {
                id: mb
                property string glyph: ""
                property bool flash: false
                signal act()
                width: 20; height: 20
                radius: Tokens.radius
                color: flash ? Tokens.bone : (mbHover.hovered ? Tokens.tint10 : "transparent")
                border { width: Tokens.border; color: mbHover.hovered ? Tokens.lineStrong : Tokens.line }
                Text {
                    anchors.centerIn: parent
                    text: mb.glyph
                    color: mb.flash ? Tokens.inkOnBone : Tokens.inkDim
                    font { family: Tokens.ui; pixelSize: 11 }
                }
                HoverHandler { id: mbHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: mb.act() }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            Column {
                id: rowCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s2 }
                spacing: Tokens.s1

                TextEdit {
                    width: parent.width - Tokens.s5
                    text: row.modelData.text
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Tokens.ink
                    selectionColor: Tokens.tint16
                    selectedTextColor: Tokens.ink
                    font { family: Tokens.ui; pixelSize: Tokens.fSmall }
                }

                Text {
                    text: notes.stamp(row.modelData.created)
                    color: Tokens.inkFaint
                    font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                }
            }

            Row {
                anchors { top: parent.top; right: parent.right; margins: Tokens.s2 }
                spacing: Tokens.s1
                visible: rowHover.hovered

                MicroBtn {
                    id: copyBtn
                    glyph: "\u2398"
                    onAct: {
                        Quickshell.execDetached(["wl-copy", row.modelData.text]);
                        flash = true;
                        copyFlash.restart();
                    }
                    Timer { id: copyFlash; interval: Motion.fast; onTriggered: copyBtn.flash = false }
                }
                MicroBtn {
                    glyph: "\u2715"
                    onAct: Notes.remove(row.modelData.id)
                }
            }
        }
    }
}
