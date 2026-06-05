pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons

// RYOKU STUB. Upstream uses PwAudioSpectrum — a bleeding-edge Quickshell
// native type not present in quickshell-ryoku — to drive the audio visualizer.
// ryoku has no spectrum source wired yet, so this is neutralized to keep the
// settings UI loadable. Public API is preserved so consumers don't break; it
// simply emits no spectrum data.
// TODO: wire to a ryoku audio-spectrum source (cava / Pipewire) when added.
Singleton {
  id: root

  function registerComponent(componentId) {}
  function unregisterComponent(componentId) {}
  function isRegistered(componentId) {
    return false;
  }

  property var _registeredComponents: ({})
  readonly property int _registeredCount: 0
  property bool _shouldRun: false

  property var values: []
  property bool isIdle: true
}
