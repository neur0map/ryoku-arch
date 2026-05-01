pragma Singleton

import Quickshell

Singleton {
  property bool bluetoothctlAvailable: false
  property bool nmcliAvailable: false
  property bool wtypeAvailable: false
  property var availableCodeClients: []
  property var availableDiscordClients: []
  property var availableEmacsClients: []

  function init() {}

  function checkAllPrograms() {}
}
