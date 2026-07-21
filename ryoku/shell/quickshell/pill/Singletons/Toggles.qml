pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// one source for the quick-toggles the System deck's control tiles and the bar's
// placeable toggle modules both read. the probes (wifi / mic / night light) poll
// only while something watches them (watchers > 0), so a bar with no toggle and a
// closed deck cost nothing; bluetooth, dnd, keep-awake and game mode are reactive
// off their live sources (the BT service and Flags). the actions mirror the
// deck's originals exactly, kept here so there is one copy, not two.
Singleton {
    id: root

    readonly property string scripts: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/"

    // refcount bumped by every on-screen toggle (a BarToggle, or the open deck),
    // so the pollers sleep when nothing shows a toggle.
    property int watchers: 0
    readonly property bool awake: watchers > 0

    // ---- wifi (nmcli) --------------------------------------------------------
    property bool wifiOn: false
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.wifiOn = this.text.trim() === "enabled" }
    }
    function toggleWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]);
        root.wifiOn = !root.wifiOn;
        wifiPoll.restart();
    }
    Timer { id: wifiPoll; interval: 1200; onTriggered: wifiProc.running = true }

    // ---- microphone (wpctl) --------------------------------------------------
    property bool micMuted: true
    Process {
        id: micProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.micMuted = this.text.indexOf("MUTED") >= 0 }
    }
    function toggleMic() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        root.micMuted = !root.micMuted;
        micPoll.restart();
    }
    Timer { id: micPoll; interval: 600; onTriggered: micProc.running = true }

    // ---- night light (hyprsunset via the shipped script) ---------------------
    property bool nightOn: false
    Process {
        id: nightProc
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null 2>&1 && echo on || echo off"]
        stdout: StdioCollector { onStreamFinished: root.nightOn = this.text.trim() === "on" }
    }
    function toggleNight() {
        Quickshell.execDetached([root.scripts + "ryoku-cmd-nightlight"]);
        root.nightOn = !root.nightOn;
        nightPoll.restart();
    }
    Timer { id: nightPoll; interval: 2000; onTriggered: nightProc.running = true }

    // ---- bluetooth (reactive off the BT service) -----------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    function toggleBt() {
        if (root.btAdapter)
            root.btAdapter.enabled = !root.btAdapter.enabled;
    }

    // ---- dnd / keep-awake / game mode (reactive off Flags) -------------------
    readonly property bool dnd: Flags.dnd
    readonly property bool keepAwake: Flags.keepAwake
    readonly property bool gameMode: Flags.gameMode
    function toggleDnd() { Flags.dnd = !Flags.dnd; }
    function toggleCaffeine() { Flags.keepAwake = !Flags.keepAwake; }
    function toggleGame() { Flags.gameMode = !Flags.gameMode; }

    function repoll() {
        if (!root.awake)
            return;
        wifiProc.running = true;
        micProc.running = true;
        nightProc.running = true;
    }
    onAwakeChanged: if (awake) repoll()
    Timer {
        interval: 4000
        running: root.awake
        repeat: true
        triggeredOnStart: true
        onTriggered: root.repoll()
    }
}
