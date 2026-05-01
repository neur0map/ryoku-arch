pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property bool available: commandAvailable
  readonly property bool wifiAvailable: available
  readonly property bool scanningActive: scanning
  readonly property bool wifiConnected: activeSsid.length > 0
  readonly property bool internetConnectivity: wifiConnected
  readonly property string networkConnectivity: wifiConnected ? "full" : "unknown"
  readonly property bool airplaneModeEnabled: false

  property bool commandAvailable: false
  property bool wifiEnabled: true
  property bool scanning: false
  property var networks: ({})
  property string activeSsid: ""
  property string error: ""
  property string lastError: error
  property string activeWifiIf: ""
  property bool connecting: false
  property string connectingTo: ""
  property string disconnectingFrom: ""
  property string forgettingNetwork: ""
  property var existingProfiles: ({})
  property var activeWifiDetails: ({})

  Component.onCompleted: refresh()

  function refresh() {
    error = "";
    if (!commandAvailable) {
      commandCheckProcess.running = true;
      return;
    }
    radioProcess.running = true;
    profileProcess.running = true;
    activeStatusProcess.running = true;
    scan();
  }

  function scan() {
    if (!available) {
      error = "nmcli is not available";
      return;
    }
    if (scanProcess.running) {
      return;
    }
    scanning = true;
    scanProcess.running = true;
  }

  function connect(ssid, security, passphrase, hidden) {
    if (connecting || !ssid) {
      return;
    }
    if (!available) {
      error = "nmcli is not available";
      return;
    }
    if (isEnterprise(security)) {
      error = "Enterprise Wi-Fi is not supported by the nmcli settings adapter";
      lastError = error;
      return;
    }
    if (hidden) {
      error = "Hidden Wi-Fi connections are not supported by the nmcli settings adapter";
      lastError = error;
      return;
    }
    if (isSecured(security) && passphrase && passphrase.length > 0) {
      error = "Secured Wi-Fi connections through nmcli are disabled because this adapter does not pass secrets in command arguments";
      lastError = error;
      return;
    }

    connecting = true;
    connectingTo = ssid;
    connectProcess.command = ["nmcli", "dev", "wifi", "connect", ssid];
    connectProcess.running = true;
  }

  function disconnect(ssid) {
    const target = ssid || activeSsid;
    if (!available || !target) {
      return;
    }
    disconnectingFrom = target;
    disconnectProcess.command = ["nmcli", "connection", "down", "id", target];
    disconnectProcess.running = true;
  }

  function forget(ssid) {
    if (!available || !ssid) {
      return;
    }
    forgettingNetwork = ssid;
    forgetProcess.command = ["nmcli", "connection", "delete", "id", ssid];
    forgetProcess.running = true;
  }

  function setWifiEnabled(enabled) {
    if (!available) {
      return;
    }
    wifiEnabled = enabled;
    radioSetProcess.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"];
    radioSetProcess.running = true;
  }

  function refreshActiveWifiDetails() {
    if (available) {
      activeStatusProcess.running = true;
    }
  }

  function getSignalInfo(signal, isConnected) {
    let icon = "";
    if (isConnected && networkConnectivity !== "full") {
      icon = "wifi-question";
    }
    const value = Number(signal) || 0;
    const label = value >= 80 ? "Excellent" : value >= 60 ? "Good" : value >= 35 ? "Fair" : value >= 15 ? "Poor" : "Weak";
    if (!icon) {
      icon = value >= 80 ? "wifi" : value >= 60 ? "wifi-3" : value >= 35 ? "wifi-2" : value >= 15 ? "wifi-1" : "wifi-0";
    }
    return {
      icon,
      label
    };
  }

  function isSecured(security) {
    return !!security && security !== "--" && security.toLowerCase() !== "open" && security.trim() !== "";
  }

  function isEnterprise(security) {
    if (!security) {
      return false;
    }
    const normalized = security.toUpperCase();
    return normalized.indexOf("802.1X") !== -1 || normalized.indexOf("EAP") !== -1 || normalized.indexOf("ENTERPRISE") !== -1;
  }

  function splitNmcli(text) {
    const parts = [];
    let current = "";
    let escaped = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (escaped) {
        current += ch;
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === ":") {
        parts.push(current);
        current = "";
      } else {
        current += ch;
      }
    }
    parts.push(current);
    return parts;
  }

  function parseNetworks(text) {
    const parsed = {};
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) {
        continue;
      }
      const parts = splitNmcli(line);
      if (parts.length < 4) {
        continue;
      }
      const active = parts[0] === "yes" || parts[0] === "*";
      const ssid = parts[1];
      const security = parts[2] && parts[2].trim() ? parts[2].trim() : "--";
      const signal = parseInt(parts[3], 10) || 0;
      if (!ssid) {
        continue;
      }
      parsed[ssid] = {
        "ssid": ssid,
        "security": security,
        "signal": signal,
        "connected": active,
        "existing": !!existingProfiles[ssid] || active
      };
      if (active) {
        activeSsid = ssid;
      }
    }
    return parsed;
  }

  function syncActiveDetails() {
    if (!activeSsid) {
      activeWifiDetails = ({});
      return;
    }
    const network = networks[activeSsid] || {};
    activeWifiDetails = {
      "connectionName": activeSsid,
      "ifname": activeWifiIf,
      "signal": network.signal || 0,
      "band": "",
      "rate": "",
      "rateShort": "",
      "ipv4": "",
      "ipv6": [],
      "dns4": [],
      "dns6": [],
      "gateway4": "",
      "gateway6": []
    };
  }

  Process {
    id: commandCheckProcess
    running: false
    command: ["bash", "-lc", "command -v nmcli >/dev/null 2>&1"]
    onExited: exitCode => {
      root.commandAvailable = exitCode === 0;
      if (root.commandAvailable) {
        root.refresh();
      } else {
        root.error = "nmcli is not available";
      }
    }
  }

  Process {
    id: radioProcess
    running: false
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector {
      onStreamFinished: root.wifiEnabled = text.trim() !== "disabled"
    }
  }

  Process {
    id: radioSetProcess
    running: false
    onExited: root.refresh()
  }

  Process {
    id: profileProcess
    running: false
    command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const profiles = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
          const name = lines[i].trim();
          if (name) {
            profiles[name] = true;
          }
        }
        root.existingProfiles = profiles;
      }
    }
  }

  Process {
    id: activeStatusProcess
    running: false
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n");
        root.activeSsid = "";
        root.activeWifiIf = "";
        for (let i = 0; i < lines.length; i++) {
          const parts = root.splitNmcli(lines[i]);
          if (parts.length >= 4 && parts[1] === "wifi" && parts[2] === "connected") {
            root.activeWifiIf = parts[0];
            root.activeSsid = parts[3];
            break;
          }
        }
        root.syncActiveDetails();
      }
    }
  }

  Process {
    id: scanProcess
    running: false
    command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SECURITY,SIGNAL", "dev", "wifi", "list", "--rescan", "yes"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.networks = root.parseNetworks(text);
        root.syncActiveDetails();
        root.scanning = false;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.error = text.trim();
        }
        root.scanning = false;
      }
    }
  }

  Process {
    id: connectProcess
    running: false
    onExited: exitCode => {
      root.connecting = false;
      root.connectingTo = "";
      if (exitCode === 0) {
        root.refresh();
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.error = text.trim();
          root.lastError = root.error;
        }
      }
    }
  }

  Process {
    id: disconnectProcess
    running: false
    onExited: {
      root.disconnectingFrom = "";
      root.refresh();
    }
  }

  Process {
    id: forgetProcess
    running: false
    onExited: {
      root.forgettingNetwork = "";
      root.refresh();
    }
  }
}
