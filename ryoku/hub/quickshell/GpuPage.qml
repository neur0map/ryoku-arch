pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Singletons"

// System -> GPU: choose how the machine's GPUs are used (Hybrid / Performance /
// Passthrough) and configure + launch the Looking-Glass passthrough VM. Built in the
// Profile idiom (showcase backdrop + a specimen card + a dossier). Everything
// dangerous is gated on the capability verdict from `ryoku-hub gpu caps`.
Item {
    id: page
    readonly property bool previewDirty: false

    property var caps: ({})
    property var vmcfg: ({})
    property var draft: ({})
    property string mode: "hybrid"
    property string seg: "graphics"
    property string planText: ""
    property bool planning: false
    property string actionError: ""
    property bool vmRunning: false

    readonly property var blockerText: ({
        "needs-relogin": "Log out and back in: Ryoku must move to the iGPU first.",
        "needs-reboot": "Reboot into hybrid mode (flip the MUX) first.",
        "needs-setup": "Enable passthrough below first.",
        "incapable": "This machine cannot pass the GPU through."
    })

    function reload() {
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
        page.act(["ryoku-hub", "gpu", "mode", "set", m]);
    }
    function reviewEnable() {
        planProc.command = ["ryoku-hub", "gpu", "apply", "enable", "--dry-run"];
        planProc.running = true;
    }
    function confirmEnable() {
        page.planText = "Enabling passthrough. You may be prompted for your password...\n";
        page.planning = true;
        enableProc.command = ["sh", "-c", "ryoku-hub gpu apply enable 2>&1"];
        enableProc.running = true;
    }

    onVmcfgChanged: page.draft = JSON.parse(JSON.stringify(page.vmcfg))
    Component.onCompleted: page.reload()

    Process {
        id: capsProc
        command: ["ryoku-hub", "gpu", "caps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.caps = JSON.parse(this.text);
                } catch (e) {
                    console.log("gpu: caps parse failed: " + e);
                }
            }
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
        id: enableProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.planText += this.text;
                page.reload();
            }
        }
    }
    Process {
        id: pickProc
        command: ["sh", "-c", "zenity --file-selection --file-filter='ISO | *.iso *.ISO' 2>/dev/null || kdialog --getopenfilename $HOME '*.iso' 2>/dev/null"]
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
    // While the Machine tab is open, keep the Launch/Stop toggle in step with the VM.
    Timer {
        interval: 5000
        repeat: true
        running: page.seg === "vm"
        onTriggered: statusProc.running = true
    }

    // A dossier row: status dot, label, and the detected value, coloured by level.
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

    Segmented {
        id: segCtl
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        model: [{ "key": "graphics", "label": "Graphics" }, { "key": "vm", "label": "Machine" }]
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
            cardWidth: Math.min(parent.width * 0.4, 380)
        }

        Item {
            id: rightCol
            anchors.left: hero.right
            anchors.leftMargin: 40
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // ── Graphics: the capability dossier + the mode switch + enable ──────
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
                    spacing: 20

                    SettingSection {
                        width: parent.width
                        title: "CAPABILITY"
                        Repeater {
                            model: page.caps.checks || []
                            delegate: CheckRow {
                                required property var modelData
                                width: parent.width
                                check: modelData
                            }
                        }
                    }

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
                            text: "Hybrid keeps the iGPU primary (battery). Performance pins the dGPU. "
                                + "Passthrough frees the dGPU for the VM. A change takes effect on the next login."
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    SettingSection {
                        width: parent.width
                        title: "PASSTHROUGH STACK"

                        Text {
                            width: parent.width
                            visible: page.caps.enabled === true
                            text: "Installed and configured. The discrete GPU joins the VM at launch and returns when it stops."
                            color: Theme.ok
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        Text {
                            width: parent.width
                            visible: page.caps.enabled !== true && !page.planning
                            wrapMode: Text.WordWrap
                            text: "Installs qemu, libvirt, OVMF, swtpm and Looking Glass, then configures kvmfr, "
                                + "a libvirt hook and permissions. Reversible. You will be asked for your password."
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        HubButton {
                            visible: page.caps.enabled !== true && !page.planning
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
                                visible: page.caps.enabled !== true
                                label: "Enable passthrough"
                                icon: "check"
                                primary: true
                                onClicked: page.confirmEnable()
                            }
                            HubButton { label: "Close"; icon: "close"; onClicked: { page.planning = false; page.planText = ""; } }
                        }
                    }
                }
            }

            // ── Machine: the VM config and launch, gated on capability ──────────
            Item {
                id: vmv
                anchors.fill: parent
                visible: page.seg === "vm"

                readonly property bool usable: page.caps.enabled === true && page.caps.verdict !== "incapable"

                Flickable {
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: vmCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    opacity: vmv.usable ? 1 : 0.35
                    enabled: vmv.usable

                    Column {
                        id: vmCol
                        width: parent.width - 8
                        spacing: 18

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
                                        text: "Path to a Windows 11 or Linux ISO"
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
                                label: "Guest"
                                options: [{ "key": "windows11", "label": "Windows 11" }, { "key": "linux", "label": "Linux" }]
                                current: page.draft.guest || "windows11"
                                onChosen: (k) => page.patch("guest", k)
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
                                onClicked: {
                                    page.act(["ryoku-hub", "vm", "save", JSON.stringify(page.draft)]);
                                }
                            }
                            HubButton {
                                visible: !page.vmRunning
                                label: "Launch VM"
                                icon: "rocket"
                                primary: true
                                enabled: page.caps.verdict === "ready"
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
                            visible: page.caps.verdict !== undefined && page.caps.verdict !== "ready"
                            wrapMode: Text.WordWrap
                            text: page.blockerText[page.caps.verdict] || ""
                            color: Theme.ember
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }

                // Gate message when the stack is not ready to configure a VM.
                Text {
                    anchors.centerIn: parent
                    visible: !vmv.usable
                    width: parent.width * 0.7
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: page.caps.verdict === "incapable"
                        ? "This machine cannot pass a GPU to a VM. See the Graphics tab for why."
                        : "Enable passthrough in the Graphics tab first."
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 14
                }
            }

            // Action error banner: a refused mode switch, a failed launch, etc.
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
