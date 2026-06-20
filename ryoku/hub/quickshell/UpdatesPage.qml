import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// The Updates section. The status header, auto-check schedule, and commit
// timeline are mock-displayed for this beta; "Update now" runs the REAL
// `ryoku update` in a terminal, and the shell island reflects its live progress
// (the CLI publishes run-state to the file the island watches). Wiring the
// display to `ryoku status --json` + a shipped changelog is a follow-up.
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

    // --- update run (mock) --------------------------------------------------
    property string phase: "idle"   // idle | running | success | failed
    property real progress: 0
    property var script: []
    property int runIndex: 0
    property bool failMode: false   // mock seam: drive the failure path
    property bool refreshing: false
    property string exportedPath: ""

    ListModel { id: logModel }
    FileView { id: logFile }

    // Cross-process run state: the shell's update island mirrors this file (a
    // wave while running, a refresh affordance on success). In-place writes so the
    // island's FileView watcher catches every change.
    readonly property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-update.json"
    FileView { id: stateFile; path: page.statePath; atomicWrites: false }
    function publish(o) { stateFile.setText(JSON.stringify(o)); }
    function goIdle() { page.phase = "idle"; page.publish({ "phase": "idle" }); }
    Component.onDestruction: if (page.phase === "running") page.publish({ "phase": "idle" });

    function pad(s, n) {
        s = String(s);
        while (s.length < n)
            s += " ";
        return s;
    }

    function buildScript(fail) {
        var s = [];
        s.push({ "level": "step", "line": "==> Fetching origin/main", "delay": 480 });
        s.push({ "level": "info", "line": "    remote: counting objects, done", "delay": 240 });
        s.push({ "level": "info", "line": "    " + Updates.behind + " commits to apply  (" + Updates.currentVersion + ".." + Updates.latestVersion + ")", "delay": 360 });
        s.push({ "level": "step", "line": "==> Applying commits", "delay": 420 });
        for (var i = Updates.commits.length - 1; i >= 0; i--) {
            var c = Updates.commits[i];
            s.push({ "level": "info", "line": "    " + c.hash + "  " + page.pad(c.area, 13) + c.subject, "delay": 190 });
        }
        s.push({ "level": "step", "line": "==> Rebuilding", "delay": 460 });
        s.push({ "level": "info", "line": "    building ryoku-shell", "delay": 340 });
        s.push({ "level": "info", "line": "    building ryoku-hub", "delay": 300 });
        s.push({ "level": "info", "line": "    compiling Ryoku.Blobs", "delay": 460 });
        if (fail) {
            s.push({ "level": "bad", "line": "    error: SPIR-V shader stage failed to compile", "delay": 320 });
            s.push({ "level": "bad", "line": "==> Update aborted; no changes were applied", "delay": 260 });
            return s;
        }
        s.push({ "level": "info", "line": "    installing quickshell components", "delay": 320 });
        s.push({ "level": "step", "line": "==> Finishing", "delay": 320 });
        s.push({ "level": "ok",   "line": "    update applied cleanly", "delay": 280 });
        return s;
    }

    function startUpdate() {
        logModel.clear();
        page.exportedPath = "";
        page.refreshing = false;
        page.script = page.buildScript(page.failMode);
        page.runIndex = 0;
        page.progress = 0;
        page.phase = "running";
        page.publish({ "phase": "running", "progress": 0 });
        runTimer.interval = 320;
        runTimer.restart();
    }

    function refreshShell() {
        Quickshell.execDetached(["ryoku-shell", "reload"]);
        page.publish({ "phase": "idle" });
        page.refreshing = true;
    }

    function stamp() {
        function p(n) { return (n < 10 ? "0" : "") + n; }
        var d = new Date();
        return "" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
            + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
    }

    function exportLogs() {
        var out = [];
        out.push("Ryoku update log  " + new Date().toString());
        out.push("target " + Updates.latestVersion + " (from " + Updates.currentVersion + ", " + Updates.branch + ")");
        out.push("");
        for (var i = 0; i < logModel.count; i++)
            out.push(logModel.get(i).line);
        var path = Quickshell.env("HOME") + "/ryoku-update-" + page.stamp() + ".log";
        logFile.path = path;
        logFile.setText(out.join("\n") + "\n");
        page.exportedPath = path;
    }

    function shortPath(p) {
        var home = Quickshell.env("HOME");
        return (home && p.indexOf(home) === 0) ? ("~" + p.substring(home.length)) : p;
    }

    Timer {
        id: runTimer
        repeat: false
        onTriggered: {
            var e = page.script[page.runIndex];
            logModel.append({ "level": e.level, "line": e.line });
            page.runIndex++;
            page.progress = page.runIndex / page.script.length;
            if (page.runIndex < page.script.length) {
                page.publish({ "phase": "running", "progress": page.progress });
                runTimer.interval = page.script[page.runIndex].delay;
                runTimer.restart();
            } else if (page.failMode) {
                page.phase = "failed";
                page.publish({ "phase": "idle" });
            } else {
                page.phase = "success";
                page.publish({ "phase": "success", "version": Updates.latestVersion });
            }
        }
    }

    // --- idle content -------------------------------------------------------
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
                radius: 2
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
                        text: "COMMITS"
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
                    model: Updates.commits

                    delegate: CommitRow {
                        required property var modelData
                        required property int index
                        width: col.width
                        hash: modelData.hash
                        area: modelData.area
                        subject: modelData.subject
                        date: modelData.date
                        head: index === 0
                        first: index === 0
                        last: index === Updates.commits.length - 1
                    }
                }
            }
        }
    }

    // --- live run console ---------------------------------------------------
    UpdateConsole {
        visible: page.phase !== "idle"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: 10
        phase: page.phase
        progress: page.progress
        logModel: logModel
        targetVersion: Updates.latestVersion
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

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                visible: page.phase === "running"
                size: 14
                tint: Theme.dim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (page.phase === "running")
                        return "Applying updates\u2026";
                    if (page.phase === "success")
                        return page.refreshing ? "Shell restarting\u2026" : ("Updated to " + Updates.latestVersion);
                    if (page.phase === "failed")
                        return page.exportedPath ? ("Saved " + page.shortPath(page.exportedPath)) : "Update failed, no changes applied";
                    return Updates.branch + (Updates.commits.length > 0 ? ("  \u00b7  " + Updates.commits[0].hash) : "");
                }
                color: (page.phase === "success" && !page.refreshing) ? Theme.ok
                    : (page.phase === "failed" && !page.exportedPath) ? Theme.bad
                    : Theme.faint
                font.family: (page.phase === "idle" || page.exportedPath !== "") ? Theme.mono : Theme.font
                font.pixelSize: 12
            }
        }

        // idle actions
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: page.phase === "idle"

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Check again"
                icon: "refresh"
                onClicked: {} // a manual check; wired to the updater backend later
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Updates.available
                label: "Update now"
                icon: "download"
                primary: true
                onClicked: Quickshell.execDetached(["kitty", "-e", "ryoku", "update"])
            }
        }

        // success actions
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: page.phase === "success"

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Back"
                onClicked: page.goIdle()
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Refresh shell"
                icon: "refresh"
                primary: true
                enabled: !page.refreshing
                onClicked: page.refreshShell()
            }
        }

        // failure actions
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: page.phase === "failed"

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Back"
                onClicked: page.goIdle()
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Export logs"
                icon: "download"
                enabled: page.exportedPath === ""
                onClicked: page.exportLogs()
            }

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Retry"
                icon: "refresh"
                primary: true
                onClicked: page.startUpdate()
            }
        }
    }
}
