//@ pragma Env QS_CRASHREPORT_URL=https://github.com/neur0map/ryoku-arch/issues/new
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import Quickshell
import qs.services
import qs.ambxst.modules.globals as AmbxstGlobals

ShellRoot {
    settings.watchFiles: true
    readonly property bool idleInhibitorLoaded: IdleInhibitor.enabled

    Background {}
    Drawers {}
    AreaPicker {}

    ConfigToasts {}
    Shortcuts {}
    BatteryMonitor {}
    LockBridge {}
    IdleMonitors {}
    WallpaperRotation {}
    ClipboardMaintenance {}
    WeatherUnitSync {}

    // RYOKU PORT: webcam mirror window, toggled from the island weather-tools row
    // (GlobalStates.mirrorWindowVisible). Registered at the shell root so it persists
    // independently of the island.
    LazyLoader {
        active: AmbxstGlobals.GlobalStates.mirrorWindowVisible
        source: "ambxst/modules/tools/MirrorWindow.qml"
    }
}
