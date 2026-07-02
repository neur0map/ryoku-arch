pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// Rashin section: an optional, fully local agent OS. this page reports the
// ryoku-rashin daemon's state (from `ryoku-rashin status --json`), toggles it
// on/off, launches the one-click Hermes setup in a floating terminal (mirroring
// its setup.json progress live), and opens the local dashboard. everything
// stays on this machine; Rashin is off until you switch it on.
Item {
    id: page

    // status snapshot. installed=false when the binary is missing: there is
    // nothing to report yet, and the actions below stay disabled.
    property bool installed: true
    property bool daemonEnabled: false
    property bool running: false
    property bool vaultExists: false
    property int vaultFiles: 0
    property bool hermesInstalled: false
    property bool hermesConfigured: false
    property int agentsPresent: 0
    property int agentsWired: 0

    // of the coding agents actually installed, how many point at the vault.
    readonly property string wiredSummary: page.agentsPresent > 0
        ? page.agentsWired + " of " + page.agentsPresent + " wired"
        : "no agents"

    Component.onCompleted: page.refresh()

    function refresh() {
        statusProc.running = true;
    }

    Process {
        id: statusProc
        // wrapped in sh so a missing ryoku-rashin still closes stdout and fires
        // onStreamFinished; a bare missing binary fails to start and fires
        // nothing. empty or unparseable output then reads as "not installed".
        command: ["sh", "-c", "ryoku-rashin status --json"]
        stderr: StdioCollector {}
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    page.installed = true;
                    page.daemonEnabled = o.enabled === true;
                    page.running = o.running === true;
                    var v = o.vault || ({});
                    page.vaultExists = v.exists === true;
                    page.vaultFiles = (typeof v.files === "number") ? v.files : 0;
                    var h = o.hermes || ({});
                    page.hermesInstalled = h.installed === true;
                    page.hermesConfigured = h.configured === true;
                    var ags = o.agents || [];
                    var present = 0, wired = 0;
                    for (var i = 0; i < ags.length; i++) {
                        if (ags[i].present) {
                            present++;
                            if (ags[i].wired)
                                wired++;
                        }
                    }
                    page.agentsPresent = present;
                    page.agentsWired = wired;
                    return;
                } catch (e) {
                    // empty output (binary missing) or malformed JSON.
                }
                page.installed = false;
                page.daemonEnabled = false;
                page.running = false;
            }
        }
    }

    Process { id: enableProc; onExited: page.refresh() }
    Process { id: disableProc; onExited: page.refresh() }

    function setEnabled(on) {
        var p = on ? enableProc : disableProc;
        p.command = ["ryoku-rashin", on ? "enable" : "disable"];
        p.running = true;
    }

    // one-click Hermes setup progress. the setup verb (run in a floating kitty)
    // writes phase updates to this file; we mirror them live and refresh status
    // once it settles on "done".
    property string setupPhase: ""
    property string setupDetail: ""
    property bool setupOk: true

    FileView {
        id: setupFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-rashin/setup.json"
        watchChanges: true
        onLoaded: page.applySetup(setupFile.text())
        onFileChanged: setupFile.reload()
        onLoadFailed: {}
    }

    function applySetup(t) {
        try {
            var o = JSON.parse(t);
            page.setupPhase = o.phase || "";
            page.setupDetail = o.detail || "";
            page.setupOk = o.ok !== false;
            if (page.setupPhase === "done")
                page.refresh();
        } catch (e) {}
    }

    function runSetup() {
        Quickshell.execDetached(["kitty", "--class", "ryoku-rashin-setup", "-e", "ryoku-rashin", "setup"]);
    }

    function openDashboard() {
        Quickshell.execDetached(["xdg-open", "http://127.0.0.1:3600"]);
    }

    // dossier row: label on the left, a mono value in a hairline pill on the
    // right, tinted by level.
    component StatusRow: Item {
        id: sr
        property string label: ""
        property string value: ""
        property color level: Theme.subtle
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sr.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chip.implicitWidth + 20
            height: 22
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(sr.level.r, sr.level.g, sr.level.b, 0.4)

            Text {
                id: chip
                anchors.centerIn: parent
                text: sr.value
                color: sr.level
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 4
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
            width: parent.width
            spacing: 26
            bottomPadding: 20

            SettingSection {
                width: col.width
                title: "ABOUT"

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    lineHeight: 1.45
                    text: "Rashin is an optional, fully local agent OS. It keeps a maintained map of "
                        + "this machine (hardware, installed packages, and every Ryoku config alongside "
                        + "the binary that owns it) so your coding agents (Hermes, Claude Code, codex, "
                        + "opencode, and Oh My Pi) read it instead of rediscovering your setup, skipping "
                        + "the tokens that discovery would otherwise burn. A small local web dashboard "
                        + "shows live system vitals, browses the vault, and opens a chat with the "
                        + "resident Hermes agent. Nothing ever leaves the machine, and Rashin stays off "
                        + "until you switch it on."
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }

            SettingSection {
                width: col.width
                title: "STATUS"

                StatusRow {
                    label: "Daemon"
                    value: page.installed ? (page.running ? "running" : "stopped") : "not installed"
                    level: page.installed ? (page.running ? Theme.ok : Theme.dim) : Theme.faint
                }
                StatusRow {
                    label: "Vault files"
                    value: page.vaultExists ? (page.vaultFiles + " files") : "empty"
                    level: page.vaultExists ? Theme.subtle : Theme.dim
                }
                StatusRow {
                    label: "Hermes agent"
                    value: page.hermesInstalled ? (page.hermesConfigured ? "installed, configured" : "installed") : "not installed"
                    level: page.hermesConfigured ? Theme.ok : (page.hermesInstalled ? Theme.ember : Theme.dim)
                }
                StatusRow {
                    label: "Agents wired"
                    value: page.wiredSummary
                    level: (page.agentsPresent > 0 && page.agentsWired === page.agentsPresent)
                        ? Theme.ok
                        : (page.agentsWired > 0 ? Theme.ember : Theme.dim)
                }
            }

            SettingSection {
                width: col.width
                title: "ENABLE"

                ToggleRow {
                    width: parent.width
                    enabled: page.installed
                    label: "Start Rashin with the desktop and keep the dashboard available"
                    checked: page.daemonEnabled
                    onToggled: c => {
                        page.daemonEnabled = c;
                        page.setEnabled(c);
                    }
                }
            }

            SettingSection {
                width: col.width
                title: "HERMES"

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                    text: "Hermes is the resident agent that lives beside the vault and answers "
                        + "questions about this machine. Set it up once: it installs Hermes if you "
                        + "don't have it, wires it to the vault, and points your other coding agents "
                        + "at the same map. An existing Hermes install is left untouched."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                HubButton {
                    enabled: page.installed
                    label: "Set up Hermes agent"
                    icon: "sparkles"
                    primary: !page.hermesConfigured
                    onClicked: page.runSetup()
                }

                Text {
                    width: parent.width
                    visible: page.setupPhase !== ""
                    wrapMode: Text.WordWrap
                    text: page.setupPhase + (page.setupDetail !== "" ? ": " + page.setupDetail : "")
                    color: page.setupOk ? Theme.subtle : Theme.bad
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            SettingSection {
                width: col.width
                title: "DASHBOARD"

                HubButton {
                    enabled: page.installed
                    label: "Open dashboard"
                    icon: "display"
                    primary: true
                    onClicked: page.openDashboard()
                }

                Text {
                    text: "http://127.0.0.1:3600"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }
        }
    }
}
