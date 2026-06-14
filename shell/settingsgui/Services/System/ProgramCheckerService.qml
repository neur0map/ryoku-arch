pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Theming

Singleton {
  id: root

  property bool nmcliAvailable: false
  property bool bluetoothctlAvailable: false
  property bool wlsunsetAvailable: false
  property bool gnomeCalendarAvailable: false
  property bool pythonAvailable: false
  property bool wtypeAvailable: false

  // Programs to check - maps property names to commands
  readonly property var programsToCheck: ({
                                            "bluetoothctlAvailable": ["sh", "-c", "command -v bluetoothctl"],
                                            "nmcliAvailable": ["sh", "-c", "command -v nmcli"],
                                            "wlsunsetAvailable": ["sh", "-c", "command -v wlsunset"],
                                            "gnomeCalendarAvailable": ["sh", "-c", "command -v gnome-calendar"],
                                            "wtypeAvailable": ["sh", "-c", "command -v wtype"],
                                            "pythonAvailable": ["sh", "-c", "command -v python3"]
                                          })

  property var availableDiscordClients: []

  property var availableCodeClients: []

  property var availableEmacsClients: []

  signal checksCompleted

  // disable Night Light in settings if wlsunset is not available
  onChecksCompleted: {
    if (!wlsunsetAvailable && GlobalConfig.nightLight.enabled) {
      GlobalConfig.nightLight.enabled = false;
      GlobalConfig.save();
    }
  }

  onWlsunsetAvailableChanged: {
    if (!wlsunsetAvailable && GlobalConfig.nightLight.enabled) {
      GlobalConfig.nightLight.enabled = false;
      GlobalConfig.save();
    }
  }

  function detectDiscordClient() {
    var scriptParts = ["available_clients=\"\";"];

    for (var i = 0; i < TemplateRegistry.discordClients.length; i++) {
      var client = TemplateRegistry.discordClients[i];
      var clientName = client.name;
      var configPath = client.configPath;

      // Use the actual config path from the client, removing ~ prefix
      var checkPath = configPath.startsWith("~") ? configPath.substring(2) : configPath.substring(1);

      scriptParts.push("if [ -d \"$HOME/" + checkPath + "\" ]; then available_clients=\"$available_clients " + clientName + "\"; fi;");
    }

    scriptParts.push("echo \"$available_clients\"");

    discordDetector.command = ["sh", "-c", scriptParts.join(" ")];
    discordDetector.running = true;
  }

  Process {
    id: discordDetector
    running: false

    onExited: function (exitCode) {
      availableDiscordClients = [];

      if (exitCode === 0) {
        var detectedClients = stdout.text.trim().split(/\s+/).filter(function (client) {
          return client.length > 0;
        });

        if (detectedClients.length > 0) {
          for (var i = 0; i < detectedClients.length; i++) {
            var clientName = detectedClients[i];
            for (var j = 0; j < TemplateRegistry.discordClients.length; j++) {
              var client = TemplateRegistry.discordClients[j];
              if (client.name === clientName) {
                availableDiscordClients.push(client);
                break;
              }
            }
          }

          Logger.d("ProgramChecker", "Detected Discord clients:", detectedClients.join(", "));
        }
      }

      if (availableDiscordClients.length === 0) {
        Logger.d("ProgramChecker", "No Discord clients detected");
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  function detectCodeClient() {
    var scriptParts = ["available_clients=\"\";"];

    for (var i = 0; i < TemplateRegistry.codeClients.length; i++) {
      var client = TemplateRegistry.codeClients[i];
      var clientName = client.name;
      var configPath = client.configPath;

      scriptParts.push("if [ -d \"$HOME" + configPath.substring(1) + "\" ]; then available_clients=\"$available_clients " + clientName + "\"; fi;");
    }

    scriptParts.push("echo \"$available_clients\"");

    codeDetector.command = ["sh", "-c", scriptParts.join(" ")];
    codeDetector.running = true;
  }

  Process {
    id: codeDetector
    running: false

    onExited: function (exitCode) {
      availableCodeClients = [];

      if (exitCode === 0) {
        var detectedClients = stdout.text.trim().split(/\s+/).filter(function (client) {
          return client.length > 0;
        });

        if (detectedClients.length > 0) {
          for (var i = 0; i < detectedClients.length; i++) {
            var clientName = detectedClients[i];
            for (var j = 0; j < TemplateRegistry.codeClients.length; j++) {
              var client = TemplateRegistry.codeClients[j];
              if (client.name === clientName) {
                availableCodeClients.push(client);
                break;
              }
            }
          }

          Logger.d("ProgramChecker", "Detected Code clients:", detectedClients.join(", "));
        }
      }

      if (availableCodeClients.length === 0) {
        Logger.d("ProgramChecker", "No Code clients detected");
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  function detectEmacsClient() {
    var scriptParts = ["available_clients=\"\";"];

    for (var i = 0; i < TemplateRegistry.emacsClients.length; i++) {
      var client = TemplateRegistry.emacsClients[i];
      var clientName = client.name;
      var configPath = client.path;

      scriptParts.push("if [ -d \"$HOME" + configPath.substring(1) + "\" ]; then available_clients=\"$available_clients " + clientName + "\"; fi;");
    }

    scriptParts.push("echo \"$available_clients\"");

    emacsDetector.command = ["sh", "-c", scriptParts.join(" ")];
    emacsDetector.running = true;
  }

  Process {
    id: emacsDetector
    running: false

    onExited: function (exitCode) {
      availableEmacsClients = [];

      if (exitCode === 0) {
        var detectedClients = stdout.text.trim().split(/\s+/).filter(function (client) {
          return client.length > 0;
        });

        if (detectedClients.length > 0) {
          for (var i = 0; i < detectedClients.length; i++) {
            var clientName = detectedClients[i];
            for (var j = 0; j < TemplateRegistry.emacsClients.length; j++) {
              var client = TemplateRegistry.emacsClients[j];
              if (client.name === clientName) {
                availableEmacsClients.push(client);
                break;
              }
            }
          }

          Logger.d("ProgramChecker", "Detected Emacs clients:", detectedClients.join(", "));
        }
      }

      if (availableEmacsClients.length === 0) {
        Logger.d("ProgramChecker", "No Emacs clients detected");
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  property int completedChecks: 0
  property int totalChecks: Object.keys(programsToCheck).length

  Process {
    id: checker
    running: false

    property string currentProperty: ""

    onExited: function (exitCode) {
      root[currentProperty] = (exitCode === 0);

      running = false;

      root.completedChecks++;

      if (root.completedChecks >= root.totalChecks) {
        root.detectDiscordClient();
        root.detectCodeClient();
        root.detectEmacsClient();
        root.checksCompleted();
      } else {
        root.checkNextProgram();
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  property var checkQueue: []
  property int currentCheckIndex: 0

  function checkNextProgram() {
    if (currentCheckIndex >= checkQueue.length)
      return;
    var propertyName = checkQueue[currentCheckIndex];
    var command = programsToCheck[propertyName];

    checker.currentProperty = propertyName;
    checker.command = command;
    checker.running = true;

    currentCheckIndex++;
  }

  function checkAllPrograms() {
    completedChecks = 0;
    currentCheckIndex = 0;
    checkQueue = Object.keys(programsToCheck);

    if (checkQueue.length > 0) {
      checkNextProgram();
    }
  }

  function checkProgram(programProperty) {
    if (!programsToCheck.hasOwnProperty(programProperty)) {
      Logger.w("ProgramChecker", "Unknown program property:", programProperty);
      return;
    }

    checker.currentProperty = programProperty;
    checker.command = programsToCheck[programProperty];
    checker.running = true;
  }

  function testDiscordDetection() {
    Logger.d("ProgramChecker", "Testing Discord detection...");
    Logger.d("ProgramChecker", "HOME:", Quickshell.env("HOME"));

    for (var i = 0; i < TemplateRegistry.discordClients.length; i++) {
      var client = TemplateRegistry.discordClients[i];
      var configDir = client.configPath.replace("~", Quickshell.env("HOME"));
      Logger.d("ProgramChecker", "Checking:", configDir);
    }

    detectDiscordClient();
  }

  Component.onCompleted: {
    checkAllPrograms();
  }
}
