pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// owns screen vibrance (nvibrant) + external monitor brightness (ddcutil) for
// the mixer. persisted vibrance % = source of truth: loaded and pushed once at
// startup so the tint survives a reboot, every later set hits nvibrant AND
// writes the state file back. ddc monitors come from `ddcutil detect` (one
// fader each). setvcp/getvcp wire format lives here so every caller agrees.
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/nvibrant-value"

    property int vibrance: 40

    // ddc monitors from `ddcutil detect`: [{ bus, label }]. label = drm connector,
    // else just the i2c bus number.
    property var ddcMonitors: []
    property var probeOwners: []
    readonly property bool probesWanted: root.probeOwners.length > 0
    // `ddcutil detect` is a slow i2c bus scan whose result almost never changes,
    // so it runs once and is cached here; the sidebar never rescans on open.
    property bool displaysProbed: false

    // load saved vibrance % and apply once -> tint survives reboot. singletons
    // init lazily, so something at startup has to actually touch this for the
    // restore to fire.
    function restore() {
        var raw = vibState.text();
        var v = parseInt((raw || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
        if (raw && raw.trim().length)
            applyVibrance(root.vibrance);
    }

    // set vibrance to `pct`%: push to nvibrant, save to state. `vibrance` tracks
    // the last value.
    function setVibrance(pct) {
        root.vibrance = Math.round(pct);
        applyVibrance(pct);
        saveVibrance(pct);
    }

    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        Quickshell.execDetached(["nvibrant", String(raw), "0", String(raw)]);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\n" "$2" > "$1"',
            "_", root.stateFile, String(Math.round(pct))]);
    }

    function startProbes(owner) {
        if (root.probeOwners.indexOf(owner) < 0)
            root.probeOwners = root.probeOwners.concat([owner]);
        // The monitor set is cached from the one prewarmed scan, so an open only
        // re-reads live values (backlight here, per-monitor getvcp in the fader)
        // and never pays for the i2c enumeration that stalled the slide.
        if (!root.displaysProbed)
            root.detect();
        root.readBacklight();
    }

    function stopProbes(owner) {
        root.probeOwners = root.probeOwners.filter(candidate => candidate !== owner);
        if (!root.probesWanted) {
            ddcDetect.running = false;
            blRead.running = false;
        }
    }

    // Prewarm the ddc monitor list once at pill start, off the sidebar's open
    // path, so the first Super+Escape open already has its faders and no open
    // ever triggers an i2c scan mid-animation.
    function prewarmDisplays() {
        if (!root.displaysProbed)
            root.detect();
    }

    function detect() {
        ddcDetect.running = false;
        ddcDetect.running = true;
    }

    function setBrightness(bus, pct) {
        Quickshell.execDetached(["timeout", "3", "ddcutil", "setvcp", "10",
            String(pct), "--bus", bus, "--noverify"]);
    }

    // pull current brightness % out of a `ddcutil getvcp --brief` line. -1 = none.
    function parseBrightness(text) {
        var m = text.match(/C\s+(\d+)\s+/);
        return m ? parseInt(m[1], 10) : -1;
    }

    // --- internal backlight (brightnessctl): the laptop panel, distinct from
    // the external ddc monitors above. backlightPct stays -1 until the first
    // read, and on a machine with no backlight device the reader never sets it,
    // so backlightAvailable stays false and the fader hides.
    property int backlightPct: -1
    readonly property bool backlightAvailable: root.backlightPct >= 0

    function readBacklight() {
        if (!root.probesWanted)
            return;
        blRead.running = false;
        blRead.running = true;
    }

    // set the panel brightness to `pct`%, floored at 1 so it never blacks out.
    // tracks the value optimistically so the fader does not snap back while the
    // poll catches up.
    function setBacklight(pct) {
        var p = Math.max(1, Math.min(100, Math.round(pct)));
        root.backlightPct = p;
        Quickshell.execDetached(["brightnessctl", "set", p + "%"]);
    }

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var mons = [];
                var blocks = this.text.split(/\bDisplay \d+/);
                for (var i = 0; i < blocks.length; i++) {
                    var bus = /I2C bus:\s+\/dev\/i2c-(\d+)/.exec(blocks[i]);
                    var conn = /DRM connector:\s+card\d+-(\S+)/.exec(blocks[i]);
                    if (bus)
                        mons.push({ bus: bus[1], label: conn ? conn[1] : "BUS " + bus[1] });
                }
                root.ddcMonitors = mons;
                // Cache the enumeration: a completed scan (even an empty one on a
                // lone laptop panel) means no open needs to rescan the bus.
                root.displaysProbed = true;
            }
        }
    }

    Process {
        id: blRead
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, 'NR==1{print substr($4,1,length($4)-1)}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.probesWanted)
                    return;
                var v = parseInt(this.text.trim());
                if (!isNaN(v))
                    root.backlightPct = v;
            }
        }
    }

    FileView {
        id: vibState
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }
}
