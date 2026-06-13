pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI

// Reads and applies Hyprland's primary render-device pin on multi-GPU machines via the
// ryoku-gpu helper, so Settings > Display > GPU can show the detected GPUs and let the
// user pick which one renders the desktop (and stream/screen-share from it).
//
// All hardware / sudo / udev / config logic lives in ryoku-gpu, per Ryoku's rule that
// system behavior belongs in a ryoku-* command, not a QML component. This service only
// sequences the command and surfaces its results.
Singleton {
  id: root

  // The render-device pin is an aquamarine (Hyprland) knob (AQ_DRM_DEVICES); other
  // compositors manage their GPU selection elsewhere.
  readonly property bool supported: CompositorService.isHyprland === true

  property var gpus: []
  property int ngpu: 0
  property string pinned: ""       // PCI slot of the currently pinned primary, or ""
  property string recommended: ""  // PCI slot the automatic policy would pin, or ""
  property bool isLaptop: false
  property bool configured: false  // gpu.lua currently carries an AQ_DRM_DEVICES pin
  property bool loading: false
  // AQ_DRM_DEVICES is read once at compositor start, so an applied change only takes
  // effect after the next Hyprland login. Flipped true once the user applies a change.
  property bool pendingRelogin: false

  // The choice the combo shows as current: the pinned slot, otherwise "auto".
  readonly property string selectedKey: (configured && pinned.length > 0) ? pinned : "auto"

  // Combo model: Automatic first, then one entry per detected GPU.
  readonly property var choices: {
    var list = [{
        "key": "auto",
        "name": I18n.tr("panels.display.gpu-automatic")
      }];
    for (var i = 0; i < gpus.length; i++)
      list.push({
                  "key": gpus[i].slot,
                  "name": gpuLabel(gpus[i])
                });
    return list;
  }

  function gpuLabel(g) {
    var name = (g.model && g.model.length > 0) ? g.model : (g.driver + " " + g.card);
    var bits = [I18n.tr("panels.display.gpu-class-" + g["class"])];
    if (g.vramMb && g.vramMb > 0)
      bits.push(Math.round(g.vramMb / 1024) + " GB");
    return name + " — " + bits.join(", ");
  }

  function refresh() {
    if (!supported)
      return;
    detectProc.running = true;
  }

  Process {
    id: detectProc
    command: ["ryoku-gpu", "detect-json"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("GpuService", "ryoku-gpu detect-json failed:", String(stderr.text || "").trim());
        return;
      }
      try {
        var d = JSON.parse(String(stdout.text || "{}"));
        root.gpus = d.gpus || [];
        root.ngpu = d.ngpu || 0;
        root.pinned = d.pinned || "";
        root.recommended = d.recommended || "";
        root.isLaptop = d.isLaptop || false;
        root.configured = d.configured || false;
      } catch (e) {
        Logger.e("GpuService", "Failed to parse detect-json:", e);
      }
    }
  }

  // Apply a choice: "auto" runs the automatic policy, any other key pins that PCI slot.
  function select(key) {
    if (!supported)
      return;
    applyProc.command = (key === "auto") ? ["ryoku-gpu", "auto"] : ["ryoku-gpu", "persist", key];
    root.loading = true;
    applyProc.running = true;
  }

  Process {
    id: applyProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function (code) {
      root.loading = false;
      if (code === 0) {
        root.pendingRelogin = true;
        ToastService.showNotice(I18n.tr("panels.display.gpu-title"), I18n.tr("panels.display.gpu-applied"));
        root.refresh();
      } else {
        var msg = String(stderr.text || "").trim();
        ToastService.showWarning(I18n.tr("panels.display.gpu-title"), msg.length > 0 ? msg : I18n.tr("panels.display.gpu-apply-failed"));
      }
    }
  }
}
