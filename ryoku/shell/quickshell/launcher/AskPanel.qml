pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// Quick-ask body panel for the "\" prefix: one terse question to the Rashin
// agent (hermes), answered inline. Runs `ryoku-rashin ask` and parses its
// marker lines; while the agent works a pulsing dot names the current step
// (tool title / thinking / writing). The finished answer is selectable text
// over a row of action chips: COPY, then every entity the daemon detected in
// the answer (files edit in nvim, folders open, URLs browse, commands and
// colors copy), then the jump into the dashboard chat, which is the same
// session, already holding this conversation. Chips walk with Up/Down or
// Tab and fire with Enter.
Item {
    id: root

    property real s: 1
    property string question: ""

    // idle -> working -> done | failed
    property string phase: "idle"
    property string working: ""
    property string answerText: ""
    property var answerImages: []
    property var answerActions: []
    property string errorText: ""
    property bool permPending: false
    property string askedQuestion: ""
    property int selectedChip: 0
    property string flash: "" // transient "copied" feedback per chip value

    readonly property bool busy: phase === "working"
    // Enter re-asks when the query moved on from what produced this answer.
    readonly property bool answerCurrent: phase === "done" && question.trim() === askedQuestion
    readonly property var chips: {
        if (phase !== "done" && !permPending)
            return [];
        var c = [];
        if (permPending) {
            c.push({ kind: "dash", value: "", label: "APPROVE IN DASHBOARD" });
            return c;
        }
        c.push({ kind: "copy", value: answerText, label: "COPY" });
        for (var i = 0; i < answerActions.length; i++)
            c.push(answerActions[i]);
        c.push({ kind: "dash", value: "", label: "DASHBOARD" });
        return c;
    }

    signal finished()

    implicitHeight: col.implicitHeight

    function reset() {
        askProc.running = false;
        phase = "idle";
        working = "";
        answerText = "";
        answerImages = [];
        answerActions = [];
        errorText = "";
        permPending = false;
        askedQuestion = "";
        selectedChip = 0;
        flash = "";
    }

    function run() {
        if (busy || question.trim().length === 0)
            return;
        answerText = "";
        answerImages = [];
        answerActions = [];
        errorText = "";
        permPending = false;
        flash = "";
        selectedChip = 0;
        askedQuestion = question.trim();
        working = "waking the needle";
        phase = "working";
        askProc.command = ["ryoku-rashin", "ask", askedQuestion];
        askProc.running = true;
    }

    function move(d) {
        if (chips.length === 0)
            return;
        selectedChip = Math.max(0, Math.min(chips.length - 1, selectedChip + d));
    }

    function activate() {
        var chip = chips[selectedChip];
        if (chip)
            root.fire(chip);
    }

    // What each chip kind does. Copyables flash COPIED in place; openers close
    // the launcher because focus moves to another window.
    function fire(chip) {
        switch (chip.kind) {
        case "copy":
        case "cmd":
        case "color":
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", String(chip.value)]);
            root.flash = chip.kind + "\u0000" + chip.value;
            flashTimer.restart();
            return;
        case "file":
            Quickshell.execDetached(["kitty", "-e", "nvim", String(chip.value)]);
            break;
        case "dir":
            Quickshell.execDetached(["xdg-open", String(chip.value)]);
            break;
        case "url":
            Quickshell.execDetached(["xdg-open", String(chip.value)]);
            break;
        case "dash":
            Quickshell.execDetached(["xdg-open", "http://127.0.0.1:3600/#/chat"]);
            break;
        }
        root.finished();
    }

    function chipCaption(chip) {
        if (root.flash === chip.kind + "\u0000" + chip.value)
            return "COPIED";
        switch (chip.kind) {
        case "file": return "nvim " + chip.label;
        case "dir": return "open " + chip.label;
        case "url": return chip.label;
        case "cmd": return "$ " + chip.label;
        case "color": return chip.label;
        default: return chip.label;
        }
    }

    Timer {
        id: flashTimer
        interval: 1400
        onTriggered: root.flash = ""
    }

    Process {
        id: askProc
        stdout: SplitParser {
            onRead: (line) => {
                line = String(line);
                if (line.indexOf("@working ") === 0) {
                    root.working = line.slice(9);
                } else if (line.indexOf("@perm ") === 0) {
                    root.permPending = true;
                    root.working = "waiting for approval: " + line.slice(6);
                } else if (line.indexOf("@answer ") === 0) {
                    try {
                        var a = JSON.parse(line.slice(8));
                        root.answerText = String(a.text || "");
                        root.answerImages = a.images || [];
                        root.answerActions = a.actions || [];
                        root.phase = "done";
                        root.selectedChip = 0;
                    } catch (e) {
                        root.errorText = "unreadable answer";
                        root.phase = "failed";
                    }
                } else if (line.indexOf("@error ") === 0) {
                    root.errorText = line.slice(7);
                    root.phase = "failed";
                }
            }
        }
        onExited: (code) => {
            if (root.phase === "working") {
                root.errorText = code === 0 ? "no answer" : "ask failed";
                root.phase = "failed";
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 8 * root.s

        Text {
            width: parent.width
            text: "RASHIN"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: Metrics.fontEyebrow * root.s
            font.letterSpacing: 1
        }

        // idle hint
        Text {
            width: parent.width
            visible: root.phase === "idle"
            text: root.question.trim().length === 0
                ? "Ask the needle anything. ENTER sends; one terse answer comes back."
                : "ENTER to ask: " + root.question.trim()
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Metrics.fontSubtitle * root.s
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // working strip: pulsing dot + live activity from the agent stream
        Row {
            visible: root.busy
            spacing: 8 * root.s

            Rectangle {
                width: 8 * root.s
                height: 8 * root.s
                radius: width / 2
                color: root.permPending ? Theme.verm : Theme.flameGlow
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 550; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 550; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                text: root.working
                color: Theme.subtle
                font.family: Theme.mono
                font.pixelSize: Metrics.fontSubtitle * root.s
                font.letterSpacing: 1
                elide: Text.ElideRight
            }
        }

        // the answer: selectable, so any fragment can be mouse-copied
        TextEdit {
            width: parent.width
            visible: root.phase === "done"
            text: root.answerText
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: Metrics.fontSubtitle * root.s
            wrapMode: TextEdit.Wrap
            readOnly: true
            selectByMouse: true
            selectionColor: Theme.vermDimDeep
            selectedTextColor: Theme.bright
            persistentSelection: false
        }

        // image results (image_gen, screenshots) preview inline; click opens
        Row {
            visible: root.phase === "done" && root.answerImages.length > 0
            spacing: 8 * root.s

            Repeater {
                model: root.answerImages
                delegate: Image {
                    id: thumb
                    required property string modelData
                    source: "file://" + modelData
                    width: 96 * root.s
                    height: 96 * root.s
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached(["xdg-open", thumb.modelData]);
                            root.finished();
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.phase === "failed"
            text: root.errorText
            color: Theme.verm
            font.family: Theme.mono
            font.pixelSize: Metrics.fontSubtitle * root.s
            wrapMode: Text.WordWrap
            maximumLineCount: 3
        }

        // action chips: COPY | detected entities | DASHBOARD
        Flow {
            width: parent.width
            visible: root.chips.length > 0
            spacing: 6 * root.s

            Repeater {
                model: root.chips
                delegate: Rectangle {
                    id: chipBox
                    required property var modelData
                    required property int index

                    readonly property bool current: index === root.selectedChip
                    width: chipRow.implicitWidth + 18 * root.s
                    height: chipRow.implicitHeight + 10 * root.s
                    radius: 6 * root.s
                    color: current || chipHover.hovered ? Theme.verm : "transparent"
                    border.color: current || chipHover.hovered ? Theme.verm : Theme.border
                    border.width: 1

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6 * root.s

                        // color chips carry a live swatch
                        Rectangle {
                            visible: chipBox.modelData.kind === "color"
                            width: 10 * root.s
                            height: 10 * root.s
                            radius: 2
                            color: String(chipBox.modelData.value)
                            border.color: Theme.hair
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.chipCaption(chipBox.modelData)
                            color: chipBox.current || chipHover.hovered ? Theme.cardTop : Theme.subtle
                            font.family: Theme.mono
                            font.pixelSize: Metrics.fontEyebrow * root.s
                            font.letterSpacing: 1
                        }
                    }

                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.fire(chipBox.modelData) }
                }
            }
        }

        // key hints under the chips
        Text {
            visible: root.chips.length > 0 && !root.permPending
            text: "\u2191\u2193 walk chips \u00b7 ENTER fires \u00b7 type to re-ask \u00b7 ESC dismisses"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: Metrics.fontEyebrow * root.s
        }
    }
}
