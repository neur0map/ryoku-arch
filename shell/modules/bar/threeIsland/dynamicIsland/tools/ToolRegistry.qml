pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell

// Single source of truth for tool buttons. Used by RyokuToolsMode (Mod+S
// pill) and the legacy UtilButtons.qml. Each entry: id -> { icon, label,
// kind ("action" | "toggle"), action(), activeWhen() }.
Singleton {
    id: root

    readonly property var tools: ({
        screenshot: {
            icon: "screenshot_region",
            label: "Screenshot region",
            kind: "action",
            action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "region", "screenshot"])
        },
        record: {
            icon: "videocam",
            label: "Screen record",
            kind: "action",
            action: () => Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]),
            activeWhen: () => RecorderStatus.isRecording
        },
        lens: {
            icon: "search",
            label: "Google Lens",
            kind: "action",
            action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "region", "search"])
        },
        colorPicker: {
            icon: "colorize",
            label: "Color picker",
            kind: "action",
            action: () => Quickshell.execDetached(["/usr/bin/hyprpicker", "-a"])
        },
        musicRecognize: {
            icon: "graphic_eq",
            label: "Recognize music",
            kind: "action",
            action: () => SongRec.toggleRunning(true),
            activeWhen: () => SongRec.running
        },
        micToggle: {
            icon: "mic",
            label: "Mic toggle",
            kind: "toggle",
            action: () => Audio.toggleMicMute(),
            activeWhen: () => !Audio.micMuted && (Privacy.micActive ?? false)
        },
        osk: {
            icon: "keyboard",
            label: "On-screen keyboard",
            kind: "toggle",
            action: () => GlobalStates.oskOpen = !GlobalStates.oskOpen,
            activeWhen: () => GlobalStates.oskOpen
        },
        caffeine: {
            icon: "coffee",
            label: "Keep awake",
            kind: "toggle",
            action: () => Idle.toggleInhibit(),
            activeWhen: () => Idle.inhibit
        },
        notepad: {
            icon: "edit_note",
            label: "Notepad",
            kind: "action",
            action: () => {
                GlobalStates.sidebarRightOpen = true;
                Persistent.states.sidebar.bottomGroup.collapsed = false;
                Persistent.states.sidebar.bottomGroup.tab = 2;
            }
        },
        screenCast: {
            icon: "visibility",
            label: "Screen cast",
            kind: "toggle",
            action: () => {
                const out = Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1";
                if (Persistent.states.screenCast.active) {
                    Quickshell.execDetached(["niri", "msg", "action", "clear-dynamic-cast-target"]);
                    Persistent.states.screenCast.active = false;
                } else {
                    Quickshell.execDetached(["niri", "msg", "action", "set-dynamic-cast-monitor", out]);
                    Persistent.states.screenCast.active = true;
                }
            },
            activeWhen: () => Persistent.states.screenCast.active
        },
        darkMode: {
            icon: "dark_mode",
            label: "Dark mode",
            kind: "toggle",
            action: () => MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode),
            activeWhen: () => Appearance.m3colors.darkmode
        },
        powerProfile: {
            icon: "settings_slow_motion",
            label: "Power profile",
            kind: "toggle",
            action: () => {
                if (PowerProfiles.hasPerformanceProfile) {
                    switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver:   PowerProfiles.profile = PowerProfile.Balanced; break;
                        case PowerProfile.Balanced:     PowerProfiles.profile = PowerProfile.Performance; break;
                        case PowerProfile.Performance:  PowerProfiles.profile = PowerProfile.PowerSaver; break;
                    }
                } else {
                    PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced;
                }
            },
            activeWhen: () => PowerProfiles.profile === PowerProfile.Performance
        }
    })
}
