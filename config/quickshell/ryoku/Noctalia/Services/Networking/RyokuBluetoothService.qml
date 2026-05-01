pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Helpers/BluetoothUtils.js" as BluetoothUtils
import qs.Noctalia.Commons

Singleton {
  id: root

  property bool available: false
  property bool powered: false
  property bool scanning: false
  property var devices: []
  property string error: ""

  readonly property bool enabled: powered
  readonly property bool bluetoothAvailable: available
  readonly property bool blocked: false
  readonly property bool scanningActive: scanning
  property bool discoverable: false
  readonly property var adapter: ({
                                    "devices": ({
                                      "values": root.devices
                                    })
                                  })
  readonly property var connectedDevices: root.devices.filter(dev => dev && dev.connected)
  readonly property bool pinRequired: false

  readonly property string scanOnCommand: "scan on"
  readonly property string scanOffCommand: "scan off"

  property string _showText: ""
  property string _devicesText: ""
  property string _infoAddress: ""
  property string _infoText: ""
  property var _infoQueue: []
  property var _actionQueue: []
  property string _busyAddress: ""
  property string _busyAction: ""
  property int _busyRevision: 0
  property string _pairAddress: ""
  property string _pairOutput: ""

  Component.onCompleted: refresh()

  Timer {
    id: refreshDebouncer
    interval: 700
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: scanRefreshTimer
    interval: 2500
    repeat: true
    running: root.scanning && root.powered
    onTriggered: root.refresh()
  }

  function refresh() {
    if (showProcess.running)
      return;

    root.error = "";
    root._showText = "";
    showProcess.running = true;
  }

  function setPowered(enabled) {
    queueBluetoothctl(["power", enabled ? "on" : "off"], "", "");
  }

  function setBluetoothEnabled(enabled) {
    setPowered(enabled);
  }

  function scan() {
    setScanActive(true);
  }

  function setScanActive(active) {
    if (!active) {
      root.scanning = false;
      if (scanProcess.running)
        scanProcess.running = false;
      if (!scanOffProcess.running)
        scanOffProcess.running = true;
      return;
    }

    if (!root.available || !root.powered) {
      root.refresh();
      return;
    }

    root.scanning = true;
    if (!scanProcess.running)
      scanProcess.running = true;
    refreshDebouncer.restart();
  }

  function setDiscoverable(enabled) {
    root.discoverable = enabled;
    if (root.available && root.powered) {
      queueBluetoothctl(["discoverable", enabled ? "on" : "off"], "", "");
    }
  }

  function pair(address) {
    const normalizedAddress = normalizeAddress(address);
    if (!normalizedAddress)
      return;
    if (pairProcess.running)
      return;

    root._pairAddress = normalizedAddress;
    root._pairOutput = "";
    root._busyAddress = normalizedAddress;
    root._busyAction = "pairing";
    root._busyRevision++;
    pairProcess.running = true;
  }

  function trust(address) {
    const normalizedAddress = normalizeAddress(address);
    if (!normalizedAddress)
      return;
    queueBluetoothctl(["trust", normalizedAddress], normalizedAddress, "");
  }

  function connect(address) {
    const normalizedAddress = normalizeAddress(address);
    if (!normalizedAddress)
      return;
    queueBluetoothctl(["connect", normalizedAddress], normalizedAddress, "connecting");
  }

  function disconnect(address) {
    const normalizedAddress = normalizeAddress(address);
    if (!normalizedAddress)
      return;
    queueBluetoothctl(["disconnect", normalizedAddress], normalizedAddress, "disconnecting");
  }

  function remove(address) {
    const normalizedAddress = normalizeAddress(address);
    if (!normalizedAddress)
      return;
    queueBluetoothctl(["remove", normalizedAddress], normalizedAddress, "removing");
  }

  function pairDevice(device) {
    pair(deviceAddress(device));
  }

  function connectDeviceWithTrust(device) {
    const address = deviceAddress(device);
    if (!address)
      return;

    connect(address);
  }

  function disconnectDevice(device) {
    disconnect(deviceAddress(device));
  }

  function unpairDevice(device) {
    forgetDevice(device);
  }

  function forgetDevice(device) {
    remove(deviceAddress(device));
  }

  function submitPin(pin) {
    return;
  }

  function cancelPairing() {
    return;
  }

  function getDeviceAutoConnect(device) {
    return false;
  }

  function setDeviceAutoConnect(device, enabled) {
    return;
  }

  function sortDevices(devList) {
    const sorted = (devList || []).slice();
    return sorted.sort(function (a, b) {
      const aConnected = a && a.connected ? 1 : 0;
      const bConnected = b && b.connected ? 1 : 0;
      if (aConnected !== bConnected)
        return bConnected - aConnected;

      const aPaired = a && (a.paired || a.trusted) ? 1 : 0;
      const bPaired = b && (b.paired || b.trusted) ? 1 : 0;
      if (aPaired !== bPaired)
        return bPaired - aPaired;

      const aName = String((a && (a.name || a.deviceName)) || "");
      const bName = String((b && (b.name || b.deviceName)) || "");
      return aName.localeCompare(bName);
    });
  }

  function dedupeDevices(devList) {
    return BluetoothUtils.dedupeDevices(devList || []);
  }

  function canConnect(device) {
    return !!device && !device.connected && (device.paired || device.trusted) && !isDeviceBusy(device) && !device.blocked;
  }

  function canDisconnect(device) {
    return !!device && device.connected && !isDeviceBusy(device) && !device.blocked;
  }

  function canPair(device) {
    return !!device && !device.connected && !device.paired && !device.trusted && !isDeviceBusy(device) && !device.blocked;
  }

  function isDeviceBusy(device) {
    const revision = root._busyRevision;
    return revision >= 0 && !!device && root._busyAddress !== "" && deviceAddress(device) === root._busyAddress && root._busyAction !== "";
  }

  function deviceKey(device) {
    return BluetoothUtils.deviceKey(device);
  }

  function getDeviceIcon(device) {
    return BluetoothUtils.deviceIcon(device ? (device.name || device.deviceName) : "", device ? device.icon : "");
  }

  function getStatusKey(device) {
    if (!device)
      return "";
    if (isDeviceBusy(device))
      return root._busyAction;
    if (device.blocked)
      return "blocked";
    return "";
  }

  function getBatteryPercent(device) {
    return null;
  }

  function getSignalPercent(device) {
    return null;
  }

  function getSignalIcon(device) {
    return "antenna-bars-off";
  }

  function getSignalStrength(device) {
    return I18n.tr("bluetooth.panel.signal-text-unknown");
  }

  function deviceAddress(device) {
    return normalizeAddress(BluetoothUtils.macFromDevice(device));
  }

  function normalizeAddress(address) {
    return String(address || "").trim().toUpperCase();
  }

  function queueBluetoothctl(args, address, busyAction) {
    if (!args || args.length === 0)
      return;

    const normalizedAddress = normalizeAddress(address);
    root._actionQueue.push({
                             "args": args,
                             "address": normalizedAddress,
                             "busyAction": busyAction || ""
                           });
    runNextAction();
  }

  function runNextAction() {
    if (actionProcess.running || root._actionQueue.length === 0)
      return;

    const item = root._actionQueue.shift();
    root._busyAddress = item.address || "";
    root._busyAction = item.busyAction || "";
    root._busyRevision++;
    actionProcess.command = ["bluetoothctl", "--timeout", "15"].concat(item.args);
    actionProcess.running = true;
  }

  function clearBusy() {
    root._busyAddress = "";
    root._busyAction = "";
    root._busyRevision++;
  }

  function parseShow(text) {
    root.available = text.indexOf("Controller ") !== -1 || text.match(/\bPowered:\s*(yes|no)\b/i) !== null;

    const poweredMatch = text.match(/\bPowered:\s*(yes|no)\b/i);
    root.powered = poweredMatch ? poweredMatch[1].toLowerCase() === "yes" : false;

    const discoverableMatch = text.match(/\bDiscoverable:\s*(yes|no)\b/i);
    if (discoverableMatch)
      root.discoverable = discoverableMatch[1].toLowerCase() === "yes";
  }

  function parseDevices(text) {
    const current = devicesByAddress();
    const parsed = [];
    const lines = String(text || "").split("\n");

    for (let i = 0; i < lines.length; i++) {
      const match = lines[i].match(/(?:^|\s)Device\s+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.+)$/);
      if (!match)
        continue;

      const address = normalizeAddress(match[1]);
      const previous = current[address] || ({});
      parsed.push(makeDevice(address, match[3].trim(), previous));
    }

    root.devices = dedupeDevices(parsed);
    root._infoQueue = root.devices.map(dev => dev.address);
    runNextInfo();
  }

  function parseDeviceInfo(address, text) {
    const previous = devicesByAddress()[address] || ({});
    const updates = ({});
    const lines = String(text || "").split("\n");

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      let match = line.match(/^(Name|Alias|Icon):\s*(.+)$/);
      if (match) {
        const key = match[1].toLowerCase();
        if (key === "alias" || key === "name") {
          updates.name = match[2].trim();
          updates.deviceName = updates.name;
        } else {
          updates.icon = match[2].trim();
        }
        continue;
      }

      match = line.match(/^(Paired|Trusted|Connected|Blocked):\s*(yes|no)$/i);
      if (match) {
        updates[match[1].toLowerCase()] = match[2].toLowerCase() === "yes";
        continue;
      }

      match = line.match(/^RSSI:\s*(-?\d+)/i);
      if (match) {
        updates.signalStrength = Math.max(0, Math.min(100, Math.round((Number(match[1]) + 100) * 2)));
        continue;
      }

      match = line.match(/^Battery Percentage:\s*(?:0x[0-9a-fA-F]+\s*)?\((\d+)\)/i);
      if (match) {
        updates.batteryAvailable = true;
        updates.battery = Number(match[1]) / 100;
      }
    }

    replaceDevice(makeDevice(address, previous.name || address, Object.assign({}, previous, updates)));
  }

  function makeDevice(address, name, values) {
    const source = values || ({});
    const label = String(name || source.name || source.deviceName || address);
    return {
      "address": address,
      "bdaddr": address,
      "mac": address,
      "name": label,
      "deviceName": label,
      "paired": !!source.paired,
      "trusted": !!source.trusted,
      "connected": !!source.connected,
      "blocked": !!source.blocked,
      "pairing": root._busyAddress === address && root._busyAction === "pairing",
      "state": root._busyAddress === address ? root._busyAction : "",
      "icon": source.icon || "",
      "batteryAvailable": !!source.batteryAvailable,
      "battery": source.battery || 0,
      "signalStrength": source.signalStrength || 0
    };
  }

  function replaceDevice(device) {
    const updated = [];
    let replaced = false;
    for (let i = 0; i < root.devices.length; i++) {
      if (root.devices[i].address === device.address) {
        updated.push(device);
        replaced = true;
      } else {
        updated.push(root.devices[i]);
      }
    }
    if (!replaced)
      updated.push(device);
    root.devices = dedupeDevices(updated);
  }

  function devicesByAddress() {
    const byAddress = ({});
    for (let i = 0; i < root.devices.length; i++) {
      const dev = root.devices[i];
      if (dev && dev.address)
        byAddress[dev.address] = dev;
    }
    return byAddress;
  }

  function runNextInfo() {
    if (infoProcess.running || root._infoQueue.length === 0)
      return;

    root._infoAddress = root._infoQueue.shift();
    root._infoText = "";
    infoProcess.command = ["bluetoothctl", "info", root._infoAddress];
    infoProcess.running = true;
  }

  Process {
    id: showProcess
    running: false
    command: ["bluetoothctl", "show"]
    stdout: StdioCollector {
      onStreamFinished: root._showText = text
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          root.error = text.trim();
      }
    }
    onExited: exitCode => {
      if (exitCode === 0) {
        root.parseShow(root._showText);
        devicesProcess.running = true;
      } else {
        root.available = false;
        root.powered = false;
        root.devices = [];
        if (root.error === "")
          root.error = "bluetoothctl show failed";
      }
    }
  }

  Process {
    id: devicesProcess
    running: false
    command: ["bluetoothctl", "devices"]
    stdout: StdioCollector {
      onStreamFinished: root._devicesText = text
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          root.error = text.trim();
      }
    }
    onExited: exitCode => {
      if (exitCode === 0) {
        root.parseDevices(root._devicesText);
      } else if (root.error === "") {
        root.error = "bluetoothctl devices failed";
      }
    }
  }

  Process {
    id: infoProcess
    running: false
    stdout: StdioCollector {
      onStreamFinished: root._infoText = text
    }
    stderr: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0)
        root.parseDeviceInfo(root._infoAddress, root._infoText);
      root._infoAddress = "";
      root._infoText = "";
      root.runNextInfo();
    }
  }

  Process {
    id: scanProcess
    running: false
    command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          root.error = text.trim();
      }
    }
    onExited: {
      if (root.scanning && root.powered) {
        refreshDebouncer.restart();
        scanRestartTimer.restart();
      }
    }
  }

  Process {
    id: scanOffProcess
    running: false
    command: ["bluetoothctl", "scan", "off"]
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          root.error = text.trim();
      }
    }
    onExited: refreshDebouncer.restart()
  }

  Timer {
    id: scanRestartTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (root.scanning && root.powered && !scanProcess.running)
        scanProcess.running = true;
    }
  }

  Process {
    id: pairProcess
    running: false
    stdinEnabled: true
    command: ["bluetoothctl", "--timeout", "45"]
    onStarted: {
      pairProcess.write("agent NoInputNoOutput\n");
      pairProcess.write("default-agent\n");
      pairProcess.write("pair " + root._pairAddress + "\n");
      pairProcess.write("quit\n");
    }
    stdout: StdioCollector {
      onStreamFinished: root._pairOutput = text
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          root.error = text.trim();
      }
    }
    onExited: exitCode => {
      if (exitCode !== 0 || root._pairOutput.match(/(Failed|Authentication|not available|rejected|timeout)/i)) {
        root.error = root.error || "Bluetooth pairing failed. Authenticated PIN pairing is not supported by this Ryoku adapter.";
      }
      root._pairAddress = "";
      root._pairOutput = "";
      root.clearBusy();
      refreshDebouncer.restart();
    }
  }

  Process {
    id: actionProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          root.error = text.trim();
      }
    }
    onExited: exitCode => {
      if (exitCode !== 0 && root.error === "")
        root.error = "bluetoothctl command failed";

      root.clearBusy();
      if (root._actionQueue.length > 0) {
        root.runNextAction();
      } else {
        refreshDebouncer.restart();
      }
    }
  }
}
