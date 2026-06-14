import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Panels.Settings
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: GlobalConfig.nightLight.enabled ? Color.mPrimary : Style.capsuleColor
  colorFg: GlobalConfig.nightLight.enabled ? Color.mOnPrimary : Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  icon: GlobalConfig.nightLight.enabled ? (GlobalConfig.nightLight.forced ? "nightlight-forced" : "nightlight-on") : "nightlight-off"
  tooltipText: GlobalConfig.nightLight.enabled ? (GlobalConfig.nightLight.forced ? I18n.tr("common.night-light") : I18n.tr("common.night-light")) : I18n.tr("common.night-light")
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  onClicked: {
    // Check if wlsunset is available before enabling night light
    if (!ProgramCheckerService.wlsunsetAvailable) {
      ToastService.showWarning(I18n.tr("common.night-light"), I18n.tr("toast.night-light.not-installed"));
      return;
    }

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

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
