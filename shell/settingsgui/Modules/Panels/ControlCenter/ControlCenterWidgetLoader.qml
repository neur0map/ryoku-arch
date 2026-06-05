import QtQuick
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.UI

Item {
  id: root

  required property string widgetId
  required property var widgetScreen
  required property var widgetProps

  property string section: widgetProps && widgetProps.section || ""
  property int sectionIndex: widgetProps && widgetProps.sectionWidgetIndex || 0

  // Don't reserve space unless the loaded widget is really visible
  implicitWidth: getImplicitSize(loader.item, "implicitWidth")
  implicitHeight: getImplicitSize(loader.item, "implicitHeight")

  function getImplicitSize(item, prop) {
    return (item && item.visible) ? item[prop] : 0;
  }

  readonly property bool _isPlugin: ControlCenterWidgetRegistry.isPluginWidget(widgetId)

  function _loadPluginWidget() {
    var comp = ControlCenterWidgetRegistry.getWidget(widgetId);
    if (!comp)
      return;
    var pluginId = widgetId.substring(7);
    var api = PluginService.getPluginAPI(pluginId);
    loader.setSource(comp.url, api ? {
                                       "pluginApi": api
                                     } : {});
  }

  Loader {
    id: loader
    anchors.fill: parent
    asynchronous: false

    // Core widgets use sourceComponent; plugin widgets use setSource()
    // so pluginApi is available from the first binding evaluation.
    Component.onCompleted: {
      if (root._isPlugin) {
        root._loadPluginWidget();
      } else {
        sourceComponent = Qt.binding(function () {
          return ControlCenterWidgetRegistry.getWidget(widgetId);
        });
      }
    }

    onLoaded: {
      if (!item)
        return;

      for (var prop in widgetProps) {
        if (item.hasOwnProperty(prop)) {
          item[prop] = widgetProps[prop];
        }
      }

      if (item.hasOwnProperty("screen")) {
        item.screen = widgetScreen;
      }

      // Call custom onLoaded if it exists
      if (item.hasOwnProperty("onLoaded")) {
        item.onLoaded();
      }
    }

    Component.onDestruction: {
      widgetProps = null;
    }
  }

  Component.onCompleted: {
    if (!ControlCenterWidgetRegistry.hasWidget(widgetId)) {
      Logger.w("ControlCenterWidgetLoader", "Widget not found in registry:", widgetId);
      // Retry briefly in case the registry initializes after this component
      retryTimer.start();
    }
  }

  // Retry mechanism to cope with early evaluation before registry is ready
  Timer {
    id: retryTimer
    interval: 150
    repeat: true
    running: false
    property int attempts: 0
    onTriggered: {
      attempts += 1;
      if (ControlCenterWidgetRegistry.hasWidget(widgetId)) {
        loader.sourceComponent = ControlCenterWidgetRegistry.getWidget(widgetId);
        stop();
        attempts = 0;
        return;
      }
      if (attempts >= 20) { // ~3s max
        stop();
        attempts = 0;
        Logger.w("ControlCenterWidgetLoader", "Giving up waiting for widget:", widgetId);
      }
    }
  }
}
