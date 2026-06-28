pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// System > GPU. two tabs. Machine (the hero): run a virtual machine -- a plain
// VM runs in a QEMU window on the GPU that drives the display, no passthrough
// needed. Graphics: which GPU Ryoku renders on, and the optional GPU-passthrough
// stack (Looking Glass) for handing a whole GPU to a VM. everything dangerous is
// gated on the verdict from `ryoku-hub gpu caps`.
Item {
    id: page
    readonly property bool previewDirty: false

    property var caps: ({})
    property var vmcfg: ({})
    property var draft: ({})
    property string mode: "hybrid"
    property string seg: "machine"
    property string planText: ""
    property bool planning: false
    property bool enabling: false      // enable launched in a terminal; awaiting recheck
    property bool settingUp: false     // qemu install launched in a terminal
    property bool showChecks: false    // disclosure: the passthrough readiness dossier
    property string actionError: ""
    property string capsError: ""     // caps probe failed/timed out; show retry, not a spinner
    property string modeWarn: ""
    property bool vmRunning: false

    // the GPU wired to the display: what the desktop and a windowed VM render on.
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
    readonly property bool vmReady: page.caps.vmReady === true
    readonly property bool kvmOff: page.capsLoaded && page.caps.kvm === false
    readonly property bool ptReady: page.caps.verdict === "ready"

    // passthrough status line, by verdict.
    readonly property string ptText: {
        switch (page.caps.verdict) {
        case "ready": return "Ready. " + page.dgpuName + " joins the VM at launch and returns to the desktop when it stops.";
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
        vmProc.running = true;
        modeProc.running = true;
        statusProc.running = true;
    }
    function patch(k, v) {
        var d = JSON.parse(JSON.stringify(page.draft));
        d[k] = v;
        page.draft = d;
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
    function installQemu() {
        Quickshell.execDetached(["kitty", "--class", "ryoku-gpu", "-e", "sh", "-c",
            "ryoku-hub vm setup; echo; read -n1 -rsp 'Press any key to close…'; echo"]);
        page.settingUp = true;
    }
    function recheck() {
        page.enabling = false;
        page.settingUp = false;
        page.reload();
    }

    onVmcfgChanged: page.draft = JSON.parse(JSON.stringify(page.vmcfg))
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
                    if (page.caps.vmReady === true)
                        page.settingUp = false;     // install finished: drop the installing notice
                    return;
                } catch (e) {
                    console.log("gpu: caps parse failed: " + e);
                }
            }
            page.capsError = capsErr.text.trim() || ("ryoku-hub gpu caps exited " + code);
        }
    }
    Process {
        id: vmProc
        command: ["ryoku-hub", "vm", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.vmcfg = JSON.parse(this.text);
                } catch (e) {
                    console.log("gpu: vm parse failed: " + e);
                }
            }
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
    Process {
        id: pickProc
        command: ["sh", "-c", "zenity --file-selection --title='Select an ISO' --file-filter='ISO images | *.iso *.ISO' --file-filter='All files | *' 2>/dev/null || kdialog --getopenfilename \"$HOME\" '*.iso *.ISO|ISO images' 2>/dev/null || notify-send 'Ryoku Settings' 'Install zenity to browse for an ISO, or type the path.'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p.length > 0)
                    page.patch("isoPath", p);
            }
        }
    }
    Process {
        id: statusProc
        command: ["ryoku-hub", "vm", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.vmRunning = JSON.parse(this.text).running === true;
                } catch (e) {}
            }
        }
    }
    // while the Machine tab is open, keep Launch/Stop in step with the VM.
    Timer {
        interval: 5000
        repeat: true
        running: page.seg === "machine"
        onTriggered: statusProc.running = true
    }
    // while QEMU installs in its terminal, poll caps so the page advances on its
    // own when the stack appears, instead of waiting for a manual Recheck.
    Timer {
        interval: 4000
        repeat: true
        running: page.seg === "machine" && page.settingUp
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

    // a soft, bordered callout used for the hero notices (install / firmware /
    // recheck). carbon surface, hairline border, optional accent.
    component Notice: Rectangle {
        id: nt
        property color accent: Theme.ember
        property real pad: 16
        default property alias body: noticeCol.data
        width: parent ? parent.width : 0
        implicitHeight: noticeCol.implicitHeight + nt.pad * 2
        radius: 12
        color: Qt.rgba(nt.accent.r, nt.accent.g, nt.accent.b, 0.07)
        border.width: 1
        border.color: Qt.rgba(nt.accent.r, nt.accent.g, nt.accent.b, 0.4)
        Column {
            id: noticeCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: nt.pad
            spacing: 12
        }
    }

    // a VM keyboard-shortcut row: a mono key chip and what it does.
    component VmKey: Row {
        id: vk
        property string keys: ""
        property string action: ""
        width: parent ? parent.width : 0
        spacing: 12
        Rectangle {
            width: 104
            height: 22
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceLo
            border.width: 1
            border.color: Theme.line
            Text {
                anchors.centerIn: parent
                text: vk.keys
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: vk.action
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    ShowcaseBackdrop { anchors.fill: parent }

    Segmented {
        id: segCtl
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        model: [{ "key": "machine", "label": "Machine" }, { "key": "graphics", "label": "Graphics" }]
        current: page.seg
        onSelected: (k) => page.seg = k
    }

    Item {
        anchors.top: segCtl.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

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

        Item {
            id: rightCol
            anchors.left: hero.right
            anchors.leftMargin: 40
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // ── Machine: run a VM. the simple, windowed path is the default. ─────
            Item {
                id: machine
                anchors.fill: parent
                visible: page.seg === "machine"

                readonly property bool vmPassthrough: (page.draft.display || "windowed") === "passthrough"
                readonly property bool launchable: machine.vmPassthrough ? page.ptReady : page.vmReady

                // gate: hardware not ready for any VM (no QEMU, or virt is off).
                Item {
                    anchors.fill: parent
                    visible: !page.vmReady

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 16

                        Text {
                            visible: !page.capsLoaded && page.capsError === ""
                            text: "Checking your hardware…"
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        // virtualization off in firmware: nothing to install fixes it.
                        Notice {
                            visible: page.kvmOff
                            accent: Theme.bad
                            Text {
                                width: parent.width
                                text: "Virtualization is off"
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "A virtual machine needs hardware virtualization. Turn on SVM / AMD-V (AMD) or VT-x (Intel) in your BIOS/firmware, then reboot."
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }

                        // the common case: just install QEMU.
                        Notice {
                            visible: page.capsLoaded && !page.kvmOff
                            accent: Theme.ember
                            Text {
                                width: parent.width
                                text: "Install QEMU to run a VM"
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "A virtual machine runs in a window on " + page.renderName + ", the GPU Ryoku already uses. No GPU passthrough, no Looking Glass. This installs QEMU, the UEFI firmware, and GL acceleration."
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                            Row {
                                spacing: 10
                                HubButton {
                                    label: "Install QEMU"
                                    icon: "download"
                                    primary: true
                                    onClicked: page.installQemu()
                                }
                                HubButton {
                                    visible: page.settingUp
                                    label: "Recheck"
                                    icon: "refresh"
                                    onClicked: page.recheck()
                                }
                            }
                            Text {
                                visible: page.settingUp
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Installing in a terminal window. Click Recheck when it finishes."
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                // ready: the VM configuration + launch.
                Flickable {
                    anchors.fill: parent
                    visible: page.vmReady
                    contentWidth: width
                    contentHeight: vmCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: vmCol
                        width: parent.width - 8
                        spacing: 18

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: machine.vmPassthrough
                                ? ("Hands " + page.dgpuName + " to the VM and shows it through Looking Glass.")
                                : ("Runs in a window on " + page.renderName + ". Point it at an ISO and launch.")
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        SettingSection {
                            width: parent.width
                            title: "INSTALL MEDIA"

                            Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: parent.width - browseBtn.width - 10
                                    height: 38
                                    radius: 9
                                    color: Theme.surfaceLo
                                    border.width: 1
                                    border.color: isoIn.activeFocus ? Theme.ember : Theme.line
                                    anchors.verticalCenter: parent.verticalCenter
                                    TextInput {
                                        id: isoIn
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: page.draft.isoPath || ""
                                        color: Theme.bright
                                        font.family: Theme.mono
                                        font.pixelSize: 12
                                        clip: true
                                        selectByMouse: true
                                        onEditingFinished: page.patch("isoPath", text)
                                    }
                                    Text {
                                        visible: isoIn.text.length === 0
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Path to a Linux or Windows ISO"
                                        color: Theme.faint
                                        font.family: Theme.mono
                                        font.pixelSize: 12
                                    }
                                }
                                HubButton {
                                    id: browseBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: "Browse"
                                    icon: "folder"
                                    onClicked: pickProc.running = true
                                }
                            }

                            ChoiceRow {
                                width: Math.min(parent.width, 460)
                                label: "Guest OS"
                                options: [{ "key": "linux", "label": "Linux" }, { "key": "windows11", "label": "Windows" }, { "key": "other", "label": "Other" }]
                                current: page.draft.guest || "linux"
                                onChosen: (k) => page.patch("guest", k)
                            }
                        }

                        SettingSection {
                            width: parent.width
                            title: "DISPLAY"

                            ChoiceRow {
                                width: Math.min(parent.width, 460)
                                label: "How the VM shows its screen"
                                options: [{ "key": "windowed", "label": "Windowed" }, { "key": "passthrough", "label": "Passthrough" }]
                                current: page.draft.display || "windowed"
                                onChosen: (k) => page.patch("display", k)
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: machine.vmPassthrough
                                    ? ("Passthrough hands " + page.dgpuName + " to the VM for near-native speed (mostly for Windows gaming). Set it up in the Graphics tab.")
                                    : ("Windowed runs in a normal QEMU window, rendered by " + page.renderName + ". Best for Linux and everyday use, with nothing to set up.")
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        SettingSection {
                            width: parent.width
                            title: "RESOURCES"
                            NumberField {
                                width: Math.min(parent.width, 460)
                                label: "CPU cores"
                                from: 1; to: 32; step: 1
                                value: page.draft.cores || 4
                                onModified: (v) => page.patch("cores", v)
                            }
                            NumberField {
                                width: Math.min(parent.width, 460)
                                label: "Memory"
                                unit: "MB"
                                from: 2048; to: 131072; step: 1024
                                value: page.draft.ramMb || 8192
                                onModified: (v) => page.patch("ramMb", v)
                            }
                            NumberField {
                                width: Math.min(parent.width, 460)
                                label: "Disk"
                                unit: "GB"
                                from: 16; to: 2048; step: 8
                                value: page.draft.diskGb || 64
                                onModified: (v) => page.patch("diskGb", v)
                            }
                        }

                        Row {
                            spacing: 10
                            HubButton {
                                label: "Save"
                                icon: "check"
                                onClicked: page.act(["ryoku-hub", "vm", "save", JSON.stringify(page.draft)])
                            }
                            HubButton {
                                visible: !page.vmRunning
                                label: "Launch VM"
                                icon: "play"
                                primary: true
                                enabled: machine.launchable
                                onClicked: page.act(["ryoku-hub", "vm", "launch"])
                            }
                            HubButton {
                                visible: page.vmRunning
                                label: "Stop VM"
                                icon: "close"
                                onClicked: page.act(["ryoku-hub", "vm", "stop"])
                            }
                        }
                        Text {
                            width: parent.width
                            visible: machine.vmPassthrough && !page.ptReady
                            wrapMode: Text.WordWrap
                            text: "Passthrough isn't ready yet. Finish setup in the Graphics tab, or switch Display to Windowed to launch now."
                            color: Theme.ember
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        SettingSection {
                            width: parent.width
                            visible: !machine.vmPassthrough
                            title: "VM CONTROLS"
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "The VM opens in a floating window on " + page.renderName + ". The menu bar starts hidden; these shortcuts drive it:"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                            VmKey { keys: "Ctrl Alt G"; action: "Lock or release the mouse and keyboard" }
                            VmKey { keys: "Ctrl Alt F"; action: "Toggle fullscreen" }
                            VmKey { keys: "Ctrl Alt M"; action: "Show or hide the menu bar" }
                            VmKey { keys: "Ctrl Alt +/-"; action: "Scale the window (Ctrl Alt 0 resets)" }
                            VmKey { keys: "Ctrl Alt 2"; action: "QEMU monitor (Ctrl Alt 1 returns to the VM)" }
                        }
                    }
                }
            }

            // ── Graphics: which GPU Ryoku renders on + the passthrough stack. ────
            Flickable {
                id: gfx
                anchors.fill: parent
                visible: page.seg === "graphics"
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
                            text: "Hand " + page.dgpuName + " to a VM for near-native performance, shown in a window through Looking Glass. Optional: a windowed VM (Machine tab) needs none of this."
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

            // action error banner: refused mode switch, failed launch, etc.
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
}
