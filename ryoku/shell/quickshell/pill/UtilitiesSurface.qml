pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "Singletons"

/**
 * Utilities surface grown from the pill centre (Super+U). Four cards ported from
 * the legacy bottom-right panel: Keep-Awake with a live elapsed counter, a Screen
 * Recorder with a record-mode dropdown (display / region / +sound) plus running
 * controls, quick toggles (wifi / bluetooth / mic / DND), and a recordings list
 * with play / open-folder / trash. Recording is driven by the Recorder singleton
 * (ryoku-cmd-screenrecord); Keep-Awake reuses the shared Flags state.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 15
    mRight: 15
    mBottom: 15

    ameForm: "off"

    implicitHeight: col.implicitHeight

    readonly property string recDir: (Quickshell.env("HOME") || "") + "/Videos/Recordings"

    // ── Keep-Awake elapsed ────────────────────────────────────────────────
    property int awakeElapsed: 0
    Timer {
        interval: 1000
        running: root.open && Flags.keepAwake && Flags.keepAwakeSince > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.awakeElapsed = Math.max(0, Math.floor((Date.now() - Flags.keepAwakeSince) / 1000))
    }

    // ── Recordings model ──────────────────────────────────────────────────
    ListModel { id: recModel }

    function refreshRecs() {
        recProc.running = true;
    }

    Process {
        id: recProc
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f -name 'recording_*.mp4' -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn", "_", root.recDir]
        stdout: StdioCollector {
            onStreamFinished: {
                recModel.clear();
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i];
                    if (!ln.length)
                        continue;
                    var tab = ln.indexOf("\t");
                    if (tab < 0)
                        continue;
                    var path = ln.substring(tab + 1);
                    var base = path.substring(path.lastIndexOf("/") + 1).replace(/\.mp4$/, "");
                    recModel.append({ path: path, label: root.prettyName(base) });
                }
            }
        }
    }

    function prettyName(base) {
        var m = base.match(/^recording_(\d{4})-(\d{2})-(\d{2})_(\d{2})\.(\d{2})\.(\d{2})/);
        if (!m)
            return base;
        var d = new Date(m[1], m[2] - 1, m[3], m[4], m[5], m[6]);
        return Qt.formatDateTime(d, "MMM d, HH:mm");
    }

    onOpenChanged: if (open) {
        refreshRecs();
        wifiProc.running = true;
        micProc.running = true;
        nightProc.running = true;
    }

    // Pre-warm recordings and toggle state once at startup so the first open is
    // already at its final size and the panel does not re-morph as polls return.
    Component.onCompleted: {
        refreshRecs();
        wifiProc.running = true;
        micProc.running = true;
        nightProc.running = true;
    }

    // Refresh the list shortly after a recording ends so the new file appears.
    Connections {
        target: Recorder
        function onActiveChanged() {
            if (!Recorder.active)
                recRefresh.restart();
        }
    }
    Timer { id: recRefresh; interval: 1500; onTriggered: root.refreshRecs() }

    // ── Quick-toggle state (wifi, mic; bluetooth via the BT service) ───────
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
    Timer {
        interval: 4000
        running: root.open
        repeat: true
        onTriggered: { wifiProc.running = true; micProc.running = true; nightProc.running = true; }
    }

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

    // ── Record modes ──────────────────────────────────────────────────────
    readonly property var recModes: [
        { glyph: "monitor", label: "Record display",      args: [] },
        { glyph: "region",  label: "Record region",       args: ["-r"] },
        { glyph: "speaker", label: "Display with sound",  args: ["-s"] },
        { glyph: "speaker", label: "Region with sound",   args: ["-sr"] }
    ]
    property bool menuOpen: false

    // Recording grabs the screen: a region mode runs slurp, and gpu-screen-recorder
    // would otherwise capture this very panel. Close the surface, let the morph
    // settle, then start, so slurp gets a clear screen and the panel stays out of
    // the recording.
    property var pendingRec: null
    function startRecording(args) {
        root.pendingRec = args;
        root.menuOpen = false;
        root.requestClose();
        recLaunch.restart();
    }
    Timer {
        id: recLaunch
        interval: 400
        onTriggered: {
            if (root.pendingRec !== null) {
                Recorder.start(root.pendingRec);
                root.pendingRec = null;
            }
        }
    }

    function fmtAwake(sec) {
        var s = Math.max(0, sec);
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var r = s % 60;
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return (h > 0 ? h + ":" + p(m) : m) + ":" + p(r);
    }

    // ── Reusable bits ─────────────────────────────────────────────────────
    component Card: Rectangle {
        default property alias kids: inner.data
        property real ipad: 12
        width: parent ? parent.width : 0
        radius: 14 * root.s
        color: Theme.cardTop
        border.width: 1
        border.color: Theme.border
        implicitHeight: inner.implicitHeight + ipad * 2 * root.s
        Column {
            id: inner
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: parent.ipad * root.s
            spacing: 10 * root.s
        }
    }

    component Eyebrow: Text {
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 9.5 * root.s
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.4 * root.s
    }

    component IconChip: Rectangle {
        property string glyph: ""
        property bool lit: false
        width: 34 * root.s
        height: 34 * root.s
        radius: width / 2
        color: lit ? Theme.brand : Theme.tileBg
        border.width: 1
        border.color: lit ? Theme.brand : Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        property alias icon: ic
        GlyphIcon {
            id: ic
            anchors.centerIn: parent
            width: 17 * root.s
            height: 17 * root.s
            name: parent.glyph
            color: parent.lit ? Theme.cardTop : Theme.iconDim
            stroke: 1.7
        }
    }

    // A flat icon button (play / folder / trash / pause / stop / chevron).
    component IconBtn: Rectangle {
        property string glyph: ""
        property color tint: Theme.iconDim
        property real box: 30
        signal clicked()
        width: box * root.s
        height: box * root.s
        radius: 9 * root.s
        color: hov.hovered ? Theme.frameBg : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: parent.box * 0.5 * root.s
            height: parent.box * 0.5 * root.s
            name: parent.glyph
            color: parent.tint
            stroke: 1.7
        }
        HoverHandler { id: hov }
        TapHandler { onTapped: parent.clicked() }
    }

    component QToggle: Rectangle {
        property string glyph: ""
        property bool on: false
        signal acted()
        Layout.fillWidth: true
        implicitHeight: 42 * root.s
        radius: 12 * root.s
        color: on ? Theme.brand : Theme.tileBg
        border.width: 1
        border.color: on ? Theme.brand : Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: 18 * root.s
            height: 18 * root.s
            name: parent.glyph
            color: parent.on ? Theme.cardTop : Theme.iconDim
            stroke: 1.7
        }
        TapHandler { onTapped: parent.acted() }
    }

    // ── Cards ─────────────────────────────────────────────────────────────
    Column {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10 * root.s

        // 1) KEEP AWAKE
        Card {
            Row {
                width: parent.width
                spacing: 11 * root.s

                IconChip {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "awake"
                    lit: Flags.keepAwake
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 34 * root.s - 11 * root.s - sw.width - 11 * root.s
                    spacing: 1 * root.s
                    Text {
                        text: "Keep Awake"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Flags.keepAwake
                            ? "Active for " + root.fmtAwake(root.awakeElapsed)
                            : "Normal power management"
                        color: Flags.keepAwake ? Theme.brand : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                    }
                }

                // switch
                Rectangle {
                    id: sw
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40 * root.s
                    height: 23 * root.s
                    radius: height / 2
                    color: Flags.keepAwake ? Theme.brand : Theme.tileBg
                    border.width: 1
                    border.color: Flags.keepAwake ? Theme.brand : Theme.border
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Rectangle {
                        width: 17 * root.s
                        height: 17 * root.s
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: Flags.keepAwake ? parent.width - width - 3 * root.s : 3 * root.s
                        color: Flags.keepAwake ? Theme.cardTop : Theme.iconDim
                        Behavior on x { NumberAnimation { duration: 130 } }
                    }
                    TapHandler { onTapped: Flags.keepAwake = !Flags.keepAwake }
                }
            }
        }

        // 2) SCREEN RECORDER
        Card {
            Row {
                width: parent.width
                spacing: 11 * root.s

                IconChip {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "record"
                    lit: Recorder.active
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s
                    Text {
                        text: "Screen Recorder"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.weight: Font.Medium
                    }
                    Text {
                        text: Recorder.paused ? "Recording paused"
                            : Recorder.active ? "Recording running"
                            : "Recording off"
                        color: Recorder.active ? Theme.brand : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                    }
                }
            }

            // Running controls
            Row {
                width: parent.width
                visible: Recorder.active
                spacing: 9 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: recPill.implicitWidth + 18 * root.s
                    height: 24 * root.s
                    radius: height / 2
                    color: Recorder.paused ? Theme.faint : Theme.brand
                    opacity: Recorder.paused ? 1 : Recorder.pulse
                    Text {
                        id: recPill
                        anchors.centerIn: parent
                        text: Recorder.paused ? "PAUSED" : "REC"
                        color: Theme.cardTop
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1 * root.s
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.elapsedText
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                }
                Item { width: 1; height: 1 }
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Recorder.canPause
                    glyph: Recorder.paused ? "play" : "pause"
                    tint: Theme.cream
                    onClicked: Recorder.togglePause()
                }
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "stop"
                    tint: Theme.vermLit
                    onClicked: Recorder.stop()
                }
            }

            // Record button + dropdown (idle)
            Rectangle {
                width: parent.width
                visible: !Recorder.active
                radius: 11 * root.s
                color: recBtnHov.hovered ? Theme.frameBg : Theme.tileBg
                border.width: 1
                border.color: root.menuOpen ? Theme.brand : Theme.border
                implicitHeight: 38 * root.s
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    anchors.centerIn: parent
                    spacing: 8 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15 * root.s
                        height: 15 * root.s
                        name: "record"
                        color: Theme.brand
                        stroke: 1.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Record"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.Medium
                    }
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-down"
                        color: Theme.subtle
                        stroke: 1.7
                        rotation: root.menuOpen ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: Motion.fast } }
                    }
                }
                HoverHandler { id: recBtnHov }
                TapHandler { onTapped: root.menuOpen = !root.menuOpen }
            }

            // Mode menu (inline expand)
            Column {
                width: parent.width
                visible: root.menuOpen && !Recorder.active
                spacing: 4 * root.s

                Repeater {
                    model: root.recModes
                    delegate: Rectangle {
                        id: mItem
                        required property var modelData
                        width: parent.width
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: mHov.hovered ? Theme.frameBg : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 9 * root.s
                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 15 * root.s
                                height: 15 * root.s
                                name: mItem.modelData.glyph
                                color: Theme.iconDim
                                stroke: 1.6
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: mItem.modelData.label
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12 * root.s
                            }
                        }
                        HoverHandler { id: mHov }
                        TapHandler {
                            onTapped: {
                                root.startRecording(mItem.modelData.args);
                            }
                        }
                    }
                }
            }
        }

        // 3) QUICK TOGGLES
        Card {
            Eyebrow { text: "Quick Toggles" }

            RowLayout {
                width: parent.width
                spacing: 8 * root.s
                QToggle { glyph: "wifi"; on: root.wifiOn; onActed: root.toggleWifi() }
                QToggle { glyph: "bluetooth"; on: root.btOn; onActed: root.toggleBt() }
                QToggle { glyph: root.micMuted ? "mic-off" : "mic"; on: !root.micMuted; onActed: root.toggleMic() }
                QToggle { glyph: "dnd"; on: Flags.dnd; onActed: Flags.dnd = !Flags.dnd }
                QToggle { glyph: "moon"; on: root.nightOn; onActed: root.toggleNight() }
            }
        }

        // 4) RECORDINGS
        Card {
            Row {
                width: parent.width
                spacing: 8 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "list"
                    color: Theme.iconDim
                    stroke: 1.7
                }
                Eyebrow {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Recordings"
                }
            }

            Text {
                visible: recModel.count === 0
                text: "No recordings yet"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11 * root.s
            }

            ListView {
                width: parent.width
                visible: recModel.count > 0
                implicitHeight: Math.min(recModel.count, 4) * 34 * root.s
                clip: true
                model: recModel
                spacing: 2 * root.s
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: recItem
                    required property string path
                    required property string label
                    width: ListView.view.width
                    height: 32 * root.s
                    radius: 8 * root.s
                    color: rHov.hovered ? Theme.frameBg : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    HoverHandler { id: rHov }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.right: actions.left
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: recItem.label
                        elide: Text.ElideRight
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }

                    Row {
                        id: actions
                        anchors.right: parent.right
                        anchors.rightMargin: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        IconBtn {
                            glyph: "play"
                            box: 28
                            tint: Theme.cream
                            onClicked: { Quickshell.execDetached(["xdg-open", recItem.path]); root.requestClose(); }
                        }
                        IconBtn {
                            glyph: "folder"
                            box: 28
                            onClicked: { Quickshell.execDetached(["xdg-open", root.recDir]); root.requestClose(); }
                        }
                        IconBtn {
                            glyph: "trash"
                            box: 28
                            tint: Theme.vermLit
                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", "gio trash \"$1\" 2>/dev/null || rm -f \"$1\"", "_", recItem.path]);
                                recRefresh.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
