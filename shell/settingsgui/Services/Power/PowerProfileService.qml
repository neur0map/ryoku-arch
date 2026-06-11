pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI

Singleton {
  id: root

  readonly property var powerProfiles: PowerProfiles
  readonly property bool available: powerProfiles && powerProfiles.hasPerformanceProfile
  property int profile: powerProfiles ? powerProfiles.profile : PowerProfile.Balanced

  // Not a power profile but a volatile property to quickly disable shadows, animations, etc..
  property bool performanceMode: false

  // Game mode drives performanceMode and the power profile together; it calls
  // beginGameModeSync() so the standalone toasts below stay quiet while game
  // mode is the change source (the profile PropertiesChanged is async and can
  // land after game mode's handler returns, so we suppress on a short window).
  property bool gameModeSync: false
  Timer {
    id: gameModeSyncTimer
    interval: 2000
    onTriggered: root.gameModeSync = false
  }
  function beginGameModeSync() {
    root.gameModeSync = true;
    gameModeSyncTimer.restart();
  }

  function getName(p) {
    if (!available)
      return "Unknown";

    const prof = (p !== undefined) ? p : profile;

    switch (prof) {
    case PowerProfile.Performance:
      return "Performance";
    case PowerProfile.Balanced:
      return "Balanced";
    case PowerProfile.PowerSaver:
      return "Power saver";
    default:
      return "Unknown";
    }
  }

  function getIcon(p) {
    if (!available)
      return "balanced";

    const prof = (p !== undefined) ? p : profile;

    switch (prof) {
    case PowerProfile.Performance:
      return "performance";
    case PowerProfile.Balanced:
      return "balanced";
    case PowerProfile.PowerSaver:
      return "powersaver";
    default:
      return "balanced";
    }
  }

  function init() {
    Logger.d("PowerProfileService", "Service started");
  }

  function setProfile(p) {
    if (!available)
      return;
    try {
      powerProfiles.profile = p;
    } catch (e) {
      Logger.e("PowerProfileService", "Failed to set profile:", e);
    }
  }

  function cycleProfile() {
    if (!available)
      return;
    const current = powerProfiles.profile;
    if (current === PowerProfile.Performance)
      setProfile(PowerProfile.PowerSaver);
    else if (current === PowerProfile.Balanced)
      setProfile(PowerProfile.Performance);
    else if (current === PowerProfile.PowerSaver)
      setProfile(PowerProfile.Balanced);
  }

  function cycleProfileReverse() {
    if (!available)
      return;
    const current = powerProfiles.profile;
    if (current === PowerProfile.Performance)
      setProfile(PowerProfile.Balanced);
    else if (current === PowerProfile.Balanced)
      setProfile(PowerProfile.PowerSaver);
    else if (current === PowerProfile.PowerSaver)
      setProfile(PowerProfile.Performance);
  }

  function isDefault() {
    if (!available)
      return true;
    return (profile === PowerProfile.Balanced);
  }

  Connections {
    target: powerProfiles
    function onProfileChanged() {
      root.profile = powerProfiles.profile;
      if (root.gameModeSync)
        return;
      const profileName = root.getName();
      if (profileName !== "Unknown") {
        ToastService.showNotice(I18n.tr("toast.power-profile.profile-name", {
                                          "profile": profileName
                                        }), I18n.tr("toast.power-profile.changed"), profileName.toLowerCase().replace(" ", ""));
      }
    }
  }

  // Performance Mode
  // - Turning shadow off
  // - Turning animation off
  // - Do Not Disturb
  function togglePerformanceMode() {
    performanceMode = !performanceMode;
  }

  function setPerformanceMode(value) {
    performanceMode = value;
  }

  onPerformanceModeChanged: {
    if (root.gameModeSync)
      return;
    if (performanceMode) {
      ToastService.showNotice(I18n.tr("toast.performance-mode.label"), I18n.tr("toast.performance-mode.enabled"), "rocket");
    } else {
      ToastService.showNotice(I18n.tr("toast.performance-mode.label"), I18n.tr("toast.performance-mode.disabled"), "rocket-off");
    }
  }
}
