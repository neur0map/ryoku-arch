pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// The Updates section, wired to `ryoku status --json` via the Updates singleton.
// Idle shows the live status and the real list of incoming commits;
// "Update now" runs the real `ryoku update` in a terminal and this page mirrors
// its progress from the run-state file the CLI publishes. When the system is
// current there are no rows and the top-right island stays hidden.
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

    // Re-check on the configured cadence.
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
    property string phase: "idle"   // idle | running | prompt
    property real progress: 0
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
            if (o.phase === "prompt" && o.prompt) {
                page.phase = "prompt";
                page.promptTitle = o.prompt.title || "";
                page.promptDetail = o.prompt.detail || "";
                page.promptOptions = o.prompt.options || [];
            } else {
                page.phase = (o.phase === "running") ? "running" : "idle";
                page.progress = (typeof o.progress === "number") ? o.progress : 0;
            }
        } catch (e) {
            page.phase = "idle";
            page.progress = 0;
        }
        // An update settled back to idle (finished): refresh so the list clears.
        if (prev !== "idle" && page.phase === "idle")
            Updates.check();
    }

    // Answer a prompt phase: write the choice to the back-channel `ryoku update`
    // is polling, and optimistically resume the running view so the buttons clear.
    function answer(choice) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + choice + "' > '" + page.answerPath + "'"]);
        page.phase = "running";
    }

    function startUpdate() {
        Quickshell.execDetached(["kitty", "-e", "sh", "-c", "RYOKU_UPDATE_UI=hub exec ryoku update"]);
    }

    // --- idle content: status + pending updates -----------------------------
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

    // --- running panel ------------------------------------------------------
    Item {
        visible: page.phase === "running"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top

        Column {
            anchors.centerIn: parent
            width: parent.width - 80
            spacing: 16

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    tint: Theme.ember
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Applying updates in the terminal\u2026"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }

            WaveMeter {
                width: parent.width
                frac: page.progress
            }
        }
    }

    // --- consent prompt: an editorial question `ryoku update` waits on, in the
    // UpdateStatus idiom (ember rule + headline + detail) with dossier-stamp
    // actions rather than a centred two-pill modal.
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
                radius: 1.5
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
                            radius: 3
                            color: index === 0
                                ? (optMa.containsMouse ? Qt.lighter(Theme.ember, 1.08) : Theme.ember)
                                : "transparent"
                            border.width: index === 0 ? 0 : 1
                            border.color: optMa.containsMouse ? Theme.ember : Theme.line

                            Text {
                                id: optLabel
                                anchors.centerIn: parent
                                text: ("" + modelData).toUpperCase()
                                color: index === 0
                                    ? Theme.onAccent
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
            text: page.phase === "running"
                ? "Update running"
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
