pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// Updates section, wired to `ryoku status --json` via the Updates singleton.
// idle = live status + the real list of incoming commits. "Update now" runs
// the real `ryoku update` in a terminal; this page mirrors progress from the
// run-state file the CLI publishes. when the system is current there are no
// rows and the top-right island stays hidden.
Item {
    id: page

    // --- automatic-check schedule (persisted in the hub's TOML) -------------
    property string interval: "daily"

    readonly property var intervalModel: [
        { "key": "off",    "label": "Off" },
        { "key": "hourly", "label": "Hourly" },
        { "key": "daily",  "label": "Daily" },
        { "key": "weekly", "label": "Weekly" }
    ]

    function intervalBlurb(k) {
        switch (k) {
        case "off":    return "manual only";
        case "hourly": return "every hour";
        case "weekly": return "once a week";
        default:       return "once a day";
        }
    }

    function setInterval(k) {
        if (page.interval === k)
            return;
        page.interval = k;
        saveInterval.command = ["ryoku-hub", "config", "set", "update_interval", k];
        saveInterval.running = true;
    }

    Process {
        id: loadInterval
        command: ["ryoku-hub", "config", "get", "update_interval"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var v = this.text.trim();
                if (v === "off" || v === "hourly" || v === "daily" || v === "weekly")
                    page.interval = v;
            }
        }
    }

    Process { id: saveInterval }

    // re-check on the configured cadence.
    readonly property int intervalMs: {
        switch (page.interval) {
        case "hourly": return 3600 * 1000;
        case "weekly": return 7 * 24 * 3600 * 1000;
        default:       return 24 * 3600 * 1000;
        }
    }

    Timer {
        interval: page.intervalMs
        running: page.interval !== "off"
        repeat: true
        onTriggered: Updates.check()
    }

    // --- live run state (published by `ryoku update`) -----------------------
    property string phase: "idle"   // idle | running | prompt | done | error
    property real progress: 0
    property string label: ""
    property var steps: []
    property var logLines: []
    property string errorMsg: ""
    property string snapshot: ""
    property string promptTitle: ""
    property string promptDetail: ""
    property var promptOptions: []
    readonly property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-update.json"
    readonly property string answerPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-update-answer"

    FileView {
        id: stateFile
        path: page.statePath
        watchChanges: true
        atomicWrites: false
        onLoaded: page.applyState(stateFile.text())
        onFileChanged: stateFile.reload()
        onLoadFailed: page.phase = "idle"
    }

    function applyState(t) {
        var prev = page.phase;
        try {
            var o = JSON.parse(t);
            page.phase = o.phase || "idle";
            page.progress = (typeof o.progress === "number") ? o.progress : 0;
            page.label = o.label || "";
            page.steps = o.steps || [];
            page.logLines = o.log || [];
            page.errorMsg = o.error || "";
            page.snapshot = o.snapshot || "";
            if (page.phase === "prompt" && o.prompt) {
                page.promptTitle = o.prompt.title || "";
                page.promptDetail = o.prompt.detail || "";
                page.promptOptions = o.prompt.options || [];
            }
        } catch (e) {
            page.phase = "idle";
            page.progress = 0;
            page.steps = [];
            page.logLines = [];
            page.errorMsg = "";
        }
        // settled back to idle = finished. refresh so the list clears.
        if (prev !== "idle" && page.phase === "idle")
            Updates.check();
    }

    // answer a prompt phase: write the choice to the back-channel `ryoku update`
    // is polling (positional args, so a quote in the label can't break out),
    // then optimistically resume the running view so the buttons clear.
    function answer(choice) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", choice, page.answerPath]);
        page.phase = "running";
    }

    // guide restoring the pre-update snapshot after a failed run, in a terminal
    // (`ryoku rollback` prints the boot-menu restore steps and exits, so hold
    // the window for the user to read), then clear the error state.
    function rollback() {
        if (page.snapshot === "")
            return;
        Quickshell.execDetached(["kitty", "-e", "sh", "-c", "ryoku rollback \"$1\"; printf '\\npress enter to close '; read -r _", "sh", page.snapshot]);
        page.dismiss();
    }

    // dismiss a finished/failed run: clear the run-state file so the page and
    // island return to idle.
    function dismiss() {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '{\"phase\":\"idle\"}' > \"$1\"", "sh", page.statePath]);
        page.phase = "idle";
        Updates.check();
    }

    function startUpdate() {
        Quickshell.execDetached(["kitty", "-e", "sh", "-c", "RYOKU_UPDATE_UI=hub exec ryoku update"]);
    }

    // --- idle: status + pending updates -------------------------------------
    Flickable {
        id: flick
        visible: page.phase === "idle"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: 6
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: Theme.radius
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Column {
            id: col
            width: flick.width - 10
            spacing: 26
            topPadding: 4
            bottomPadding: 14

            Item {
                width: col.width
                implicitHeight: Math.max(status.implicitHeight, autoCol.implicitHeight)

                UpdateStatus {
                    id: status
                    anchors.left: parent.left
                    anchors.right: autoCol.left
                    anchors.rightMargin: 32
                    anchors.top: parent.top
                }

                Column {
                    id: autoCol
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    spacing: 9

                    Text {
                        anchors.right: parent.right
                        text: "AUTOMATIC CHECKS"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }

                    Segmented {
                        anchors.right: parent.right
                        model: page.intervalModel
                        current: page.interval
                        onSelected: (k) => page.setInterval(k)
                    }

                    Text {
                        anchors.right: parent.right
                        text: page.intervalBlurb(page.interval)
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
            }

            Column {
                width: col.width
                spacing: 0

                Item {
                    width: parent.width
                    height: 30

                    Text {
                        id: secLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INCOMING COMMITS"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }

                    Rectangle {
                        anchors.left: secLabel.right
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1
                        color: Theme.lineSoft
                    }
                }

                Repeater {
                    model: Updates.updates

                    delegate: UpdateRow {
                        required property var modelData
                        required property int index
                        width: col.width
                        name: modelData.name
                        fromVersion: modelData.old
                        toVersion: modelData.new
                        first: index === 0
                        last: index === Updates.updates.length - 1
                    }
                }

                Text {
                    visible: Updates.updates.length === 0
                    text: "Everything is up to date."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 13
                    topPadding: 6
                    leftPadding: 40
                }
            }
        }
    }

    // --- running / done panel: the ordered stages as a determinate bar ------
    Item {
        visible: page.phase === "running" || page.phase === "done"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top

        Column {
            anchors.centerIn: parent
            width: parent.width - 72
            spacing: 22

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    tint: Theme.ember
                    visible: page.phase === "running"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.phase === "done"
                    text: "\u2713"
                    color: Theme.ember
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.phase === "done" ? "Update complete"
                        : (page.label !== "" ? page.label + "\u2026" : "Applying updates\u2026")
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            // one segment per stage, coloured by state; the running one pulses.
            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: page.steps

                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - (page.steps.length - 1) * 6) / Math.max(1, page.steps.length)
                        height: 5
                        radius: 2.5
                        color: modelData.state === "failed" ? Theme.emberDeep : Theme.ember
                        opacity: {
                            switch (modelData.state) {
                            case "running": return 1.0;
                            case "ok": return 0.9;
                            case "failed": return 1.0;
                            case "skipped": return 0.35;
                            default: return 0.18;
                            }
                        }

                        SequentialAnimation on opacity {
                            running: modelData.state === "running"
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.4; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.0; to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                        }
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }
                }
            }

            // the update's own narrative, streamed from the run-state log ring.
            Column {
                width: parent.width
                spacing: 3
                visible: page.logLines.length > 0

                Repeater {
                    model: page.logLines

                    delegate: Text {
                        required property var modelData
                        required property int index
                        width: parent.width
                        text: modelData
                        color: index === page.logLines.length - 1 ? Theme.subtle : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // --- error panel: the update stopped; offer a one-click rollback --------
    Item {
        visible: page.phase === "error"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top

        Row {
            anchors.centerIn: parent
            width: Math.min(parent.width - 72, 560)
            spacing: 20

            Rectangle {
                width: 3
                height: errCol.implicitHeight
                radius: Theme.radius
                color: Theme.ember
            }

            Column {
                id: errCol
                width: parent.width - 23
                spacing: 12

                Text {
                    width: parent.width
                    text: page.label !== "" ? "Update failed while " + page.label.toLowerCase() : "Update failed"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: page.errorMsg !== ""
                    text: page.errorMsg
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 12
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: page.snapshot !== ""
                        ? "The system was snapshotted before the update. Roll back to undo every change."
                        : "Check the terminal for details, then try again."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }

                Item { width: 1; height: 4 }

                Row {
                    spacing: 12

                    HubButton {
                        visible: page.snapshot !== ""
                        label: "Roll back"
                        icon: "undo"
                        primary: true
                        onClicked: page.rollback()
                    }

                    HubButton {
                        label: "Dismiss"
                        icon: "close"
                        onClicked: page.dismiss()
                    }
                }
            }
        }
    }

    // --- consent prompt: editorial question `ryoku update` is waiting on, in
    // the UpdateStatus idiom (ember rule + headline + detail) with dossier-
    // stamp actions instead of a centred two-pill modal.
    Item {
        visible: page.phase === "prompt"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top

        Row {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 540)
            spacing: 20

            Rectangle {
                width: 3
                height: promptCol.implicitHeight
                radius: Theme.radius
                color: Theme.ember
            }

            Column {
                id: promptCol
                width: parent.width - 23
                spacing: 14

                Text {
                    width: parent.width
                    text: page.promptTitle
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: page.promptDetail
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }

                Item { width: 1; height: 4 }

                Row {
                    spacing: 18

                    Repeater {
                        model: page.promptOptions

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            height: 32
                            width: optLabel.implicitWidth + (index === 0 ? 30 : 22)
                            radius: Theme.radius
                            color: optMa.containsMouse
                                ? (index === 0 ? Theme.frameBg : Theme.keyTop)
                                : "transparent"
                            border.width: 1
                            border.color: index === 0 ? Theme.ember : (optMa.containsMouse ? Theme.ember : Theme.line)

                            Text {
                                id: optLabel
                                anchors.centerIn: parent
                                text: ("" + modelData).toUpperCase()
                                color: index === 0
                                    ? (optMa.containsMouse ? Qt.lighter(Theme.ember, 1.25) : Theme.ember)
                                    : (optMa.containsMouse ? Theme.cream : Theme.dim)
                                font.family: Theme.mono
                                font.pixelSize: 12
                                font.weight: index === 0 ? Font.Bold : Font.DemiBold
                                font.letterSpacing: 2
                            }

                            MouseArea {
                                id: optMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.answer(modelData)
                            }

                            Behavior on color { ColorAnimation { duration: Theme.quick } }
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                        }
                    }
                }
            }
        }
    }

    // --- action bar, pinned at the bottom -----------------------------------
    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 66

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.line
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: page.phase === "running" ? "Update running"
                : page.phase === "error" ? "Update failed"
                : page.phase === "done" ? "Update complete"
                : (Updates.branch + (Updates.currentVersion !== "" ? ("  \u00b7  " + Updates.currentVersion) : ""))
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 12
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: page.phase === "idle"

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Check again"
                icon: "refresh"
                onClicked: Updates.check()
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Updates.available
                label: "Update now"
                icon: "download"
                primary: true
                onClicked: page.startUpdate()
            }
        }
    }
}
