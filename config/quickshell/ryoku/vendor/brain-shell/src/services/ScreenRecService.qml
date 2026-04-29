pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ScreenRecService — owns all screen recording state.
//
// Recording bug fix: ~ does not expand inside double-quoted bash strings.
// Use $HOME instead throughout all path construction.
//
// Cava always runs during recording — source depends on audio selection:
//   mic only      → default PulseAudio source (microphone)
//   system only   → default sink .monitor
//   both          → sink .monitor (PipeWire mixes both at capture level)
//   none          → sink .monitor (visualiser stays alive, just silent)
//
// wl-screenrec audio: single --audio flag with one resolved device.
// If both mic+system selected we use the sink monitor (PipeWire routes both).

QtObject {
    id: root

    // ── Persisted options ─────────────────────────────────────────────────────
    property string captureTarget: "screen"
    property bool   audioMic:      false
    property bool   audioSystem:   false

    // ── Display helpers ───────────────────────────────────────────────────────
    readonly property var _captureIcons:  ({ screen: "󰍹", window: "󱂬", region: "󰩭" })
    readonly property var _captureLabels: ({ screen: "Screen", window: "Window", region: "Region" })
    readonly property string captureIcon:  _captureIcons[captureTarget]  ?? "󰍹"
    readonly property string captureLabel: _captureLabels[captureTarget] ?? "Screen"

    readonly property string audioLabel: {
        if (audioMic && audioSystem) return "Mic + Sys"
        if (audioMic)                return "Mic"
        if (audioSystem)             return "Sys"
        return "Non"
    }

    // ── Strip hover (open = "capture" | "audio" | "") ─────────────────────────
    property string openStrip: ""
    property real popupTargetX: 0
    property real popupTargetWidth: 0

    property var _stripTimer: Timer {
        interval: 280
        onTriggered: root.openStrip = ""
    }
    function keepStripOpen()      { _stripTimer.stop()    }
    function scheduleStripClose() { _stripTimer.restart() }

    // ── Recording state ───────────────────────────────────────────────────────
    property bool   recording: false
    property int    elapsed:   0
    property string _currentFile: ""   // tracked so discard can delete it

    readonly property string elapsedDisplay: {
        var m = Math.floor(elapsed / 60)
        var s = elapsed % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    property var _elapsedTimer: Timer {
        interval: 1000
        running:  root.recording
        repeat:   true
        onTriggered: root.elapsed++
    }

    // ── Audio bars — 6 bars, always active during recording ───────────────────
    property var audioBars: [0, 0, 0, 0, 0, 0]

    // ── Config ────────────────────────────────────────────────────────────────
    property var _configView: FileView {
        id: configView
        watchChanges: false
        onLoaded: root._parseConfig(configView.text())
    }

    // Create defaults if missing, then load — prevents FileView warning
    property var _initConfig: Process {
        command: []
        running: false
        onExited: function() { configView.reload() }
    }

    Component.onCompleted: {
        var path = Quickshell.shellDir + "/src/user_data/screenrec.json"
        configView.path = path
        _initConfig.command = [
            "bash", "-c",
            "[ -f '" + path + "' ] || " +
            "(mkdir -p \"$(dirname '" + path + "')\" && " +
            "printf '{\"captureTarget\":\"screen\",\"audioMic\":false,\"audioSystem\":false}\\n'" +
            " > '" + path + "')"
        ]
        _initConfig.running = true
    }

    function _parseConfig(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var o = JSON.parse(raw)
            if (o.captureTarget) root.captureTarget = o.captureTarget
            if (typeof o.audioMic    === "boolean") root.audioMic    = o.audioMic
            if (typeof o.audioSystem === "boolean") root.audioSystem = o.audioSystem
        } catch(e) {}
    }

    function saveConfig() {
        var path = Quickshell.shellDir + "/src/user_data/screenrec.json"
        var data = JSON.stringify({
            captureTarget: root.captureTarget,
            audioMic:      root.audioMic,
            audioSystem:   root.audioSystem
        })
        _saveProc.command = ["bash", "-c",
            "printf '%s' '" + data.replace(/'/g, "'\\''") + "' > '" + path + "'"]
        _saveProc.running = false
        _saveProc.running = true
    }

    property var _saveProc: Process { command: []; running: false }

    // ── Recording process ─────────────────────────────────────────────────────
    property string _pendingGeometry: ""
    property string _resolvedAudioDevice: ""

    property var _windowPickerProc: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: windowPickerOut
            onStreamFinished: {
                var g = windowPickerOut.text.trim()
                if (g !== "") root._pendingGeometry = g
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && root._pendingGeometry !== "")
                root._resolveAudio()
            else
                root._pendingGeometry = ""
        }
    }

    property var _regionPickerProc: Process {
        command: []
        running: false
        stdout: StdioCollector {
            id: regionPickerOut
            onStreamFinished: {
                var g = regionPickerOut.text.trim()
                console.log("Region picker output:", g)
                if (g !== "") root._pendingGeometry = g
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && root._pendingGeometry !== "")
                root._resolveAudio()
            else
                root._pendingGeometry = ""
        }
    }

    // Step 1: resolve audio device, then launch
    property var _audioDeviceProc: Process {
        command: []
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var s = line.trim()
                if (s !== "") root._resolvedAudioDevice = s
            }
        }
        onExited: function(exitCode, exitStatus) {
            root._launch()
        }
    }

    function _resolveAudio() {
        root._resolvedAudioDevice = ""
        if (!root.audioMic && !root.audioSystem) {
            // No audio capture — still resolve sink monitor for cava visualiser
            _audioDeviceProc.command = ["bash", "-c",
                "pactl get-default-sink | tr -d '\\n' && printf '.monitor'"]
        } else if (root.audioMic && !root.audioSystem) {
            _audioDeviceProc.command = ["pactl", "get-default-source"]
        } else {
            // system audio or both — use sink monitor
            // PipeWire routes mic into the combined stream at capture level
            _audioDeviceProc.command = ["bash", "-c",
                "pactl get-default-sink | tr -d '\\n' && printf '.monitor'"]
        }
        _audioDeviceProc.running = false
        _audioDeviceProc.running = true
    }

    property var _recProc: Process {
        command: []
        running: false
        onExited: function(exitCode, exitStatus) {
            root.recording        = false
            root.elapsed          = 0
            root._pendingGeometry = ""
            root._currentFile     = ""
            root._cavaRecProc.running = false
            root.audioBars        = [0, 0, 0, 0, 0, 0]
            ShellState.screenRecord = false
        }
    }

    function _buildCmd() {
        // Use $HOME — ~ does NOT expand inside double-quoted bash strings
        var ts  = Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")
        root._currentFile = "$HOME/Videos/screen_recordings/" + ts + ".mp4"
        var cmd = "mkdir -p $HOME/Videos/screen_recordings && " +
                  "LIBVA_DRIVER_NAME=iHD wl-screenrec" +
                  " --filename " + root._currentFile
        if (root._pendingGeometry !== "")
            cmd += " --geometry '" + root._pendingGeometry + "'"
        var hasAudio = root.audioMic || root.audioSystem
        if (hasAudio && root._resolvedAudioDevice !== "")
            cmd += " --audio --audio-device " + root._resolvedAudioDevice
        return cmd
    }

    function _launch() {
        _recProc.command = ["bash", "-c", root._buildCmd()]
        _recProc.running = false
        _recProc.running = true
        root.recording   = true
        root.elapsed     = 0
        root.openStrip   = ""
        if (root._resolvedAudioDevice !== "")
            _startCavaWithSource(root._resolvedAudioDevice)
    }

    function startRecording() {
        root._pendingGeometry = ""
        saveConfig()
        if (root.captureTarget === "screen") {
            root._resolveAudio()
        } else if (root.captureTarget === "window") {
            _windowPickerProc.command = [
                "bash", "-c",
                "hyprctl clients -j | python3 -c \"" +
                "import sys,json; ws=json.load(sys.stdin); " +
                "[print(str(w['at'][0])+','+str(w['at'][1])+' '+str(w['size'][0])+'x'+str(w['size'][1])) " +
                "for w in ws if w['mapped']]\" | slurp"
            ]
            _windowPickerProc.running = false
            _windowPickerProc.running = true
        } else {
            _regionPickerProc.command = [
                "bash", "-c",
                "hyprctl monitors -j | python3 -c \"" +
                "import sys,json; ms=json.load(sys.stdin); " +
                "[print(str(m['x'])+','+str(m['y'])+' '+str(m['width'])+'x'+str(m['height'])) for m in ms]\" | slurp"
            ]
            _regionPickerProc.running = false
            _regionPickerProc.running = true
        }
    }

    function stopRecording() {
        _sigProc.command = ["bash", "-c", "pkill -INT wl-screenrec"]
        _sigProc.running = false
        _sigProc.running = true
    }

    function discardRecording() {
        // Stop recording and delete the file
        var fileToDelete = root._currentFile
        _sigProc.command = ["bash", "-c", "pkill -INT wl-screenrec"]
        _sigProc.running = false
        _sigProc.running = true
        // Delete after a short delay so wl-screenrec has time to close the file
        _discardTimer.fileToDelete = fileToDelete
        _discardTimer.restart()
    }

property var _discardTimer: Timer {
        property string fileToDelete: ""
        interval: 800
        onTriggered: {
            if (fileToDelete !== "") {
                // Use double quotes so Bash expands $HOME
                _discardDeleteProc.command = ["bash", "-c",
                    "rm -f \"" + fileToDelete + "\""]
                _discardDeleteProc.running = false
                _discardDeleteProc.running = true
                fileToDelete = ""
            }
        }
    }

    property var _discardDeleteProc: Process { command: []; running: false }

    function cancelSetup() {
        root.openStrip = ""
        ShellState.screenRecord = false
    }

    property var _sigProc: Process { command: []; running: false }

    // ── Cava — always runs during recording ───────────────────────────────────
    property var _cavaRecProc: Process {
        command: []
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (!root.recording) return
                var t = line.trim()
                if (t === "") return
                if (t.endsWith(";")) t = t.slice(0, -1)
                var parts = t.split(";")
                if (parts.length !== 12) return
                var bars = []
                for (var i = 0; i < 12; i++) bars.push(parseInt(parts[i]) || 0)
                root.audioBars = bars
            }
        }
    }

    function _startCavaWithSource(src) {
        var config =
            "[general]\nbars = 12\nframerate = 20\nnoise_reduction = 77\n\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\n" +
            "data_format = ascii\nascii_max_range = 100\n" +
            "bar_delimiter = 59\nframe_delimiter = 10\n\n" +
            "[input]\nmethod = pulse\nsource = " + src + "\n"

        _cavaRecProc.command = [
            "bash", "-c",
            "mkdir -p /tmp/brain_shell && printf '%s\\n' '" +
            config.replace(/'/g, "'\\''") +
            "' > /tmp/brain_shell/cava_rec.ini && " +
            "exec cava -p /tmp/brain_shell/cava_rec.ini 2>/dev/null"
        ]
        _cavaRecProc.running = false
        _cavaRecProc.running = true
    }
}
