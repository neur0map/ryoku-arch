pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// The Instant lane's right pane: pick a prebuilt cloud OS, choose whether it's
// disposable (burn) or a keeper, and press one key to get an ssh-able machine
// with the ryoku burn account — no installer. Reuses the create download bar
// (instant streams the same phases) so the build shows live and lands in the
// Library.
Item {
    id: pane

    property var os: null              // a cloudList entry
    property bool disposableRun: true  // instant machines default to burn

    // curated toolset chips; clip (OSC 52 host-clipboard) is always baked, spice
    // adds the console clipboard. heavy tools (docker/podman) reinstall on every
    // disposable boot — the steer points those users at templates.
    property var toolDefs: [
        { id: "git", label: "git" }, { id: "build", label: "build tools" },
        { id: "python", label: "python" }, { id: "node", label: "node/npm" },
        { id: "go", label: "go" }, { id: "rust", label: "rust" },
        { id: "docker", label: "docker", heavy: true }, { id: "podman", label: "podman", heavy: true },
        { id: "jq", label: "jq" }, { id: "net", label: "curl/wget" },
        { id: "cli", label: "htop·tmux·vim·rg" }, { id: "spice", label: "SPICE clipboard" }
    ]
    property var picked: (Vm.settings.tools || "").split(",").filter(s => s.length > 0)
    function toggleTool(id) {
        var i = pane.picked.indexOf(id);
        if (i < 0) pane.picked.push(id); else pane.picked.splice(i, 1);
        pane.picked = pane.picked.slice();
        Vm.settings.tools = pane.picked.join(",");
        Vm.saveSettings();
    }
    readonly property bool heavyDisposable: pane.disposableRun
        && pane.toolDefs.some(t => t.heavy && pane.picked.indexOf(t.id) >= 0)

    // empty state.
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: pane.os === null && !Vm.downloading
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "download"; size: 30; tint: Theme.faint }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: 320
            wrapMode: Text.WordWrap
            text: "Pick a system for an instant machine — prebuilt, no installer, logs in as ryoku."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
        }
    }

    // building state: reuse the streaming download bar.
    Column {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width - 48
        visible: Vm.downloading
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "download"; size: 34; tint: Theme.ember }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Vm.dlName
            color: Theme.bright; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({ "resolve": "Fetching the cloud image", "download": "Downloading the image", "config": "Baking the burn account" })[Vm.dlPhase] || "Working"
            color: Theme.subtle; font.family: Theme.font; font.pixelSize: 13
        }
        Rectangle {
            width: parent.width; height: 8; color: Theme.surfaceLo
            border.width: 1; border.color: Theme.line; clip: true; antialiasing: false
            Rectangle {
                id: sweep
                width: parent.width * 0.3; height: parent.height; color: Theme.ember; antialiasing: false
                SequentialAnimation on x {
                    running: sweep.visible; loops: Animation.Infinite
                    NumberAnimation { from: -sweep.width; to: sweep.parent.width; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: "First image of a distro downloads once; the next is seconds."
            color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
        }
        HubButton {
            anchors.horizontalCenter: parent.horizontalCenter
            label: "Cancel"; icon: "close"; accent: Theme.bad
            onClicked: Vm.cancelCreate()
        }
    }

    // chosen OS: the create sheet.
    Item {
        anchors.fill: parent
        visible: pane.os !== null && !Vm.downloading

        Eyebrow { id: eyebrow; anchors.top: parent.top; anchors.left: parent.left; text: "Instant machine" }

        BrutalPanel {
            id: hero
            anchors.top: eyebrow.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            step: Theme.shadowStep
            surface: Theme.rail
            line: Theme.lineStrong
            implicitHeight: Math.max(150, parent.height * 0.26) + Theme.shadowStep
            RegMark { x: parent.width - width - 16; y: 15; size: 12; tint: Theme.faint }
            Column {
                anchors.centerIn: parent
                spacing: 12
                OsIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64; size: 64
                    slug: pane.os ? pane.os.os : ""
                    label: pane.os ? pane.os.name : ""
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pane.os ? pane.os.name : ""
                    color: Theme.bright; font.family: Theme.display; font.pixelSize: 22; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (pane.os ? "~" + pane.os.size + " · " : "") + "logs in as ryoku / ryoku"
                    color: Theme.faint; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.2
                }
            }
        }

        Flickable {
            anchors.top: hero.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: lower.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: BoardScrollBar {}

            Column {
                id: lower
                width: parent.width - 8
                spacing: 16

                Row {
                    spacing: 10
                    Toggle { anchors.verticalCenter: parent.verticalCenter; on: pane.disposableRun; onToggled: (v) => pane.disposableRun = v }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: pane.disposableRun ? "DISPOSABLE — writes burn at power-off" : "KEEPER — writes persist"
                            color: pane.disposableRun ? Theme.ember : Theme.cream
                            font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                        }
                        Text {
                            text: pane.disposableRun ? "every boot re-provisions the ryoku account, factory-fresh" : "a normal machine you can seal and reuse"
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10
                    Eyebrow { text: "Tools baked in on first boot" }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: pane.toolDefs
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool on: pane.picked.indexOf(modelData.id) >= 0
                                height: 28
                                width: chipLabel.width + 22
                                color: on ? Theme.frameBg : Theme.surfaceLo
                                border.width: 1
                                border.color: on ? Theme.ember : (ch.hovered ? Qt.alpha(Theme.ember, 0.5) : Theme.line)
                                antialiasing: false
                                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: on ? Theme.ember : Theme.cream
                                    font.family: Theme.mono; font.pixelSize: 12
                                }
                                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: pane.toggleTool(modelData.id) }
                            }
                        }
                    }
                    // free-text: any extra distro packages, comma-separated.
                    Rectangle {
                        width: parent.width
                        height: 34
                        color: Theme.surfaceLo
                        border.width: 1
                        border.color: extraInput.activeFocus ? Theme.ember : Theme.line
                        antialiasing: false
                        TextInput {
                            id: extraInput
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.bright
                            font.family: Theme.mono; font.pixelSize: 12
                            clip: true
                            selectByMouse: true
                            text: Vm.settings.extraPkgs || ""
                            onTextEdited: { Vm.settings.extraPkgs = text; Vm.saveSettings(); }
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: extraInput.text.length === 0
                                text: "…and any other packages, comma-separated (e.g. postgresql, redis)"
                                color: Theme.faint
                                font: extraInput.font
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: pane.heavyDisposable
                        text: "Heavy tools reinstall on every disposable boot (~a minute). For a fast throwaway with these baked in, make this a keeper, then \u201cSave as template\u201d in its detail pane and spawn clones — tools baked, boot in seconds."
                        color: Theme.warn
                        font.family: Theme.font; font.pixelSize: 11
                    }
                }

                HubButton {
                    primary: true
                    icon: "play"
                    label: pane.disposableRun ? "Create · burn" : "Create machine"
                    enabled: pane.os !== null && Vm.caps.quickemu === true
                    onClicked: Vm.instant(pane.os.os, "", pane.disposableRun, pane.picked.join(","), Vm.settings.extraPkgs || "")
                }

                Item { width: 1; height: 6 }
            }
        }
    }
}
