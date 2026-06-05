pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI

Singleton {
  id: root

  property bool isInhibited: false
  property string reason: I18n.tr("system.user-requested")
  property var activeInhibitors: []
  property var timeout: null // in seconds

  // True when the native Wayland IdleInhibitor is handling inhibition
  // (set by the IdleInhibitor element in MainScreen via the nativeInhibitor property)
  property bool nativeInhibitorAvailable: false

  function init() {
    Logger.i("IdleInhibitor", "Service started");
  }

  function addInhibitor(id, reason = "Application request") {
    if (activeInhibitors.includes(id)) {
      Logger.w("IdleInhibitor", "Inhibitor already active:", id);
      return false;
    }

    activeInhibitors.push(id);
    updateInhibition(reason);
    Logger.d("IdleInhibitor", "Added inhibitor:", id);
    return true;
  }

  function removeInhibitor(id) {
    const index = activeInhibitors.indexOf(id);
    if (index === -1) {
      Logger.w("IdleInhibitor", "Inhibitor not found:", id);
      return false;
    }

    activeInhibitors.splice(index, 1);
    updateInhibition();
    Logger.d("IdleInhibitor", "Removed inhibitor:", id);
    return true;
  }

  function updateInhibition(newReason = reason) {
    const shouldInhibit = activeInhibitors.length > 0;

    if (shouldInhibit === isInhibited) {
      return;
    }

    if (shouldInhibit) {
      startInhibition(newReason);
    } else {
      stopInhibition();
    }
  }

  function startInhibition(newReason) {
    reason = newReason;

    if (nativeInhibitorAvailable) {
      // Native IdleInhibitor in MainScreen handles it via isInhibited binding
      Logger.d("IdleInhibitor", "Native inhibitor active");
    } else {
      startSubprocessInhibition();
    }

    isInhibited = true;
    Logger.i("IdleInhibitor", "Started inhibition:", reason);
  }

  function stopInhibition() {
    if (!isInhibited)
      return;

    if (!nativeInhibitorAvailable && inhibitorProcess.running) {
      inhibitorProcess.signal(15); // SIGTERM
    }

    isInhibited = false;
    Logger.i("IdleInhibitor", "Stopped inhibition");
  }

  function startSubprocessInhibition() {
    inhibitorProcess.command = ["systemd-inhibit", "--what=idle", "--why=" + reason, "--mode=block", "sleep", "infinity"];
    inhibitorProcess.running = true;
  }

  Process {
    id: inhibitorProcess
    running: false

    onExited: function (exitCode, exitStatus) {
      if (isInhibited) {
        Logger.w("IdleInhibitor", "Inhibitor process exited unexpectedly:", exitCode);
        isInhibited = false;
      }
    }

    onStarted: function () {
      Logger.d("IdleInhibitor", "Inhibitor process started successfully");
    }
  }

  Timer {
    id: inhibitorTimeout
    repeat: true
    interval: 1000 // 1 second
    onTriggered: function () {
      if (timeout == null) {
        inhibitorTimeout.stop();
        return;
      }

      timeout -= 1;
      if (timeout <= 0) {
        removeManualInhibitor();
        return;
      }
    }
  }

  function manualToggle() {
    timeout = null;
    if (activeInhibitors.includes("manual")) {
      removeManualInhibitor();
      return false;
    } else {
      addManualInhibitor(null);
      return true;
    }
  }

  function changeTimeout(delta) {
    if (timeout == null && delta < 0) {
      return;
    }

    if (timeout == null && delta > 0) {
      addManualInhibitor(timeout + delta);
      return;
    }

    if (timeout + delta <= 0) {
      removeManualInhibitor();
      return;
    }

    if (timeout + delta > 0) {
      addManualInhibitor(timeout + delta);
      return;
    }
  }

  function removeManualInhibitor() {
    if (timeout !== null) {
      timeout = null;
      if (inhibitorTimeout.running) {
        inhibitorTimeout.stop();
      }
    }

    if (activeInhibitors.includes("manual")) {
      removeInhibitor("manual");
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.disabled"), "keep-awake-off");
      Logger.i("IdleInhibitor", "Manual inhibition disabled");
    }
  }

  function addManualInhibitor(timeoutSec) {
    if (!activeInhibitors.includes("manual")) {
      addInhibitor("manual", "Manually activated by user");
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.enabled"), "keep-awake-on");
    }

    if (timeoutSec === null && timeout === null) {
      Logger.i("IdleInhibitor", "Manual inhibition enabled");
      return;
    } else if (timeoutSec !== null && timeout === null) {
      timeout = timeoutSec;
      inhibitorTimeout.start();
      Logger.i("IdleInhibitor", "Manual inhibition enabled with timeout:", timeoutSec);
      return;
    } else if (timeoutSec !== null && timeout !== null) {
      timeout = timeoutSec;
      Logger.i("IdleInhibitor", "Manual inhibition timeout changed to:", timeoutSec);
      return;
    } else if (timeoutSec === null && timeout !== null) {
      timeout = null;
      inhibitorTimeout.stop();
      Logger.i("IdleInhibitor", "Manual inhibition timeout cleared");
      return;
    }
  }

  // Clean up on shutdown
  Component.onDestruction: {
    stopInhibition();
  }
}
