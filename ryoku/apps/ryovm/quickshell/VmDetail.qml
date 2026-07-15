pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// The right half in Library mode: the live machine stage as the hero, then the
// lifecycle actions, the resource editor, snapshots, and the danger zone. Driven
// by Vm.selected (the list row) and Vm.detail (the full `get`).
Item {
    id: pane

    readonly property var vm: Vm.selected
    readonly property var det: Vm.detail
    readonly property bool running: pane.vm ? pane.vm.running === true : false
    readonly property string name: pane.vm ? pane.vm.name : ""
    // the launch display also persists, so the choice survives the 5s refresh
    // (which re-creates the vm object) and is remembered next session.
    property string launchMode: "window"
    // run the next launch on a burn-after-use overlay (quickemu --status-quo).
    property bool disposableRun: false
    readonly property var sealSnap: {
        var ss = pane.det ? (pane.det.snapshots || []) : [];
        for (var i = 0; i < ss.length; i++)
            if (ss[i].name === "sealed")
                return ss[i];
        return null;
    }
    readonly property var _modeFromDisplay: ({ "gtk": "window", "spice": "spice", "none": "headless" })
    // current disk cap in GB (from the conf), and the grow target the field edits.
    readonly property int capGb: {
        var d = pane.vm ? (pane.vm.disk || "") : "";
        var n = parseInt(d);
        return d.length === 0 ? 0 : (d.indexOf("M") >= 0 ? Math.max(1, Math.round(n / 1024)) : (n || 0));
    }
    property int diskTarget: 64
    onVmChanged: {
        pane.launchMode = pane._modeFromDisplay[pane.vm ? pane.vm.display : "gtk"] || "window";
        var d = pane.vm ? (pane.vm.disk || "") : "", n = parseInt(d);
        pane.diskTarget = d.length === 0 ? 64 : (d.indexOf("M") >= 0 ? Math.max(1, Math.round(n / 1024)) : (n || 64));
    }
    onNameChanged: renameField.text = pane.name

    // empty state when nothing is selected.
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: pane.vm === null
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "server"; size: 30; tint: Theme.faint }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pick a machine to manage it"
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
        }
    }

    Item {
        anchors.fill: parent
        visible: pane.vm !== null

        // eyebrow.
        Item {
            id: eyebrow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            Eyebrow {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Machine"
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 220
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: pane.name
                color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 11
            }
        }

        // hero stage.
        VmStage {
            id: stage
            anchors.top: eyebrow.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(210, parent.height * 0.36)
            name: pane.name
            installed: pane.det ? pane.det.installed === true : false
            disposable: pane.vm ? pane.vm.disposable === true : false
            sshReady: pane.det ? pane.det.sshReady === true : false
            sealed: pane.det ? pane.det.sealed === true : (pane.vm ? pane.vm.sealed === true : false)
            tpmOn: pane.vm ? pane.vm.tpm === true : false
            uefiOn: pane.vm ? pane.vm.uefi !== false : true
            guest: pane.vm ? (pane.vm.guest || "linux") : "linux"
            os: pane.vm ? (pane.vm.os || "") : ""
            running: pane.running
            mode: pane.vm ? pane.vm.display : "gtk"
            ssh: pane.vm ? (pane.vm.ssh || "") : ""
            spice: pane.vm ? (pane.vm.spice || "") : ""
            cores: pane.vm ? (pane.vm.cores || "auto") : "auto"
            ram: pane.vm ? (pane.vm.ram || "auto") : "auto"
            diskUsed: pane.vm ? (pane.vm.diskUsed || 0) : 0
            diskCap: pane.vm ? (pane.vm.disk || "") : ""
        }

        // actions row.
        Item {
            id: actions
            anchors.top: stage.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56

            // stopped: Launch + mode selector + the disposable switch, and an
            // honest caption per mode.
            Column {
                visible: !pane.running
                spacing: 6
                Row {
                    spacing: 10
                    HubButton {
                        primary: true
                        icon: "play"
                        label: pane.disposableRun ? "Launch · burn" : "Launch"
                        enabled: !Vm.busy && Vm.caps.quickemu === true
                            && !(pane.launchMode === "spice" && Vm.caps.spice !== true)
                        onClicked: Vm.launch(pane.name, pane.launchMode, pane.disposableRun)
                    }
                    Segmented {
                        anchors.verticalCenter: parent.verticalCenter
                        segW: 74
                        model: [{ key: "window", label: "Window" }, { key: "spice", label: "SPICE" }, { key: "headless", label: "Headless" }]
                        current: pane.launchMode
                        onSelected: (k) => { pane.launchMode = k; Vm.setConfig(pane.name, "display", ({ "window": "gtk", "spice": "spice", "headless": "none" })[k]); }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        visible: pane.det && pane.det.installed === true
                        Toggle {
                            anchors.verticalCenter: parent.verticalCenter
                            on: pane.disposableRun
                            enabled: !Vm.busy
                            onToggled: (v) => pane.disposableRun = v
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DISPOSABLE"
                            color: pane.disposableRun ? Theme.ember : Theme.faint
                            font.family: Theme.mono; font.pixelSize: 9
                            font.weight: Font.DemiBold; font.letterSpacing: 1.5
                            Behavior on color { ColorAnimation { duration: Theme.quick } }
                        }
                    }
                }
                Text {
                    text: pane.det && pane.det.installed !== true
                        ? "First launch boots the OS installer — install onto the virtual disk, then power off. After that it boots from disk."
                        : pane.launchMode === "spice" && Vm.caps.spice !== true
                        ? "SPICE needs its viewer — install the spice-gtk package, then relaunch"
                        : pane.disposableRun
                        ? "Disposable session: every disk write burns up at power-off — the machine boots identical next time"
                        : ({
                            "window": "Plain window · host↔guest clipboard is OFF in this mode",
                            "spice": "SPICE viewer · shared clipboard, USB redirect, best desktop fidelity",
                            "headless": "No display · reach it over SSH or attach a console anytime"
                        })[pane.launchMode] || ""
                    color: pane.det && pane.det.installed !== true ? Theme.dim
                        : pane.launchMode === "spice" && Vm.caps.spice !== true ? Theme.warn
                        : pane.disposableRun ? Theme.ember : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }

            // running: Stop + Console + SSH.
            Row {
                visible: pane.running
                spacing: 10
                HubButton {
                    icon: "stop"
                    label: "Stop"
                    accent: Theme.bad
                    enabled: !Vm.busy
                    onClicked: Vm.stop(pane.name)
                }
                HubButton {
                    primary: true
                    icon: "display"
                    label: "Console"
                    enabled: (pane.vm && (pane.vm.spice || "").length > 0) && Vm.caps.spice === true
                    onClicked: Vm.openConsole(pane.name)
                }
                HubButton {
                    icon: "terminal"
                    label: "SSH"
                    enabled: (pane.vm && (pane.vm.ssh || "").length > 0)
                    onClicked: Vm.openSsh(pane.name)
                }
            }
        }

        // lower: scrollable config + snapshots + danger.
        Flickable {
            anchors.top: actions.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: lower.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: BoardScrollBar {}

            Column {
                id: lower
                width: parent.width - 8
                spacing: 18

                // ── reach it: every live line into the machine ──────────────
                // The most important panel while a VM runs: the SSH endpoint as
                // a ready command with one-tap copy, the console's real
                // availability (socket AND viewer), and the release keys for
                // whichever display mode has the cursor.
                Column {
                    width: parent.width
                    spacing: 10
                    visible: pane.running
                    SectionHead { text: "Reach it" }
                    Rectangle {
                        width: parent.width
                        color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.35)
                        antialiasing: false
                        implicitHeight: ctrlCol.implicitHeight + 28
                        Column {
                            id: ctrlCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 12

                            // SSH line: the command as-is, then act on it.
                            Row {
                                width: parent.width
                                spacing: 10
                                visible: pane.vm && (pane.vm.ssh || "").length > 0
                                Rectangle {
                                    width: parent.width - sshBtns.width - 10
                                    height: 30
                                    color: Theme.bgBot
                                    border.width: 1
                                    border.color: Theme.lineSoft
                                    antialiasing: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        // what Open/Copy actually run (short form): a
                                        // display line that hides the login invites a
                                        // "password I never set" haunting.
                                        text: "ssh -p " + (pane.vm ? pane.vm.ssh : "")
                                            + " " + (pane.det && pane.det.sshUser ? pane.det.sshUser + "@" : "") + "localhost"
                                        color: Theme.cream
                                        font.family: Theme.mono; font.pixelSize: 12
                                    }
                                }
                                Row {
                                    id: sshBtns
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    HubButton { label: "Open"; icon: "terminal"; onClicked: Vm.openSsh(pane.name) }
                                    HubButton { label: "Copy"; icon: "copy"; onClicked: Vm.copySsh(pane.name) }
                                }
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                visible: pane.vm && (pane.vm.ssh || "").length > 0
                                text: pane.det && pane.det.sshReady === true
                                    ? "Guest is answering — connect away."
                                    : "Port is forwarded but the guest isn't answering yet: still booting, or no SSH server inside (live ISOs never have one)."
                                color: pane.det && pane.det.sshReady === true ? Theme.ok : Theme.warn
                                font.family: Theme.font; font.pixelSize: 11
                            }

                            // the account ssh signs in with — the #1 "asked for a
                            // password I never set": that account must exist in the
                            // guest. Editable hot; the conf keeps it per machine.
                            Row {
                                width: parent.width
                                spacing: 10
                                visible: pane.vm && (pane.vm.ssh || "").length > 0
                                SubLabel { anchors.verticalCenter: parent.verticalCenter; text: "Login as" }
                                Rectangle {
                                    width: 170
                                    height: 30
                                    color: Theme.bgBot
                                    border.width: 1
                                    border.color: sshUserField.activeFocus ? Theme.ember : Theme.lineSoft
                                    antialiasing: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    TextInput {
                                        id: sshUserField
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.bright
                                        font.family: Theme.mono
                                        font.pixelSize: 12
                                        clip: true
                                        selectByMouse: true
                                        text: pane.det && pane.det.sshUser ? pane.det.sshUser : ""
                                        onTextEdited: text = text.replace(/\s+/g, "")
                                        onEditingFinished: {
                                            var u = text.trim();
                                            if (u.length > 0 && pane.det && u !== pane.det.sshUser) {
                                                Vm.setConfig(pane.name, "ryovm_ssh_user", u);
                                                Vm.reselect();
                                            }
                                        }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "the guest account ssh signs in with"
                                    color: Theme.faint; font.family: Theme.font; font.pixelSize: 11
                                }
                            }

                            // console line: honest about socket AND viewer.
                            Row {
                                spacing: 10
                                visible: pane.vm && (pane.vm.spice || "").length > 0
                                HubButton {
                                    label: "Attach console"
                                    icon: "display"
                                    enabled: Vm.caps.spice === true
                                    onClicked: Vm.openConsole(pane.name)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Vm.caps.spice === true
                                        ? "SPICE screen on localhost:" + (pane.vm ? pane.vm.spice : "")
                                        : "needs the SPICE viewer — install the spice-gtk package"
                                    color: Vm.caps.spice === true ? Theme.dim : Theme.warn
                                    font.family: Theme.font; font.pixelSize: 11
                                }
                            }

                            KeyHint {
                                keys: pane.vm && pane.vm.display === "spice" ? "Shift  F12"
                                    : pane.vm && pane.vm.display === "gtk" ? "Ctrl  Alt  G" : ""
                                action: "Release the mouse and keyboard"
                                visible: pane.vm && pane.vm.display !== "none"
                            }
                            KeyHint {
                                keys: pane.vm && pane.vm.display === "spice" ? "F11" : "Ctrl  Alt  F"
                                action: "Toggle fullscreen"
                                visible: pane.vm && pane.vm.display !== "none"
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: pane.vm && pane.vm.display === "none"
                                    ? "Headless: no window exists — this panel is the machine's only door."
                                    : "Stuck with the cursor grabbed? The Stop button above always powers the machine off."
                                color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }
                }

                // ── identity: rename the machine (stopped only) ─────────────
                Column {
                    width: parent.width
                    spacing: 10
                    SectionHead { text: "Identity" }
                    Text {
                        visible: pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Stop the machine to rename it."
                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        visible: !pane.running
                        Rectangle {
                            width: parent.width - renameBtn.width - 10
                            height: 38
                            radius: Theme.radius
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: renameField.activeFocus ? Theme.ember : Theme.line
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                            TextInput {
                                id: renameField
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                Component.onCompleted: text = pane.name
                                onTextEdited: text = text.replace(/[\/\s]+/g, "-")
                                onAccepted: if (renameBtn.enabled) renameBtn.clicked()
                            }
                        }
                        HubButton {
                            id: renameBtn
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Rename"
                            icon: "check"
                            primary: true
                            enabled: !Vm.busy && renameField.text.trim().length > 0 && renameField.text.trim() !== pane.name
                            onClicked: Vm.renameVm(pane.name, renameField.text.trim())
                        }
                    }
                }

                // ── resources (editable only when stopped) ──────────────────
                Column {
                    width: parent.width
                    spacing: 12
                    SectionHead { text: "Resources" }
                    Text {
                        visible: !pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "AUTO means quickemu tunes it to your hardware at launch. Set a number here to pin it."
                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                    }
                    Text {
                        visible: pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Stop the machine to change its hardware."
                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                    }
                    NumberField {
                        width: Math.min(parent.width, 460)
                        enabled: !pane.running
                        label: "CPU cores"
                        from: 1; to: 32; step: 1
                        value: pane.vm && pane.vm.cores !== "auto" ? (parseInt(pane.vm.cores) || Vm.settings.defaultCores) : Vm.settings.defaultCores
                        onModified: (v) => Vm.setConfig(pane.name, "cpu_cores", Math.round(v))
                    }
                    NumberField {
                        width: Math.min(parent.width, 460)
                        enabled: !pane.running
                        label: "Memory"
                        unit: "GB"
                        from: 1; to: 128; step: 1
                        value: {
                            var r = pane.vm ? pane.vm.ram : "";
                            if (!r || r === "auto")
                                return Vm.settings.defaultRam;
                            var n = parseFloat(r);
                            return r.indexOf("M") >= 0 ? Math.max(1, Math.round(n / 1024)) : (n || Vm.settings.defaultRam);
                        }
                        onModified: (v) => Vm.setConfig(pane.name, "ram", Math.round(v) + "G")
                    }
                    // disk: the real footprint and an explicit grow (reclaim lives
                    // in the danger zone with the other destructive actions).
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: pane.det && pane.det.installed
                        Row {
                            width: parent.width
                            spacing: 9
                            SubLabel { anchors.verticalCenter: parent.verticalCenter; text: "Disk" }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (pane.vm ? Vm.human(pane.vm.diskUsed || 0) : "0") + " used"
                                    + (pane.vm && pane.vm.disk ? "  \u00b7  " + pane.vm.disk + " cap" : "")
                                color: Theme.cream; font.family: Theme.mono; font.pixelSize: 12
                            }
                        }
                        Row {
                            width: parent.width
                            spacing: 10
                            NumberField {
                                width: Math.min(parent.width - growBtn.width - 10, 360)
                                enabled: !pane.running
                                label: "Disk size"
                                unit: "GB"
                                from: 1; to: 2048; step: 8
                                value: pane.diskTarget
                                onModified: (v) => pane.diskTarget = Math.round(v)
                            }
                            HubButton {
                                id: growBtn
                                anchors.verticalCenter: parent.verticalCenter
                                label: "Grow"
                                icon: "disk"
                                primary: true
                                enabled: !pane.running && !Vm.busy && pane.diskTarget > pane.capGb
                                onClicked: Vm.resizeDisk(pane.name, pane.diskTarget + "G")
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Grow only; the guest extends its partition afterwards."
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
                }

                // ── the seal: golden state for disposable machines ──────────
                Column {
                    width: parent.width
                    spacing: 10
                    visible: pane.det && pane.det.installed === true
                    SectionHead { text: "Seal" }
                    Text {
                        visible: pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Stop the machine to seal or restore it."
                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                    }
                    Column {
                        width: parent.width
                        spacing: 10
                        visible: !pane.running
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: pane.sealSnap !== null
                                ? "Sealed " + pane.sealSnap.date + ". Disposable runs never touch the seal; a normal run that dirties the machine can be rolled back to it."
                                : "Set the machine up the way you want it — packages, users, config — then seal that state. Disposable runs will boot from it forever; restore brings a dirtied machine back."
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                        }
                        Row {
                            spacing: 12
                            HubButton {
                                visible: pane.sealSnap === null
                                label: "Seal machine"
                                icon: "snapshot"
                                primary: true
                                enabled: !Vm.busy
                                onClicked: Vm.seal(pane.name)
                            }
                            ConfirmButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pane.sealSnap !== null
                                enabled: !Vm.busy
                                label: "Re-seal now"
                                confirmLabel: "Overwrite seal?"
                                icon: "snapshot"
                                onConfirmed: Vm.seal(pane.name)
                            }
                            GuardSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pane.sealSnap !== null
                                enabled: !Vm.busy
                                label: "RESTORE SEAL"
                                armedLabel: "ROLL BACK"
                                onFired: Vm.restoreSeal(pane.name)
                            }
                        }
                    }
                }

                // ── usb: host devices handed to this machine at boot ────────
                Column {
                    width: parent.width
                    spacing: 10
                    SectionHead { text: "USB devices" }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: pane.running
                            ? "Stop the machine to change assignments — devices attach at the next launch."
                            : "Engaged devices are handed to the guest when it boots."
                        color: pane.running ? Theme.ember : Theme.dim
                        font.family: Theme.font; font.pixelSize: pane.running ? 12 : 11
                    }
                    Text {
                        visible: Vm.usb.length === 0
                        text: "No USB devices detected on the host."
                        color: Theme.faint; font.family: Theme.font; font.pixelSize: 12
                    }
                    Repeater {
                        model: Vm.usb
                        delegate: Rectangle {
                            id: usbRow
                            required property var modelData
                            width: parent ? parent.width : 0
                            height: 40
                            color: usbRow.modelData.assigned ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.05) : Theme.surfaceLo
                            border.width: 1
                            border.color: usbRow.modelData.assigned ? Qt.alpha(Theme.ember, 0.35) : Theme.lineSoft
                            antialiasing: false
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            Toggle {
                                id: usbToggle
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: !pane.running && !Vm.busy
                                on: usbRow.modelData.assigned === true
                                onToggled: (v) => Vm.setUsb(pane.name, usbRow.modelData.id, v)
                            }
                            Text {
                                anchors.left: usbToggle.right
                                anchors.leftMargin: 12
                                anchors.right: usbId.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: usbRow.modelData.name
                                color: usbRow.modelData.assigned ? Theme.cream : Theme.subtle
                                font.family: Theme.font; font.pixelSize: 13
                            }
                            Text {
                                id: usbId
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: usbRow.modelData.id
                                color: Theme.faint
                                font.family: Theme.mono; font.pixelSize: 11
                            }
                        }
                    }
                }

                // ── snapshots ────────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 10
                    SectionHead { text: "Snapshots" }
                    // no disk yet: say exactly what a snapshot needs and what to
                    // press, instead of promising a section that never appears.
                    Rectangle {
                        visible: !(pane.det && pane.det.installed)
                        width: parent.width
                        height: 44
                        color: Theme.surfaceLo
                        border.width: 1
                        border.color: Theme.lineSoft
                        antialiasing: false
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Annunciator { anchors.verticalCenter: parent.verticalCenter; label: "NO DISK"; lit: false; tileW: 60 }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Snapshots capture the disk — press Launch once to create it, then save states here."
                                color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }
                    Text {
                        visible: pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Stop the machine to manage snapshots."
                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        visible: pane.det && pane.det.installed && !pane.running
                        Rectangle {
                            width: parent.width - addSnap.width - 10
                            height: 38
                            radius: Theme.radius
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: snapIn.activeFocus ? Theme.ember : Theme.line
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                            TextInput {
                                id: snapIn
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onAccepted: if (addSnap.enabled) addSnap.clicked()
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: snapIn.text.length === 0
                                    text: "Snapshot name (e.g. clean install)"
                                    color: Theme.faint
                                    font: snapIn.font
                                }
                            }
                        }
                        HubButton {
                            id: addSnap
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Save"
                            icon: "snapshot"
                            primary: true
                            enabled: snapIn.text.trim().length > 0
                            onClicked: { Vm.snapshot(pane.name, "create", snapIn.text.trim()); snapIn.text = ""; }
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: pane.det && pane.det.installed
                        Text {
                            visible: pane.det && (!pane.det.snapshots || pane.det.snapshots.length === 0) && !pane.running
                            text: "No snapshots yet."
                            color: Theme.faint; font.family: Theme.font; font.pixelSize: 12
                        }
                        Repeater {
                            model: pane.det ? pane.det.snapshots : []
                            delegate: Rectangle {
                                id: snapRow
                                required property var modelData
                                width: parent ? parent.width : 0
                                height: 44
                                radius: Theme.radius
                                color: Theme.surfaceLo
                                border.width: 1
                                border.color: Theme.line
                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: snapActions.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: snapRow.modelData.name
                                        color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                                    }
                                    Text {
                                        text: snapRow.modelData.date
                                        color: Theme.dim; font.family: Theme.mono; font.pixelSize: 10
                                    }
                                }
                                Row {
                                    id: snapActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    GuardSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        enabled: !pane.running && !Vm.busy
                                        label: "RESTORE"
                                        armedLabel: "ROLL BACK"
                                        onFired: Vm.snapshot(pane.name, "restore", snapRow.modelData.name)
                                    }
                                    ConfirmButton {
                                        enabled: !pane.running
                                        label: "Delete"
                                        confirmLabel: "Delete?"
                                        icon: "trash"
                                        onConfirmed: Vm.snapshot(pane.name, "delete", snapRow.modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── danger: verbs under guard covers ────────────────────────
                Column {
                    width: parent.width
                    spacing: 10
                    SectionHead { text: "Danger zone" }
                    Row {
                        spacing: 12
                        HubButton {
                            icon: "folder"
                            label: "Open folder"
                            onClicked: Vm.openFolder(pane.name)
                        }
                        GuardSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pane.det && pane.det.installed === true
                            enabled: !pane.running && !Vm.busy
                            label: "RECLAIM DISK"
                            armedLabel: "WIPE DISK"
                            onFired: Vm.reclaimDisk(pane.name)
                        }
                        GuardSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !pane.running && !Vm.busy
                            label: "DELETE MACHINE"
                            armedLabel: "DESTROY"
                            onFired: Vm.deleteVm(pane.name)
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Reclaim deletes the disk image but keeps the machine and its setup, ready to reinstall. Delete removes everything."
                        color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                    }
                }

                // ── the machine plate: engraved, screwed on ─────────────────
                Rectangle {
                    width: parent.width
                    height: 54
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: Theme.line
                    antialiasing: false

                    // inner engraved bevel.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.lineSoft
                        antialiasing: false
                    }
                    // corner screws.
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 4; height: 4
                            radius: 2
                            color: Theme.faint
                            x: index % 2 === 0 ? 7 : parent.width - 11
                            y: index < 2 ? 7 : parent.height - 11
                        }
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 26
                        Text {
                            text: "RYOKU RYOVM · TYPE V-01"
                            color: Theme.dim
                            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
                        }
                        Text {
                            text: "GUEST " + (pane.vm ? (pane.vm.guest || "linux").toUpperCase() : "—")
                            color: Theme.faint
                            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
                        }
                        Text {
                            text: "CARRIER QEMU·KVM"
                            color: Theme.faint
                            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2
                        }
                    }
                }

                Item { width: 1; height: 6 }
            }
        }
    }

    component SectionHead: Row {
        id: sh
        property string text: ""
        spacing: 7
        Rectangle { width: 5; height: 5; radius: Theme.radius; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
        Text { anchors.verticalCenter: parent.verticalCenter; text: sh.text; color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
    }
    component SubLabel: Text {
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10
        font.letterSpacing: 1.5
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    // a keyboard-shortcut row: mono key chips + what they do.
    component KeyHint: Row {
        id: kh
        property string keys: ""
        property string action: ""
        width: parent ? parent.width : 0
        spacing: 10
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 112
            height: 24
            radius: Theme.radius
            color: Theme.surfaceLo
            border.width: 1
            border.color: Theme.line
            Text {
                anchors.centerIn: parent
                text: kh.keys
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: kh.action
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
