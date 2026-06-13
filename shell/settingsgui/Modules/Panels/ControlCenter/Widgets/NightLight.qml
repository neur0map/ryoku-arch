import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Panels.Settings
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  enabled: ProgramCheckerService.wlsunsetAvailable
  icon: GlobalConfig.nightLight.enabled ? (GlobalConfig.nightLight.forced ? "nightlight-forced" : "nightlight-on") : "nightlight-off"
  hot: GlobalConfig.nightLight.enabled
  tooltipText: I18n.tr("common.night-light")

  onClicked: {
    if (!GlobalConfig.nightLight.enabled) {
      GlobalConfig.nightLight.enabled = true;
      GlobalConfig.nightLight.forced = false;
    } else if (GlobalConfig.nightLight.enabled && !GlobalConfig.nightLight.forced) {
      GlobalConfig.nightLight.forced = true;
    } else {
      GlobalConfig.nightLight.enabled = false;
      GlobalConfig.nightLight.forced = false;
    }
    GlobalConfig.save();
  }

  onRightClicked: {
    var settingsPanel = PanelService.getPanel("settingsPanel", screen);
    settingsPanel.requestedTab = SettingsPanel.Tab.Display;
    settingsPanel.open();
  }
}
