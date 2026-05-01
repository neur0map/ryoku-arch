pragma Singleton

import Quickshell

Singleton {
  signal brightnessUpdated()

  property var availableBacklightDevices: []
  property var mappedBacklightDevices: ({})

  function init() {}

  function getMonitorForScreen(screen) {
    return screen || null;
  }

  function getBacklightDeviceName(path) {
    if (!path) {
      return "";
    }
    var parts = String(path).split("/");
    return parts[parts.length - 1] || String(path);
  }

  function getMappedBacklightDevice(screenName) {
    return mappedBacklightDevices[screenName] || "";
  }

  function setMappedBacklightDevice(screenName, key) {
    var next = Object.assign({}, mappedBacklightDevices);
    next[screenName] = key || "";
    mappedBacklightDevices = next;
    brightnessUpdated();
  }
}
