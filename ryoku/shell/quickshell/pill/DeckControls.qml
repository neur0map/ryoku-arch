pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "Singletons"

/**
 * controls zone of the 力 deck = the unified control centre. two "session"
 * states on top (Keep-Awake with its live elapsed clock, Game-Mode with its
 * profile name) as wide stat-tiles carrying an inline switch, then the five
 * momentary quick-toggles (wifi, bluetooth, mic, do-not-disturb, night) as a
 * flat tile row beneath. replaces the old three stacked Keep-Awake / Game-Mode
 * / Toggles sections. polling (wifi / mic / night probes) is gated on `active`
 * so it only runs while the deck is open. content is column-wide; the deck
 * renders the "Controls" eyebrow above us.
 */
Item {
    id: root

    property real s: 1
    property bool active: true

    implicitHeight: content.implicitHeight

    readonly property string scripts: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/"

    // ── keep-awake elapsed ────────────────────────────────────────────────
    property int awakeElapsed: 0
    Timer {
        interval: 1000
        running: root.active && Flags.keepAwake && Flags.keepAwakeSince > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.awakeElapsed = Math.max(0, Math.floor((Date.now() - Flags.keepAwakeSince) / 1000))
    }

    function fmtAwake(sec) {
        var v = Math.max(0, sec);
        var h = Math.floor(v / 3600);
        var m = Math.floor((v % 3600) / 60);
        var r = v % 60;
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return (h > 0 ? h + ":" + p(m) : m) + ":" + p(r);
    }

    // ── quick-toggle state (wifi, mic; bluetooth via BT service, night via pgrep) ──
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

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    function toggleBt() {
        if (root.btAdapter)
            root.btAdapter.enabled = !root.btAdapter.enabled;
    }

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

    function repoll() {
        wifiProc.running = true;
        micProc.running = true;
        nightProc.running = true;
    }
    onActiveChanged: if (active) repoll()
    Component.onCompleted: repoll()
    Timer {
        interval: 4000
        running: root.active
        repeat: true
        onTriggered: root.repoll()
    }

    // ── wide session stat-tile: glyph · label · live value. lights the whole
    // tile vermilion-tinted when on and the whole face taps to toggle, matching
    // the quick-toggles below (no separate switch; the tint is the state).
    component StatTile: Rectangle {
        id: st
        property string glyph: ""
        property string label: ""
        property string value: ""
        property bool on: false
        signal toggled()

        height: 46 * root.s
        radius: 4 * root.s
        color: st.on ? Qt.alpha(Theme.brand, 0.16)
            : (stHov.hovered ? Theme.frameBg : Theme.tileBg)
        border.width: 1
        border.color: st.on ? Theme.brand
            : (stHov.hovered ? Theme.frameBorder : Theme.border)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        GlyphIcon {
            id: stIcon
            anchors.left: parent.left
            anchors.leftMargin: 11 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            name: st.glyph
            color: st.on ? Theme.brand : Theme.iconDim
            stroke: 1.6
        }

        Column {
            anchors.left: stIcon.right
            anchors.leftMargin: 10 * root.s
            anchors.right: parent.right
            anchors.rightMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1 * root.s

            Text {
                width: parent.width
                text: st.label
                elide: Text.ElideRight
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 8 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4 * root.s
                font.capitalization: Font.AllUppercase
            }
            Text {
                width: parent.width
                text: st.value
                elide: Text.ElideRight
                color: st.on ? Theme.brand : Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        HoverHandler { id: stHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: st.toggled() }
    }

    // ── flat quick-toggle tile: glyph only, lights vermilion when on. ──
    component ToggleTile: Rectangle {
        id: tt
        property string glyph: ""
        property bool on: false
        signal acted()
        height: 38 * root.s
        radius: 4 * root.s
        color: tt.on ? Theme.brand : (tHov.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: tt.on ? Theme.brand : (tHov.hovered ? Theme.frameBorder : Theme.border)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: tt.glyph
            color: tt.on ? Theme.cream : (tHov.hovered ? Theme.cream : Theme.iconDim)
            stroke: 1.6
        }
        HoverHandler { id: tHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tt.acted() }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8 * root.s

        // two session stat-tiles side by side.
        Row {
            width: parent.width
            spacing: 8 * root.s
            readonly property real tileW: (width - spacing) / 2

            StatTile {
                width: parent.tileW
                glyph: "coffee"
                label: "Keep Awake"
                value: Flags.keepAwake ? root.fmtAwake(root.awakeElapsed) : "OFF"
                on: Flags.keepAwake
                onToggled: Flags.keepAwake = !Flags.keepAwake
            }
            StatTile {
                width: parent.tileW
                glyph: "cpu"
                label: "Game Mode"
                value: Flags.gameMode ? "ON" : "OFF"
                on: Flags.gameMode
                onToggled: Flags.gameMode = !Flags.gameMode
            }
        }

        // five momentary quick-toggles.
        Row {
            id: togglesRow
            width: parent.width
            spacing: 8 * root.s
            readonly property real tileW: (width - spacing * 4) / 5

            ToggleTile {
                width: togglesRow.tileW
                glyph: "wifi"
                on: root.wifiOn
                onActed: root.toggleWifi()
            }
            ToggleTile {
                width: togglesRow.tileW
                glyph: "bluetooth"
                on: root.btOn
                onActed: root.toggleBt()
            }
            ToggleTile {
                width: togglesRow.tileW
                glyph: root.micMuted ? "mic-off" : "mic"
                on: !root.micMuted
                onActed: root.toggleMic()
            }
            ToggleTile {
                width: togglesRow.tileW
                glyph: "dnd"
                on: Flags.dnd
                onActed: Flags.dnd = !Flags.dnd
            }
            ToggleTile {
                width: togglesRow.tileW
                glyph: "moon"
                on: root.nightOn
                onActed: root.toggleNight()
            }
        }
    }
}
