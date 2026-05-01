pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property bool ready: stationDevice.length > 0
  readonly property bool available: commandAvailable && ready
  readonly property bool wifiAvailable: available
  readonly property bool wifiEnabled: wifiAvailable && wifiPowered
  readonly property bool scanningActive: scanning
  readonly property bool wifiConnected: activeSsid.length > 0
  readonly property bool internetConnectivity: wifiConnected
  readonly property string networkConnectivity: wifiConnected ? "full" : "unknown"
  readonly property bool airplaneModeEnabled: false

  property bool commandAvailable: false
  property bool scanning: false
  property var networks: ({})
  property string activeSsid: ""
  property string error: ""
  property string lastError: error
  property string stationDevice: ""
  property string activeWifiIf: stationDevice
  property bool wifiPowered: false
  property bool connecting: false
  property string connectingTo: ""
  property string disconnectingFrom: ""
  property string forgettingNetwork: ""
  property var existingProfiles: ({})
  property var activeWifiDetails: ({})
  property bool pendingScan: false
  property string pendingConnectSsid: ""
  property string pendingConnectPassphrase: ""

  Component.onCompleted: refresh()

  function refresh() {
    error = "";
    if (!commandAvailable) {
      commandCheckProcess.running = true;
      return;
    }
    deviceListProcess.running = true;
  }

  function scan() {
    error = "";
    if (!commandAvailable) {
      pendingScan = true;
      commandCheckProcess.running = true;
      error = "iwctl is not available";
      return;
    }
    if (!ready) {
      pendingScan = true;
      deviceListProcess.running = true;
      return;
    }
    if (!wifiEnabled) {
      pendingScan = true;
      return;
    }
    if (scanProcess.running || networkListProcess.running) {
      pendingScan = true;
      return;
    }
    scanning = true;
    scanProcess.command = ["iwctl", "station", stationDevice, "scan"];
    scanProcess.running = true;
  }

  function connect(ssid, security, passphrase, hidden) {
    if (connecting || !ssid) {
      return;
    }
    if (!available) {
      error = "iwctl is not available";
      return;
    }
    if (!stationDevice) {
      error = "No iwd Wi-Fi station was found";
      return;
    }
    if (isEnterprise(security)) {
      error = "Enterprise Wi-Fi is not supported by the iwd settings adapter";
      lastError = error;
      return;
    }

    pendingConnectSsid = ssid;
    pendingConnectPassphrase = isSecured(security) && passphrase ? passphrase : "";
    connecting = true;
    connectingTo = ssid;
    error = "";

    const args = ["iwctl", "station", stationDevice, hidden ? "connect-hidden" : "connect", ssid];
    connectProcess.command = args;
    connectProcess.stdinEnabled = pendingConnectPassphrase.length > 0;
    connectProcess.running = true;
  }

  function disconnect(ssid) {
    const target = ssid || activeSsid;
    if (!available || !stationDevice || !target) {
      return;
    }
    disconnectingFrom = target;
    disconnectProcess.command = ["iwctl", "station", stationDevice, "disconnect"];
    disconnectProcess.running = true;
  }

  function forget(ssid) {
    if (!available || !ssid) {
      return;
    }
    forgettingNetwork = ssid;
    forgetProcess.command = ["iwctl", "known-networks", ssid, "forget"];
    forgetProcess.running = true;
  }

  function setWifiEnabled(enabled) {
    if (!available || !stationDevice) {
      return;
    }
    wifiPowerProcess.command = ["iwctl", "device", stationDevice, "set-property", "Powered", enabled ? "on" : "off"];
    wifiPowerProcess.running = true;
  }

  function refreshActiveWifiDetails() {
    if (!available || !stationDevice) {
      return;
    }
    activeStatusProcess.running = true;
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

  function signalValue(token) {
    const text = String(token || "").trim();
    const number = parseInt(text, 10);
    if (!isNaN(number)) {
      return number;
    }
    const bars = (text.match(/\*/g) || []).length;
    return Math.max(0, Math.min(100, bars * 25));
  }

  function normalizeSecurity(security) {
    const value = String(security || "").trim();
    if (!value || value === "open" || value === "--") {
      return "--";
    }
    return value.toUpperCase();
  }

  function parsePowerToken(token) {
    const value = String(token || "").toLowerCase();
    if (value === "on" || value === "yes" || value === "true") {
      return true;
    }
    if (value === "off" || value === "no" || value === "false") {
      return false;
    }
    return null;
  }

  function parseDeviceList(text) {
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line || line.indexOf("---") === 0 || line.indexOf("Name") === 0 || line.indexOf("Devices") !== -1) {
        continue;
      }
      const parts = line.split(/\s+/);
      if (parts.length === 0) {
        continue;
      }
      if (parts[parts.length - 1] !== "station") {
        continue;
      }

      let powered = null;
      for (let j = 1; j < parts.length; j++) {
        powered = parsePowerToken(parts[j]);
        if (powered !== null) {
          break;
        }
      }
      return {
        "name": parts[0],
        "powered": powered === null ? true : powered
      };
    }
    return {
      "name": "",
      "powered": false
    };
  }

  function parseActiveSsid(text) {
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.indexOf("Powered") === 0) {
        const powered = parsePowerToken(line.replace(/^Powered\s+/i, "").trim());
        if (powered !== null) {
          wifiPowered = powered;
        }
      }
      if (line.indexOf("Connected network") === 0) {
        return line.replace(/^Connected network\s+/i, "").trim();
      }
      if (line.indexOf("State") === 0 && line.indexOf("connected") === -1) {
        return "";
      }
    }
    return activeSsid;
  }

  function parseNetworks(text) {
    const parsed = {};
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      let line = lines[i].trim();
      if (!line || line.indexOf("---") === 0 || line.indexOf("Available networks") !== -1 || line.indexOf("Network name") === 0) {
        continue;
      }
      line = line.replace(/^[>*]\s*/, "").trim();
      const parts = line.split(/\s{2,}/).filter(part => part.length > 0);
      if (parts.length < 2) {
        continue;
      }

      let ssid = "";
      let security = "--";
      let signal = 0;
      if (parts.length >= 3) {
        ssid = parts.slice(0, parts.length - 2).join(" ").trim();
        security = normalizeSecurity(parts[parts.length - 2]);
        signal = signalValue(parts[parts.length - 1]);
      } else {
        ssid = parts[0].trim();
        signal = signalValue(parts[1]);
      }
      if (!ssid) {
        continue;
      }
      parsed[ssid] = {
        "ssid": ssid,
        "security": security,
        "signal": signal,
        "connected": ssid === activeSsid,
        "existing": !!existingProfiles[ssid] || ssid === activeSsid
      };
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
      "ifname": stationDevice,
      "signal": network.signal || 0,
      "band": network.band || "",
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
    command: ["bash", "-lc", "command -v iwctl >/dev/null 2>&1"]
    onExited: exitCode => {
      root.commandAvailable = exitCode === 0;
      if (root.commandAvailable) {
        deviceListProcess.running = true;
      } else {
        root.error = "iwctl is not available";
      }
    }
  }

  Process {
    id: deviceListProcess
    running: false
    command: ["iwctl", "device", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const station = root.parseDeviceList(text);
        root.stationDevice = station.name;
        root.wifiPowered = station.powered;
        root.activeWifiIf = root.stationDevice;
        if (root.stationDevice) {
          activeStatusProcess.running = true;
          knownNetworksProcess.running = true;
          if (root.pendingScan) {
            root.pendingScan = false;
            if (root.wifiEnabled) {
              root.scan();
            }
          }
        } else {
          root.error = "No iwd Wi-Fi station was found";
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.error = text.trim();
        }
      }
    }
  }

  Process {
    id: knownNetworksProcess
    running: false
    command: ["iwctl", "known-networks", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const profiles = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line || line.indexOf("---") === 0 || line.indexOf("Known Networks") !== -1 || line.indexOf("Name") === 0) {
            continue;
          }
          const name = line.split(/\s{2,}/)[0].trim();
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
    command: ["iwctl", "station", root.stationDevice, "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.activeSsid = root.parseActiveSsid(text);
        root.syncActiveDetails();
      }
    }
  }

  Process {
    id: scanProcess
    running: false
    onExited: {
      networkListProcess.command = ["iwctl", "station", root.stationDevice, "get-networks"];
      networkListProcess.running = true;
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.error = text.trim();
        }
      }
    }
  }

  Process {
    id: networkListProcess
    running: false
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
    stdinEnabled: false
    onStarted: {
      if (root.pendingConnectPassphrase.length > 0) {
        connectProcess.write(root.pendingConnectPassphrase + "\n");
      }
    }
    onExited: exitCode => {
      root.connecting = false;
      root.connectingTo = "";
      root.pendingConnectPassphrase = "";
      if (exitCode === 0) {
        root.activeSsid = root.pendingConnectSsid;
        root.pendingConnectSsid = "";
        root.refreshActiveWifiDetails();
        root.scan();
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
      root.activeSsid = "";
      root.refreshActiveWifiDetails();
      root.scan();
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.error = text.trim();
        }
      }
    }
  }

  Process {
    id: forgetProcess
    running: false
    onExited: {
      root.forgettingNetwork = "";
      knownNetworksProcess.running = true;
      root.scan();
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.error = text.trim();
        }
      }
    }
  }

  Process {
    id: wifiPowerProcess
    running: false
    onExited: root.refresh()
  }
}
