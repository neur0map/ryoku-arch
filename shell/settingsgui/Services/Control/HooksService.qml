pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.settingsgui.Services.Theming
import qs.settingsgui.Services.UI

Singleton {
  id: root

  Connections {
    target: GlobalConfig.colorSchemes
    function onDarkModeChanged() {
      executeDarkModeHook(GlobalConfig.colorSchemes.darkMode);
    }
  }

  // Pending wallpaper hook when waiting for color generation
  property var pendingWallpaperHook: null

  Connections {
    target: WallpaperService
    function onWallpaperChanged(screenName, path) {
      // Check if we need to wait for color generation
      if (GlobalConfig.colorSchemes.useWallpaperColors) {
        var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
        if (effectiveMonitor === "" || effectiveMonitor === undefined) {
          effectiveMonitor = Screen.name;
        }

        if (screenName === effectiveMonitor) {
          // Store pending hook and wait for colors to be generated
          root.pendingWallpaperHook = {
            path: path,
            screenName: screenName
          };
          return;
        }
      }
      // No color generation, execute immediately
      executeWallpaperHook(path, screenName);
    }
  }

  Connections {
    target: TemplateProcessor
    function onColorsGenerated() {
      // Execute pending wallpaper hook after colors are ready
      if (root.pendingWallpaperHook) {
        const hook = root.pendingWallpaperHook;
        root.pendingWallpaperHook = null;
        executeWallpaperHook(hook.path, hook.screenName);
      }
      executeColorGenerationHook();
    }
  }

  // Track lock screen state for unlock hook
  property bool wasLocked: false

  Connections {
    target: PanelService
    function onLockScreenChanged() {
      if (PanelService.lockScreen) {
        lockScreenActiveConnection.target = PanelService.lockScreen;
      }
    }
  }

  Connections {
    id: lockScreenActiveConnection
    target: PanelService.lockScreen
    function onActiveChanged() {
      if (!wasLocked && PanelService.lockScreen.active) {
        executeLockHook();
      }
      if (wasLocked && !PanelService.lockScreen.active) {
        executeUnlockHook();
      }
      wasLocked = PanelService.lockScreen.active;
    }
  }

  // Track performance mode state for hooks
  property bool wasPerformanceModeEnabled: false

  Connections {
    target: PowerProfileService
    function onPerformanceModeChanged() {
      const isEnabled = PowerProfileService.performanceMode;

      if (!wasPerformanceModeEnabled && isEnabled) {
        executePerformanceModeEnabledHook();
      }
      if (wasPerformanceModeEnabled && !isEnabled) {
        executePerformanceModeDisabledHook();
      }
      wasPerformanceModeEnabled = isEnabled;
    }
  }

  function executeWallpaperHook(wallpaperPath, screenName) {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.wallpaperChange;
    if (!script || script === "") {
      return;
    }

    try {
      const theme = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
      let command = script.replace(/\$1/g, wallpaperPath);
      command = command.replace(/\$2/g, screenName || "");
      command = command.replace(/\$3/g, theme);
      Quickshell.execDetached(["sh", "-lc", command]);
      Logger.d("HooksService", `Executed wallpaper hook: ${command}`);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute wallpaper hook: ${e}`);
    }
  }

  function executeDarkModeHook(isDarkMode) {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.darkModeChange;
    if (!script || script === "") {
      return;
    }

    try {
      const command = script.replace(/\$1/g, isDarkMode ? "true" : "false");
      Quickshell.execDetached(["sh", "-lc", command]);
      Logger.d("HooksService", `Executed dark mode hook: ${command}`);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute dark mode hook: ${e}`);
    }
  }

  function executeLockHook() {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.screenLock;
    if (!script || script === "") {
      return;
    }

    try {
      // Pass "lock" as $1 via shell arguments so the script receives it
      Quickshell.execDetached(["sh", "-lc", script, "lock-hook", "lock"]);
      Logger.d("HooksService", `Executed screen lock hook: ${script}`);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute screen lock hook: ${e}`);
    }
  }

  function executeUnlockHook() {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.screenUnlock;
    if (!script || script === "") {
      return;
    }

    try {
      // Pass "unlock" as $1 via shell arguments so the script receives it
      Quickshell.execDetached(["sh", "-lc", script, "unlock-hook", "unlock"]);
      Logger.d("HooksService", `Executed screen unlock hook: ${script}`);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute screen unlock hook: ${e}`);
    }
  }

  function executePerformanceModeEnabledHook() {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.performanceModeEnabled;
    if (!script || script === "") {
      return;
    }

    try {
      Quickshell.execDetached(["sh", "-lc", script]);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute performance mode enabled hook: ${e}`);
    }
  }

  function executePerformanceModeDisabledHook() {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.performanceModeDisabled;
    if (!script || script === "") {
      return;
    }

    try {
      Quickshell.execDetached(["sh", "-lc", script]);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute performance mode disabled hook: ${e}`);
    }
  }

  function executeColorGenerationHook() {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.colorGeneration;
    if (!script || script === "") {
      return;
    }

    try {
      const theme = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
      const command = script.replace(/\$1/g, theme);
      Quickshell.execDetached(["sh", "-lc", command]);
      Logger.d("HooksService", `Executed color generation hook: ${command}`);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute color generation hook: ${e}`);
    }
  }

  property var pendingPowerCallback: null

  Process {
    id: powerHookProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        Logger.w("HooksService", `Power hook failed with exit code ${exitCode}`);
      }

      if (pendingPowerCallback !== null) {
        const callback = pendingPowerCallback;
        pendingPowerCallback = null;
        callback();
      }
    }
  }

  function runPowerHook(script, callback) {
    pendingPowerCallback = callback;
    powerHookProcess.command = ["sh", "-lc", script];
    powerHookProcess.running = true;
  }

  function executeSessionHook(action, callback) {
    if (!GlobalConfig.hooks.enabled) {
      callback();

      return;
    }

    const script = GlobalConfig.hooks.session;
    if (!script) {
      callback();

      return;
    }

    Logger.i("HooksService", `Executing session hook for ${action}`);
    runPowerHook(`${script} ${action}`, callback);
  }

  function executeStartupHook() {
    if (!GlobalConfig.hooks.enabled) {
      return;
    }

    const script = GlobalConfig.hooks.startup;
    if (!script || script === "") {
      return;
    }

    try {
      Quickshell.execDetached(["sh", "-lc", script]);
      Logger.d("HooksService", `Executed startup hook: ${script}`);
    } catch (e) {
      Logger.e("HooksService", `Failed to execute startup hook: ${e}`);
    }
  }

  function init() {
    Logger.i("HooksService", "Service started");
    Qt.callLater(() => {
                   if (PanelService.lockScreen) {
                     wasLocked = PanelService.lockScreen.active;
                     lockScreenActiveConnection.target = PanelService.lockScreen;
                   }
                   wasPerformanceModeEnabled = PowerProfileService.performanceMode;
                   executeStartupHook();
                 });
  }
}
