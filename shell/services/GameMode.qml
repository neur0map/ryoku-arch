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

    // Opt-in "no visuals at all": the vendored Overlay.qml suppresses pinned
    // widget input regions when this is true.
    readonly property bool shouldHidePanels: props.enabled && GlobalConfig.gameMode.hidePanels

    // gamemoded auto-detect state
    property bool gamesRunning: false
    property bool manualLatch: false
    property bool autoEnabled: false
    property bool _autoFlip: false

    // Pre-toggle states, restored on disable. Persisted in the state file so a
    // restarted shell process still restores correctly.
    property string prevProfile: ""
    property bool prevDnd: false
    property bool prevIdle: false
    property bool prevPerfMode: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    readonly property string stateFile: stateDir + "/gamemode.json"

    function perfUnits(): list<string> {
        return ["ryoku-gamemode-perf@full.service", "ryoku-gamemode-perf@base.service"];
    }

    function setDynamicConfs(): void {
        if (!GlobalConfig.gameMode.hyprlandVisuals)
            return;

        const opts = {
            "animations:enabled": 0,
            "decoration:shadow:enabled": 0,
            "decoration:blur:enabled": 0,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 1,
            "decoration:rounding": 0,
            "general:allow_tearing": 1
        };
        if (GlobalConfig.gameMode.vrr)
            opts["misc:vrr"] = 2;
        if (GlobalConfig.gameMode.directScanout)
            opts["render:direct_scanout"] = 1;
        Hypr.extras.applyOptions(opts);
    }

    function persistState(): void {
        const payload = JSON.stringify({
            enabled: props.enabled,
            prev: {
                profile: root.prevProfile,
                dnd: root.prevDnd,
                idleInhibit: root.prevIdle,
                performanceMode: root.prevPerfMode
            }
        });
        // The payload cannot contain single quotes (profile names are plain
        // words, the rest are booleans), so the sh single-quote wrap is safe.
        writeStateProc.command = ["sh", "-c", `mkdir -p '${stateDir}' && printf '%s' '${payload}' > '${stateFile}'`];
        writeStateProc.running = true;
    }

    onEnabledChanged: {
        const fromWatcher = root._autoFlip;
        root._autoFlip = false;
        root.autoEnabled = fromWatcher && enabled;

        if (enabled) {
            if (!fromWatcher)
                root.manualLatch = false;

            // Capture pre-toggle session states before stomping them.
            root.prevDnd = Notifs.dnd;
            root.prevIdle = IdleInhibitor.enabled;
            root.prevPerfMode = SGPower.PowerProfileService.performanceMode;

            setDynamicConfs();

            if (GlobalConfig.gameMode.dnd)
                Notifs.dnd = true;
            if (GlobalConfig.gameMode.idleInhibit)
                IdleInhibitor.enabled = true;
            if (GlobalConfig.gameMode.nightLightOff)
                SGLocation.NightLightService.inhibited = true;
            // Converge with the settingsgui performance mode (its notification
            // pipeline, wallpaper automation and desktop widgets follow it).
            SGPower.PowerProfileService.setPerformanceMode(true);

            if (GlobalConfig.gameMode.pauseWallpaper)
                wallpaperPauseProc.running = true;

            if (GlobalConfig.gameMode.hardwarePerf) {
                profileCaptureProc.running = true;
                const unit = GlobalConfig.gameMode.nvidiaClockLock ? "ryoku-gamemode-perf@full.service" : "ryoku-gamemode-perf@base.service";
                perfUnitProc.command = ["systemctl", "start", unit];
                perfUnitProc.running = true;
            }

            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode enabled"), qsTr("Maximum performance: visuals off, hardware at full tilt"), "gamepad");
        } else {
            if (!fromWatcher && root.gamesRunning)
                root.manualLatch = true;

            Hypr.extras.message("reload");

            Notifs.dnd = root.prevDnd;
            IdleInhibitor.enabled = root.prevIdle;
            SGLocation.NightLightService.inhibited = false;
            SGPower.PowerProfileService.setPerformanceMode(root.prevPerfMode);

            wallpaperResumeProc.running = true;

            profileRestoreCheckProc.running = true;
            perfUnitProc.command = ["systemctl", "stop"].concat(perfUnits());
            perfUnitProc.running = true;

            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode disabled"), qsTr("Settings restored"), "gamepad");
        }

        persistState();
    }

    onGamesRunningChanged: {
        if (!GlobalConfig.gameMode.autoDetect)
            return;

        if (gamesRunning) {
            if (!props.enabled && !manualLatch) {
                root._autoFlip = true;
                props.enabled = true;
            }
        } else {
            root.manualLatch = false;
            if (props.enabled && root.autoEnabled) {
                root._autoFlip = true;
                props.enabled = false;
            }
        }
    }

    Process {
        id: writeStateProc
    }

    Process {
        id: wallpaperPauseProc

        command: ["ryoku-wallpaper-pause"]
    }

    Process {
        id: wallpaperResumeProc

        command: ["ryoku-wallpaper-resume"]
    }

    Process {
        id: perfUnitProc
    }

    Process {
        id: profileSetProc
    }

    // Capture the current power profile, then switch to performance.
    Process {
        id: profileCaptureProc

        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const current = text.trim();
                if (current && current !== "performance")
                    root.prevProfile = current;
                profileSetProc.command = ["powerprofilesctl", "set", "performance"];
                profileSetProc.running = true;
                root.persistState();
            }
        }
    }

    // On disable: restore the remembered profile only if the current one is
    // still the "performance" we set (an AC/battery udev event may have
    // changed it mid-game — leave the newer state alone then).
    Process {
        id: profileRestoreCheckProc

        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "performance" && root.prevProfile) {
                    profileSetProc.command = ["powerprofilesctl", "set", root.prevProfile];
                    profileSetProc.running = true;
                }
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
            if (code === 0 && !props.enabled) {
                perfUnitProc.command = ["systemctl", "stop"].concat(root.perfUnits());
                perfUnitProc.running = true;
            }
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
                    clientCountProc.running = true;
            }
        }
    }

    Process {
        id: clientCountProc

        command: ["gdbus", "call", "--session", "--dest", "com.feralinteractive.GameMode", "--object-path", "/com/feralinteractive/GameMode", "--method", "org.freedesktop.DBus.Properties.Get", "com.feralinteractive.GameMode", "ClientCount"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/int32 (\d+)/);
                if (m)
                    root.gamesRunning = parseInt(m[1], 10) > 0;
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
                root.prevIdle = !!(s.prev?.idleInhibit);
                root.prevPerfMode = !!(s.prev?.performanceMode);
            } catch (e) {
                console.warn("GameMode: failed to parse state file:", e);
            }
        }
    }

    PersistentProperties {
        id: props

        // Detect from the compositor itself: animations:enabled is off only
        // while game mode's live tweaks are applied. The Lua parser reports a
        // bool, the legacy parser an int — accept both.
        property bool enabled: Hypr.options["animations:enabled"] === 0 || Hypr.options["animations:enabled"] === false

        reloadableId: "gameMode"
    }

    Connections {
        function onConfigReloaded(): void {
            if (props.enabled)
                root.setDynamicConfs();
        }

        target: Hypr
    }

    Component.onCompleted: reconcileProc.running = true

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
