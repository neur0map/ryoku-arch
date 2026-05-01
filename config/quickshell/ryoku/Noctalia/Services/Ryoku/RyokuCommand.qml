pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool helperAvailable: false
  property var _callbacks: ({})

  function checkPresent(commandName, callback) {
    if (!commandName)
      return;

    _callbacks[commandName] = callback;
    presenceProcess.commandName = commandName;
    presenceProcess.command = ["ryoku-cmd-present", commandName];
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
    property string commandName: ""
    command: ["true"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      const callback = root._callbacks[commandName];
      delete root._callbacks[commandName];
      if (callback)
        callback(exitCode === 0);
    }
  }
}
