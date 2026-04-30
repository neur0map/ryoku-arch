pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property bool active: false
  property bool busy: false
  property bool _stopping: false

  function refresh() {
    if (_checkProc.running) return

    _checkProc.running = true
  }

  function start() {
    if (root.busy || root.active) return

    root.busy = true
    root._stopping = false
    root.active = true
    _stopProc.running = false
    _startProc.running = false
    _startProc.running = true
  }

  function stop() {
    if (root.busy || !root.active) return

    root.busy = true
    root._stopping = true
    root.active = false
    _startProc.running = false
    _stopProc.running = false
    _stopProc.running = true
  }

  function toggle() {
    if (root.busy) return
    if (root.active) root.stop()
    else root.start()
  }

  property var _checkProc: Process {
    command: ["ryoku-cmd-caffeine", "status"]
    running: false
    onExited: function(exitCode, exitStatus) {
      if (!root.busy && !_startProc.running)
        root.active = exitCode === 0
    }
  }

  property var _startProc: Process {
    command: ["ryoku-cmd-caffeine", "start"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.busy = false
      if (!root._stopping)
        root.active = exitCode === 0
      root.refresh()
    }
  }

  property var _stopProc: Process {
    command: ["ryoku-cmd-caffeine", "stop"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.busy = false
      root._stopping = false
      root.active = false
    }
  }

  property var _refreshTimer: Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
