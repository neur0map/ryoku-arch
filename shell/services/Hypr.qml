pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Ryoku
import Ryoku.Config
import Ryoku.Internal
import qs.components.misc

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: {
        const t = Hyprland.activeToplevel;
        return t?.workspace?.name.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length > 0 ? t : null;
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    readonly property HyprKeyboard keyboard: extras.devices.keyboards.find(kb => kb.main) ?? null
    readonly property bool capsLock: keyboard?.capsLock ?? false
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string defaultKbLayout: keyboard?.layout.split(",")[0] ?? "??"
    readonly property string kbLayoutFull: keyboard?.activeKeymap ?? "Unknown"
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property bool hadKeyboard
    property string lastSpecialWorkspace: ""
    property bool refreshToplevelsPending
    property bool refreshWorkspacesPending
    property bool refreshMonitorsPending

    // RYOKU: Hyprland v0.55+ can run in Lua config mode (configProvider: lua),
    // where the IPC `dispatch` is evaluated as Lua (hl.dispatch(hl.dsp.*)) and
    // legacy string dispatchers like "workspace 2" fail outright. We detect the
    // mode once at startup via a harmless `hl.dsp.no_op()` probe, then translate
    // the dispatch verbs this shell emits into their hl.dsp.* equivalents. Legacy
    // Hyprland is untouched (the probe fails and we keep sending raw strings).
    // Distinct from `extras.luaMode`: that one probes the *parser* synchronously in
    // the plugin constructor (option/keyword translation must be settled before
    // Component.onCompleted callers fire); this async probe only covers dispatchers.
    property bool useLuaDispatch: false
    property bool dispatchModeChecked: false

    signal configReloaded

    function dispatch(request: string): void {
        if (useLuaDispatch)
            Quickshell.execDetached(["hyprctl", "dispatch", toLuaDispatch(request)]);
        else
            Hyprland.dispatch(request);
    }

    // RYOKU: run a dispatch as if `monitor` were focused, so a bar on a secondary
    // display drives its own monitor instead of the focused one (native
    // multi-monitor workspace switching). Ordered/atomic in both dispatch modes:
    // Lua mode batches the monitor focus and the action into one hyprctl call;
    // legacy mode sends the two ordered IPC dispatches. Falls back to a plain
    // dispatch when there is no distinct target monitor.
    function dispatchOnMonitor(monitor: HyprlandMonitor, request: string): void {
        if (!monitor || monitor.id === focusedMonitor?.id) {
            dispatch(request);
            return;
        }

        if (useLuaDispatch) {
            const focus = toLuaDispatch(`focusmonitor ${monitor.name}`);
            const action = toLuaDispatch(request);
            Quickshell.execDetached(["hyprctl", "--batch", `dispatch ${focus} ; dispatch ${action}`]);
        } else {
            Hyprland.dispatch(`focusmonitor ${monitor.name}`);
            Hyprland.dispatch(request);
        }
    }

    // Escape a string for embedding inside a Lua double-quoted literal.
    function luaQuote(value: string): string {
        return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    // Translate the legacy Hyprland dispatch strings this shell emits into the Lua
    // dispatcher syntax used by Hyprland's Lua config mode. Only the verbs the shell
    // actually sends are mapped; unknown verbs fall back to the raw string.
    function toLuaDispatch(request: string): string {
        const trimmed = String(request).trim();
        const sep = trimmed.indexOf(" ");
        const verb = sep === -1 ? trimmed : trimmed.slice(0, sep);
        const rest = sep === -1 ? "" : trimmed.slice(sep + 1).trim();
        const wsArg = value => /^\d+$/.test(value) ? value : `"${luaQuote(value)}"`;

        switch (verb) {
        case "workspace":
            return `hl.dsp.focus({ workspace = ${wsArg(rest)} })`;
        case "togglespecialworkspace":
            return rest ? `hl.dsp.workspace.toggle_special({ name = "${luaQuote(rest)}" })` : "hl.dsp.workspace.toggle_special()";
        case "movetoworkspace": {
            const comma = rest.indexOf(",");
            const ws = (comma === -1 ? rest : rest.slice(0, comma)).trim();
            const win = comma === -1 ? "" : rest.slice(comma + 1).trim();
            const winPart = win ? `, window = "${luaQuote(win)}"` : "";
            return `hl.dsp.window.move({ workspace = ${wsArg(ws)}${winPart} })`;
        }
        case "togglefloating":
            return rest ? `hl.dsp.window.float({ window = "${luaQuote(rest)}" })` : "hl.dsp.window.float()";
        case "pin":
            return rest ? `hl.dsp.window.pin({ window = "${luaQuote(rest)}" })` : "hl.dsp.window.pin()";
        case "killwindow":
            return rest ? `hl.dsp.window.close({ window = "${luaQuote(rest)}" })` : "hl.dsp.window.close()";
        case "focusmonitor":
            return rest ? `hl.dsp.focus({ monitor = "${luaQuote(rest)}" })` : "hl.dsp.focus()";
        default:
            console.warn(`Hypr.dispatch: no Lua mapping for "${trimmed}"; sending as-is`);
            return trimmed;
        }
    }

    function detectDispatchMode(): void {
        if (dispatchModeChecked || dispatchProbe.running)
            return;
        dispatchProbe.running = true;
    }

    function cycleSpecialWorkspace(direction: string): void {
        const openSpecials = workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0);

        if (openSpecials.length === 0)
            return;

        const activeSpecial = focusedMonitor.lastIpcObject.specialWorkspace.name ?? "";

        if (!activeSpecial) {
            if (lastSpecialWorkspace) {
                const workspace = workspaces.values.find(w => w.name === lastSpecialWorkspace);
                if (workspace && workspace.lastIpcObject.windows > 0) {
                    dispatch(`workspace ${lastSpecialWorkspace}`);
                    return;
                }
            }
            dispatch(`workspace ${openSpecials[0].name}`);
            return;
        }

        const currentIndex = openSpecials.findIndex(w => w.name === activeSpecial);
        let nextIndex = 0;

        if (currentIndex !== -1) {
            if (direction === "next")
                nextIndex = (currentIndex + 1) % openSpecials.length;
            else
                nextIndex = (currentIndex - 1 + openSpecials.length) % openSpecials.length;
        }

        dispatch(`workspace ${openSpecials[nextIndex].name}`);
    }

    function monitorNames(): list<string> {
        return monitors.values.map(e => e.name);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function reloadDynamicConfs(): void {
        if (extras.luaMode) {
            // bindlni flags map to locked / non_consuming / ignore_mods
            // (verified live: the bind registers with dispatcher __lua). Re-evaling
            // does not stack duplicates: `reload config-only` wipes eval-registered
            // binds and the configreloaded handler re-adds exactly one (probed live).
            extras.evalLua(`hl.bind("Caps_Lock", hl.dsp.global("ryoku:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true })`);
            extras.evalLua(`hl.bind("Num_Lock", hl.dsp.global("ryoku:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true })`);
            return;
        }
        extras.batchMessage(["keyword bindlni ,Caps_Lock,global,ryoku:refreshDevices", "keyword bindlni ,Num_Lock,global,ryoku:refreshDevices"]);
    }

    function queueRefresh(toplevels: bool, workspaces: bool, monitors: bool): void {
        refreshToplevelsPending = refreshToplevelsPending || toplevels;
        refreshWorkspacesPending = refreshWorkspacesPending || workspaces;
        refreshMonitorsPending = refreshMonitorsPending || monitors;
        refreshTimer.restart();
    }

    Component.onCompleted: {
        reloadDynamicConfs();
        detectDispatchMode();
    }

    onCapsLockChanged: {
        if (!GlobalConfig.utilities.toasts.capsLockChanged)
            return;

        if (capsLock)
            Toaster.toast(qsTr("Caps lock enabled"), qsTr("Caps lock is currently enabled"), "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock disabled"), qsTr("Caps lock is currently disabled"), "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!GlobalConfig.utilities.toasts.numLockChanged)
            return;

        if (numLock)
            Toaster.toast(qsTr("Num lock enabled"), qsTr("Num lock is currently enabled"), "looks_one");
        else
            Toaster.toast(qsTr("Num lock disabled"), qsTr("Num lock is currently disabled"), "timer_1");
    }

    onKbLayoutFullChanged: {
        if (hadKeyboard && GlobalConfig.utilities.toasts.kbLayoutChanged)
            Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayoutFull), "keyboard");

        hadKeyboard = !!keyboard;
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (n === "configreloaded") {
                root.configReloaded();
                root.reloadDynamicConfs();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                root.queueRefresh(false, true, true);
            } else if (["activewindow", "windowtitle"].includes(n)) {
                return;
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                root.queueRefresh(true, true, false);
            } else if (n.includes("mon")) {
                root.queueRefresh(false, false, true);
            } else if (n.includes("workspace")) {
                root.queueRefresh(false, true, false);
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                root.queueRefresh(true, false, false);
            }
        }

        target: Hyprland
    }

    Timer {
        id: refreshTimer

        interval: 25
        repeat: false
        onTriggered: {
            const refreshToplevels = root.refreshToplevelsPending;
            const refreshWorkspaces = root.refreshWorkspacesPending;
            const refreshMonitors = root.refreshMonitorsPending;

            root.refreshToplevelsPending = false;
            root.refreshWorkspacesPending = false;
            root.refreshMonitorsPending = false;

            if (refreshToplevels)
                Hyprland.refreshToplevels();
            if (refreshWorkspaces)
                Hyprland.refreshWorkspaces();
            if (refreshMonitors)
                Hyprland.refreshMonitors();
        }
    }

    Connections {
        function onLastIpcObjectChanged(): void {
            const specialName = root.focusedMonitor.lastIpcObject.specialWorkspace.name;

            if (specialName && specialName.startsWith("special:")) {
                root.lastSpecialWorkspace = specialName;
            }
        }

        target: root.focusedMonitor
    }

    FileView {
        id: kbLayoutFile

        path: Quickshell.env("RYOKU_SHELL_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
        }
    }

    IpcHandler {
        function refreshDevices(): void {
            extras.refreshDevices();
        }

        function cycleSpecialWorkspace(direction: string): void {
            root.cycleSpecialWorkspace(direction);
        }

        function listSpecialWorkspaces(): string {
            return root.workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0).map(w => w.name).join("\n");
        }

        target: "hypr"
    }

    CustomShortcut {
        name: "refreshDevices"
        description: "Reload devices"
        onPressed: extras.refreshDevices()
        onReleased: extras.refreshDevices()
    }

    // One-shot probe: `hl.dsp.no_op()` returns "ok" only when Hyprland evaluates
    // dispatches as Lua (v0.55+ Lua config). In legacy mode it errors, so the flag
    // stays false and dispatch() keeps sending raw legacy strings.
    Process {
        id: dispatchProbe

        running: false
        command: ["hyprctl", "dispatch", "hl.dsp.no_op()"]

        property string out: ""
        property string err: ""

        stdout: SplitParser {
            onRead: data => dispatchProbe.out += data
        }

        stderr: SplitParser {
            onRead: data => dispatchProbe.err += data
        }

        onExited: (exitCode, exitStatus) => {
            root.useLuaDispatch = dispatchProbe.out.includes("ok") && !dispatchProbe.err.toLowerCase().includes("error");
            root.dispatchModeChecked = true;
            dispatchProbe.out = "";
            dispatchProbe.err = "";
        }
    }

    HyprExtras {
        id: extras
    }
}
