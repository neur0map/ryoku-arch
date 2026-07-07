pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "Singletons"

// System > Dictation. Voice typing with Voxtype: switch it on, pick a
// speech-to-text engine and model, and add an API key for the cloud engines.
// The shell owns Super+` and the pill mic-wave; this page only shapes
// ~/.config/voxtype/config.toml and the voxtype user service through
// `ryoku-hub voxtype`. Local models download in Voxtype's own terminal TUI.
Item {
    id: page
    readonly property bool previewDirty: false

    property var presets: []
    property string selected: "whisper-fast"
    property bool voiceOn: false
    property bool installed: false
    property bool loaded: false
    property bool openaiKeySet: false
    property bool sonioxKeySet: false
    property string busyError: ""

    readonly property var sel: {
        for (var i = 0; i < page.presets.length; i++)
            if (page.presets[i].key === page.selected)
                return page.presets[i];
        return null;
    }
    readonly property string keyKind: page.sel !== null ? page.sel.keyKind : ""
    readonly property bool needsKey: page.keyKind !== ""
    readonly property bool keyOnFile: page.keyKind === "openai" ? page.openaiKeySet
                                    : (page.keyKind === "soniox" ? page.sonioxKeySet : false)
    readonly property bool needDownload: page.sel !== null && page.sel.cloud !== true && page.sel.present !== true

    function reload() { getProc.running = true; }

    // apply a full snapshot: the selected preset, the enable state, and any
    // freshly typed key (blank keys are kept by the backend, never wiped).
    function apply(extra) {
        var req = { "preset": page.selected, "enabled": page.voiceOn, "openaiKey": "", "sonioxKey": "" };
        if (extra)
            for (var k in extra)
                req[k] = extra[k];
        page.busyError = "";
        setProc.command = ["ryoku-hub", "voxtype", "set", JSON.stringify(req)];
        setProc.running = true;
    }
    function choose(key) { page.selected = key; page.apply(null); }
    function setEnabled(on) { page.voiceOn = on; page.apply(null); }
    function saveKey(value) {
        if (value.length === 0)
            return;
        var e = {};
        e[page.keyKind === "openai" ? "openaiKey" : "sonioxKey"] = value;
        page.apply(e);
    }
    // model downloads run in a terminal: `voxtype setup model` is an interactive
    // picker, and the files are large, so it belongs in a window the user watches.
    function downloadModels() {
        Quickshell.execDetached(["kitty", "--class", "ryoku-dictation", "-e", "sh", "-c",
            "voxtype setup model; echo; read -n1 -rsp 'Done. Press any key to close\u2026'; echo"]);
    }

    // gpk (GlazePKG, the RyokuArch package manager) needs a tty for its AUR
    // build and sudo prompts; --hold keeps any error on screen after it exits.
    function installVoxtype() {
        Quickshell.execDetached(["kitty", "--hold", "-e", "gpk", "install", "voxtype-bin", "--manager", "aur"]);
    }

    // when the gpk terminal closes and the Hub regains focus, re-probe so the
    // page flips from the install prompt to the live settings on its own.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: if (page.windowActive) page.reload()

    Component.onCompleted: page.reload()

    Process {
        id: getProc
        command: ["ryoku-hub", "voxtype", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    page.presets = d.presets || [];
                    page.selected = d.selected || "whisper-fast";
                    page.voiceOn = d.enabled === true;
                    page.installed = d.installed === true;
                    page.openaiKeySet = d.openaiKeySet === true;
                    page.sonioxKeySet = d.sonioxKeySet === true;
                    page.loaded = true;
                } catch (e) {
                    console.log("voxtype: get parse failed: " + e);
                }
            }
        }
    }
    Process {
        id: setProc
        stdout: StdioCollector { onStreamFinished: page.reload() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0)
                    page.busyError = e;
            }
        }
    }

    ShowcaseBackdrop { anchors.fill: parent }

    // voxtype missing: a clear message, not an inert page. voxtype-bin ships with
    // the desktop, so this is the rare hand-removed case.
    Column {
        visible: page.loaded && !page.installed
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.6, 460)
        spacing: 16
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: "Voxtype isn't installed"
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: "Voice dictation needs the voxtype-bin package. Install it below; GlazePKG opens in a terminal to confirm, and this page fills in once it finishes."
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 13
        }
        Item {
            width: parent.width
            height: installBtn.implicitHeight
            HubButton {
                id: installBtn
                anchors.horizontalCenter: parent.horizontalCenter
                label: "Install Voxtype"
                icon: "download"
                primary: true
                onClicked: page.installVoxtype()
            }
        }
    }

    Flickable {
        visible: !page.loaded || page.installed
        anchors.fill: parent
        anchors.leftMargin: 4
        contentWidth: width
        contentHeight: col.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: Math.min(parent.width - 8, 620)
            spacing: 24

            // --- DICTATION ------------------------------------------------
            SettingSection {
                width: parent.width
                title: "DICTATION"

                ToggleRow {
                    width: Math.min(parent.width, 460)
                    label: "Voice typing"
                    checked: page.voiceOn
                    onToggled: (on) => page.setEnabled(on)
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Tap Super+` to dictate into whatever app has focus; tap again to stop. The pill grows a live mic wave while you speak."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            // --- ENGINE & MODEL -------------------------------------------
            SettingSection {
                width: parent.width
                title: "ENGINE & MODEL"

                Column {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: page.presets

                        // one selectable engine/model row: name, provider · size
                        // (+ download state for local models), and a one-liner.
                        // the active one wears the ember edge.
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool active: page.selected === card.modelData.key
                            width: parent ? parent.width : 0
                            height: cardCol.height + 24
                            radius: Theme.radius
                            color: card.active ? Theme.frameBg : (cardHov.hovered ? Theme.keyTop : Theme.surfaceLo)
                            border.width: 1
                            border.color: card.active ? Theme.ember : Theme.line
                            Behavior on color { ColorAnimation { duration: Theme.quick } }
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            Column {
                                id: cardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 4

                                Row {
                                    width: parent.width
                                    spacing: 10
                                    Text {
                                        text: card.modelData.label
                                        color: card.active ? Theme.bright : Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: card.modelData.provider + "  \u00b7  " + card.modelData.size
                                            + (card.modelData.cloud ? "" : (card.modelData.present ? "  \u00b7  downloaded" : "  \u00b7  not downloaded"))
                                        color: (!card.modelData.cloud && !card.modelData.present) ? Theme.ember : Theme.faint
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: card.modelData.detail
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }
                            }

                            HoverHandler { id: cardHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.choose(card.modelData.key) }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: page.needDownload
                    wrapMode: Text.WordWrap
                    text: "This model isn't downloaded yet. Download it, then dictation is ready."
                    color: Theme.ember
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                HubButton {
                    label: "Download models"
                    icon: "download"
                    primary: page.needDownload
                    onClicked: page.downloadModels()
                }
            }

            // --- API KEY --------------------------------------------------
            SettingSection {
                width: parent.width
                visible: page.needsKey
                title: "API KEY"

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: page.keyOnFile
                        ? "A key is saved. Enter a new one to replace it."
                        : "This cloud engine needs an API key. It is stored locally in your Voxtype config."
                    color: page.keyOnFile ? Theme.ok : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        id: keyField
                        width: parent.width - saveBtn.width - 10
                        height: 40
                        radius: Theme.radius
                        color: keyInput.activeFocus ? Theme.surface : Theme.surfaceLo
                        border.width: 1
                        border.color: keyInput.activeFocus ? Theme.ember : Theme.line
                        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                        TextInput {
                            id: keyInput
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: Text.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.bright
                            font.family: Theme.mono
                            font.pixelSize: 13
                            selectionColor: Theme.ember
                            selectedTextColor: Theme.onAccent
                            clip: true
                            onAccepted: { page.saveKey(text); text = ""; }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: keyInput.text.length === 0
                                text: page.keyKind === "soniox" ? "Soniox API key" : "OpenAI API key"
                                color: Theme.faint
                                font: keyInput.font
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: keyInput.forceActiveFocus() }
                    }

                    HubButton {
                        id: saveBtn
                        label: "Save key"
                        icon: "check"
                        primary: true
                        onClicked: { page.saveKey(keyInput.text); keyInput.text = ""; }
                    }
                }
            }

            // --- error ----------------------------------------------------
            Rectangle {
                visible: page.busyError !== ""
                width: parent.width
                height: errText.implicitHeight + 20
                radius: Theme.radius
                color: Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.10)
                border.width: 1
                border.color: Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.4)
                Text {
                    id: errText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    text: page.busyError
                    color: Theme.bad
                    wrapMode: Text.WordWrap
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
