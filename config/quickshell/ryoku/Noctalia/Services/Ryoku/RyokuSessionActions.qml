pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Noctalia.Services.UI

Singleton {
  id: root

  readonly property string unavailableReason: "Ryoku does not expose this session action from Noctalia settings."
  readonly property var actionCommands: ({
                                          "lock": ["ryoku-lock-screen"],
                                          "logout": ["ryoku-system-logout"],
                                          "reboot": ["ryoku-system-reboot"],
                                          "shutdown": ["ryoku-system-shutdown"],
                                          "poweroff": ["ryoku-system-shutdown"]
                                        })

  property var _queue: []
  property string _activeAction: ""

  function isSafeAction(action) {
    return actionCommands.hasOwnProperty(action);
  }

  function commandForAction(action) {
    return actionCommands[action] || [];
  }

  function runAction(action) {
    if (!isSafeAction(action)) {
      ToastService.showWarning("Ryoku", unavailableReason);
      return;
    }

    run(action, commandForAction(action));
  }

  function run(action, commandArgs) {
    if (actionProcess.running) {
      _queue.push({
                    "action": action,
                    "command": commandArgs
                  });
      return;
    }

    _activeAction = action;
    actionProcess.command = commandArgs;
    actionProcess.running = true;
  }

  function runNext() {
    if (actionProcess.running || _queue.length === 0)
      return;

    const next = _queue.shift();
    run(next.action, next.command);
  }

  Process {
    id: actionProcess
    command: ["true"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      if (exitCode !== 0)
        ToastService.showWarning("Ryoku", "Session action failed");
      root.runNext();
    }
  }
}
