import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Modules.Panels.Settings
import qs.noctalia.Services.System
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

NIconButtonHot {
  property ShellScreen screen

  enabled: ProgramCheckerService.wlsunsetAvailable
  icon: Settings.data.nightLight.enabled ? (Settings.data.nightLight.forced ? "nightlight-forced" : "nightlight-on") : "nightlight-off"
  hot: Settings.data.nightLight.enabled
  tooltipText: I18n.tr("common.night-light")

  onClicked: {
    if (!Settings.data.nightLight.enabled) {
      Settings.data.nightLight.enabled = true;
      Settings.data.nightLight.forced = false;
    } else if (Settings.data.nightLight.enabled && !Settings.data.nightLight.forced) {
      Settings.data.nightLight.forced = true;
    } else {
      Settings.data.nightLight.enabled = false;
      Settings.data.nightLight.forced = false;
    }
  }

  onRightClicked: {
    var settingsPanel = PanelService.getPanel("settingsPanel", screen);
    settingsPanel.requestedTab = SettingsPanel.Tab.Display;
    settingsPanel.open();
  }
}
