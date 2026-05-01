pragma Singleton

import Quickshell

Singleton {
  property var deviceModel: []

  function init() {}

  function getIcon(level, charging, plugged, present) {
    if (present === false) {
      return "battery-off";
    }
    return charging ? "battery-charging" : "battery";
  }
}
