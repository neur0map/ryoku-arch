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
// performance restores brightness saved at the moment of entering
// powersave, switches the focused display to its highest advertised refresh
// rate, CPU governor "performance", AMD EPP "performance", and
// Theme.staticMode = false.
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
    property string targetRefresh:   ""
    property string _pendingMode:    ""
    property string _pendingRefresh: ""

    // Display refresh changes blank the panel briefly. Keep this state public so
    // the fullscreen overlay can fade in before the Hyprland mode command runs.
    property bool displayTransitionActive: false
    property int displayRefreshGeneration: 0
    readonly property int displayTransitionFadeDuration: 320
    readonly property int displayTransitionPreDelay:     1000
    readonly property int displayTransitionPostDelay:    1800

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
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var mons = JSON.parse(text)
                    if (!mons || mons.length === 0) return

                    var mon = mons[0]
                    for (var i = 0; i < mons.length; i++) {
                        if (mons[i].focused) {
                            mon = mons[i]
                            break
                        }
                    }

                    root.monitorName   = mon.name || ""
                    root.monitorRes    = (mon.width || 0) + "x" + (mon.height || 0)
                    root.monitorScale  = String(mon.scale || 1)
                    root.targetRefresh = root._targetRefreshForMode(mon, root._pendingMode)

                    if (root.targetRefresh !== "")
                        root._beginDisplayTransition(root.targetRefresh)
                } catch (e) {
                }
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

    function _refreshFromMode(mode) {
        var m = String(mode).match(/@([0-9.]+)Hz/)
        return m ? parseFloat(m[1]) : 0
    }

    function _modeMatchesCurrentRes(mode, mon) {
        return String(mode).indexOf((mon.width || 0) + "x" + (mon.height || 0) + "@") === 0
    }

    function _maxRefreshHz(mon) {
        var modes = mon.availableModes || []
        var bestHz = 0
        var bestText = ""

        for (var i = 0; i < modes.length; i++) {
            if (!root._modeMatchesCurrentRes(modes[i], mon)) continue

            var hz = root._refreshFromMode(modes[i])
            if (hz > bestHz) {
                bestHz = hz
                bestText = String(hz)
            }
        }

        if (bestText !== "") return bestText
        return mon.refreshRate ? String(Math.round(mon.refreshRate)) : ""
    }

    function _powersaveRefreshHz(mon) {
        var modes = mon.availableModes || []
        for (var i = 0; i < modes.length; i++) {
            if (!root._modeMatchesCurrentRes(modes[i], mon)) continue

            var hz = root._refreshFromMode(modes[i])
            if (Math.round(hz) === root.powersaveRefresh) return String(hz)
        }

        return ""
    }

    function _targetRefreshForMode(mon, target) {
        if (target === "performance") return root._maxRefreshHz(mon)
        if (target === "powersave") return root._powersaveRefreshHz(mon)
        return ""
    }

    function _beginDisplayTransition(hz) {
        root._pendingRefresh = hz
        root.displayTransitionActive = true
        _displayPostSwitch.stop()
        _displayPreSwitch.restart()
    }

    function _scheduleDisplayRefresh(target) {
        root._pendingMode = target
        _monRead.running = false
        _monRead.running = true
    }

    property var _displayPreSwitch: Timer {
        id: _displayPreSwitch
        interval: root.displayTransitionPreDelay
        repeat: false
        onTriggered: {
            if (root._pendingRefresh !== "") root._setMonitorRefresh(root._pendingRefresh)
            root.displayRefreshGeneration++
            _displayPostSwitch.restart()
        }
    }

    property var _displayPostSwitch: Timer {
        id: _displayPostSwitch
        interval: root.displayTransitionPostDelay
        repeat: false
        onTriggered: {
            root.displayRefreshGeneration++
            root.displayTransitionActive = false
        }
    }

    // ── Mode persistence ───────────────────────────────────────────────────────
    // Quickshell exits and relaunches on theme switches (ryoku-restart-shell)
    // and other config refreshes, wiping in-memory state. The `hyprctl reload`
    // that runs alongside also re-applies monitors.conf, so any runtime refresh
    // override is lost. Persist the user's mode under $XDG_RUNTIME_DIR (cleared
    // at logout) so the choice survives the restart and side effects re-apply.

    property bool _restoring: false

    property var _stateWrite: Process {
        command: []
        running: false
    }

    function _persistMode(m) {
        // setMode validates m before getting here, but keep the allowlist
        // local for defense-in-depth before shell interpolation.
        if (m !== "performance" && m !== "powersave") return
        _stateWrite.command = [
            "sh", "-c",
            "printf %s " + m + " > \"${XDG_RUNTIME_DIR:-/tmp}/ryoku-power-mode\""
        ]
        _stateWrite.running = false
        _stateWrite.running = true
    }

    property var _stateRead: Process {
        command: ["sh", "-c", "cat \"${XDG_RUNTIME_DIR:-/tmp}/ryoku-power-mode\" 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var saved = String(text).trim()
                if (saved !== "powersave" && saved !== "performance") return
                if (saved === root.mode) return
                root._restoring = true
                root.setMode(saved)
                root._restoring = false
            }
        }
    }

    Component.onCompleted: _stateRead.running = true

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
            _scheduleDisplayRefresh(target)
        } else {
            _setGovernor("performance")
            _setEpp("performance")
            _setBrightness(root.savedBrightness > 0 ? root.savedBrightness : 100)
            _scheduleDisplayRefresh(target)
        }

        if (!root._restoring) _persistMode(target)
    }

    function toggle() {
        setMode(root.mode === "powersave" ? "performance" : "powersave")
    }
}
