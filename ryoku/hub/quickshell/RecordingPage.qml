pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// Recording: the quality knobs behind the bar's one-tap screen recorder. Writes
// ~/.config/ryoku/recording.json, read by ryoku-cmd-screenrecord (env vars still
// override). Constant framerate is the default because variable-framerate files
// often import or play back as ~30fps and look choppy. The under-the-hood card
// asks the recorder which backend + hardware encoder will actually run.
Item {
    id: page

    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/recording.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property int fps: 60
            property string framerateMode: "cfr"
            property string quality: "very_high"
            property string codec: "h264"
            property string encoder: "gpu"
            property bool cursor: true
        }

        Component.onCompleted: if (!cfg.text()) cfg.writeAdapter()
    }

    // live readout: which backend + encoder the recorder resolves for this
    // machine (gsr probe is time-boxed, so this can take a moment on first open).
    property string infoBackend: ""
    property string infoEncoder: ""
    Process {
        id: info
        command: [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-screenrecord", "--info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text);
                    page.infoBackend = j.backend || "";
                    page.infoEncoder = j.encoder || "";
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: info.running = true

    readonly property var fpsOptions: [{ "key": "30", "label": "30 fps" }, { "key": "60", "label": "60 fps" }, { "key": "120", "label": "120 fps" }]
    readonly property var fmOptions: [{ "key": "cfr", "label": "Constant (smooth, recommended)" }, { "key": "vfr", "label": "Variable (smaller, can look choppy)" }]
    readonly property var qualityOptions: [{ "key": "medium", "label": "Medium" }, { "key": "high", "label": "High" }, { "key": "very_high", "label": "Very high" }, { "key": "ultra", "label": "Ultra" }]
    readonly property var codecOptions: [{ "key": "h264", "label": "H.264 (most compatible)" }, { "key": "hevc", "label": "HEVC / H.265 (crisper)" }, { "key": "av1", "label": "AV1 (best, newer GPUs)" }]
    readonly property var encoderOptions: [{ "key": "gpu", "label": "GPU (hardware)" }, { "key": "cpu", "label": "CPU (libx264)" }]

    Flickable {
        anchors.fill: parent
        anchors.margins: 4
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: col
            width: parent.width
            spacing: 26

            Text {
                width: col.width
                wrapMode: Text.WordWrap
                text: "Ryoku records with gpu-screen-recorder, hardware-encoded on your GPU (it falls back to wf-recorder on multi-GPU machines). Start and stop from the bar's screen-capture Tools; these settings shape every recording. Files land in ~/Videos/Recordings."
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            SettingSection {
                width: col.width
                title: "QUALITY"
                description: "Higher framerate is smoother (120 gets closer to a high-refresh panel); higher quality and HEVC/AV1 are crisper but larger. Constant framerate plays and edits correctly everywhere; variable is smaller but can look choppy or import as 30fps."

                Dropdown {
                    width: parent.width
                    label: "Framerate"
                    fieldWidth: 200
                    options: page.fpsOptions
                    current: String(adapter.fps)
                    onChosen: (k) => {
                        adapter.fps = parseInt(k);
                        cfg.writeAdapter();
                    }
                }
                Dropdown {
                    width: parent.width
                    label: "Framerate mode"
                    fieldWidth: 200
                    options: page.fmOptions
                    current: adapter.framerateMode
                    onChosen: (k) => {
                        adapter.framerateMode = k;
                        cfg.writeAdapter();
                    }
                }
                Dropdown {
                    width: parent.width
                    label: "Quality"
                    fieldWidth: 200
                    options: page.qualityOptions
                    current: adapter.quality
                    onChosen: (k) => {
                        adapter.quality = k;
                        cfg.writeAdapter();
                    }
                }
                Dropdown {
                    width: parent.width
                    label: "Codec"
                    fieldWidth: 200
                    options: page.codecOptions
                    current: adapter.codec
                    onChosen: (k) => {
                        adapter.codec = k;
                        cfg.writeAdapter();
                    }
                }
            }

            SettingSection {
                width: col.width
                title: "ENCODER"
                description: "GPU encoding is fast and barely touches your CPU. CPU is a fallback if the GPU encoder misbehaves."

                Dropdown {
                    width: parent.width
                    label: "Encoder"
                    fieldWidth: 200
                    options: page.encoderOptions
                    current: adapter.encoder
                    onChosen: (k) => {
                        adapter.encoder = k;
                        cfg.writeAdapter();
                    }
                }
                ToggleRow {
                    width: parent.width
                    label: "Show the cursor in recordings"
                    checked: adapter.cursor
                    onToggled: (c) => {
                        adapter.cursor = c;
                        cfg.writeAdapter();
                    }
                }
            }

            SettingSection {
                width: col.width
                title: "UNDER THE HOOD"
                description: "What the recorder resolves for this machine right now."

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: page.infoBackend === "" ? "Detecting\u2026" : ("Backend    " + (page.infoBackend === "gsr" ? "gpu-screen-recorder" : "wf-recorder") + "\nEncoder    " + page.infoEncoder + "\nContainer  MP4  \u00b7  " + adapter.fps + "fps " + adapter.framerateMode.toUpperCase() + "  \u00b7  " + adapter.codec + "  \u00b7  " + adapter.quality)
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 12
                    lineHeight: 1.5
                }
            }
        }
    }
}
