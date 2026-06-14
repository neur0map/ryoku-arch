import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.System
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  Layout.fillWidth: true

  NLabel {
    Layout.fillWidth: true
    description: I18n.tr("panels.system-monitor.thresholds-section-description")
  }

  GridLayout {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    columns: 3
    columnSpacing: Style.marginM
    rowSpacing: Style.marginM

    Item {
      Layout.fillWidth: true
    }

    NText {
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: I18n.tr("panels.system-monitor.threshold-warning")
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }

    NText {
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: I18n.tr("panels.system-monitor.threshold-critical")
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }

    NText {
      text: I18n.tr("bar.system-monitor.cpu-usage-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.cpuWarningThreshold
      defaultValue: 80
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.cpuWarningThreshold = value;
        if (GlobalConfig.systemMonitor.cpuCriticalThreshold < value) {
          GlobalConfig.systemMonitor.cpuCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: GlobalConfig.systemMonitor.cpuWarningThreshold
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.cpuCriticalThreshold
      defaultValue: 90
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.cpuCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      text: I18n.tr("bar.system-monitor.cpu-temperature-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.tempWarningThreshold
      defaultValue: 80
      suffix: "°C"
      onValueChanged: {
        GlobalConfig.systemMonitor.tempWarningThreshold = value;
        if (GlobalConfig.systemMonitor.tempCriticalThreshold < value) {
          GlobalConfig.systemMonitor.tempCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: GlobalConfig.systemMonitor.tempWarningThreshold
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.tempCriticalThreshold
      defaultValue: 90
      suffix: "°C"
      onValueChanged: {
        GlobalConfig.systemMonitor.tempCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      visible: SystemStatService.gpuAvailable
      text: I18n.tr("panels.system-monitor.gpu-section-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      visible: SystemStatService.gpuAvailable
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 120
      stepSize: 5
      value: GlobalConfig.systemMonitor.gpuWarningThreshold
      defaultValue: 80
      suffix: "°C"
      onValueChanged: {
        GlobalConfig.systemMonitor.gpuWarningThreshold = value;
        if (GlobalConfig.systemMonitor.gpuCriticalThreshold < value) {
          GlobalConfig.systemMonitor.gpuCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      visible: SystemStatService.gpuAvailable
      Layout.alignment: Qt.AlignHCenter
      from: GlobalConfig.systemMonitor.gpuWarningThreshold
      to: 120
      stepSize: 5
      value: GlobalConfig.systemMonitor.gpuCriticalThreshold
      defaultValue: 90
      suffix: "°C"
      onValueChanged: {
        GlobalConfig.systemMonitor.gpuCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      text: I18n.tr("bar.system-monitor.memory-usage-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.memWarningThreshold
      defaultValue: 80
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.memWarningThreshold = value;
        if (GlobalConfig.systemMonitor.memCriticalThreshold < value) {
          GlobalConfig.systemMonitor.memCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: GlobalConfig.systemMonitor.memWarningThreshold
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.memCriticalThreshold
      defaultValue: 90
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.memCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      text: I18n.tr("bar.system-monitor.swap-usage-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.swapWarningThreshold
      defaultValue: 80
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.swapWarningThreshold = value;
        if (GlobalConfig.systemMonitor.swapCriticalThreshold < value) {
          GlobalConfig.systemMonitor.swapCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: GlobalConfig.systemMonitor.swapWarningThreshold
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.swapCriticalThreshold
      defaultValue: 90
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.swapCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      text: I18n.tr("panels.system-monitor.disk-section-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.diskWarningThreshold
      defaultValue: 80
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.diskWarningThreshold = value;
        if (GlobalConfig.systemMonitor.diskCriticalThreshold < value) {
          GlobalConfig.systemMonitor.diskCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: GlobalConfig.systemMonitor.diskWarningThreshold
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.diskCriticalThreshold
      defaultValue: 90
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.diskCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      text: I18n.tr("panels.system-monitor.disk-available-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.diskAvailWarningThreshold
      defaultValue: 20
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.diskAvailWarningThreshold = value;
        if (GlobalConfig.systemMonitor.diskAvailCriticalThreshold > value) {
          GlobalConfig.systemMonitor.diskAvailCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 20
      stepSize: 5
      value: GlobalConfig.systemMonitor.diskAvailCriticalThreshold
      defaultValue: 10
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.diskAvailCriticalThreshold = value;
        GlobalConfig.save();
      }
    }

    NText {
      text: I18n.tr("panels.notifications.toast-battery-label")
      pointSize: Style.fontSizeM
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: 100
      stepSize: 5
      value: GlobalConfig.systemMonitor.batteryWarningThreshold
      defaultValue: 20
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.batteryWarningThreshold = value;
        if (GlobalConfig.systemMonitor.batteryCriticalThreshold > value) {
          GlobalConfig.systemMonitor.batteryCriticalThreshold = value;
        }
        GlobalConfig.save();
      }
    }

    NSpinBox {
      Layout.alignment: Qt.AlignHCenter
      from: 0
      to: GlobalConfig.systemMonitor.batteryWarningThreshold
      stepSize: 5
      value: GlobalConfig.systemMonitor.batteryCriticalThreshold
      defaultValue: 5
      suffix: "%"
      onValueChanged: {
        GlobalConfig.systemMonitor.batteryCriticalThreshold = value;
        GlobalConfig.save();
      }
    }
  }
}
