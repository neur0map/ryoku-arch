pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Panels.ControlCenter.Widgets

Singleton {
  id: root

  property var widgets: ({
                           "AirplaneMode": airplaneModeComponent,
                           "Bluetooth": bluetoothComponent,
                           "CustomButton": customButtonComponent,
                           "DarkMode": darkModeComponent,
                           "KeepAwake": keepAwakeComponent,
                           "NightLight": nightLightComponent,
                           "Notifications": notificationsComponent,
                           "PowerProfile": powerProfileComponent,
                           "WiFi": networkComponent,
                           "Network": networkComponent,
                           "PerformanceMode": performanceModeComponent,
                           "WallpaperSelector": wallpaperSelectorComponent
                         })

  property var widgetMetadata: ({
                                  "CustomButton": {
                                    "icon": "heart",
                                    "onClicked": "",
                                    "onRightClicked": "",
                                    "onMiddleClicked": "",
                                    "stateChecksJson": "[]",
                                    "generalTooltipText": "",
                                    "enableOnStateLogic": false,
                                    "showExecTooltip": true
                                  }
                                })

  property var cpuIntensiveWidgets: ["SystemStat"]

  property Component airplaneModeComponent: Component {
    AirplaneMode {}
  }
  property Component bluetoothComponent: Component {
    Bluetooth {}
  }
  property Component customButtonComponent: Component {
    CustomButton {}
  }
  property Component darkModeComponent: Component {
    DarkMode {}
  }
  property Component keepAwakeComponent: Component {
    KeepAwake {}
  }
  property Component nightLightComponent: Component {
    NightLight {}
  }
  property Component notificationsComponent: Component {
    Notifications {}
  }
  property Component powerProfileComponent: Component {
    PowerProfile {}
  }
  property Component networkComponent: Component {
    Network {}
  }
  property Component performanceModeComponent: Component {
    PerformanceMode {}
  }
  property Component wallpaperSelectorComponent: Component {
    WallpaperSelector {}
  }

  function init() {
    Logger.i("ControlCenterWidgetRegistry", "Service started");
  }

  function getWidget(id) {
    return widgets[id] || null;
  }

  function hasWidget(id) {
    return id in widgets;
  }

  function getAvailableWidgets() {
    return Object.keys(widgets);
  }

  function widgetHasUserSettings(id) {
    return widgetMetadata[id] !== undefined;
  }


  property var pluginWidgets: ({})
  property var pluginWidgetMetadata: ({})

  function registerPluginWidget(pluginId, component, metadata) {
    if (!pluginId || !component) {
      Logger.e("ControlCenterWidgetRegistry", "Cannot register plugin widget: invalid parameters");
      return false;
    }

    // Add plugin: prefix to avoid conflicts with core widgets
    var widgetId = "plugin:" + pluginId;

    pluginWidgets[widgetId] = component;
    pluginWidgetMetadata[widgetId] = metadata || {};

    // Also add to main widgets object for unified access
    widgets[widgetId] = component;
    widgetMetadata[widgetId] = metadata || {};

    Logger.i("ControlCenterWidgetRegistry", "Registered plugin widget:", widgetId);
    return true;
  }

  function unregisterPluginWidget(pluginId) {
    var widgetId = "plugin:" + pluginId;

    if (!pluginWidgets[widgetId]) {
      Logger.w("ControlCenterWidgetRegistry", "Plugin widget not registered:", widgetId);
      return false;
    }

    delete pluginWidgets[widgetId];
    delete pluginWidgetMetadata[widgetId];
    delete widgets[widgetId];
    delete widgetMetadata[widgetId];

    Logger.i("ControlCenterWidgetRegistry", "Unregistered plugin widget:", widgetId);
    return true;
  }

  function isPluginWidget(id) {
    return id.startsWith("plugin:");
  }

  function getPluginWidgets() {
    return Object.keys(pluginWidgets);
  }

  function isCpuIntensive(id) {
    if (pluginWidgetMetadata[id]?.cpuIntensive)
      return true;
    return cpuIntensiveWidgets.indexOf(id) >= 0;
  }
}
