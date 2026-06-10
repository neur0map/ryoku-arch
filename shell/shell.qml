//@ pragma Env QS_CRASHREPORT_URL=https://github.com/neur0map/ryoku-arch/issues/new
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import qs.modules.ii.overlay
import QtQuick
import Quickshell
import qs.services
import qs.dashboard.modules.globals as DashGlobals
import qs.settingsgui.Services.Platform

ShellRoot {
    settings.watchFiles: true
    readonly property bool idleInhibitorLoaded: IdleInhibitor.enabled
    // Eager-instantiate the lazy GameMode singleton: its IpcHandler, startup
    // reconcile and gamemoded watcher must live from shell start, not from the
    // first utilities-drawer open. Same trick as idleInhibitorLoaded above.
    readonly property bool gameModeLoaded: GameMode.enabled

    Background {}
    Drawers {}
    AreaPicker {}

    Overlay {}

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
    LockBridge {}
    IdleMonitors {}
    WallpaperRotation {}
    ClipboardMaintenance {}
    WeatherUnitSync {}
    PluginMenu {}

    // Bridge the plugin system into the running scene: `main` entry points (e.g. the
    // wallhaven service) are created under pluginContainer; withCurrentScreen resolves
    // the focused monitor for plugin APIs.
    Item {
        id: pluginContainer
    }

    QtObject {
        id: pluginScreenDetector

        function withCurrentScreen(callback): void {
            const mon = Hypr.focusedMonitor;
            if (mon) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === mon.name) {
                        callback(Quickshell.screens[i]);
                        return;
                    }
                }
            }
            callback(Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        }
    }

    Component.onCompleted: {
        PluginService.pluginContainer = pluginContainer;
        PluginService.screenDetector = pluginScreenDetector;
    }

    // RYOKU PORT: webcam mirror window, toggled from the island weather-tools row
    // (GlobalStates.mirrorWindowVisible). Registered at the shell root so it persists
    // independently of the island.
    LazyLoader {
        active: DashGlobals.GlobalStates.mirrorWindowVisible
        source: "dashboard/modules/tools/MirrorWindow.qml"
    }
}
