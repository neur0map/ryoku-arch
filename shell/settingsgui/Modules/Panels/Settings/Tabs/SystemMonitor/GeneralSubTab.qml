import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var screen

  NToggle {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    label: I18n.tr("panels.system-monitor.enable-dgpu-monitoring-label")
    description: I18n.tr("panels.system-monitor.enable-dgpu-monitoring-description")
    checked: GlobalConfig.systemMonitor.enableDgpuMonitoring
    defaultValue: false
    onToggled: checked => {
                 GlobalConfig.systemMonitor.enableDgpuMonitoring = checked;
                 GlobalConfig.save();
               }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NToggle {
      label: I18n.tr("panels.system-monitor.use-custom-highlight-colors-label")
      description: I18n.tr("panels.system-monitor.use-custom-highlight-colors-description")
      checked: GlobalConfig.systemMonitor.useCustomColors
      defaultValue: false
      onToggled: checked => {
                   // If enabling custom colors and no custom color is saved, persist current theme colors
                   if (checked) {
                     if (!GlobalConfig.systemMonitor.warningColor || GlobalConfig.systemMonitor.warningColor === "") {
                       GlobalConfig.systemMonitor.warningColor = Color.mTertiary.toString();
                     }
                     if (!GlobalConfig.systemMonitor.criticalColor || GlobalConfig.systemMonitor.criticalColor === "") {
                       GlobalConfig.systemMonitor.criticalColor = Color.mError.toString();
                     }
                   }
                   GlobalConfig.systemMonitor.useCustomColors = checked;
                   GlobalConfig.save();
                 }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginXL
    visible: GlobalConfig.systemMonitor.useCustomColors

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NText {
        text: I18n.tr("panels.system-monitor.warning-color-label")
        pointSize: Style.fontSizeM
      }

      NColorPicker {
        screen: root.screen
        Layout.preferredWidth: Style.sliderWidth
        Layout.preferredHeight: Style.baseWidgetSize
        enabled: GlobalConfig.systemMonitor.useCustomColors
        selectedColor: GlobalConfig.systemMonitor.warningColor || Color.mTertiary
        onColorSelected: color => {
                           GlobalConfig.systemMonitor.warningColor = color;
                           GlobalConfig.save();
                         }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NText {
        text: I18n.tr("panels.system-monitor.critical-color-label")
        pointSize: Style.fontSizeM
      }

      NColorPicker {
        screen: root.screen
        Layout.preferredWidth: Style.sliderWidth
        Layout.preferredHeight: Style.baseWidgetSize
        enabled: GlobalConfig.systemMonitor.useCustomColors
        selectedColor: GlobalConfig.systemMonitor.criticalColor || Color.mError
        onColorSelected: color => {
                           GlobalConfig.systemMonitor.criticalColor = color;
                           GlobalConfig.save();
                         }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NTextInput {
    label: I18n.tr("panels.system-monitor.external-monitor-label")
    description: I18n.tr("panels.system-monitor.external-monitor-description")
    placeholderText: I18n.tr("panels.system-monitor.external-monitor-placeholder")
    text: GlobalConfig.systemMonitor.externalMonitor
    defaultValue: "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor"
    onTextChanged: {
      GlobalConfig.systemMonitor.externalMonitor = text;
      GlobalConfig.save();
    }
  }
}
