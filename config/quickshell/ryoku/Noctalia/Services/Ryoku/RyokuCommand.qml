pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool helperAvailable: false
  property var _commandCache: ({})
  property var _pendingChecks: ({})
  property var _checkQueue: []
  property string _activeCommand: ""

  function checkPresent(commandName, callback) {
    if (!commandName)
      return;

    if (_commandCache.hasOwnProperty(commandName)) {
      if (callback)
        Qt.callLater(() => callback(_commandCache[commandName]));
      return;
    }

    if (!_pendingChecks[commandName]) {
      _pendingChecks[commandName] = [];
      _checkQueue.push(commandName);
    }
    if (callback)
      _pendingChecks[commandName].push(callback);

    runNextCheck();
  }

  function runNextCheck() {
    if (presenceProcess.running || _activeCommand !== "" || _checkQueue.length === 0)
      return;

    _activeCommand = _checkQueue.shift();
    presenceProcess.command = ["ryoku-cmd-present", _activeCommand];
    presenceProcess.running = true;
  }

  Process {
    id: ryokuCmdPresentProcess
    command: ["sh", "-c", "command -v ryoku-cmd-present"]
    running: true
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.helperAvailable = exitCode === 0;
    }
  }

  Process {
    id: presenceProcess
    command: ["true"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      const commandName = root._activeCommand;
      const available = exitCode === 0;
      root._commandCache[commandName] = available;

      const callbacks = root._pendingChecks[commandName] || [];
      delete root._pendingChecks[commandName];
      root._activeCommand = "";

      for (let i = 0; i < callbacks.length; i++) {
        callbacks[i](available);
      }
      root.runNextCheck();
    }
  }
}
