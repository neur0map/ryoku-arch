pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.UI

Singleton {
  id: root

  property bool isVisible: true

  // Computed visibility that factors in compositor overview state
  readonly property bool effectivelyVisible: {
    if (!isVisible) {
      return false;
    }
    if (Settings.data.bar.hideOnOverview && CompositorService.overviewActive) {
      return false;
    }
    return true;
  }

  property var readyBars: ({})

  // Revision counter - increment when widget list structure changes (add/remove/reorder)
  // This triggers Bar.qml to re-sync its ListModels
  property int widgetsRevision: 0

  // Registry to store actual widget instances
  // Key format: "screenName|section|widgetId|index"
  property var widgetInstances: ({})

  signal activeWidgetsChanged
  signal barReadyChanged(string screenName)
  signal barAutoHideStateChanged(string screenName, bool hidden)
  signal barHoverStateChanged(string screenName, bool hovered)

  // Track if a popup menu is open from the bar (prevents auto-hide)
  property bool popupOpen: false

  // Auto-hide state per screen: { screenName: { hovered: bool, hidden: bool } }
  property var screenAutoHideState: ({})

  function getOrCreateAutoHideState(screenName) {
    if (!screenAutoHideState[screenName]) {
      screenAutoHideState[screenName] = {
        "hovered": false,
        "hidden": Settings.getBarDisplayModeForScreen(screenName) === "auto_hide"
      };
    }
    return screenAutoHideState[screenName];
  }

  function setScreenHovered(screenName, hovered) {
    var state = getOrCreateAutoHideState(screenName);
    if (state.hovered !== hovered) {
      state.hovered = hovered;
      screenAutoHideState = Object.assign({}, screenAutoHideState);
      barHoverStateChanged(screenName, hovered);
    }
  }

  function setScreenHidden(screenName, hidden) {
    var state = getOrCreateAutoHideState(screenName);
    if (state.hidden !== hidden) {
      state.hidden = hidden;
      screenAutoHideState = Object.assign({}, screenAutoHideState);
      barAutoHideStateChanged(screenName, hidden);
    }
  }

  function isBarHidden(screenName) {
    var state = screenAutoHideState[screenName];
    return state ? state.hidden : false;
  }

  function isBarHovered(screenName) {
    var state = screenAutoHideState[screenName];
    return state ? state.hovered : false;
  }

  // Toggle bar visibility. In auto-hide mode, toggles the per-screen hidden
  // state without touching isVisible (so hover-to-show still works).
  // For non-auto-hide screens, toggles the global isVisible flag.
  function toggleVisibility() {
    var anyAutoHideVisible = false;
    var hasAutoHideScreens = false;
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        hasAutoHideScreens = true;
        if (!screenAutoHideState[screenName].hidden) {
          anyAutoHideVisible = true;
          break;
        }
      }
    }

    if (hasAutoHideScreens) {
      for (var screenName in screenAutoHideState) {
        if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
          setScreenHidden(screenName, anyAutoHideVisible);
        }
      }
    }

    // Only toggle global visibility when no auto-hide screens exist,
    // otherwise it would permanently disable hover-to-show
    if (!hasAutoHideScreens) {
      isVisible = !isVisible;
    }
  }

  // Show bar. In auto-hide mode, un-hides on screens with auto-hide enabled.
  // The bar stays visible until the user hovers and moves away.
  function show() {
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        setScreenHidden(screenName, false);
      }
    }
    isVisible = true;
  }

  // Hide bar. In auto-hide mode, sets per-screen hidden state without touching
  // isVisible so hover-to-show still works. For non-auto-hide screens, sets
  // global visibility to false.
  function hide() {
    var hasAutoHideScreens = false;
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        setScreenHidden(screenName, true);
        hasAutoHideScreens = true;
      }
    }
    // Only set global visibility off when no auto-hide screens exist,
    // otherwise it would permanently disable hover-to-show
    if (!hasAutoHideScreens) {
      isVisible = false;
    }
  }

  // Temporarily show the bar, then auto-hide after the configured delay.
  // Uses the same pattern as workspace switch: show, then emit unhover
  // to start the hide timer.
  function peek() {
    for (var screenName in screenAutoHideState) {
      if (Settings.getBarDisplayModeForScreen(screenName) === "auto_hide") {
        setScreenHidden(screenName, false);
        if (!isBarHovered(screenName)) {
          barHoverStateChanged(screenName, false);
        }
      }
    }
  }

  Component.onCompleted: {
    Logger.i("BarService", "Service started");
  }

  // Bump widgetsRevision when settings are reloaded from an external file change
  // so Bar.qml re-syncs its widget ListModels with the updated widget configuration
  Connections {
    target: Settings
    function onSettingsReloaded() {
      Logger.d("BarService", "Settings reloaded externally, bumping widgetsRevision");
      root.widgetsRevision++;
    }
  }

  Connections {
    target: Settings.data.bar
    function onDisplayModeChanged() {
      Logger.d("BarService", "Display mode changed to:", Settings.data.bar.displayMode);

      for (let screenName in screenAutoHideState) {
        if (!Settings.hasScreenOverride(screenName, "displayMode")) {
          var displayMode = Settings.getBarDisplayModeForScreen(screenName);
          if (displayMode === "auto_hide") {
            setScreenHidden(screenName, true);
          } else {
            if (screenAutoHideState[screenName].hidden) {
              setScreenHidden(screenName, false);
            }
          }
        }
      }
    }

    function onScreenOverridesChanged() {
      Logger.d("BarService", "Screen overrides changed, re-evaluating auto-hide states");

      for (let screenName in screenAutoHideState) {
        var displayMode = Settings.getBarDisplayModeForScreen(screenName);
        if (displayMode === "auto_hide") {
          if (!screenAutoHideState[screenName].hidden) {
            setScreenHidden(screenName, true);
          }
        } else {
          if (screenAutoHideState[screenName].hidden) {
            setScreenHidden(screenName, false);
          }
        }
      }
    }
  }

  property var lastWorkspaceId: null

  // Debounce rapid workspace switches to reduce load/unload races (SIGSEGV in QV4)
  property string _pendingWorkspaceScreen: ""

  Timer {
    id: workspaceDebounceTimer
    interval: 80
    repeat: false
    onTriggered: {
      var screen = root._pendingWorkspaceScreen;
      root._pendingWorkspaceScreen = "";
      if (screen) {
        setScreenHidden(screen, false);
        if (!root.isBarHovered(screen)) {
          barHoverStateChanged(screen, false);
        }
      }
    }
  }

  Connections {
    target: CompositorService
    function onWorkspaceChanged() {
      if (!Settings.data.bar.showOnWorkspaceSwitch)
        return;
      if (Settings.data.bar.displayMode !== "auto_hide")
        return;

      var ws = CompositorService.getCurrentWorkspace();
      if (!ws || !ws.output) {
        return;
      }

      var currentWsId = ws.id;
      if (currentWsId === root.lastWorkspaceId) {
        return;
      }
      root.lastWorkspaceId = currentWsId;

      var screenName = ws.output || "";
      Logger.d("BarService", "Workspace switched to:", currentWsId, "on screen:", screenName);

      // Debounce: rapid switches (e.g. external monitor ↔ laptop) cause overlapping
      // bar load/unload; 80ms delay coalesces them and reduces QV4 incubation races
      root._pendingWorkspaceScreen = screenName;
      workspaceDebounceTimer.restart();
    }
  }

  function registerBar(screenName) {
    if (!readyBars[screenName]) {
      readyBars[screenName] = true;
      Logger.d("BarService", "Bar is ready on screen:", screenName);
      barReadyChanged(screenName);
    }
  }

  function isBarReady(screenName) {
    return readyBars[screenName] || false;
  }

  function registerWidget(screenName, section, widgetId, index, instance) {
    const key = [screenName, section, widgetId, index].join("|");
    widgetInstances[key] = {
      "key": key,
      "screenName": screenName,
      "section": section,
      "widgetId": widgetId,
      "index": index,
      "instance": instance
    };

    Logger.d("BarService", "Registered widget:", key);
    root.activeWidgetsChanged();
  }

  function unregisterWidget(screenName, section, widgetId, index) {
    const key = [screenName, section, widgetId, index].join("|");
    delete widgetInstances[key];
    Logger.d("BarService", "Unregistered widget:", key);
    root.activeWidgetsChanged();
  }

  function lookupWidget(widgetId, screenName = null, section = null, index = null) {
    if (screenName && section !== null) {
      for (var key in widgetInstances) {
        var widget = widgetInstances[key];
        if (!widget)
          continue;
        if (widget.widgetId === widgetId && widget.screenName === screenName && widget.section === section) {
          if (index === null) {
            return widget.instance;
          } else if (widget.index == index) {
            return widget.instance;
          }
        }
      }
    }

    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.widgetId === widgetId) {
        if (!screenName || widget.screenName === screenName) {
          if (section === null || widget.section === section) {
            return widget.instance;
          }
        }
      }
    }

    return undefined;
  }

  function getAllWidgetInstances(widgetId = null, screenName = null, section = null) {
    var instances = [];

    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;

      var matches = true;
      if (widgetId && widget.widgetId !== widgetId)
        matches = false;
      if (screenName && widget.screenName !== screenName)
        matches = false;
      if (section !== null && widget.section !== section)
        matches = false;

      if (matches) {
        instances.push(widget.instance);
      }
    }

    return instances;
  }

  function getWidgetWithMetadata(widgetId, screenName = null, section = null) {
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.widgetId === widgetId) {
        if (!screenName || widget.screenName === screenName) {
          if (section === null || widget.section === section) {
            return widget;
          }
        }
      }
    }
    return undefined;
  }

  function getWidgetsBySection(section, screenName = null) {
    var widgetEntries = [];

    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.section === section) {
        if (!screenName || widget.screenName === screenName) {
          widgetEntries.push(widget);
        }
      }
    }

    // Sort by index to maintain order
    widgetEntries.sort(function (a, b) {
      return (a.index || 0) - (b.index || 0);
    });

    // Return just the instances
    return widgetEntries.map(function (w) {
      return w.instance;
    });
  }

  // Get all registered widgets (for debugging)
  function getAllRegisteredWidgets() {
    var result = [];
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      result.push({
                    "key": key,
                    "widgetId": widget.widgetId,
                    "section": widget.section,
                    "screenName": widget.screenName,
                    "index": widget.index
                  });
    }
    return result;
  }

  // Check if a widget type exists in a section
  function hasWidget(widgetId, section = null, screenName = null) {
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (!widget)
        continue;
      if (widget.widgetId === widgetId) {
        if (section === null || widget.section === section) {
          if (!screenName || widget.screenName === screenName) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Unregister all widget instances for a plugin (used during hot reload)
  // Note: We don't destroy instances here - the Loader manages that when the component is unregistered
  function destroyPluginWidgetInstances(pluginId) {
    var widgetId = "plugin:" + pluginId;
    var keysToRemove = [];

    // Find all instances of this plugin's widget
    for (var key in widgetInstances) {
      var widget = widgetInstances[key];
      if (widget && widget.widgetId === widgetId) {
        keysToRemove.push(key);
        Logger.d("BarService", "Unregistering plugin widget instance:", key);
      }
    }

    // Remove from registry
    for (var i = 0; i < keysToRemove.length; i++) {
      delete widgetInstances[keysToRemove[i]];
    }

    if (keysToRemove.length > 0) {
      Logger.i("BarService", "Unregistered", keysToRemove.length, "instance(s) of plugin widget:", widgetId);
      root.activeWidgetsChanged();
    }
  }

  // Get pill direction for a widget instance
  function getPillDirection(widgetInstance) {
    try {
      if (widgetInstance.section === "left") {
        return false;
      } else if (widgetInstance.section === "right") {
        return true;
      } else {
        // middle section
        if (widgetInstance.sectionWidgetIndex < widgetInstance.sectionWidgetsCount / 2) {
          return true;
        } else {
          return false;
        }
      }
    } catch (e) {
      Logger.e(e);
    }
    return true;
  }

  function getTooltipDirection(screenName) {
    const position = Settings.getBarPositionForScreen(screenName);
    switch (position) {
    case "right":
      return "left";
    case "left":
      return "right";
    case "bottom":
      return "top";
    default:
      return "bottom";
    }
  }

  // Helper to close any existing dialogs in a popup menu window
  function closeExistingDialogs(popupMenuWindow) {
    if (!popupMenuWindow || !popupMenuWindow.dialogParent)
      return;

    var dialogParent = popupMenuWindow.dialogParent;
    for (var i = dialogParent.children.length - 1; i >= 0; i--) {
      var child = dialogParent.children[i];
      if (child && typeof child.close === "function") {
        child.close();
      }
    }
    popupMenuWindow.hasDialog = false;
  }

  // Open widget settings dialog for a bar widget
  // Parameters:
  //   screen: The screen to show the dialog on
  //   section: Section id ("left", "center", "right")
  //   index: Widget index in section
  //   widgetId: Widget type id (e.g., "Volume")
  //   widgetData: Current widget settings object
  function openWidgetSettings(screen, section, index, widgetId, widgetData) {
    // Get the popup menu window to use as parent (avoids clipping issues with bar height)
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (!popupMenuWindow) {
      Logger.e("BarService", "No popup menu window found for screen");
      return;
    }

    // Close any existing dialogs first to prevent stacking
    closeExistingDialogs(popupMenuWindow);

    if (PanelService.openedPanel) {
      PanelService.openedPanel.close();
    }

    var component = Qt.createComponent(Quickshell.shellDir + "/settingsgui" + "/Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml");

    function instantiateAndOpen() {
      // Use dialogParent (Item) instead of window directly for proper Popup anchoring
      var dialog = component.createObject(popupMenuWindow.dialogParent, {
                                            "widgetIndex": index,
                                            "widgetData": widgetData,
                                            "widgetId": widgetId,
                                            "sectionId": section,
                                            "screen": screen
                                          });

      if (dialog) {
        dialog.updateWidgetSettings.connect((sec, idx, settings) => {
                                              var screenName = screen?.name || "";
                                              if (Settings.hasScreenOverride(screenName, "widgets")) {
                                                var overrideWidgets = Settings.getBarWidgetsForScreen(screenName);
                                                if (overrideWidgets && overrideWidgets[sec] && idx < overrideWidgets[sec].length) {
                                                  overrideWidgets[sec][idx] = Object.assign({}, overrideWidgets[sec][idx], settings);
                                                  Settings.setScreenOverride(screenName, "widgets", overrideWidgets);
                                                }
                                              } else {
                                                var widgets = Settings.data.bar.widgets[sec];
                                                if (widgets && idx < widgets.length) {
                                                  widgets[idx] = Object.assign({}, widgets[idx], settings);
                                                  Settings.data.bar.widgets[sec] = widgets;
                                                  Settings.saveImmediate();
                                                }
                                              }
                                            });
        // Enable keyboard focus for the popup menu window when dialog is open
        popupMenuWindow.hasDialog = true;
        // Close the popup menu window when dialog closes
        dialog.closed.connect(() => {
                                popupMenuWindow.hasDialog = false;
                                popupMenuWindow.close();
                                dialog.destroy();
                              });
        // Show the popup menu window and open the dialog
        popupMenuWindow.open();
        dialog.open();
      } else {
        Logger.e("BarService", "Failed to create widget settings dialog");
      }
    }

    if (component.status === Component.Ready) {
      instantiateAndOpen();
    } else if (component.status === Component.Error) {
      Logger.e("BarService", "Error loading widget settings dialog:", component.errorString());
    } else {
      component.statusChanged.connect(function () {
        if (component.status === Component.Ready) {
          instantiateAndOpen();
        } else if (component.status === Component.Error) {
          Logger.e("BarService", "Error loading widget settings dialog:", component.errorString());
        }
      });
    }
  }

  // Open plugin settings dialog
  // Parameters:
  //   screen: The screen to show the dialog on
  //   pluginManifest: The plugin's manifest object (must have entryPoints.settings)
  function openPluginSettings(screen, pluginManifest) {
    if (!pluginManifest || !pluginManifest.entryPoints || !pluginManifest.entryPoints.settings) {
      Logger.e("BarService", "Cannot open plugin settings: no settings entry point");
      return;
    }

    // Get the popup menu window to use as parent
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (!popupMenuWindow) {
      Logger.e("BarService", "No popup menu window found for screen");
      return;
    }

    // Close any existing dialogs first to prevent stacking
    closeExistingDialogs(popupMenuWindow);

    var component = Qt.createComponent(Quickshell.shellDir + "/settingsgui" + "/Widgets/NPluginSettingsPopup.qml");

    function instantiateAndOpen() {
      var dialog = component.createObject(popupMenuWindow.dialogParent, {
                                            "showToastOnSave": true,
                                            "screen": screen
                                          });

      if (dialog) {
        // Enable keyboard focus for the popup menu window when dialog is open
        popupMenuWindow.hasDialog = true;
        // Close the popup menu window when dialog closes
        dialog.closed.connect(() => {
                                popupMenuWindow.hasDialog = false;
                                popupMenuWindow.close();
                                dialog.destroy();
                              });
        // Show the popup menu window and open the dialog
        popupMenuWindow.open();
        dialog.openPluginSettings(pluginManifest);
      } else {
        Logger.e("BarService", "Failed to create plugin settings dialog");
      }
    }

    if (component.status === Component.Ready) {
      instantiateAndOpen();
    } else if (component.status === Component.Error) {
      Logger.e("BarService", "Error loading plugin settings dialog:", component.errorString());
    } else {
      component.statusChanged.connect(function () {
        if (component.status === Component.Ready) {
          instantiateAndOpen();
        } else if (component.status === Component.Error) {
          Logger.e("BarService", "Error loading plugin settings dialog:", component.errorString());
        }
      });
    }
  }
}
