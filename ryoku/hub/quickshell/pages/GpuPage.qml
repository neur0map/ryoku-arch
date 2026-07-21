pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// System > GPU. Four honest jobs, top to bottom: see the graphics hardware,
// choose which GPU the desktop renders on, tune power and performance for this
// session, and (advanced) set up GPU-passthrough so a VM can own a GPU. Backed
// by `ryoku-hub gpu` (caps + mode + tune + preset), not the shared config store,
// so it is full-bleed and draws its own head. Beta-18 language throughout: paper
// and ink, Section heads, a Ticks-framed specimen, the 描画 watermark, no colour.
//
// Tuning is deliberately per session: every knob is runtime sysfs / nvidia-smi
// state and is gone on reboot, which is the whole safety model. The page probes
// each machine (`gpu tune caps`) and shows only the knobs that box exposes, so
// nothing here is specific to any one card.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true
    readonly property bool previewDirty: false

    // passthrough dossier + render mode (unchanged backend)
    property var caps: ({})
    property string mode: "hybrid"
    property string planText: ""
    property bool planning: false
    property bool enabling: false
    property bool showChecks: false
    property string actionError: ""
    property string capsError: ""
    property string modeWarn: ""

    // tuning + presets
    property var tune: []
    property var presets: []
    property bool showAdvanced: false
    property bool namingPreset: false
    property string tuneError: ""

    // live telemetry for the render GPU (self-contained poll)
    property int liveTemp: 0
    property int liveUtil: 0
    property bool liveOk: false

    readonly property var renderGpu: {
        var p = pg.caps.passthrough, h = pg.caps.host;
        if (p && p.drivesDisplay)
            return p;
        if (h && h.drivesDisplay)
            return h;
        return h || p || null;
    }
    readonly property string renderName: pg.renderGpu ? pg.renderGpu.model : "your GPU"
    readonly property string dgpuName: pg.caps.passthrough ? pg.caps.passthrough.model : "the discrete GPU"

    readonly property bool capsLoaded: pg.caps.verdict !== undefined
    readonly property bool ptPending: pg.capsError === "" && !pg.capsLoaded
    readonly property bool ptOk: pg.caps.verdict === "ready"

    readonly property var safeTune: (pg.tune || []).filter(t => t.risk === "safe")
    readonly property var advTune: (pg.tune || []).filter(t => t.risk === "advanced")
    readonly property string thermalNow: {
        var t = (pg.tune || []).find(x => x.id === "thermal");
        return t ? t.value : "";
    }
    readonly property string statusLine: {
        var s = pg.renderName + " renders here";
        if (pg.liveOk)
            s += "  ·  " + pg.liveTemp + "°C  ·  " + pg.liveUtil + "% GPU";
        if (pg.thermalNow !== "")
            s += "  ·  " + pg.thermalNow;
        return s;
    }

    readonly property string ptText: {
        switch (pg.caps.verdict) {
        case "ready": return "Ready. " + pg.dgpuName + " is free for a VM to claim, and returns to the desktop when the VM stops.";
        case "needs-relogin": return "Set up. Log out and back in once, then it is ready.";
        case "needs-reboot": return "Your screen runs on " + pg.dgpuName + ". Switch to Hybrid GPU mode in the BIOS (look for GPU Mode, MUX, or Hybrid/Optimus) and reboot, so the built-in GPU drives the display and the discrete GPU is free.";
        case "needs-setup": return "Not set up yet. Review the changes, then enable it below.";
        case "incapable": return "This machine can't pass a GPU to a VM. Open the readiness checks below for why.";
        default: return pg.capsError !== "" ? "Couldn't read your graphics hardware." : "Checking…";
        }
    }

    // short role tag for a gpu slot, so a tuning row reads "dGPU · Power limit".
    function tag(gpu) {
        if (gpu === "platform")
            return "Chassis";
        if (pg.caps.passthrough && gpu === pg.caps.passthrough.slot)
            return "dGPU";
        if (pg.caps.host && gpu === pg.caps.host.slot)
            return "iGPU";
        return "GPU";
    }

    function reload() {
        pg.capsError = "";
        capsProc.running = true;
        modeProc.running = true;
        tuneProc.running = true;
        presetProc.running = true;
    }
    function reloadTune() {
        tuneProc.running = true;
        presetProc.running = true;
    }
    function act(cmd) {
        pg.actionError = "";
        runProc.command = cmd;
        runProc.running = true;
    }
    function setMode(m) {
        pg.modeWarn = "";
        modeSetProc.command = ["ryoku-hub", "gpu", "mode", "set", m];
        modeSetProc.running = true;
    }
    function tuneSet(gpu, id, value) {
        pg.tuneError = "";
        tuneSetProc.command = ["ryoku-hub", "gpu", "tune", "set", gpu, id, "" + value];
        tuneSetProc.running = true;
    }
    function tuneReset() {
        pg.tuneError = "";
        tuneSetProc.command = ["ryoku-hub", "gpu", "tune", "reset"];
        tuneSetProc.running = true;
    }
    function applyPreset(name) {
        pg.tuneError = "";
        tuneSetProc.command = ["ryoku-hub", "gpu", "tune", "preset", "apply", name];
        tuneSetProc.running = true;
    }
    function savePreset(name) {
        if (name.trim() === "")
            return;
        pg.namingPreset = false;
        presetSaveProc.command = ["ryoku-hub", "gpu", "tune", "preset", "save", name.trim()];
        presetSaveProc.running = true;
    }
    function deletePreset(name) {
        presetSaveProc.command = ["ryoku-hub", "gpu", "tune", "preset", "delete", name];
        presetSaveProc.running = true;
    }
    function reviewEnable() {
        planProc.command = ["ryoku-hub", "gpu", "apply", "enable", "--dry-run"];
        planProc.running = true;
    }
    function enableInTerminal() {
        Quickshell.execDetached(["kitty", "--class", "ryoku-gpu", "-e", "sh", "-c",
            "ryoku-hub gpu apply enable; echo; read -n1 -rsp 'Done. Press any key to close…'; echo"]);
        pg.planning = false;
        pg.planText = "";
        pg.enabling = true;
    }
    function recheck() {
        pg.enabling = false;
        pg.reload();
    }
    function modeLabel(m) { return m.length ? m.charAt(0).toUpperCase() + m.slice(1) : ""; }

    Component.onCompleted: pg.reload()

    // ── backends ─────────────────────────────────────────────────────────────
    Process {
        id: capsProc
        command: ["ryoku-hub", "gpu", "caps"]
        stdout: StdioCollector { id: capsOut }
        stderr: StdioCollector { id: capsErr }
        onExited: (code) => {
            if (code === 0) {
                try {
                    pg.caps = JSON.parse(capsOut.text);
                    pg.capsError = "";
                    return;
                } catch (e) {
                    console.log("gpu: caps parse failed: " + e);
                }
            }
            pg.capsError = capsErr.text.trim() || ("ryoku-hub gpu caps exited " + code);
        }
    }
    Process {
        id: modeProc
        command: ["ryoku-hub", "gpu", "mode", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.mode = JSON.parse(this.text).mode; } catch (e) {}
            }
        }
    }
    Process {
        id: tuneProc
        command: ["ryoku-hub", "gpu", "tune", "caps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.tune = JSON.parse(this.text) || []; } catch (e) { pg.tune = []; }
            }
        }
    }
    Process {
        id: presetProc
        command: ["ryoku-hub", "gpu", "tune", "preset", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.presets = JSON.parse(this.text) || []; } catch (e) { pg.presets = []; }
            }
        }
    }
    Process {
        id: modeSetProc
        stdout: StdioCollector { onStreamFinished: pg.reload() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0) pg.modeWarn = e;
            }
        }
    }
    Process {
        id: tuneSetProc
        stdout: StdioCollector { onStreamFinished: pg.reloadTune() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0) pg.tuneError = e;
            }
        }
    }
    Process {
        id: presetSaveProc
        stdout: StdioCollector { onStreamFinished: pg.reloadTune() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0) pg.tuneError = e;
            }
        }
    }
    Process {
        id: runProc
        stdout: StdioCollector { onStreamFinished: pg.reload() }
        stderr: StdioCollector {
            onStreamFinished: {
                var e = this.text.trim();
                if (e.length > 0) pg.actionError = e;
            }
        }
    }
    Process {
        id: planProc
        stdout: StdioCollector {
            onStreamFinished: { pg.planText = this.text; pg.planning = true; }
        }
    }
    // live temperature + utilisation for the render GPU: nvidia-smi first, then
    // the first amdgpu card's sysfs, so it degrades on any hardware.
    Process {
        id: liveProc
        command: ["bash", "-c", `
g=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
if [ -n "$g" ]; then echo "$g" | tr ',' ' '; exit 0; fi
for d in /sys/class/drm/card*/device; do
  [ -r "$d/gpu_busy_percent" ] || continue
  u=$(cat "$d/gpu_busy_percent" 2>/dev/null)
  t=$(cat "$d"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
  echo "$((t/1000)) $u"; exit 0
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim().split(/\s+/);
                if (p.length >= 2) {
                    pg.liveTemp = parseInt(p[0]) || 0;
                    pg.liveUtil = parseInt(p[1]) || 0;
                    pg.liveOk = true;
                }
            }
        }
    }
    Timer {
        interval: 2000; repeat: true; running: pg.visible
        triggeredOnStart: true
        onTriggered: liveProc.running = true
    }
    Timer {
        interval: 4000; repeat: true; running: pg.enabling
        onTriggered: capsProc.running = true
    }

    // background: the section kanji as a faint haze, per DESIGN.md section 12.
    Watermark { anchors.fill: parent; text: "描画" }

    // ── one dossier row inside the specimen: tag chip, model, role marker ──────
    component GpuRow: Item {
        id: gr
        property var gpu: null
        property string tag: ""
        width: parent ? parent.width : 0
        height: 34
        visible: gr.gpu !== null && gr.gpu !== undefined
        readonly property bool active: !!(gr.gpu && gr.gpu.drivesDisplay === true)

        Rectangle {
            id: chip
            width: 44; height: 20; radius: Tokens.radius
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: Tokens.border
            border.color: gr.active ? Tokens.ink : Tokens.line
            Text {
                anchors.centerIn: parent
                text: gr.tag
                color: gr.active ? Tokens.ink : Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
        }
        Column {
            anchors.left: chip.right; anchors.leftMargin: Tokens.s3
            anchors.right: role.left; anchors.rightMargin: Tokens.s2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: gr.gpu ? gr.gpu.model : ""
                color: gr.active ? Tokens.ink : Tokens.inkDim
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                elide: Text.ElideRight
            }
            Text {
                text: gr.gpu ? (Math.round(gr.gpu.vramMb / 1024) + "G · " + gr.gpu.driver) : ""
                color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
        }
        Row {
            id: role
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s1
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: gr.active ? "DISPLAY" : "FREE"
                color: gr.active ? Tokens.ink : Tokens.inkFaint
                font.family: Tokens.ui; font.pixelSize: Tokens.fTiny
                font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
            }
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: gr.active ? Tokens.ink : Tokens.inkFaint
            }
        }
    }

    // ── the read-only specimen: a Ticks-framed instrument plate ────────────────
    component GpuSpecimen: Rectangle {
        id: card
        property var caps: ({})
        property bool failed: false
        readonly property var renderGpu: {
            var p = card.caps.passthrough, h = card.caps.host;
            if (p && p.drivesDisplay) return p;
            if (h && h.drivesDisplay) return h;
            return h || p || null;
        }
        implicitHeight: body.implicitHeight + Tokens.s4 * 2
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.line

        Ticks { color: Tokens.lineStrong; arm: 10 }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s4 }
            spacing: Tokens.s4

            Row {
                spacing: Tokens.s2
                Text {
                    text: "力"; color: Tokens.ink; font.family: Tokens.jp
                    font.pixelSize: Tokens.fMicro; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "GRAPHICS"; color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackMark
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                spacing: Tokens.s3
                Column {
                    width: parent.width - vram.width - parent.spacing
                    spacing: Tokens.s1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "RENDERS ON"
                        color: Tokens.inkMuted; font.family: Tokens.ui
                        font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                        font.letterSpacing: Tokens.trackLabel
                    }
                    Text {
                        width: parent.width
                        text: card.renderGpu ? card.renderGpu.model : (card.failed ? "Unavailable" : "Detecting…")
                        color: Tokens.ink; font.family: Tokens.ui
                        font.pixelSize: Tokens.fValue; font.weight: Font.Light
                        elide: Text.ElideRight
                    }
                    Text {
                        text: pg.liveOk ? (pg.liveTemp + "°C · " + pg.liveUtil + "% · draws here") : "the desktop draws here"
                        color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fTiny
                    }
                }
                Rectangle {
                    id: vram
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.renderGpu !== null
                    width: vramCol.width + Tokens.s3 * 2
                    height: vramCol.height + Tokens.s2 * 2
                    radius: Tokens.radius
                    color: "transparent"
                    border.width: Tokens.border; border.color: Tokens.line
                    Column {
                        id: vramCol
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.renderGpu ? (Math.round(card.renderGpu.vramMb / 1024) + "G") : ""
                            color: Tokens.ink; font.family: Tokens.ui
                            font.pixelSize: Tokens.fRow; font.weight: Font.Light
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "VRAM"
                            color: Tokens.inkMuted; font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                        }
                    }
                }
            }

            Row {
                width: parent.width; spacing: Tokens.s2; height: 20
                Rectangle {
                    id: invBadge
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18; width: invText.implicitWidth + Tokens.s3
                    radius: Tokens.radius; color: "transparent"
                    border.width: Tokens.border; border.color: Tokens.line
                    Text {
                        id: invText
                        anchors.centerIn: parent; text: "INVENTORY"
                        color: Tokens.inkMuted; font.family: Tokens.ui
                        font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                        font.letterSpacing: Tokens.trackLabel
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, parent.width - invBadge.width - machineLabel.implicitWidth - 2 * parent.spacing)
                    height: 1; color: Tokens.lineSoft
                }
                Text {
                    id: machineLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: (card.caps.chassis === "laptop" ? "LAPTOP" : "DESKTOP") + (card.caps.cpu ? " · " + card.caps.cpu : "")
                    color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackLabel
                }
            }

            Rectangle {
                width: parent.width
                height: invCol.implicitHeight + Tokens.s3 * 2
                color: Tokens.tint5; radius: Tokens.radius
                border.width: Tokens.border; border.color: Tokens.lineSoft
                Column {
                    id: invCol
                    anchors.fill: parent; anchors.margins: Tokens.s3; spacing: Tokens.s2
                    GpuRow { tag: "iGPU"; gpu: card.caps.host }
                    Rectangle {
                        visible: (card.caps.host !== undefined) && (card.caps.passthrough !== undefined)
                        width: parent.width; height: 1; color: Tokens.lineSoft
                    }
                    GpuRow { tag: "dGPU"; gpu: card.caps.passthrough }
                }
            }

            Text {
                visible: card.caps.mux !== undefined && card.caps.mux !== "none"
                text: "MUX " + (card.caps.mux ? card.caps.mux.replace("present-", "").toUpperCase() : "")
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
        }
    }

    // ── one tuning knob as a Cell, control chosen from its kind ────────────────
    component TuneCell: Cell {
        id: tc
        property var tunable: ({})
        readonly property string knd: tc.tunable.kind || ""
        readonly property int optCount: (tc.tunable.options || []).length

        height: neededHeight
        block: tc.knd === "segment"
        controlWidth: Spans.inlineWidth(tc.knd === "toggle" ? "sw" : (tc.knd === "slider" ? "slid" : "seg"), tc.optCount, width)
        label: pg.tag(tc.tunable.gpu) + " · " + (tc.tunable.label || "")
        unit: tc.tunable.unit || ""
        value: tc.knd === "slider" ? String(Math.round(tc.tunable.current || 0))
            : (tc.knd === "toggle" ? (tc.tunable.value === "on" ? "ON" : "OFF") : "")
        desc: tc.tunable.risk === "advanced" ? "Advanced · per session, can misbehave" : "Applies now, resets on reboot"
        source: tc.tunable.src || ""
        changed: false

        Loader {
            anchors.fill: parent
            sourceComponent: tc.knd === "toggle" ? swC : (tc.knd === "slider" ? slidC : segC)
        }
        Component {
            id: swC
            Sw {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                on: tc.tunable.value === "on"
                onToggled: (v) => pg.tuneSet(tc.tunable.gpu, tc.tunable.id, v ? "on" : "off")
            }
        }
        Component {
            id: slidC
            Slid {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.round(tc.width * 0.42)
                from: tc.tunable.min || 0
                to: tc.tunable.max || 1
                value: tc.tunable.current || 0
                onModified: (v) => pg.tuneSet(tc.tunable.gpu, tc.tunable.id, String(Math.round(v)))
            }
        }
        Component {
            id: segC
            Seg {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                options: tc.tunable.options || []
                current: tc.tunable.value
                onChose: (k) => pg.tuneSet(tc.tunable.gpu, tc.tunable.id, k)
            }
        }
    }

    // ── head ───────────────────────────────────────────────────────────────────
    Column {
        id: head
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: Tokens.s6; rightMargin: Tokens.s6; topMargin: Tokens.s6
        }
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "SYSTEM"; color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: "GPU"; color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: "See your graphics hardware, choose which GPU the desktop renders on, and tune power and performance for this session. Passthrough (advanced) frees the discrete GPU so a virtual machine can own it."
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
        // live status line: one glance at what is happening right now.
        Text {
            text: pg.statusLine
            color: Tokens.inkDim; font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall; font.weight: Font.Medium
        }
    }

    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "描画"
        index: "02"; label: "SYSTEM"
        glyph: "asanoha"; glyph2: "meander"
    }

    // ── content: specimen rail left, scrolling sections right ──────────────────
    Item {
        id: below
        anchors {
            left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom
            leftMargin: Tokens.s6; rightMargin: Tokens.s6; topMargin: Tokens.s5; bottomMargin: Tokens.s6
        }

        Column {
            id: rail
            anchors.left: parent.left; anchors.top: parent.top
            width: Math.min(parent.width * 0.36, 380)
            spacing: Tokens.s4

            GpuSpecimen {
                width: parent.width
                caps: pg.caps
                failed: pg.capsError !== ""
            }

            Column {
                visible: pg.capsError !== ""
                width: parent.width; spacing: Tokens.s3
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "Couldn't read your graphics hardware."
                    color: Tokens.ink; font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody; font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: pg.capsError
                    color: Tokens.inkMuted; font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
                }
                Btn { text: "Retry"; primary: true; onAct: pg.reload() }
            }
        }

        Flickable {
            id: gfx
            anchors {
                left: rail.right; right: parent.right; top: parent.top; bottom: renderDecor.top
                leftMargin: Tokens.s6; bottomMargin: Tokens.s5
            }
            contentWidth: width
            contentHeight: gfxCol.height + Tokens.s5
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            Column {
                id: gfxCol
                width: Math.min(gfx.width - Tokens.s3, 660)
                spacing: Tokens.s6

                // ── RYOKU RENDERS ON ──
                Section {
                    width: parent.width
                    title: "RYOKU RENDERS ON"

                    Column {
                        width: parent.width
                        spacing: Tokens.s3
                        Row {
                            width: parent.width
                            Text {
                                width: parent.width - segMode.width
                                text: "Graphics mode"
                                color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Seg {
                                id: segMode
                                options: ["Hybrid", "Performance", "Passthrough"]
                                current: pg.modeLabel(pg.mode)
                                onChose: (label) => pg.setMode(label.toLowerCase())
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: pg.mode === "hybrid"
                                ? "Hybrid keeps the built-in GPU primary for battery; apps can still use " + pg.dgpuName + " on demand."
                                : (pg.mode === "performance"
                                    ? "Performance pins " + pg.dgpuName + " as primary: fastest, more power draw."
                                    : "Passthrough runs the desktop on the built-in GPU so " + pg.dgpuName + " is free for a VM.")
                            color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        }
                        Text {
                            width: parent.width
                            text: "A change takes effect on your next login."
                            color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        }
                        Rectangle {
                            visible: pg.modeWarn !== ""
                            width: parent.width
                            height: modeWarnText.implicitHeight + Tokens.s3 * 2
                            radius: Tokens.radius; color: "transparent"
                            border.width: Tokens.border; border.color: Tokens.lineStrong
                            Text {
                                id: modeWarnText
                                anchors {
                                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                    leftMargin: Tokens.s3; rightMargin: Tokens.s3
                                }
                                text: pg.modeWarn
                                color: Tokens.ink; wrapMode: Text.WordWrap
                                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                            }
                        }
                    }
                }

                // ── TUNING · THIS SESSION ──
                Section {
                    id: tuneSect
                    width: parent.width
                    title: "TUNING · THIS SESSION"

                    // the per-session promise, said plainly and kept in view.
                    Row {
                        width: parent.width
                        spacing: Tokens.s2
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Tokens.inkMuted
                        }
                        Text {
                            width: parent.width - 6 - Tokens.s2
                            text: "Tuning is live and per session. Everything resets on reboot; there is nothing to save and nothing to undo but a reboot."
                            color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                            wrapMode: Text.WordWrap
                        }
                    }

                    // presets: apply a bundle, or save the current knobs as your own.
                    Column {
                        width: parent.width
                        spacing: Tokens.s2
                        visible: (pg.tune || []).length > 0
                        Text {
                            text: "PRESETS"
                            color: Tokens.inkMuted; font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                        }
                        Flow {
                            width: parent.width; spacing: Tokens.s2
                            Repeater {
                                model: pg.presets
                                delegate: Row {
                                    id: prow
                                    required property var modelData
                                    spacing: 0
                                    Btn {
                                        text: prow.modelData.name
                                        onAct: pg.applyPreset(prow.modelData.name)
                                    }
                                    Btn {
                                        visible: prow.modelData.builtin !== true
                                        text: "×"; compact: true
                                        onAct: pg.deletePreset(prow.modelData.name)
                                    }
                                }
                            }
                            Btn {
                                text: "Save current…"
                                onAct: pg.namingPreset = true
                            }
                            Btn { text: "Reset all"; onAct: pg.tuneReset() }
                        }
                        // inline name entry for a new custom preset.
                        Rectangle {
                            visible: pg.namingPreset
                            width: parent.width; height: 32
                            radius: Tokens.radius; color: "transparent"
                            border.width: nameIn.activeFocus ? 2 : Tokens.border
                            border.color: nameIn.activeFocus ? Tokens.ink : Tokens.line
                            TextInput {
                                id: nameIn
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.s3; anchors.rightMargin: 90
                                verticalAlignment: Text.AlignVCenter
                                color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: 13
                                clip: true; selectByMouse: true
                                onAccepted: pg.savePreset(text)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: nameIn.text === ""
                                    text: "Name this preset…"
                                    color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: 13
                                }
                            }
                            Btn {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: Tokens.s2
                                text: "Save"; primary: true; compact: true
                                onAct: pg.savePreset(nameIn.text)
                            }
                        }
                    }

                    // safe knobs, always visible; one cell per probed tunable.
                    Flow {
                        width: parent.width; spacing: Tokens.s2
                        Repeater {
                            model: pg.safeTune
                            delegate: TuneCell {
                                required property var modelData
                                tunable: modelData
                                width: modelData.kind === "segment" ? tuneSect.span(12)
                                    : (modelData.kind === "slider" ? tuneSect.span(6) : tuneSect.span(4))
                            }
                        }
                    }

                    // nothing writable on this hardware: say so, do not leave a void.
                    Text {
                        visible: (pg.tune || []).length === 0
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Your graphics driver exposes no tunable knobs on this session. Everything here is read-only on this hardware."
                        color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                    }

                    // advanced disclosure: overclock, undervolt, clock-lock, fan.
                    Item {
                        visible: pg.advTune.length > 0
                        width: parent.width; height: 22
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.s2
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ">"; rotation: pg.showAdvanced ? 90 : 0
                                color: advHov.hovered ? Tokens.ink : Tokens.inkMuted
                                font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                                Behavior on rotation { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pg.showAdvanced ? "Hide advanced" : "Advanced · per session, can misbehave"
                                color: advHov.hovered ? Tokens.ink : Tokens.inkMuted
                                font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                                font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                            }
                        }
                        HoverHandler { id: advHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: pg.showAdvanced = !pg.showAdvanced }
                    }
                    Column {
                        width: parent.width
                        visible: pg.showAdvanced && pg.advTune.length > 0
                        spacing: Tokens.s3
                        // the warning is a bone plate and the words, never a colour.
                        Rectangle {
                            width: parent.width
                            height: advWarn.implicitHeight + Tokens.s3 * 2
                            radius: Tokens.radius; color: Tokens.bone
                            Text {
                                id: advWarn
                                anchors {
                                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                    leftMargin: Tokens.s3; rightMargin: Tokens.s3
                                }
                                text: "Overclocking, undervolting and fan control can freeze the GPU or the desktop. Every change is per session and clears on reboot; if the screen misbehaves, reboot to recover."
                                color: Tokens.inkOnBone; wrapMode: Text.WordWrap
                                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium
                            }
                        }
                        Flow {
                            width: parent.width; spacing: Tokens.s2
                            Repeater {
                                model: pg.advTune
                                delegate: TuneCell {
                                    required property var modelData
                                    tunable: modelData
                                    width: modelData.kind === "segment" ? tuneSect.span(12)
                                        : (modelData.kind === "slider" ? tuneSect.span(6) : tuneSect.span(4))
                                }
                            }
                        }
                    }

                    Text {
                        visible: pg.tuneError !== ""
                        width: parent.width; wrapMode: Text.WordWrap
                        text: pg.tuneError
                        color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Want deeper overclocking (voltage curves, fan curves)? Install LACT, a dedicated GPU control daemon."
                        color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fTiny
                    }
                }

                // ── GPU PASSTHROUGH · ADVANCED ──
                Section {
                    width: parent.width
                    title: "GPU PASSTHROUGH · ADVANCED"

                    Column {
                        width: parent.width
                        spacing: Tokens.s3

                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: "Free " + pg.dgpuName + " from the desktop and bind it to vfio so a virtual machine can own it for near-native performance. This sets up the host only; you run the VM yourself (libvirt + Looking Glass). Everyday VMs in ryovm need none of this."
                            color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        }

                        Row {
                            width: parent.width; spacing: Tokens.s2
                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                anchors.top: parent.top; anchors.topMargin: 5
                                color: pg.ptPending ? Tokens.inkMuted : (pg.ptOk ? Tokens.ink : "transparent")
                                border.width: (!pg.ptPending && !pg.ptOk) ? Tokens.border : 0
                                border.color: Tokens.ink
                            }
                            Text {
                                width: parent.width - 7 - Tokens.s2
                                wrapMode: Text.WordWrap
                                text: pg.ptText
                                color: pg.ptPending ? Tokens.inkMuted : (pg.ptOk ? Tokens.inkDim : Tokens.ink)
                                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium
                            }
                        }

                        Btn {
                            visible: pg.caps.enabled === true
                            text: "Disable passthrough"
                            onAct: pg.act(["ryoku-hub", "gpu", "apply", "disable"])
                        }
                        Btn {
                            visible: pg.caps.enabled !== true && pg.caps.verdict !== "incapable" && !pg.planning && !pg.enabling
                            text: "Review changes"
                            onAct: pg.reviewEnable()
                        }

                        Rectangle {
                            visible: pg.planning
                            width: parent.width; height: 220
                            radius: Tokens.radius; color: Tokens.tint5
                            border.width: Tokens.border; border.color: Tokens.line
                            clip: true
                            Flickable {
                                id: planFlick
                                anchors.fill: parent; anchors.margins: Tokens.s3
                                contentWidth: width; contentHeight: planView.height
                                clip: true; boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }
                                Text {
                                    id: planView
                                    width: planFlick.width
                                    text: pg.planText
                                    color: Tokens.inkDim; font.family: Tokens.mono
                                    font.pixelSize: Tokens.fMicro; wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                        Row {
                            visible: pg.planning
                            spacing: Tokens.s2
                            Btn { text: "Enable passthrough"; primary: true; onAct: pg.enableInTerminal() }
                            Btn { text: "Close"; onAct: { pg.planning = false; pg.planText = ""; } }
                        }

                        Text {
                            visible: pg.enabling
                            width: parent.width; wrapMode: Text.WordWrap
                            text: "Setting up in a terminal window (it builds a kernel module, so it can take a few minutes). Click Recheck when it finishes."
                            color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        }
                        Btn { visible: pg.enabling; text: "Recheck"; onAct: pg.recheck() }

                        Item {
                            width: parent.width; height: 22
                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s2
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ">"; rotation: pg.showChecks ? 90 : 0
                                    color: chkHov.hovered ? Tokens.ink : Tokens.inkMuted
                                    font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                                    Behavior on rotation { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pg.showChecks ? "Hide readiness checks" : "Readiness checks"
                                    color: chkHov.hovered ? Tokens.ink : Tokens.inkMuted
                                    font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                                }
                            }
                            HoverHandler { id: chkHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: pg.showChecks = !pg.showChecks }
                        }
                        Item {
                            width: parent.width; clip: true
                            height: pg.showChecks ? checksCol.implicitHeight : 0
                            visible: height > 0.5
                            opacity: pg.showChecks ? 1 : 0
                            Behavior on height { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                            Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
                            Column {
                                id: checksCol
                                width: parent.width; spacing: 0
                                Repeater {
                                    model: pg.caps.checks || []
                                    delegate: Item {
                                        id: cr
                                        required property var modelData
                                        readonly property string lvl: cr.modelData ? cr.modelData.level : ""
                                        readonly property bool attn: cr.lvl === "warn" || cr.lvl === "bad" || cr.lvl === "fail"
                                        width: parent.width; height: 30
                                        Rectangle {
                                            id: crdot
                                            width: 7; height: 7; radius: 3.5
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            color: cr.attn ? "transparent" : Tokens.ink
                                            border.width: cr.attn ? Tokens.border : 0
                                            border.color: Tokens.ink
                                        }
                                        Text {
                                            anchors.left: crdot.right; anchors.leftMargin: Tokens.s3
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: cr.modelData ? cr.modelData.label : ""
                                            color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                                        }
                                        Text {
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            text: cr.modelData ? cr.modelData.value : ""
                                            color: cr.attn ? Tokens.ink : Tokens.inkMuted
                                            font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // action error banner (passthrough)
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            visible: pg.actionError !== ""
            height: Math.min(errText.implicitHeight + Tokens.s3 * 2, 110)
            radius: Tokens.radius; color: Tokens.paper
            border.width: Tokens.border; border.color: Tokens.lineStrong
            clip: true
            Rectangle {
                id: errTag
                anchors.left: parent.left; anchors.top: parent.top
                anchors.leftMargin: Tokens.s3; anchors.topMargin: Tokens.s3
                width: errTagLab.width + Tokens.s2 * 2; height: 18
                radius: Tokens.radius; color: Tokens.bone
                Text {
                    id: errTagLab
                    anchors.centerIn: parent; text: "ERROR"
                    color: Tokens.inkOnBone; font.family: Tokens.ui; font.pixelSize: Tokens.fTiny
                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
            }
            Text {
                id: errText
                anchors {
                    left: errTag.right; right: parent.right; top: parent.top
                    leftMargin: Tokens.s3; rightMargin: Tokens.s3; topMargin: Tokens.s3
                }
                text: pg.actionError
                color: Tokens.ink; wrapMode: Text.WordWrap
                elide: Text.ElideRight; maximumLineCount: 4
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
            }
            TapHandler { onTapped: pg.actionError = "" }
        }

        Decor {
            id: renderDecor
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.min(300, below.height - rail.height - Tokens.s5)
            images: ["render.gif", "torus.gif", "sphere.gif", "cube.gif", "spring.gif"]
            title: "描画"; sub: "三次元"
            tate: "光と三角形"
            caption: "The desktop, drawn in real time: geometry, light, and a few million triangles a frame."
            readout: ["SHADING|per-pixel", "GEOMETRY|instanced", "SURFACES|composited", "REFRESH|adaptive"]
            code: "GPU-02"; seal: "描"; boxId: "gpu.render"; seed: 0; ditherFreq: 1.0
        }
    }
}
