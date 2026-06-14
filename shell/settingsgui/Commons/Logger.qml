pragma Singleton

import Quickshell
import qs.settingsgui.Commons

Singleton {
  id: root

  function _formatMessage(...args) {
    var t = Time.getFormattedTimestamp();
    if (args.length > 1) {
      const maxLength = 14;
      var module = args.shift().substring(0, maxLength).padStart(maxLength, " ");
      return `\x1b[36m[${t}]\x1b[0m \x1b[35m${module}\x1b[0m ` + args.join(" ");
    } else {
      return `[\x1b[36m[${t}]\x1b[0m ` + args.join(" ");
    }
  }

  function _getStackTrace() {
    try {
      throw new Error("Stack trace");
    } catch (e) {
      return e.stack;
    }
  }

  // Debug log (only when Settings.isDebug is true)
  function d(...args) {
    if (Settings?.isDebug) {
      var msg = _formatMessage(...args);
      console.debug(msg);
    }
  }

  function i(...args) {
    var msg = _formatMessage(...args);
    console.info(msg);
  }

  function w(...args) {
    var msg = _formatMessage(...args);
    console.warn(msg);
  }

  function e(...args) {
    var msg = _formatMessage(...args);
    console.error(msg);
  }

  function callStack() {
    var stack = _getStackTrace();
    Logger.i("Debug", "--------------------------");
    Logger.i("Debug", "Current call stack");
    var stackLines = stack.split('\n');
    for (var i = 0; i < stackLines.length; i++) {
      var line = stackLines[i].trim();
      if (line.length > 0) {
        Logger.i("Debug", `- ${line}`);
      }
    }
    Logger.i("Debug", "--------------------------");
  }
}
