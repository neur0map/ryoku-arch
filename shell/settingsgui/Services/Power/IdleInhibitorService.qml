pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI

// Keep-awake control surface for the bar and control-center widgets.
//
// This is an ADAPTER over the single keep-awake source of truth, qs.services
// IdleInhibitor (backed by ryoku-cmd-caffeine: one systemd idle:sleep inhibitor
// plus the Wayland idle-inhibitor, persisted across restarts). It owns no
// inhibitor of its own — every toggle drives IdleInhibitor.enabled — so the bar,
// the control center and the island "Keep Awake" card can no longer diverge (the
// bug where one read "off" while a stale second inhibitor still blocked the
// screensaver / DPMS / lock). The optional countdown timer just flips
// IdleInhibitor off when it expires.
Singleton {
  id: root

  // Single source of truth: mirror the shared inhibitor.
  readonly property bool isInhibited: IdleInhibitor.enabled
  property string reason: I18n.tr("system.user-requested")
  property var timeout: null // seconds remaining; null = indefinite / off

  // Set true by MainScreen's native Wayland inhibitor when that surface is
  // loaded. Ryoku does not load MainScreen, so it stays false; kept for parity
  // with the upstream settings shell.
  property bool nativeInhibitorAvailable: false

  function init() {
    Logger.i("IdleInhibitor", "Service started");
  }

  function setInhibited(on, why) {
    if (why !== undefined)
      reason = why;
    if (IdleInhibitor.enabled !== on)
      IdleInhibitor.enabled = on;
  }

  // Compatibility shims for any application-driven inhibition. Nothing currently
  // calls these, but keep the API: they drive the same shared inhibitor.
  function addInhibitor(id, why) {
    setInhibited(true, why ?? reason);
    return true;
  }

  function removeInhibitor(id) {
    clearTimer();
    setInhibited(false);
    return true;
  }

  function manualToggle() {
    clearTimer();
    const next = !IdleInhibitor.enabled;
    setInhibited(next);
    ToastService.showNotice(I18n.tr("tooltips.keep-awake"), next ? I18n.tr("common.enabled") : I18n.tr("common.disabled"), next ? "keep-awake-on" : "keep-awake-off");
    return next;
  }

  // Mouse-wheel timed keep-awake from the bar pill.
  function changeTimeout(delta) {
    if (timeout === null && delta < 0)
      return; // nothing to wind down

    const next = (timeout === null ? 0 : timeout) + delta;
    if (next <= 0) {
      clearTimer();
      setInhibited(false);
      return;
    }

    timeout = next;
    setInhibited(true);
    if (!countdown.running)
      countdown.start();
  }

  function clearTimer() {
    timeout = null;
    countdown.stop();
  }

  Timer {
    id: countdown
    repeat: true
    interval: 1000
    onTriggered: {
      if (root.timeout === null) {
        stop();
        return;
      }
      root.timeout -= 1;
      if (root.timeout <= 0) {
        root.timeout = null;
        stop();
        root.setInhibited(false);
      }
    }
  }
}
