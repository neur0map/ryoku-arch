import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.Hardware
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  ColumnLayout {
    spacing: Style.marginL

    // RYOKU WIRED: per-screen brightness via Brightness.getMonitorForScreen (Brightness.qml:22)
    Repeater {
      model: Quickshell.screens || []
      delegate: NBox {
        id: monitorBox
        Layout.fillWidth: true
        implicitHeight: Math.round(contentCol.implicitHeight + Style.margin2L)
        color: Color.mSurface

        // RYOKU WIRED: Brightness singleton from qs.services
        property var ryokuMonitor: Brightness.getMonitorForScreen(modelData)
        property real localBrightness: ryokuMonitor ? ryokuMonitor.brightness : 0.5
        property bool localBrightnessChanging: false

        onRyokuMonitorChanged: {
          if (ryokuMonitor && !localBrightnessChanging)
            localBrightness = ryokuMonitor.brightness;
        }

        Connections {
          target: monitorBox.ryokuMonitor ?? null
          ignoreUnknownSignals: true
          function onBrightnessChanged() {
            if (!monitorBox.localBrightnessChanging)
              monitorBox.localBrightness = monitorBox.ryokuMonitor.brightness;
          }
        }

        Timer {
          id: debounceTimer
          interval: 120
          repeat: false
          onTriggered: {
            if (monitorBox.ryokuMonitor)
              monitorBox.ryokuMonitor.setBrightness(monitorBox.localBrightness);
          }
        }

        ColumnLayout {
          id: contentCol
          width: parent.width - Style.margin2L
          x: Style.marginL
          y: Style.marginL
          spacing: Style.marginXXS

          RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom

            NText {
              text: modelData.name || "Unknown"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightSemiBold
              Layout.alignment: Qt.AlignBottom
            }

            NText {
              Layout.fillWidth: true
              readonly property real compositorScale: {
                const info = CompositorService.displayScales[modelData.name];
                return (info && info.scale) ? info.scale : 1.0;
              }
              text: {
                I18n.tr("system.monitor-description", {
                          "model": modelData.model,
                          "width": modelData.width * compositorScale,
                          "height": modelData.height * compositorScale,
                          "scale": compositorScale
                        });
              }
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignRight
              Layout.alignment: Qt.AlignBottom
            }
          }

          ColumnLayout {
            spacing: Style.marginS
            Layout.fillWidth: true
            visible: monitorBox.ryokuMonitor !== undefined && monitorBox.ryokuMonitor !== null

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginL

              NText {
                text: I18n.tr("common.brightness")
                Layout.preferredWidth: 90
                Layout.alignment: Qt.AlignVCenter
              }

              NValueSlider {
                // RYOKU WIRED: Brightness.getMonitorForScreen().setBrightness() (Brightness.qml:199)
                id: brightnessSlider
                from: 0
                to: 1
                value: monitorBox.localBrightness
                stepSize: 0.01
                enabled: monitorBox.ryokuMonitor !== null
                onMoved: value => {
                           monitorBox.localBrightness = value;
                           debounceTimer.restart();
                         }
                Layout.fillWidth: true
              }

              NText {
                text: monitorBox.ryokuMonitor ? Math.round(monitorBox.localBrightness * 100) + "%" : "N/A"
                Layout.preferredWidth: 55
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
              }

              Item {
                Layout.preferredWidth: 30
                Layout.fillHeight: true
                NIcon {
                  icon: "device-desktop"
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            NComboBox {
              // TODO: wire backlight device picker to ryoku (no enumerated backlight device list in ryoku)
              Layout.fillWidth: true
              visible: false
              label: I18n.tr("panels.display.monitors-backlight-device-label")
              description: I18n.tr("panels.display.monitors-backlight-device-description")
              enabled: false
              opacity: 0.45
              model: []
              currentKey: ""
            }
          }
        }
      }
    }

    NSpinBox {
      // RYOKU WIRED: GlobalConfig.services.brightnessIncrement (serviceconfig.hpp:29) — stored as 0.0-1.0, displayed as integer %
      Layout.fillWidth: true
      label: I18n.tr("panels.display.monitors-brightness-step-label")
      description: I18n.tr("panels.display.monitors-brightness-step-description")
      minimum: 1
      maximum: 50
      value: Math.round(GlobalConfig.services.brightnessIncrement * 100)
      stepSize: 1
      suffix: "%"
      onValueChanged: {
        const newVal = value / 100;
        if (Math.abs(GlobalConfig.services.brightnessIncrement - newVal) > 0.001) {
          GlobalConfig.services.brightnessIncrement = newVal;
          GlobalConfig.save();
        }
      }
    }

    NToggle {
      // RYOKU WIRED: GlobalConfig.services.brightnessEnforceMin (serviceconfig.hpp)
      Layout.fillWidth: true
      label: I18n.tr("panels.display.monitors-enforce-minimum-label")
      description: I18n.tr("panels.display.monitors-enforce-minimum-description")
      checked: GlobalConfig.services.brightnessEnforceMin
      onToggled: checked => {
                   GlobalConfig.services.brightnessEnforceMin = checked;
                   GlobalConfig.save();
                 }
    }

    NToggle {
      // RYOKU WIRED: GlobalConfig.services.brightnessDdc (serviceconfig.hpp). ryoku
      // auto-detects DDC; this toggles whether it is used for external monitors.
      Layout.fillWidth: true
      label: I18n.tr("panels.display.monitors-external-brightness-label")
      description: I18n.tr("panels.display.monitors-external-brightness-description")
      checked: GlobalConfig.services.brightnessDdc
      onToggled: checked => {
                   GlobalConfig.services.brightnessDdc = checked;
                   GlobalConfig.save();
                 }
    }
  }
}
