pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons

// Orchestrates the Display > Monitors settings flow on top of CompositorService.
//
// Responsibilities (kept out of the settings view so they are reusable and testable):
//   - build the normalized, view-ready monitor list,
//   - own the apply -> confirm-or-revert state machine + countdown,
//   - guard against disabling the last active output (a blank-screen footgun),
//   - suggest a scale from EDID physical size,
//   - route apply/persist/revert through the active compositor backend.
//
// All system mutations live in the `ryoku-monitor` bash helper (per Ryoku's rule that
// package/sudo/systemd/compositor-config logic belongs in a ryoku-* command, not QML).
// This service only sequences and guards them; the backend translates a neutral config
// object into compositor syntax.
Singleton {
  id: root

  // True only when the active compositor can actually apply + persist monitor layout
  // (Hyprland). On other backends the Monitors tab shows an informational message
  // instead of controls that would silently no-op.
  readonly property bool supported: CompositorService.monitorConfigSupported === true

  // Normalized monitor list: the authoritative connected-screen list (Quickshell.screens)
  // enriched with hyprctl-parsed details (modes/refresh/transform/physical size...).
  // displayScales alone can be empty at first render, so we never iterate it directly.
  readonly property var monitors: {
    var screens = Quickshell.screens || [];
    var ds = CompositorService.displayScales || ({});
    var out = [];
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i];
      var d = ds[s.name] || ({});
      out.push({
                 "name": s.name,
                 "description": d.description || s.model || s.name,
                 "width": d.width || s.width || 0,
                 "height": d.height || s.height || 0,
                 "refresh_rate": d.refresh_rate || 60,
                 "scale": d.scale || s.scale || 1.0,
                 "transform": d.transform || 0,
                 "disabled": d.disabled || false,
                 "mirrorOf": d.mirrorOf || "none",
                 "vrr": d.vrr || false,
                 "availableModes": d.availableModes || [],
                 "physicalWidth": d.physicalWidth || 0,
                 "physicalHeight": d.physicalHeight || 0,
                 "x": d.x || 0,
                 "y": d.y || 0
               });
    }
    return out;
  }

  // Number of currently-enabled outputs (reactive: tracks `monitors`).
  readonly property int enabledCount: {
    var n = 0;
    var ms = monitors;
    for (var i = 0; i < ms.length; i++)
      if (!ms[i].disabled)
        n++;
    return n;
  }

  // ---- apply -> confirm-or-revert state (bound by the Monitors tab) ----
  readonly property int confirmTimeout: 15
  property bool pendingActive: false
  property string pendingMonitor: ""
  property int remaining: confirmTimeout
  property var _prevConfig: null

  // Emitted with an i18n KEY when an apply is refused, so the view can toast it.
  signal blocked(string reasonKey)

  // Re-query live monitor state (modes/refresh populate asynchronously).
  function refresh() {
    CompositorService.updateDisplayScales();
  }

  // Structured, compositor-neutral config snapshot of a monitor's current live state.
  function currentConfigOf(m) {
    return {
      "name": m.name,
      "enabled": !m.disabled,
      "width": m.width,
      "height": m.height,
      "refreshRate": Math.round(m.refresh_rate),
      "x": m.x,
      "y": m.y,
      "scale": m.scale,
      "transform": m.transform,
      "mirror": m.mirrorOf || "none",
      "vrr": m.vrr || false
    };
  }

  // Would applying `cfg` leave zero enabled outputs? (disabling the last active screen)
  function wouldBlankAllScreens(cfg) {
    if (cfg.enabled)
      return false;
    var ms = monitors;
    for (var i = 0; i < ms.length; i++) {
      if (ms[i].name === cfg.name)
        continue;
      if (!ms[i].disabled)
        return false; // another output stays on
    }
    return true; // cfg is the only enabled output and it's being turned off
  }

  // Apply `cfg` live (preview) and arm the confirm-or-revert timer. `prevConfig` is the
  // snapshot re-applied on revert/timeout. Returns false (and emits blocked) when the
  // compositor is unsupported or the change would black out every screen.
  function applyWithConfirm(cfg, prevConfig) {
    if (!supported) {
      Logger.w("DisplayService", "Monitor config unsupported on this compositor");
      blocked("panels.display.unsupported-body");
      return false;
    }
    if (wouldBlankAllScreens(cfg)) {
      Logger.w("DisplayService", "Refused to disable the last active output:", cfg.name);
      blocked("panels.display.last-output-body");
      return false;
    }
    _prevConfig = prevConfig;
    pendingMonitor = cfg.name;
    CompositorService.applyMonitorConfig(cfg);
    remaining = confirmTimeout;
    pendingActive = true;
    countdown.restart();
    return true;
  }

  // Confirm: persist the live layout to the compositor config.
  function keep() {
    countdown.stop();
    pendingActive = false;
    _prevConfig = null;
    CompositorService.persistMonitors();
  }

  // Revert: re-apply the pre-change snapshot, do not persist.
  function revert() {
    countdown.stop();
    pendingActive = false;
    if (_prevConfig)
      CompositorService.applyMonitorConfig(_prevConfig);
    _prevConfig = null;
  }

  // Suggest a scale from EDID physical size (mm) + chosen resolution -> DPI bucket.
  // Reliable enough to seed the "Auto scale" control without baking a distro-wide default.
  function suggestScale(physicalWidth, physicalHeight, resString) {
    var parts = String(resString).split("x");
    var w = parseInt(parts[0]);
    var h = parseInt(parts[1]);
    if (physicalWidth <= 0 || physicalHeight <= 0 || !w || !h)
      return 1.0;
    var diagIn = Math.sqrt(physicalWidth * physicalWidth + physicalHeight * physicalHeight) / 25.4;
    var dpi = Math.sqrt(w * w + h * h) / diagIn;
    if (dpi <= 120)
      return 1.0;
    if (dpi <= 160)
      return 1.25;
    if (dpi <= 200)
      return 1.5;
    return 2.0;
  }

  Timer {
    id: countdown
    interval: 1000
    repeat: true
    onTriggered: {
      root.remaining -= 1;
      if (root.remaining <= 0)
        root.revert();
    }
  }
}
