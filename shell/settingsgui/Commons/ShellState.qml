pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/QtObj2JS.js" as QtObj2JS
import qs.settingsgui.Services.Power
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI

// Centralized shell state management for small cache files
Singleton {
  id: root

  property string stateFile: ""
  property bool isLoaded: false

  readonly property alias data: adapter

  signal displayStateChanged
  signal notificationsStateChanged
  signal changelogStateChanged
  signal colorSchemesListChanged

  Component.onCompleted: {
    // Setup state file path (needs Settings to be available)
    Qt.callLater(() => {
                   if (typeof Settings !== 'undefined' && Settings.cacheDir) {
                     stateFile = Settings.cacheDir + "shell-state.json";
                     stateFileView.path = stateFile;
                   }
                 });
  }

  FileView {
    id: stateFileView
    printErrors: false
    watchChanges: false

    adapter: JsonAdapter {
      id: adapter

      // CompositorService: display scales
      property var display: ({})

      // NotificationService: notification state
      property var notificationsState: ({
                                          lastSeenTs: 0
                                        })

      // UpdateService: changelog state
      property var changelogState: ({
                                      lastSeenVersion: ""
                                    })

      // SchemeDownloader: color schemes list
      property var colorSchemesList: ({
                                        schemes: [],
                                        timestamp: 0
                                      })

      // UI state: settings panel, etc.
      property var ui: ({
                          settingsSidebarExpanded: true
                        })

      // Telemetry state
      property var telemetry: ({
                                 instanceId: ""
                               })

      // Launcher app usage counts
      property var launcherUsage: ({})
    }

    onLoaded: {
      root.isLoaded = true;
      Logger.d("ShellState", "Loaded state file");
    }

    onLoadFailed: error => {
      if (error === 2) {
        root.isLoaded = true;
        Logger.d("ShellState", "State file doesn't exist, will create on first write");
      } else {
        Logger.e("ShellState", "Failed to load state file:", error);
        root.isLoaded = true;
      }
    }
  }

  function getLauncherUsageCount(key) {
    const m = adapter.launcherUsage;
    if (!m)
      return 0;
    const v = m[key];
    return typeof v === 'number' && isFinite(v) ? v : 0;
  }

  function recordLauncherUsage(key) {
    let counts = Object.assign({}, adapter.launcherUsage || {});
    counts[key] = getLauncherUsageCount(key) + 1;
    adapter.launcherUsage = counts;
    save();
  }

  function migrateLauncherUsage(fromKey, toKey) {
    let counts = Object.assign({}, adapter.launcherUsage || {});
    const fromCount = typeof counts[fromKey] === 'number' && isFinite(counts[fromKey]) ? counts[fromKey] : 0;
    const toCount = typeof counts[toKey] === 'number' && isFinite(counts[toKey]) ? counts[toKey] : 0;
    counts[toKey] = toCount + fromCount;
    delete counts[fromKey];
    adapter.launcherUsage = counts;
    save();
  }

  Timer {
    id: saveTimer
    interval: 500
    onTriggered: performSave()
  }

  property bool saveQueued: false

  function save() {
    saveQueued = true;
    saveTimer.restart();
  }

  function performSave() {
    if (!saveQueued || !stateFile) {
      return;
    }

    saveQueued = false;

    try {
      Quickshell.execDetached(["mkdir", "-p", Settings.cacheDir]);

      Qt.callLater(() => {
                     try {
                       stateFileView.writeAdapter();
                       Logger.d("ShellState", "Saved state file");
                     } catch (writeError) {
                       Logger.e("ShellState", "Failed to write state file:", writeError);
                     }
                   });
    } catch (error) {
      Logger.e("ShellState", "Failed to save state:", error);
    }
  }


  function setDisplay(displayData) {
    adapter.display = displayData;
    save();
    displayStateChanged();
  }

  function getDisplay() {
    return adapter.display || {};
  }

  function setNotificationsState(stateData) {
    adapter.notificationsState = stateData;
    save();
    notificationsStateChanged();
  }

  function getNotificationsState() {
    return adapter.notificationsState || {
      lastSeenTs: 0
    };
  }

  function setChangelogState(stateData) {
    adapter.changelogState = stateData;
    save();
    changelogStateChanged();
  }

  function getChangelogState() {
    return adapter.changelogState || {
      lastSeenVersion: ""
    };
  }

  function setColorSchemesList(listData) {
    adapter.colorSchemesList = listData;
    save();
    colorSchemesListChanged();
  }

  function getColorSchemesList() {
    return adapter.colorSchemesList || {
      schemes: [],
      timestamp: 0
    };
  }

  function setUiState(stateData) {
    adapter.ui = stateData;
    save();
  }

  function getUiState() {
    return adapter.ui || {
      settingsSidebarExpanded: true
    };
  }

  function setSettingsSidebarExpanded(expanded) {
    let uiState = getUiState();
    uiState.settingsSidebarExpanded = expanded;
    setUiState(uiState);
  }

  function getSettingsSidebarExpanded() {
    return getUiState().settingsSidebarExpanded !== false; // default to true
  }

  function setTelemetryState(stateData) {
    adapter.telemetry = stateData;
    save();
  }

  function getTelemetryState() {
    return adapter.telemetry || {
      instanceId: ""
    };
  }

  function getTelemetryInstanceId() {
    return getTelemetryState().instanceId || "";
  }

  function setTelemetryInstanceId(instanceId) {
    let state = getTelemetryState();
    state.instanceId = instanceId;
    setTelemetryState(state);
  }

  function buildStateSnapshot() {
    try {
      const settingsData = QtObj2JS.qtObjectToPlainObject(Settings.data);
      const shellStateData = ShellState?.data ? QtObj2JS.qtObjectToPlainObject(ShellState.data) || {} : {};

      return {
        settings: settingsData,
        state: {
          doNotDisturb: NotificationService.doNotDisturb,
          performanceMode: PowerProfileService.performanceMode,
          barVisible: BarService.isVisible,
          openedPanel: PanelService.openedPanel?.objectName || "",
          lockScreenActive: PanelService.lockScreen?.active || false,
          wallpapers: WallpaperService.getWallpapersEffectiveMap(),
          desktopWidgetsEditMode: DesktopWidgetRegistry.editMode || false,
          display: shellStateData.display || {},
          notificationsState: shellStateData.notificationsState || {},
          changelogState: shellStateData.changelogState || {},
          colorSchemesList: shellStateData.colorSchemesList || {},
          ui: shellStateData.ui || {}
        }
      };
    } catch (error) {
      Logger.e("Settings", "Failed to build state snapshot:", error);
      return null;
    }
  }
}
