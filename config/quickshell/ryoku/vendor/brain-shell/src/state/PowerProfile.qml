pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

// Battery vs performance profile.
//
// powersave applies: brightness 45 %, monitor 60 Hz when that mode is
// advertised, CPU governor "powersave", AMD EPP "powersave", and
// Theme.staticMode = true (freezes high-visibility motion — the rest of
// the UI keeps working normally).
//
// performance restores brightness/refresh saved at the moment of
// entering powersave (or sensible defaults if never saved), CPU governor
// "performance", AMD EPP "performance", and Theme.staticMode = false.
//
// All side-effects are best-effort: brightnessctl needs an udev/setuid
// rule, and scaling_governor / EPP sysfs writes may need elevated access.
// Failures are silent — same compromise QuickSettings made.
//
// Deliberately do not force GPU DPM levels here: that is separate from
// brightness/refresh and can affect hybrid laptop display pipelines.

QtObject {
    id: root

    // ── Public state ───────────────────────────────────────────────────────────
    property string mode: "performance"

    // Powersave target values.
    readonly property int powersaveBrightness: 45
    readonly property int powersaveRefresh:    60

    // ── Saved-from-performance state (used to restore on toggle off) ───────────
    property int    savedBrightness: -1
    property string monitorName:     ""
    property string monitorRes:      ""
    property string monitorScale:    ""
    property string savedRefresh:    ""
    property string targetRefresh:   ""

    // ── Brightness read (brightnessctl -m → "dev,name,X%,cur,max") ─────────────
    property var _brightRead: Process {
        command: ["bash", "-c", "brightnessctl -c backlight -m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/(\d+)%/)
                if (m) root.savedBrightness = parseInt(m[1])
                root._setBrightness(root.powersaveBrightness)
            }
        }
    }

    property var _brightSet: Process {
        command: []
        running: false
    }

    function _setBrightness(pct) {
        var n = Math.max(1, Math.min(100, parseInt(pct)))
        _brightSet.command = ["bash", "-c", "brightnessctl -c backlight set " + n + "%"]
        _brightSet.running = false
        _brightSet.running = true
    }

    // ── Monitor info read (name, resolution, refresh, scale) ───────────────────
    property var _monRead: Process {
        command: ["bash", "-c",
            "hyprctl monitors -j | python3 -c '" +
            "import sys,json;" +
            "mons=json.load(sys.stdin);" +
            "m=next((x for x in mons if x.get(\"focused\")), mons[0]);" +
            "res=\"%dx%d\"%(m[\"width\"],m[\"height\"]);" +
            "prefix=res+\"@\";" +
            "target_hz=\"" + root.powersaveRefresh + "\";" +
            "target=next((mode.split(\"@\")[1].replace(\"Hz\",\"\") for mode in m.get(\"availableModes\",[]) if mode.startswith(prefix) and mode.split(\"@\")[1].startswith(target_hz)), \"\");" +
            "print(m[\"name\"]);" +
            "print(res);" +
            "print(int(round(m[\"refreshRate\"])));" +
            "print(m[\"scale\"]);" +
            "print(target);" +
            "'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length < 5) return
                root.monitorName   = lines[0].trim()
                root.monitorRes    = lines[1].trim()
                root.savedRefresh  = lines[2].trim()
                root.monitorScale  = lines[3].trim()
                root.targetRefresh = lines[4].trim()
                if (root.targetRefresh !== "") root._setMonitorRefresh(root.targetRefresh)
            }
        }
    }

    property var _monSet: Process {
        command: []
        running: false
    }

    function _setMonitorRefresh(hz) {
        if (root.monitorName === "" || root.monitorRes === "") return
        // hyprctl keyword monitor "<name>,<res>@<hz>,auto,<scale>"
        _monSet.command = [
            "hyprctl", "keyword", "monitor",
            root.monitorName + "," + root.monitorRes + "@" + hz +
            ",auto," + root.monitorScale
        ]
        _monSet.running = false
        _monSet.running = true
    }

    // ── CPU governor write ─────────────────────────────────────────────────────
    property var _govSet: Process {
        command: []
        running: false
    }

    function _setGovernor(gov) {
        // Defense-in-depth: even though setMode only ever passes these two,
        // validate the value before shell interpolation.
        var allowed = ["performance", "powersave"]
        if (allowed.indexOf(gov) === -1) return
        _govSet.command = [
            "sh", "-c",
            "echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
        ]
        _govSet.running = false
        _govSet.running = true
    }

    // ── AMD energy_performance_preference (EPP) ────────────────────────────────
    // amd_pstate driver biases the silicon's P-state firmware independently
    // of the governor. On AMD laptops this is the single biggest CPU-side
    // power knob — auto-cpufreq does not touch it.
    property var _eppSet: Process {
        command: []
        running: false
    }

    function _setEpp(epp) {
        var allowed = [
            "default", "performance", "powersave", "powersupersave",
            "balance_performance", "balance_power", "power"
        ]
        if (allowed.indexOf(epp) === -1) return
        _eppSet.command = [
            "sh", "-c",
            "echo " + epp + " | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
        ]
        _eppSet.running = false
        _eppSet.running = true
    }

    // ── Public API ─────────────────────────────────────────────────────────────
    function setMode(target) {
        if (target !== "performance" && target !== "powersave") return
        if (target === root.mode) return

        root.mode        = target
        Theme.staticMode = (target === "powersave")

        if (target === "powersave") {
            _setGovernor("powersave")
            _setEpp("powersave")
            _brightRead.running = false
            _brightRead.running = true
            _monRead.running    = false
            _monRead.running    = true
        } else {
            _setGovernor("performance")
            _setEpp("performance")
            _setBrightness(root.savedBrightness > 0 ? root.savedBrightness : 100)
            if (root.monitorName !== "" && root.monitorRes !== "" && root.savedRefresh !== "") {
                _setMonitorRefresh(root.savedRefresh)
            }
        }
    }

    function toggle() {
        setMode(root.mode === "powersave" ? "performance" : "powersave")
    }
}
