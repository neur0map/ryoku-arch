pragma Singleton

import Quickshell

Singleton {
  property bool overviewActive: false
  property bool isNiri: false
  property var displayScales: ({})

  function init() {}

  function getCurrentWorkspace() {
    return 0;
  }
}
