import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Services.Keyboard

Item {
  id: root

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged
  signal monitorApplyFinished(bool success, string message)

  property bool initialized: false
  property var workspaceCache: ({})
  property var windowCache: ({})

  property bool dispatchModeChecked: false
  property bool useLuaDispatch: false

  // Debounce timer for window updates
  Timer {
    id: updateTimer
    interval: 50
    repeat: false
    onTriggered: safeUpdate()
  }

  // Deferred via Qt.callLater to coalesce workspace updates: onRawEvent calls
  // refreshWorkspaces() which triggers onValuesChanged synchronously in the
  // same call stack — without deferral the ListModel gets cleared+repopulated
  // twice per event. Qt.callLater deduplicates by function identity.
  function _deferredWorkspaceUpdate() {
    safeUpdateWorkspaces();
    workspaceChanged();
  }

  function initialize() {
    if (initialized)
      return;
    try {
      Hyprland.refreshWorkspaces();
      Hyprland.refreshToplevels();
      Qt.callLater(() => {
                     safeUpdateWorkspaces();
                     safeUpdateWindows();
                     queryDisplayScales();
                     queryKeyboardLayout();
                     detectDispatchMode();
                   });
      initialized = true;
      Logger.i("HyprlandService", "Service started");
    } catch (e) {
      Logger.e("HyprlandService", "Failed to initialize:", e);
    }
  }

  function queryDisplayScales() {
    hyprlandMonitorsProcess.running = true;
  }

  Process {
    id: hyprlandMonitorsProcess
    running: false
    command: ["hyprctl", "monitors", "-j"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        hyprlandMonitorsProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandService", "Failed to query monitors, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const monitorsData = JSON.parse(accumulatedOutput);
        const scales = {};

        for (const monitor of monitorsData) {
          if (monitor.name) {
            scales[monitor.name] = {
              "name": monitor.name,
              "scale": monitor.scale || 1.0,
              "width": monitor.width || 0,
              "height": monitor.height || 0,
              "refresh_rate": monitor.refreshRate || 0,
              "x": monitor.x || 0,
              "y": monitor.y || 0,
              "active_workspace": monitor.activeWorkspace ? monitor.activeWorkspace.id : -1,
              "vrr": monitor.vrr || false,
              "focused": monitor.focused || false,
              // Extended fields for the Monitors settings tab (resolution/Hz/rotation/mirror).
              "make": monitor.make || "",
              "model": monitor.model || "",
              "description": monitor.description || "",
              "transform": monitor.transform || 0,
              "disabled": monitor.disabled || false,
              "mirrorOf": monitor.mirrorOf || "none",
              "availableModes": monitor.availableModes || [],
              // Physical size in mm, for DPI-based auto-scaling (Phase 2).
              "physicalWidth": monitor.physicalWidth || 0,
              "physicalHeight": monitor.physicalHeight || 0
            };
          }
        }

        // Notify CompositorService (it will emit displayScalesChanged)
        if (CompositorService && CompositorService.onDisplayScalesUpdated) {
          CompositorService.onDisplayScalesUpdated(scales);
        }
      } catch (e) {
        Logger.e("HyprlandService", "Failed to parse monitors:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  // Hyprland can apply + persist monitor layout (via the ryoku-monitor helper), so the
  // facade reports this backend as capable and the Display tab shows the controls.
  property bool monitorConfigSupported: true

  // Translate a compositor-neutral monitor config into a Hyprland `monitor=` spec.
  function buildMonitorSpec(cfg) {
    if (!cfg.enabled)
      return cfg.name + ", disable";
    var spec = cfg.name + ", " + cfg.width + "x" + cfg.height + "@" + cfg.refreshRate + ", " + cfg.x + "x" + cfg.y + ", " + cfg.scale;
    if (cfg.transform && cfg.transform !== 0)
      spec += ", transform, " + cfg.transform;
    if (cfg.vrr)
      spec += ", vrr, 1";
    if (cfg.mirror && cfg.mirror !== "none")
      spec += ", mirror, " + cfg.mirror;
    return spec;
  }

  // Apply a monitor config live (session-only preview). Persistence is deferred so the
  // Display panel can confirm-or-revert first. ryoku-monitor owns the hyprctl call and
  // the last-active-output backstop.
  function applyMonitorConfig(cfg) {
    monitorApplyProcess.command = ["ryoku-monitor", "apply", buildMonitorSpec(cfg)];
    monitorApplyProcess.running = true;
  }

  // Captures the apply result so the Display panel can surface a rejected change (bad
  // mode, refused last-output disable) instead of silently arming the confirm dialog
  // over a screen that never changed.
  Process {
    id: monitorApplyProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function (code) {
      const err = String(stderr.text || "").trim();
      root.monitorApplyFinished(code === 0, err);
    }
  }

  // Persist the current live layout via ryoku-monitor (monitors.lua / monitors.conf) + GDK_SCALE sync.
  function persistMonitors() {
    Quickshell.execDetached(["ryoku-monitor", "persist"]);
  }

  // Dispatch mode probe
  // This Process detects whether hyprland is using legacy
  // hyprlang dispatch or the new Lua-based dispatch system
  // (Hyprland v0.55+)
  //
  // This runs a harmless dispatcher shown in the docs:
  // hl.dsp.no_op()
  // If it returns "ok", Lua dispatch is supported.
  Process {
    id: dispatchProbeProcess

    running: false
    command: ["hyprctl", "dispatch", "hl.dsp.no_op()"]

    // Accumulate stdout/stderr because SplitParser delivers line-by-line
    property string accumulatedOutput: ""
    property string accumulatedError: ""

    stdout: SplitParser {
      onRead: function (line) {
        dispatchProbeProcess.accumulatedOutput += line;
      }
    }

    stderr: SplitParser {
      onRead: function (line) {
        dispatchProbeProcess.accumulatedError += line;
      }
    }

    onExited: function (exitCode) {
      const stdout = String(accumulatedOutput || "").trim();
      const stderr = String(accumulatedError || "").trim();

      // If Lua dispatch is supported, Hyprland returns "ok"
      const lowerErr = stderr.toLowerCase();
      useLuaDispatch = stdout.indexOf("ok") !== -1 && lowerErr.indexOf("error") === -1;

      dispatchModeChecked = true;

      Logger.i("HyprlandService", useLuaDispatch ? "Detected Lua hyprctl dispatch syntax" : "Using legacy hyprctl dispatch syntax");

      if (stdout.length > 0) {
        Logger.d("HyprlandService", "Dispatch probe stdout:", stdout);
      }

      if (stderr.length > 0) {
        Logger.d("HyprlandService", "Dispatch probe stderr:", stderr);
      }

      accumulatedOutput = "";
      accumulatedError = "";
    }
  }

  function queryKeyboardLayout() {
    hyprlandDevicesProcess.running = true;
  }
  Process {
    id: hyprlandDevicesProcess
    running: false
    command: ["hyprctl", "devices", "-j"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        hyprlandDevicesProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandService", "Failed to query devices, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const devicesData = JSON.parse(accumulatedOutput);
        for (const keyboard of devicesData.keyboards) {
          if (keyboard.main) {
            const layoutName = keyboard.active_keymap;
            KeyboardLayoutService.setCurrentLayout(layoutName);
            Logger.d("HyprlandService", "Keyboard layout switched:", layoutName);
          }
        }
      } catch (e) {
        Logger.e("HyprlandService", "Failed to parse devices:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  function safeUpdate() {
    safeUpdateWindows();
    safeUpdateWorkspaces();
    workspaceChanged();
    windowListChanged();
  }

  function safeUpdateWorkspaces() {
    try {
      workspaces.clear();
      workspaceCache = {};

      if (!Hyprland.workspaces || !Hyprland.workspaces.values) {
        return;
      }

      const hlWorkspaces = Hyprland.workspaces.values;
      const occupiedIds = getOccupiedWorkspaceIds();

      for (var i = 0; i < hlWorkspaces.length; i++) {
        const ws = hlWorkspaces[i];
        if (ws.name && ws.name.startsWith("special:"))
          continue;

        const wsData = {
          "id": ws.id,
          "idx": ws.id,
          "name": ws.name || "",
          "output": (ws.monitor && ws.monitor.name) ? ws.monitor.name : "",
          "isActive": ws.active === true,
          "isFocused": ws.focused === true,
          "isUrgent": ws.urgent === true,
          "isOccupied": occupiedIds[ws.id] === true
        };

        workspaceCache[ws.id] = wsData;
        workspaces.append(wsData);
      }
    } catch (e) {
      Logger.e("HyprlandService", "Error updating workspaces:", e);
    }
  }

  function getOccupiedWorkspaceIds() {
    const occupiedIds = {};

    try {
      if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
        return occupiedIds;
      }

      const hlToplevels = Hyprland.toplevels.values;
      for (var i = 0; i < hlToplevels.length; i++) {
        const toplevel = hlToplevels[i];
        if (!toplevel)
          continue;
        try {
          const wsId = toplevel.workspace ? toplevel.workspace.id : null;
          if (wsId !== null && wsId !== undefined) {
            occupiedIds[wsId] = true;
          }
        } catch (e)

          // Ignore individual toplevel errors
        {}
      }
    } catch (e)

      // Return empty if we can't determine occupancy
    {}

    return occupiedIds;
  }

  function safeUpdateWindows() {
    try {
      const windowsList = [];
      windowCache = {};

      if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
        windows = [];
        focusedWindowIndex = -1;
        return;
      }

      const hlToplevels = Hyprland.toplevels.values;
      let focusedWindowId = null;

      const activeWorkspaceIds = {};
      if (Hyprland.workspaces && Hyprland.workspaces.values) {
        const hlWorkspaces = Hyprland.workspaces.values;
        for (var j = 0; j < hlWorkspaces.length; j++) {
          if (hlWorkspaces[j].active) {
            activeWorkspaceIds[hlWorkspaces[j].id] = true;
          }
        }
      }

      for (var i = 0; i < hlToplevels.length; i++) {
        const toplevel = hlToplevels[i];
        if (!toplevel)
          continue;
        const windowData = extractWindowData(toplevel);
        if (windowData) {
          // If the window claims to be focused, verify it's on an active workspace
          if (windowData.isFocused) {
            if (!activeWorkspaceIds[windowData.workspaceId]) {
              windowData.isFocused = false;
            }
          }

          // Normalize to a plain, backend-independent window object
          const normalized = {
            "id": windowData.id ? String(windowData.id) : "",
            "title": windowData.title ? String(windowData.title) : "",
            "appId": windowData.appId ? String(windowData.appId) : "",
            "workspaceId": (typeof windowData.workspaceId === "number" && !isNaN(windowData.workspaceId)) ? windowData.workspaceId : -1,
            "isFocused": windowData.isFocused === true,
            "output": windowData.output ? String(windowData.output) : "",
            "x": (typeof windowData.x === "number" && !isNaN(windowData.x)) ? windowData.x : 0,
            "y": (typeof windowData.y === "number" && !isNaN(windowData.y)) ? windowData.y : 0
          };

          windowsList.push(normalized);
          windowCache[normalized.id] = normalized;

          if (normalized.isFocused) {
            focusedWindowId = normalized.id;
          }
        }
      }

      windows = toSortedWindowList(windowsList);

      // Resolve focused index from sorted list (order changes after sort)
      let newFocusedIndex = -1;
      if (focusedWindowId) {
        for (let k = 0; k < windows.length; k++) {
          if (windows[k].id === focusedWindowId) {
            newFocusedIndex = k;
            break;
          }
        }
      }

      if (newFocusedIndex !== focusedWindowIndex) {
        focusedWindowIndex = newFocusedIndex;
        activeWindowChanged();
      }
    } catch (e) {
      Logger.e("HyprlandService", "Error updating windows:", e);
    }
  }

  function extractWindowData(toplevel) {
    if (!toplevel)
      return null;

    try {
      const windowId = safeGetProperty(toplevel, "address", "");
      if (!windowId)
        return null;

      const appId = getAppId(toplevel);
      const title = getAppTitle(toplevel);
      const wsId = toplevel.workspace ? toplevel.workspace.id : null;
      const focused = toplevel.activated === true;
      const output = toplevel.monitor?.name || "";

      let x = 0;
      let y = 0;
      try {
        const ipcData = toplevel.lastIpcObject;
        if (ipcData && ipcData.at) {
          x = ipcData.at[0];
          y = ipcData.at[1];
        } else if (typeof toplevel.x !== 'undefined') {
          x = toplevel.x;
          y = toplevel.y;
        }
      } catch (e) {}

      const safeX = (typeof x === "number" && !isNaN(x)) ? x : 0;
      const safeY = (typeof y === "number" && !isNaN(y)) ? y : 0;

      return {
        "id": windowId,
        "title": title,
        "appId": appId,
        "workspaceId": wsId || -1,
        "isFocused": focused,
        "output": output,
        "x": safeX,
        "y": safeY
      };
    } catch (e) {
      return null;
    }
  }

  function toSortedWindowList(windowList) {
    return windowList.sort((a, b) => {
                             // Sort by workspace first (just in case they are mixed)
                             if (a.workspaceId !== b.workspaceId) {
                               return a.workspaceId - b.workspaceId;
                             }
                             // Then sort by X position (left to right)
                             if (a.x !== b.x) {
                               return a.x - b.x;
                             }
                             // Then sort by Y position (top to bottom)
                             if (a.y !== b.y) {
                               return a.y - b.y;
                             }
                             // Fallback to Window ID mapping
                             return a.id.localeCompare(b.id);
                           });
  }

  function getAppTitle(toplevel) {
    try {
      var title = toplevel.wayland.title;
      if (title)
        return title;
    } catch (e) {}

    return safeGetProperty(toplevel, "title", "");
  }

  function getAppId(toplevel) {
    if (!toplevel)
      return "";

    var appId = "";

    // Try the wayland object first!
    // From my (Lemmy) testing it works fine so we could probably get rid of all the other attempts below.
    // Leaving them in for now, just in case...
    try {
      appId = toplevel.wayland.appId;
      if (appId)
        return appId;
    } catch (e) {}

    // Try direct properties
    appId = safeGetProperty(toplevel, "class", "");
    if (appId)
      return appId;

    appId = safeGetProperty(toplevel, "initialClass", "");
    if (appId)
      return appId;

    appId = safeGetProperty(toplevel, "appId", "");
    if (appId)
      return appId;

    // Try lastIpcObject
    try {
      const ipcData = toplevel.lastIpcObject;
      if (ipcData) {
        return String(ipcData.class || ipcData.initialClass || ipcData.appId || ipcData.wm_class || "");
      }
    } catch (e) {}

    return "";
  }

  function safeGetProperty(obj, prop, defaultValue) {
    try {
      const value = obj[prop];
      if (value !== undefined && value !== null) {
        return String(value);
      }
    } catch (e)

      // Property access failed
    {}
    return defaultValue;
  }

  function handleActiveLayoutEvent(ev) {
    try {
      let beforeParenthesis;
      const parenthesisPos = ev.lastIndexOf('(');

      if (parenthesisPos === -1) {
        beforeParenthesis = ev;
      } else {
        beforeParenthesis = ev.substring(0, parenthesisPos);
      }

      const layoutNameStart = beforeParenthesis.lastIndexOf(',') + 1;
      const layoutName = ev.substring(layoutNameStart);

      // Ignore bogus "error" layout reported by virtual keyboards (e.g. wtype)
      if (layoutName.toLowerCase() === "error") {
        Logger.d("HyprlandService", "Ignoring bogus 'error' layout from activelayout event");
        return;
      }

      KeyboardLayoutService.setCurrentLayout(layoutName);
      Logger.d("HyprlandService", "Keyboard layout switched:", layoutName);
    } catch (e) {
      Logger.e("HyprlandService", "Error handling activelayout:", e);
    }
  }

  Connections {
    target: Hyprland.workspaces
    enabled: initialized
    function onValuesChanged() {
      Qt.callLater(_deferredWorkspaceUpdate);
    }
  }

  Connections {
    target: Hyprland.toplevels
    enabled: initialized
    function onValuesChanged() {
      updateTimer.restart();
    }
  }

  Connections {
    target: Hyprland
    enabled: initialized
    function onRawEvent(event) {
      Hyprland.refreshWorkspaces();
      Hyprland.refreshToplevels();
      // Workspace and window updates are deferred — refreshWorkspaces()/
      // refreshToplevels() trigger onValuesChanged which also calls
      // Qt.callLater, so the deduplication coalesces into one update.
      Qt.callLater(_deferredWorkspaceUpdate);
      updateTimer.restart();

      const monitorsEvents = ["configreloaded", "monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2"];

      if (monitorsEvents.includes(event.name)) {
        Qt.callLater(queryDisplayScales);
      }

      if (event.name == "activelayout") {
        handleActiveLayoutEvent(event.data);
      }
    }
  }

  function luaQuote(str) {
    return String(str).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r");
  }

  function detectDispatchMode() {
    if (dispatchModeChecked || dispatchProbeProcess.running) {
      return;
    }

    Logger.i("HyprlandService", "Checking hyprctl dispatch syntax");
    dispatchProbeProcess.running = true;
  }

  function dispatchCommand(legacyDispatcher, legacyArgs, luaCommand) {
    try {
      // Ensure dispatch mode is known before sending commands.
      if (!dispatchModeChecked) {
        Logger.w("HyprlandService", "Dispatch mode not detected yet, using legacy syntax");
      }
      const legacyFull = legacyArgs ? `${legacyDispatcher} ${legacyArgs}` : legacyDispatcher;

      if (useLuaDispatch) {
        Logger.d("HyprlandService", "Dispatch (Lua):", luaCommand);

        Quickshell.execDetached(["hyprctl", "dispatch", luaCommand]);
      } else {
        Logger.d("HyprlandService", "Dispatch (Legacy):", legacyFull);

        Hyprland.dispatch(legacyFull);
      }
    } catch (e) {
      Logger.e("HyprlandService", "Dispatch failed:", legacyDispatcher, legacyArgs, e);
    }
  }

  function switchToWorkspace(workspace) {
    try {
      if (workspace.name) {
        dispatchCommand("workspace", workspace.name, `hl.dsp.focus({ workspace = "${luaQuote(workspace.name)}" })`);
        return;
      }

      dispatchCommand("workspace", workspace.idx, `hl.dsp.focus({ workspace = ${workspace.idx} })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to switch workspace:", e);
    }
  }

  function focusWindow(window) {
    try {
      if (!window || !window.id) {
        Logger.w("HyprlandService", "Invalid window object for focus");
        return;
      }

      const windowId = window.id.toString();
      const addr = `address:0x${windowId}`;

      dispatchCommand("focuswindow", addr, `hl.dsp.focus({ window = "${luaQuote(addr)}" })`);

      dispatchCommand("alterzorder", `top,${addr}`, `hl.dsp.window.alter_zorder({ mode = "top", window = "${luaQuote(addr)}" })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to switch window:", e);
    }
  }

  function closeWindow(window) {
    try {
      const addr = `address:0x${window.id}`;

      dispatchCommand("killwindow", addr, `hl.dsp.window.close("${luaQuote(addr)}")`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to close window:", e);
    }
  }

  function turnOffMonitors() {
    try {
      dispatchCommand("dpms", "off", `hl.dsp.dpms({ action = "off" })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to turn off monitors:", e);
    }
  }

  function turnOnMonitors() {
    try {
      dispatchCommand("dpms", "on", `hl.dsp.dpms({ action = "on" })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to turn on monitors:", e);
    }
  }

  function logout() {
    try {
      dispatchCommand("exit", "", "hl.dsp.exit()");
    } catch (e) {
      Logger.e("HyprlandService", "Failed to logout:", e);
    }
  }

  function cycleKeyboardLayout() {
    try {
      Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to cycle keyboard layout:", e);
    }
  }
  function getFocusedScreen() {
    const hyprMon = Hyprland.focusedMonitor;
    if (hyprMon) {
      const monitorName = hyprMon.name;
      for (let i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name === monitorName) {
          return Quickshell.screens[i];
        }
      }
    }
    return null;
  }

  function spawn(command) {
    try {
      const cmd = command instanceof Array ? command.join(" ") : String(command);

      dispatchCommand("exec", cmd, `hl.dsp.exec_cmd("${luaQuote(cmd)}")`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to spawn command:", e);
    }
  }
}
