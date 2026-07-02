pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// Quick-ask body panel for the "\" prefix: one terse question to the Rashin
// agent (hermes), answered inline. Runs `ryoku-rashin ask` and parses its
// marker lines; while the agent works a pulsing dot names the current step
// (tool title / thinking / writing), and the finished answer offers a jump
// into the dashboard chat, which is the same session, already holding this
// conversation.
Item {
    id: root

    property real s: 1
    property string question: ""

    // idle -> working -> done | failed
    property string phase: "idle"
    property string working: ""
    property string answerText: ""
    property var answerImages: []
    property string errorText: ""
    property bool permPending: false

    readonly property bool busy: phase === "working"
    signal finished()

    implicitHeight: col.implicitHeight

    function reset() {
        askProc.running = false;
        phase = "idle";
        working = "";
        answerText = "";
        answerImages = [];
        errorText = "";
        permPending = false;
    }

    function run() {
        if (busy || question.trim().length === 0)
            return;
        answerText = "";
        answerImages = [];
        errorText = "";
        permPending = false;
        working = "waking the needle";
        phase = "working";
        askProc.command = ["ryoku-rashin", "ask", question.trim()];
        askProc.running = true;
    }

    function openDashboard() {
        Quickshell.execDetached(["xdg-open", "http://127.0.0.1:3600/#/chat"]);
        root.finished();
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
                        root.phase = "done";
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
        spacing: 7 * root.s

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
                id: pulse
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

        // the answer
        Text {
            width: parent.width
            visible: root.phase === "done"
            text: root.answerText
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: Metrics.fontSubtitle * root.s
            wrapMode: Text.WordWrap
            maximumLineCount: 10
            elide: Text.ElideRight
        }

        // image results (image_gen, screenshots) preview inline
        Row {
            visible: root.phase === "done" && root.answerImages.length > 0
            spacing: 8 * root.s

            Repeater {
                model: root.answerImages
                delegate: Image {
                    required property string modelData
                    source: "file://" + modelData
                    width: 96 * root.s
                    height: 96 * root.s
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
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

        // continue into the dashboard: same session, conversation already there
        Row {
            visible: root.phase === "done" || root.permPending
            spacing: 6 * root.s

            Rectangle {
                width: contRow.implicitWidth + 20 * root.s
                height: contRow.implicitHeight + 10 * root.s
                radius: 6 * root.s
                color: contHover.hovered ? Theme.verm : "transparent"
                border.color: Theme.verm
                border.width: 1

                Row {
                    id: contRow
                    anchors.centerIn: parent
                    spacing: 6 * root.s
                    Text {
                        text: root.permPending ? "APPROVE IN DASHBOARD" : "CONTINUE IN DASHBOARD"
                        color: contHover.hovered ? Theme.cardTop : Theme.verm
                        font.family: Theme.mono
                        font.pixelSize: Metrics.fontEyebrow * root.s
                        font.letterSpacing: 1
                    }
                }

                HoverHandler { id: contHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.openDashboard() }
            }

            Text {
                visible: root.phase === "done"
                anchors.verticalCenter: parent.verticalCenter
                text: "ESC dismisses"
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: Metrics.fontEyebrow * root.s
            }
        }
    }
}
