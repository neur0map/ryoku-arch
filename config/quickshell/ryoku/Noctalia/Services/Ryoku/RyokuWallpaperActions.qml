pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Noctalia.Services.UI

Singleton {
  id: root

  readonly property bool noctaliaWallpaperControlsAvailable: false
  readonly property string unavailableReason: "Ryoku wallpapers are managed by the Ryoku wallpaper tools."

  property var _queue: []
  property string _successMessage: ""

  function openWallpaperPicker() {
    run(["ryoku-ipc", "shell", "toggle", "wallpaper"], "Wallpaper picker opened");
  }

  function openWallhaven() {
    openWallpaperPicker();
  }

  function rebuildCache() {
    run(["ryoku-ipc", "wallpaper", "cache", "rebuild"], "Wallpaper cache rebuild started");
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
        ToastService.showWarning("Ryoku", "Wallpaper action failed");
      }
      root.runNext();
    }
  }
}
