pragma Singleton

import Quickshell

Singleton {
  property real volume: 0
  property bool muted: false
  property real inputVolume: 0
  property bool inputMuted: false
  property bool isSwitchingSink: false
  property var sink: null
  property var source: null
  property var sinks: []
  property var sources: []

  function init() {}

  function setVolume(value) {
    volume = value;
  }

  function setOutputMuted(value) {
    muted = value;
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
}
