pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Noctalia.Services.UI

Singleton {
  id: root

  readonly property bool wallpaperColorControlsAvailable: false
  readonly property bool templateControlsAvailable: false
  readonly property string unavailableReason: "Ryoku does not expose this Noctalia backend yet."

  property var _queue: []
  property string _successMessage: ""

  function refreshTheme() {
    run(["ryoku-theme-refresh"], "Theme templates refreshed");
  }

  function openThemePicker() {
    run(["ryoku-ipc", "shell", "toggle", "themes"], "Theme picker opened");
  }

  function run(commandArgs, successMessage) {
    if (actionProcess.running) {
      _queue.push({
                    "command": commandArgs,
                    "successMessage": successMessage
                  });
      return;
    }

    _successMessage = successMessage;
    actionProcess.command = commandArgs;
    actionProcess.running = true;
  }

  function runNext() {
    if (actionProcess.running || _queue.length === 0)
      return;

    const next = _queue.shift();
    run(next.command, next.successMessage);
  }

  Process {
    id: actionProcess
    command: ["true"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      if (exitCode === 0) {
        ToastService.showNotice("Ryoku", root._successMessage);
      } else {
        ToastService.showWarning("Ryoku", "Theme action failed");
      }
      root.runNext();
    }
  }
}
