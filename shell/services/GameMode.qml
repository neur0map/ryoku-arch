pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku
import Ryoku.Config
import qs.services
import qs.settingsgui.Services.Location as SGLocation
import qs.settingsgui.Services.Power as SGPower

Singleton {
    id: root

    property alias enabled: props.enabled

    // Opt-in "no visuals at all": the overlay suppresses pinned widget input
    // regions when this is true.
    readonly property bool shouldHidePanels: props.enabled && GlobalConfig.gameMode.hidePanels

    // gamemoded auto-detect state
    property bool gamesRunning: false
    property bool manualLatch: false
    property bool autoEnabled: false
    // Routes watcher-driven flips into onEnabledChanged: works because QML
    // change handlers run synchronously within the assignment.
    property bool _changeFromWatcher: false

    // Restart recovery: the state file is the primary "was enabled" signal;
    // _recoveredSession marks the next enable as a recovery (re-apply effects,
    // but skip the pre-state capture and the toast).
    property bool _persistedEnabled: false
    property bool _recoveredSession: false

    // Restore-only-what-we-touched flags. Not persisted: recovery re-applies
    // the effects and rebuilds them.
    property bool _visualsApplied: false
    property bool _wallpaperPaused: false
    property bool _nightLightInhibited: false
    property bool _dndApplied: false
    property bool _idleApplied: false

    // Pre-toggle states, restored on disable. Persisted in the state file so a
    // restarted shell process still restores correctly.
    property string prevProfile: ""
    property bool prevDnd: false
    property bool prevIdleInhibit: false
    property bool prevPerformanceMode: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    readonly property string stateFile: stateDir + "/gamemode.json"

    function perfUnits(): list<string> {
        return ["ryoku-gamemode-perf@full.service", "ryoku-gamemode-perf@base.service"];
    }

    function pollClientCount(): void {
        clientCountProc.exec(["gdbus", "call", "--session", "--dest", "com.feralinteractive.GameMode", "--object-path", "/com/feralinteractive/GameMode", "--method", "org.freedesktop.DBus.Properties.Get", "com.feralinteractive.GameMode", "ClientCount"]);
    }

    function setDynamicConfs(): void {
        const opts = {};
        if (GlobalConfig.gameMode.hyprlandVisuals) {
            opts["animations:enabled"] = 0;
            opts["decoration:shadow:enabled"] = 0;
            opts["decoration:blur:enabled"] = 0;
            opts["general:gaps_in"] = 0;
            opts["general:gaps_out"] = 0;
            opts["general:border_size"] = 1;
            opts["decoration:rounding"] = 0;
            opts["general:allow_tearing"] = 1;
        }
        // vrr and directScanout are independent toggles, not part of the
        // visuals-off bundle — apply them regardless of hyprlandVisuals.
        if (GlobalConfig.gameMode.vrr)
            opts["misc:vrr"] = 2;
        if (GlobalConfig.gameMode.directScanout)
            opts["render:direct_scanout"] = 1;
        if (Object.keys(opts).length === 0)
            return;
        Hypr.extras.applyOptions(opts);
        root._visualsApplied = true;
    }

    function persistState(): void {
        const payload = JSON.stringify({
            enabled: props.enabled,
            autoEnabled: root.autoEnabled,
            prev: {
                profile: root.prevProfile,
                dnd: root.prevDnd,
                idleInhibit: root.prevIdleInhibit,
                performanceMode: root.prevPerformanceMode
            }
        });
        // Payload travels as argv, immune to quoting and apostrophe-in-$HOME issues.
        writeStateProc.exec(["sh", "-c", "mkdir -p \"$1\" && printf %s \"$3\" > \"$2\"", "_", stateDir, stateFile, payload]);
    }

    onEnabledChanged: {
        const fromWatcher = root._changeFromWatcher;
        root._changeFromWatcher = false;
        const recovery = root._recoveredSession;
        root._recoveredSession = false;
        root.autoEnabled = recovery ? root.autoEnabled : (fromWatcher && enabled);
        // Suppress the standalone perf-mode/profile toasts while game mode is
        // the one flipping them (one gamepad toast is enough).
        SGPower.PowerProfileService.beginGameModeSync();

        if (enabled) {
            if (!fromWatcher)
                root.manualLatch = false;

            // Capture pre-toggle session states before stomping them. On
            // recovery the file values are the truth (loaded together with the
            // flag) — capturing now would record our own stomped state.
            if (!recovery) {
                root.prevDnd = Notifs.dnd;
                root.prevIdleInhibit = IdleInhibitor.enabled;
                root.prevPerformanceMode = SGPower.PowerProfileService.performanceMode;
            }

            setDynamicConfs();

            if (GlobalConfig.gameMode.dnd) {
                Notifs.dnd = true;
                root._dndApplied = true;
            }
            if (GlobalConfig.gameMode.idleInhibit) {
                IdleInhibitor.enabled = true;
                root._idleApplied = true;
            }
            if (GlobalConfig.gameMode.nightLightOff) {
                SGLocation.NightLightService.inhibited = true;
                root._nightLightInhibited = true;
            }
            // Converge with the settingsgui performance mode (its notification
            // pipeline, wallpaper automation and desktop widgets follow it).
            SGPower.PowerProfileService.setPerformanceMode(true);

            if (GlobalConfig.gameMode.pauseWallpaper) {
                wallpaperPauseProc.exec(["ryoku-wallpaper-pause"]);
                root._wallpaperPaused = true;
            }

            if (GlobalConfig.gameMode.hardwarePerf) {
                profileCaptureProc.exec(["powerprofilesctl", "get"]);
                const unit = GlobalConfig.gameMode.nvidiaClockLock ? "ryoku-gamemode-perf@full.service" : "ryoku-gamemode-perf@base.service";
                perfUnitProc.exec(["systemctl", "start", unit]);
            }

            if (!recovery && GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode enabled"), GlobalConfig.gameMode.hardwarePerf ? qsTr("Maximum performance: visuals off, hardware at full tilt") : qsTr("Visuals off, distractions silenced"), "gamepad");
        } else {
            if (!fromWatcher && root.gamesRunning)
                root.manualLatch = true;

            // Reload only when we applied visuals: a full compositor reload
            // wipes unrelated runtime keywords.
            if (root._visualsApplied) {
                Hypr.extras.message("reload");
                root._visualsApplied = false;
            }

            // Restore session states only if they are still what we set — a
            // user who deliberately changed these mid-game keeps their choice.
            if (root._dndApplied && Notifs.dnd) {
                Notifs.dnd = root.prevDnd;
                root._dndApplied = false;
            }
            if (root._idleApplied && IdleInhibitor.enabled) {
                IdleInhibitor.enabled = root.prevIdleInhibit;
                root._idleApplied = false;
            }
            if (root._nightLightInhibited) {
                SGLocation.NightLightService.inhibited = false;
                root._nightLightInhibited = false;
            }
            if (SGPower.PowerProfileService.performanceMode)
                SGPower.PowerProfileService.setPerformanceMode(root.prevPerformanceMode);

            if (root._wallpaperPaused) {
                wallpaperResumeProc.exec(["ryoku-wallpaper-resume"]);
                root._wallpaperPaused = false;
            }

            profileRestoreCheckProc.exec(["powerprofilesctl", "get"]);
            perfUnitProc.exec(["systemctl", "stop"].concat(perfUnits()));

            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode disabled"), qsTr("Settings restored"), "gamepad");
        }

        persistState();
    }

    // Drive auto-detect directly from the polled client count rather than a
    // gamesRunning transition: a game that exits during shell downtime leaves
    // no transition at startup, so a signal-only handler would never auto-disable
    // a recovered session.
    function reconcileAutoDetect(running: bool): void {
        if (!GlobalConfig.gameMode.autoDetect)
            return;

        root.gamesRunning = running;

        if (running) {
            if (!props.enabled && !manualLatch) {
                root._changeFromWatcher = true;
                props.enabled = true;
            }
        } else {
            root.manualLatch = false;
            if (props.enabled && root.autoEnabled) {
                root._changeFromWatcher = true;
                props.enabled = false;
            }
        }
    }

    Process {
        id: writeStateProc

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("GameMode: state write:", text.trim());
            }
        }
        onExited: code => {
            if (code !== 0)
                console.warn("GameMode: state write exited", code);
        }
    }

    Process {
        id: wallpaperPauseProc
    }

    Process {
        id: wallpaperResumeProc
    }

    Process {
        id: perfUnitProc

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("GameMode: perf unit:", text.trim());
            }
        }
        onExited: code => {
            if (code !== 0)
                console.warn("GameMode: perf unit exited", code);
        }
    }

    Process {
        id: profileSetProc

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("GameMode: profile set:", text.trim());
            }
        }
        onExited: code => {
            if (code !== 0)
                console.warn("GameMode: profile set exited", code);
        }
    }

    // Capture the current power profile, then switch to performance.
    Process {
        id: profileCaptureProc

        stdout: StdioCollector {
            onStreamFinished: {
                const current = text.trim();
                if (current && current !== "performance")
                    root.prevProfile = current;
                profileSetProc.exec(["powerprofilesctl", "set", "performance"]);
                root.persistState();
            }
        }
    }

    // On disable: restore the remembered profile only if the current one is
    // still the "performance" we set (an AC/battery udev event may have
    // changed it mid-game — leave the newer state alone then).
    Process {
        id: profileRestoreCheckProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "performance" && root.prevProfile)
                    profileSetProc.exec(["powerprofilesctl", "set", root.prevProfile]);
                root.prevProfile = "";
                root.persistState();
            }
        }
    }

    // Startup reconcile: a perf unit left active while game mode is off means
    // the shell/compositor died mid-game — revert the hardware knobs.
    Process {
        id: reconcileProc

        command: ["sh", "-c", "systemctl is-active --quiet ryoku-gamemode-perf@full.service || systemctl is-active --quiet ryoku-gamemode-perf@base.service"]
        onExited: code => {
            if (code === 0 && !props.enabled)
                perfUnitProc.exec(["systemctl", "stop"].concat(root.perfUnits()));
        }
    }

    // gamemoded auto-detect: enable with the first registered game, disable
    // with the last. Silent no-op when gdbus or gamemoded are absent (the
    // monitor process just exits).
    Process {
        id: gamemodedMonitor

        command: ["gdbus", "monitor", "--session", "--dest", "com.feralinteractive.GameMode"]
        running: GlobalConfig.gameMode.autoDetect
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("GameRegistered") || data.includes("GameUnregistered"))
                    root.pollClientCount();
            }
        }
    }

    Process {
        id: clientCountProc

        stdout: StdioCollector {
            onStreamFinished: {
                // gdbus prints "(<2>,)" — the int32 annotation is omitted for
                // GVariant's default numeric type — or "(<int32 2>,)".
                const m = text.match(/\(<(?:int32 )?(\d+)>/);
                if (m)
                    root.reconcileAutoDetect(parseInt(m[1], 10) > 0);
            }
        }
    }

    // Restore remembered pre-states across shell process restarts.
    FileView {
        path: root.stateFile
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.prevProfile = s.prev?.profile ?? "";
                root.prevDnd = !!(s.prev?.dnd);
                root.prevIdleInhibit = !!(s.prev?.idleInhibit);
                root.prevPerformanceMode = !!(s.prev?.performanceMode);
                if (s.enabled) {
                    root._recoveredSession = true;
                    root.autoEnabled = !!s.autoEnabled;
                }
                // Assign _persistedEnabled LAST: the props.enabled binding depends
                // on it and re-evaluates synchronously, so recovery must be armed
                // before it can flip (else the enable runs as a non-recovery and
                // clobbers the file-loaded prev* state).
                root._persistedEnabled = !!s.enabled;
            } catch (e) {
                console.warn("GameMode: failed to parse state file:", e);
            }
        }
    }

    PersistentProperties {
        id: props

        // Detect from the compositor itself: animations:enabled is off only
        // while game mode's live tweaks are applied. The Lua parser reports a
        // bool, the legacy parser an int — accept both. The persisted state
        // file is the primary signal; the compositor state merely corroborates
        // it, so a user whose own Hyprland config disables animations does not
        // trigger full activation at every login. The binding is intentionally
        // one-shot: any write (IPC, quick toggle, watcher) replaces it — it
        // exists only for fresh-process recovery.
        property bool enabled: root._persistedEnabled && (Hypr.options["animations:enabled"] === 0 || Hypr.options["animations:enabled"] === false)

        reloadableId: "gameMode"
    }

    Connections {
        function onConfigReloaded(): void {
            if (props.enabled)
                root.setDynamicConfs();
        }

        target: Hypr
    }

    Component.onCompleted: {
        reconcileProc.running = true;
        // Prime auto-detect: a game already registered before a shell restart
        // is seen immediately (auto-disable then works after recovery thanks
        // to the persisted autoEnabled).
        if (GlobalConfig.gameMode.autoDetect)
            pollClientCount();
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "gameMode"
    }
}
