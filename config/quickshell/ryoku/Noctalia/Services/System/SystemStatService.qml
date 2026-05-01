pragma Singleton

import Quickshell

Singleton {
  property var diskPercents: ({})
  property bool gpuAvailable: false
  property string gpuType: ""
  property real rxSpeed: 0
  property real txSpeed: 0

  function init() {}

  function registerComponent(componentId) {}

  function unregisterComponent(componentId) {}

  function formatSpeed(speed) {
    if (!speed || speed <= 0) {
      return "0 B/s";
    }
    return Math.round(speed) + " B/s";
  }
}
