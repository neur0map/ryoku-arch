pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// System > GPU. Which GPU Ryoku renders on, and the optional GPU-passthrough
// stack (binds the discrete GPU to vfio so a VM can own it). Running virtual
// machines lives in the ryovm app, not here; this page is graphics hardware
// only. Everything dangerous is gated on the verdict from `ryoku-hub gpu caps`.
Item {
    id: page
    readonly property bool previewDirty: false

    property var caps: ({})
    property string mode: "hybrid"
    property string planText: ""
    property bool planning: false
    property bool enabling: false      // enable launched in a terminal; awaiting recheck
    property bool showChecks: false    // disclosure: the passthrough readiness dossier
    property string actionError: ""
    property string capsError: ""      // caps probe failed/timed out; show retry, not a spinner
    property string modeWarn: ""

    // the GPU wired to the display: what the desktop renders on.
    readonly property var renderGpu: {
        var p = page.caps.passthrough, h = page.caps.host;
        if (p && p.drivesDisplay)
            return p;
        if (h && h.drivesDisplay)
            return h;
        return h || p || null;
    }
    readonly property string renderName: page.renderGpu ? page.renderGpu.model : "your GPU"
    readonly property string dgpuName: page.caps.passthrough ? page.caps.passthrough.model : "the discrete GPU"

    readonly property bool capsLoaded: page.caps.verdict !== undefined

    // passthrough status line, by verdict.
    readonly property string ptText: {
        switch (page.caps.verdict) {
        case "ready": return "Ready. " + page.dgpuName + " is free for a VM to claim, and returns to the desktop when the VM stops.";
        case "needs-relogin": return "Set up. Log out and back in once, then it is ready.";
        case "needs-reboot": return "Your screen runs on " + page.dgpuName + ". Switch to Hybrid GPU mode in the BIOS (look for GPU Mode, MUX, or Hybrid/Optimus) and reboot, so the built-in GPU drives the display and the discrete GPU is free.";
        case "needs-setup": return "Not set up yet. Review the changes, then enable it below.";
        case "incapable": return "This machine can't pass a GPU to a VM. Open the readiness checks below for why.";
        default: return page.capsError !== "" ? "Couldn't read your graphics hardware." : "Checking…";
        }
    }
    readonly property color ptColor: {
        switch (page.caps.verdict) {
        case "ready": return Theme.ok;
        case "needs-relogin":
        case "needs-reboot": return Theme.ember;
        case "incapable": return Theme.bad;
        default: return page.capsError !== "" ? Theme.bad : Theme.subtle;
        }
    }

    function reload() {
        page.capsError = "";    // re-checking: clear the old failure so Retry shows progress, not a frozen error
        capsProc.running = true;
        modeProc.running = true;
    }
    function act(cmd) {
        page.actionError = "";
        runProc.command = cmd;
        runProc.running = true;
    }
    function setMode(m) {
        page.modeWarn = "";
        modeSetProc.command = ["ryoku-hub", "gpu", "mode", "set", m];
        modeSetProc.running = true;
    }
    function reviewEnable() {
        planProc.command = ["ryoku-hub", "gpu", "apply", "enable", "--dry-run"];
        planProc.running = true;
    }
    // the real enable builds the AUR Looking Glass stack (needs a TTY for the
    // build + sudo) then escalates for the system setup, so it runs in a terminal.
    function enableInTerminal() {
        Quickshell.execDetached(["kitty", "--class", "ryoku-gpu", "-e", "sh", "-c",
            "ryoku-hub gpu apply enable; echo; read -n1 -rsp 'Done. Press any key to close…'; echo"]);
        page.planning = false;
        page.planText = "";
        page.enabling = true;
    }
    function recheck() {
        page.enabling = false;
        page.reload();
    }

    Component.onCompleted: page.reload()

    Process {
        id: capsProc
        command: ["ryoku-hub", "gpu", "caps"]
        stdout: StdioCollector { id: capsOut }
        stderr: StdioCollector { id: capsErr }
        // decide on exit, not per-stream: a non-zero exit or unparseable output
        // becomes a visible error + retry instead of an endless "Detecting…".
        onExited: (code) => {
            if (code === 0) {
                try {
                    page.caps = JSON.parse(capsOut.text);
                    page.capsError = "";
                    return;
                } catch (e) {
                    console.log("gpu: caps parse failed: " + e);
                }
            }
            page.capsError = capsErr.text.trim() || ("ryoku-hub gpu caps exited " + code);
        }
    }
    Process {
        id: modeProc
        command: ["ryoku-hub", "gpu", "mode", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.mode = JSON.parse(this.text).mode;
                } catch (e) {}
            }
        }
    }
    Process {
        id: modeSetProc
        stdout: StdioCollector { onStreamFinished: page.reload() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0)
                    page.modeWarn = e;
            }
        }
    }
    Process {
        id: runProc
        stdout: StdioCollector { onStreamFinished: page.reload() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0)
                    page.actionError = e;
            }
        }
    }
    Process {
        id: planProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.planText = this.text;
                page.planning = true;
            }
        }
    }
    // while the enable runs in its terminal, poll caps so the page advances on
    // its own when the stack appears, instead of waiting for a manual Recheck.
    Timer {
        interval: 4000
        repeat: true
        running: page.enabling
        onTriggered: capsProc.running = true
    }

    // dossier row: status dot, label, detected value, coloured by level.
    component CheckRow: Item {
        id: cr
        property var check: null
        width: parent ? parent.width : 0
        height: 30
        readonly property color lvl: cr.check ? (cr.check.level === "ok" ? Theme.ok : (cr.check.level === "warn" ? Theme.ember : Theme.bad)) : Theme.dim

        Rectangle {
            id: dot
            width: 7
            height: 7
            radius: 3.5
            color: cr.lvl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.left: dot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: cr.check ? cr.check.label : ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: cr.check ? cr.check.value : ""
            color: cr.lvl
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    ShowcaseBackdrop { anchors.fill: parent }

    Item {
        anchors.fill: parent

        GpuCard {
            id: hero
            anchors.left: parent.left
            anchors.top: parent.top
            caps: page.caps
            failed: page.capsError !== ""
            cardWidth: Math.min(parent.width * 0.4, 380)
        }

        // caps probe failed (detector missing, wedged, or timed out): surface it
        // with a retry instead of leaving the page stuck on "Detecting…".
        Column {
            visible: page.capsError !== ""
            anchors.left: hero.left
            anchors.right: hero.right
            anchors.top: hero.bottom
            anchors.topMargin: 16
            spacing: 10
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Couldn't read your graphics hardware."
                color: Theme.bad
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: page.capsError
                color: Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 11
            }
            HubButton {
                label: "Retry"
                icon: "refresh"
                primary: true
                onClicked: page.reload()
            }
        }

        Flickable {
            id: gfx
            anchors.left: hero.right
            anchors.leftMargin: 40
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: gfxCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: gfxCol
                width: gfx.width - 8
                spacing: 22

                SettingSection {
                    width: parent.width
                    title: "RYOKU RENDERS ON"
                    ChoiceRow {
                        width: Math.min(parent.width, 460)
                        label: "Graphics mode"
                        options: [
                            { "key": "hybrid", "label": "Hybrid" },
                            { "key": "performance", "label": "Performance" },
                            { "key": "passthrough", "label": "Passthrough" }
                        ]
                        current: page.mode
                        onChosen: (k) => page.setMode(k)
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: page.mode === "hybrid"
                            ? "Hybrid keeps the built-in GPU primary for battery; apps can still use " + page.dgpuName + " on demand."
                            : (page.mode === "performance"
                                ? "Performance pins " + page.dgpuName + " as primary: fastest, more power draw."
                                : "Passthrough runs the desktop on the built-in GPU so " + page.dgpuName + " is free for a VM.")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    Text {
                        width: parent.width
                        text: "A change takes effect on your next login."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    Rectangle {
                        visible: page.modeWarn !== ""
                        width: parent.width
                        height: modeWarnText.implicitHeight + 20
                        radius: 8
                        color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.4)
                        Text {
                            id: modeWarnText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 10
                            text: page.modeWarn
                            color: Theme.ember
                            wrapMode: Text.WordWrap
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "GPU PASSTHROUGH · ADVANCED"

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Free " + page.dgpuName + " from the desktop and bind it to vfio so a virtual machine can own it for near-native performance. This sets up the host only; you run the VM yourself (libvirt + Looking Glass). Everyday VMs in ryovm need none of this."
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    // status line, coloured by verdict.
                    Row {
                        width: parent.width
                        spacing: 10
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: page.ptColor
                        }
                        Text {
                            width: parent.width - 17
                            wrapMode: Text.WordWrap
                            text: page.ptText
                            color: page.ptColor
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }

                    // enabled: nothing to do but tear it down.
                    HubButton {
                        visible: page.caps.enabled === true
                        label: "Disable passthrough"
                        icon: "trash"
                        onClicked: page.act(["ryoku-hub", "gpu", "apply", "disable"])
                    }

                    // not enabled + capable: review, then enable in a terminal.
                    HubButton {
                        visible: page.caps.enabled !== true && page.caps.verdict !== "incapable" && !page.planning && !page.enabling
                        label: "Review changes"
                        icon: "search"
                        onClicked: page.reviewEnable()
                    }

                    Rectangle {
                        visible: page.planning
                        width: parent.width
                        height: 220
                        radius: 10
                        color: Theme.surfaceLo
                        border.width: 1
                        border.color: Theme.line
                        clip: true
                        Flickable {
                            id: planFlick
                            anchors.fill: parent
                            anchors.margins: 12
                            contentWidth: width
                            contentHeight: planView.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Text {
                                id: planView
                                width: planFlick.width
                                text: page.planText
                                color: Theme.cream
                                font.family: Theme.mono
                                font.pixelSize: 11
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                    Row {
                        visible: page.planning
                        spacing: 10
                        HubButton {
                            label: "Enable passthrough"
                            icon: "check"
                            primary: true
                            onClicked: page.enableInTerminal()
                        }
                        HubButton { label: "Close"; icon: "close"; onClicked: { page.planning = false; page.planText = ""; } }
                    }

                    // enable running in a terminal: prompt a recheck.
                    Text {
                        visible: page.enabling
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Setting up in a terminal window (it builds a kernel module, so it can take a few minutes). Click Recheck when it finishes."
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    HubButton {
                        visible: page.enabling
                        label: "Recheck"
                        icon: "refresh"
                        onClicked: page.recheck()
                    }

                    // disclosure: the full readiness dossier, collapsed by default.
                    Item {
                        width: parent.width
                        height: 22
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: page.showChecks ? "collapse" : "expand"
                                size: 13
                                tint: chkHov.hovered ? Theme.cream : Theme.dim
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.showChecks ? "Hide readiness checks" : "Readiness checks"
                                color: chkHov.hovered ? Theme.cream : Theme.dim
                                font.family: Theme.mono
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1
                            }
                        }
                        HoverHandler { id: chkHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: page.showChecks = !page.showChecks }
                    }
                    Column {
                        visible: page.showChecks
                        width: parent.width
                        spacing: 0
                        Repeater {
                            model: page.showChecks ? (page.caps.checks || []) : []
                            delegate: CheckRow {
                                required property var modelData
                                width: parent.width
                                check: modelData
                            }
                        }
                    }
                }
            }
        }

        // action error banner: refused mode switch, failed enable, etc.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: page.actionError !== ""
            height: Math.min(errText.implicitHeight + 22, 110)
            radius: 10
            color: Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.5)
            clip: true
            Text {
                id: errText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 14
                text: page.actionError
                color: Theme.bad
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 5
            }
            TapHandler { onTapped: page.actionError = "" }
        }
    }
}
