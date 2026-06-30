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
    readonly property var _modeFromDisplay: ({ "gtk": "window", "spice": "spice", "none": "headless" })
    onVmChanged: pane.launchMode = pane._modeFromDisplay[pane.vm ? pane.vm.display : "gtk"] || "window"

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
        Row {
            id: eyebrow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            spacing: 7
            Rectangle { width: 5; height: 5; radius: 1; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Machine"
                color: Theme.faint; font.family: Theme.mono; font.pixelSize: 10
                font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
            }
            Item { width: pane.width - 260; height: 1 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 200
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
            height: Math.max(190, parent.height * 0.34)
            guest: pane.vm ? (pane.vm.guest || "linux") : "linux"
            os: pane.vm ? (pane.vm.os || "") : ""
            running: pane.running
            mode: pane.vm ? pane.vm.display : "gtk"
            ssh: pane.vm ? (pane.vm.ssh || "") : ""
            spice: pane.vm ? (pane.vm.spice || "") : ""
        }

        // actions row.
        Item {
            id: actions
            anchors.top: stage.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38

            // stopped: Launch + mode selector.
            Row {
                visible: !pane.running
                spacing: 10
                HubButton {
                    primary: true
                    icon: "play"
                    label: "Launch"
                    enabled: !Vm.busy
                    onClicked: Vm.launch(pane.name, pane.launchMode)
                }
                Segmented {
                    anchors.verticalCenter: parent.verticalCenter
                    segW: 74
                    model: [{ key: "window", label: "Window" }, { key: "spice", label: "SPICE" }, { key: "headless", label: "Headless" }]
                    current: pane.launchMode
                    onSelected: (k) => { pane.launchMode = k; Vm.setConfig(pane.name, "display", ({ "window": "gtk", "spice": "spice", "headless": "none" })[k]); }
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
                    enabled: (pane.vm && (pane.vm.spice || "").length > 0)
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
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: lower
                width: parent.width - 8
                spacing: 18

                // ── controls: how to free the cursor + reach the VM ─────────
                // The single most important thing when a VM grabs input, so it
                // leads, and the release key matches the actual display mode.
                Column {
                    width: parent.width
                    spacing: 10
                    visible: pane.running
                    SectionHead { text: "Controls" }
                    Rectangle {
                        width: parent.width
                        radius: 12
                        color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.4)
                        implicitHeight: ctrlCol.implicitHeight + 28
                        Column {
                            id: ctrlCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 10
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
                                visible: pane.vm && pane.vm.display === "none"
                                text: "This machine runs headless (no window). Open Console for a SPICE screen, or SSH in."
                                color: Theme.subtle; font.family: Theme.font; font.pixelSize: 13
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Stuck with the cursor grabbed? The Stop button above always powers the machine off."
                                color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }
                }

                // ── resources (editable only when stopped) ──────────────────
                Column {
                    width: parent.width
                    spacing: 12
                    SectionHead { text: "Resources" }
                    Text {
                        visible: pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Stop the machine to change its hardware."
                        color: Theme.ember; font.family: Theme.font; font.pixelSize: 12
                    }
                    NumberField {
                        width: Math.min(parent.width, 460)
                        enabled: !pane.running
                        label: "CPU cores"
                        from: 1; to: 32; step: 1
                        value: pane.vm && pane.vm.cores !== "auto" ? parseInt(pane.vm.cores) || 4 : 4
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
                                return 4;
                            var n = parseFloat(r);
                            return r.indexOf("M") >= 0 ? Math.max(1, Math.round(n / 1024)) : (n || 4);
                        }
                        onModified: (v) => Vm.setConfig(pane.name, "ram", Math.round(v) + "G")
                    }
                }

                // ── snapshots ────────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 10
                    SectionHead { text: "Snapshots" }
                    Text {
                        visible: !(pane.det && pane.det.installed)
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Launch the machine once to create its disk, then snapshots appear here."
                        color: Theme.faint; font.family: Theme.font; font.pixelSize: 12
                    }
                    Text {
                        visible: pane.running
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Stop the machine to manage snapshots."
                        color: Theme.ember; font.family: Theme.font; font.pixelSize: 12
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        visible: pane.det && pane.det.installed && !pane.running
                        Rectangle {
                            width: parent.width - addSnap.width - 10
                            height: 38
                            radius: 9
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
                                radius: 9
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
                                    ConfirmButton {
                                        enabled: !pane.running
                                        label: "Restore"
                                        confirmLabel: "Roll back?"
                                        icon: "refresh"
                                        onConfirmed: Vm.snapshot(pane.name, "restore", snapRow.modelData.name)
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

                // ── danger ───────────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 10
                    SectionHead { text: "Danger zone" }
                    Row {
                        spacing: 10
                        HubButton {
                            icon: "folder"
                            label: "Open folder"
                            onClicked: Vm.openFolder(pane.name)
                        }
                        ConfirmButton {
                            enabled: !pane.running
                            label: "Delete VM"
                            confirmLabel: "Erase everything?"
                            icon: "trash"
                            onConfirmed: Vm.deleteVm(pane.name)
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
        Rectangle { width: 5; height: 5; radius: 1; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
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
            radius: 6
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
