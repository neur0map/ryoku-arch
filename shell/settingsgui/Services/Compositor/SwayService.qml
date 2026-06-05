import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import qs.settingsgui.Commons
import qs.settingsgui.Services.Keyboard

Item {
  id: root

  // Configurable IPC command name (overridden to "scrollmsg" for Scroll)
  property string msgCommand: "swaymsg"

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  property bool initialized: false

  property var windowWorkspaceMap: ({})

  // Track window usage counts per workspace to handle duplicates
  property var windowUsageCountsPerWorkspace: ({})

  // Debounce timer for updates
  Timer {
    id: updateTimer
    interval: 50
    repeat: false
    onTriggered: safeUpdate()
  }

  function initialize() {
    if (initialized)
      return;
    try {
      I3.refreshWorkspaces();
      Qt.callLater(() => {
                     safeUpdateWorkspaces();
                     queryWindowWorkspaces();
                     queryDisplayScales();
                     queryKeyboardLayout();
                   });
      initialized = true;
      Logger.i("SwayService", "Service started");
    } catch (e) {
      Logger.e("SwayService", "Failed to initialize:", e);
    }
  }

  function queryWindowWorkspaces() {
    swayTreeProcess.running = true;
  }

  Process {
    id: swayTreeProcess
    running: false
    command: [msgCommand, "-t", "get_tree", "-r"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        swayTreeProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("SwayService", "Failed to query tree, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const treeData = JSON.parse(accumulatedOutput);
        const newMap = {};
        const workspaceWindows = {};

        function traverseTree(node, workspaceNum) {
          if (!node)
            return;

          if (node.type === "workspace" && node.num !== undefined) {
            workspaceNum = node.num;
            if (!workspaceWindows[workspaceNum]) {
              workspaceWindows[workspaceNum] = [];
            }
          }

          // If this is a regular or floating container with app_id/class (i.e., a window)
          if ((node.type === "con" || node.type === "floating_con") && (node.app_id || node.window_properties)) {
            const appId = node.app_id || (node.window_properties ? node.window_properties.class : null);
            const title = node.name || "";
            const id = node.id;

            if (appId && workspaceNum !== undefined && workspaceNum >= 0) {
              workspaceWindows[workspaceNum].push({
                                                    appId: appId,
                                                    title: title,
                                                    id: id
                                                  });
            }
          }

          if (node.nodes && node.nodes.length > 0) {
            for (const child of node.nodes) {
              traverseTree(child, workspaceNum);
            }
          }

          if (node.floating_nodes && node.floating_nodes.length > 0) {
            for (const child of node.floating_nodes) {
              traverseTree(child, workspaceNum);
            }
          }
        }

        traverseTree(treeData, -1);

        for (const wsNum in workspaceWindows) {
          const windows = workspaceWindows[wsNum];
          const appTitleCounts = {};

          for (const win of windows) {
            const baseKey = `${win.appId}:${win.title}`;

            if (!appTitleCounts[baseKey]) {
              appTitleCounts[baseKey] = 0;
            }
            const occurrence = appTitleCounts[baseKey];
            appTitleCounts[baseKey]++;

            const uniqueKey = `ws${wsNum}:${baseKey}[${occurrence}]`;
            newMap[uniqueKey] = parseInt(wsNum);

            // Also store by ID if available (most reliable)
            if (win.id) {
              newMap[`id:${win.id}`] = parseInt(wsNum);
            }
          }
        }

        windowWorkspaceMap = newMap;

        Qt.callLater(safeUpdateWindows);
      } catch (e) {
        Logger.e("SwayService", "Failed to parse tree:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  function queryDisplayScales() {
    swayOutputsProcess.running = true;
  }

  Process {
    id: swayOutputsProcess
    running: false
    command: [msgCommand, "-t", "get_outputs", "-r"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        swayOutputsProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("SwayService", "Failed to query outputs, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const outputsData = JSON.parse(accumulatedOutput);
        const scales = {};

        for (const output of outputsData) {
          if (output.name) {
            scales[output.name] = {
              "name": output.name,
              "scale": output.scale || 1.0,
              "width": output.current_mode ? output.current_mode.width : 0,
              "height": output.current_mode ? output.current_mode.height : 0,
              "refresh_rate": output.current_mode ? output.current_mode.refresh : 0,
              "x": output.rect ? output.rect.x : 0,
              "y": output.rect ? output.rect.y : 0,
              "active": output.active || false,
              "focused": output.focused || false,
              "current_workspace": output.current_workspace || ""
            };
          }
        }

        // Notify CompositorService (it will emit displayScalesChanged)
        if (CompositorService && CompositorService.onDisplayScalesUpdated) {
          CompositorService.onDisplayScalesUpdated(scales);
        }
      } catch (e) {
        Logger.e("SwayService", "Failed to parse outputs:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  function queryKeyboardLayout() {
    swayInputsProcess.running = true;
  }
  Process {
    id: swayInputsProcess
    running: false
    command: [msgCommand, "-t", "get_inputs", "-r"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        swayInputsProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("SwayService", "Failed to query inputs, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const inputsData = JSON.parse(accumulatedOutput);
        for (const input of inputsData) {
          if (input.type == "keyboard") {
            const layoutName = input.xkb_active_layout_name;
            KeyboardLayoutService.setCurrentLayout(layoutName);
            Logger.d("SwayService", "Keyboard layout switched:", layoutName);
            break;
          }
        }
      } catch (e) {
        Logger.e("SwayService", "Failed to parse inputs:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  function safeUpdate() {
    queryWindowWorkspaces();
    safeUpdateWorkspaces();
  }

  function safeUpdateWorkspaces() {
    try {
      workspaces.clear();

      if (!I3.workspaces || !I3.workspaces.values) {
        return;
      }

      const hlWorkspaces = I3.workspaces.values;

      for (var i = 0; i < hlWorkspaces.length; i++) {
        const ws = hlWorkspaces[i];
        if (!ws || ws.id < 1)
          continue;
        const wsData = {
          "id": i,
          "idx": ws.num,
          "name": ws.name || "",
          "output": (ws.monitor && ws.monitor.name) ? ws.monitor.name : "",
          "isActive": ws.active === true,
          "isFocused": ws.focused === true,
          "isUrgent": ws.urgent === true,
          "isOccupied": true,
          "handle": ws
        };

        workspaces.append(wsData);
      }
    } catch (e) {
      Logger.e("SwayService", "Error updating workspaces:", e);
    }
  }

  function safeUpdateWindows() {
    try {
      const windowsList = [];

      windowUsageCountsPerWorkspace = {};

      if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values) {
        windows = [];
        focusedWindowIndex = -1;
        windowListChanged();
        return;
      }

      const hlToplevels = ToplevelManager.toplevels.values;
      let newFocusedIndex = -1;

      for (var i = 0; i < hlToplevels.length; i++) {
        const toplevel = hlToplevels[i];
        if (!toplevel)
          continue;
        const windowData = extractWindowData(toplevel);
        if (windowData) {
          windowsList.push(windowData);

          if (windowData.isFocused) {
            newFocusedIndex = windowsList.length - 1;
          }
        }
      }

      windows = windowsList;

      if (newFocusedIndex !== focusedWindowIndex) {
        focusedWindowIndex = newFocusedIndex;
        activeWindowChanged();
      }

      windowListChanged();
    } catch (e) {
      Logger.e("SwayService", "Error updating windows:", e);
    }
  }

  function extractWindowData(toplevel) {
    if (!toplevel)
      return null;

    try {
      const appId = getAppId(toplevel);
      const title = safeGetProperty(toplevel, "title", "");
      const focused = toplevel.activated === true;

      let workspaceId = -1;
      let foundWorkspaceNum = -1;

      const baseKey = `${appId}:${title}`;

      for (var i = 0; i < workspaces.count; i++) {
        const ws = workspaces.get(i);
        if (!ws)
          continue;

        const wsNum = ws.idx;

        if (!windowUsageCountsPerWorkspace[wsNum]) {
          windowUsageCountsPerWorkspace[wsNum] = {};
        }

        if (!windowUsageCountsPerWorkspace[wsNum][baseKey]) {
          windowUsageCountsPerWorkspace[wsNum][baseKey] = 0;
        }

        const occurrence = windowUsageCountsPerWorkspace[wsNum][baseKey];
        const uniqueKey = `ws${wsNum}:${baseKey}[${occurrence}]`;

        if (windowWorkspaceMap[uniqueKey] !== undefined) {
          foundWorkspaceNum = windowWorkspaceMap[uniqueKey];
          workspaceId = ws.id;

          windowUsageCountsPerWorkspace[wsNum][baseKey]++;
          break;
        }
      }

      return {
        "title": title,
        "appId": appId,
        "isFocused": focused,
        "workspaceId": workspaceId,
        "handle": toplevel
      };
    } catch (e) {
      return null;
    }
  }

  function getAppId(toplevel) {
    if (!toplevel)
      return "";

    return toplevel.appId;
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

  function handleInputEvent(ev) {
    try {
      const eventData = JSON.parse(ev);
      if (eventData.change == "xkb_layout" && eventData.input != null) {
        const input = eventData.input;
        if (input.type == "keyboard" && input.xkb_active_layout_name != null) {
          const layoutName = input.xkb_active_layout_name;
          KeyboardLayoutService.setCurrentLayout(layoutName);
          Logger.d("SwayService", "Keyboard layout switched:", layoutName);
        }
      }
    } catch (e) {
      Logger.e("SwayService", "Error handling input event:", e);
    }
  }

  Connections {
    target: I3.workspaces
    enabled: initialized
    function onValuesChanged() {
      safeUpdateWorkspaces();
      workspaceChanged();
    }
  }

  Connections {
    target: ToplevelManager
    enabled: initialized
    function onActiveToplevelChanged() {
      updateTimer.restart();
    }
  }

  // Some programs change title of window dependent on content
  Connections {
    target: ToplevelManager ? ToplevelManager.activeToplevel : null
    enabled: initialized
    function onTitleChanged() {
      updateTimer.restart();
    }
  }

  Connections {
    target: I3
    enabled: initialized
    function onRawEvent(event) {
      safeUpdateWorkspaces();
      workspaceChanged();
      updateTimer.restart();

      if (event.type === "output") {
        Qt.callLater(queryDisplayScales);
      }
    }
  }

  I3IpcListener {
    subscriptions: ["input"]
    onIpcEvent: function (event) {
      handleInputEvent(event.data);
    }
  }

  function switchToWorkspace(workspace) {
    try {
      workspace.handle.activate();
    } catch (e) {
      Logger.e("SwayService", "Failed to switch workspace:", e);
    }
  }

  function focusWindow(window) {
    try {
      window.handle.activate();
    } catch (e) {
      Logger.e("SwayService", "Failed to switch window:", e);
    }
  }

  function closeWindow(window) {
    try {
      window.handle.close();
    } catch (e) {
      Logger.e("SwayService", "Failed to close window:", e);
    }
  }

  function turnOffMonitors() {
    try {
      Quickshell.execDetached([msgCommand, "output", "*", "dpms", "off"]);
    } catch (e) {
      Logger.e("SwayService", "Failed to turn off monitors:", e);
    }
  }

  function turnOnMonitors() {
    try {
      Quickshell.execDetached([msgCommand, "output", "*", "dpms", "on"]);
    } catch (e) {
      Logger.e("SwayService", "Failed to turn on monitors:", e);
    }
  }

  function logout() {
    try {
      Quickshell.execDetached([msgCommand, "exit"]);
    } catch (e) {
      Logger.e("SwayService", "Failed to logout:", e);
    }
  }

  function cycleKeyboardLayout() {
    try {
      Quickshell.execDetached([msgCommand, "input", "type:keyboard", "xkb_switch_layout", "next"]);
    } catch (e) {
      Logger.e("SwayService", "Failed to cycle keyboard layout:", e);
    }
  }

  function getFocusedScreen() {
    // de-activated until proper testing
    return null;

    // const i3Mon = I3.focusedMonitor;
    // if (i3Mon) {
    //   const monitorName = i3Mon.name;
    //   for (let i = 0; i < Quickshell.screens.length; i++) {
    //     if (Quickshell.screens[i].name === monitorName) {
    //       return Quickshell.screens[i];
    //     }
    //   }
    // }
    // return null;
  }

  function spawn(command) {
    try {
      Quickshell.execDetached([msgCommand, "exec", "--"].concat(command));
    } catch (e) {
      Logger.e("SwayService", "Failed to spawn command:", e);
    }
  }
}
