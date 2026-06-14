pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.dashboard.modules.services
import qs.dashboard.config

Singleton {
    id: root

    property var wallpaperManager: null

    property string compositorLayout: ""
    property bool compositorLayoutReady: false
    // RYOKU PORT: ryoku's dynamic island drives dashboard open/close (see getActiveDashboard).
    property bool ryokuDashboardOpen: false
    readonly property var availableLayouts: ["dwindle", "master", "scrolling"]

    Process {
        id: getLayoutProcess
        command: ["hyprctl", "getoption", "general:layout", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed && typeof parsed.str === 'string') {
                        const layout = parsed.str.trim();
                        if (root.availableLayouts.includes(layout)) {
                            root.compositorLayout = layout;
                        } else {
                            root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                        }
                    } else {
                        root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                    }
                } catch (e) {
                    console.warn("GlobalStates: Failed to parse hyprctl layout:", e);
                    root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                }
                root.compositorLayoutReady = true;
            }
        }
    }



    Component.onCompleted: {
        LockscreenService.toString();
        getLayoutProcess.running = true;
    }

    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    property int dashboardCurrentTab: 0
    



    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveDashboard() {
        // Driven by ryoku's dynamic-island open state (see ryokuDashboardOpen).
        // The per-screen Visibilities path depends on AxctlService.focusedMonitor
        // (the axctl daemon), which is not used here, so getForActive() is always null.
        return root.ryokuDashboardOpen;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview : false;
    }



    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: getActiveDashboard()

    property bool lockscreenVisible: false


    // Mirror Tool state
    property bool mirrorWindowVisible: false

    property bool settingsWindowVisible: false


}
