pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property real volume: 0
  property bool muted: false
  property real inputVolume: 0
  property bool inputMuted: false
  property bool isSwitchingSink: false
  property var sink: null
  property var source: null
  property var sinks: []
  property var sources: []
  property bool ryokuVolumeAvailable: true
  property var _volumeCommandQueue: []

  function init() {
    refresh();
  }

  function refresh() {
    if (!volumeQueryProcess.running)
      volumeQueryProcess.running = true;
  }

  function setVolume(value) {
    const clamped = Math.max(0, Math.min(1, value));
    const delta = Math.round((clamped - volume) * 100);
    volume = clamped;

    if (delta > 0) {
      runVolumeCommand(["ryoku-volume", "up", String(delta)]);
    } else if (delta < 0) {
      runVolumeCommand(["ryoku-volume", "down", String(Math.abs(delta))]);
    }
  }

  function setOutputMuted(value) {
    if (muted === value)
      return;

    muted = value;
    runVolumeCommand(["ryoku-volume", "mute-toggle"]);
  }

  function setInputVolume(value) {
    inputVolume = value;
  }

  function setInputMuted(value) {
    inputMuted = value;
  }

  function setAudioSink(value) {
    sink = value;
  }

  function setAudioSource(value) {
    source = value;
  }

  function runVolumeCommand(commandArgs) {
    if (volumeCommandProcess.running) {
      _volumeCommandQueue.push(commandArgs);
      return;
    }

    volumeCommandProcess.command = commandArgs;
    volumeCommandProcess.running = true;
  }

  function runNextVolumeCommand() {
    if (volumeCommandProcess.running || _volumeCommandQueue.length === 0) {
      return false;
    }

    const nextCommand = _volumeCommandQueue.shift();
    volumeCommandProcess.command = nextCommand;
    volumeCommandProcess.running = true;
    return true;
  }

  function parseWpctlVolume(output) {
    const match = String(output).match(/Volume:\s+([0-9.]+)/);
    if (match) {
      const parsed = Number(match[1]);
      if (!isNaN(parsed))
        volume = Math.max(0, Math.min(1, parsed));
    }

    muted = String(output).indexOf("[MUTED]") >= 0;
  }

  Timer {
    interval: 2500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: volumeQueryProcess
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    running: true
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.ryokuVolumeAvailable = exitCode === 0;
      if (exitCode === 0)
        root.parseWpctlVolume(stdout.text);
    }
  }

  Process {
    id: volumeCommandProcess
    command: ["true"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function () {
      if (!root.runNextVolumeCommand())
        root.refresh();
    }
  }
}
