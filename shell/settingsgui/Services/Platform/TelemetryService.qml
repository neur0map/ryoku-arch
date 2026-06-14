pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.System

Singleton {
  id: root

  property bool initialized: false
  property string instanceId: ""

  function init() {
    if (initialized)
      return;

    initialized = true;

    // RYOKU: telemetry network reporting is permanently disabled — Ryoku never
    // contacts any remote endpoint. We still resolve a local instance id so the
    // About > system-info view has a stable anonymous identifier to display.
    instanceId = ShellState.getTelemetryInstanceId();
    if (!instanceId) {
      instanceId = generateRandomId();
      ShellState.setTelemetryInstanceId(instanceId);
    }
  }

  function generateRandomId() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  function getInstanceId() {
    return instanceId;
  }


  function getCompositorType() {
    if (CompositorService.isHyprland)
      return "Hyprland";
    if (CompositorService.isNiri)
      return "Niri";
    if (CompositorService.isScroll)
      return "Scroll";
    if (CompositorService.isSway)
      return "Sway";
    if (CompositorService.isMango)
      return "MangoWC";
    if (CompositorService.isLabwc)
      return "LabWC";
    if (CompositorService.isExtWorkspace)
      return "ExtWorkspace";
    return "Unknown";
  }
}
