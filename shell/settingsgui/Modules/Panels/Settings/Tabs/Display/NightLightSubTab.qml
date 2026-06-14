import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Location
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var timeOptions

  signal checkWlsunset

  NToggle {
    label: I18n.tr("panels.display.night-light-enable-label")
    description: I18n.tr("panels.display.night-light-enable-description")
    checked: GlobalConfig.nightLight.enabled
    onToggled: checked => {
                 if (checked) {
                   root.checkWlsunset();
                 } else {
                   GlobalConfig.nightLight.enabled = false;
                   GlobalConfig.nightLight.forced = false;
                   GlobalConfig.save();
                   NightLightService.apply();
                   ToastService.showNotice(I18n.tr("common.night-light"), I18n.tr("common.disabled"), "nightlight-off");
                 }
               }
  }

  ColumnLayout {
    enabled: GlobalConfig.nightLight.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NLabel {
      label: I18n.tr("panels.display.night-light-temperature-night")
      description: I18n.tr("panels.display.night-light-temperature-night-description")
      Layout.fillWidth: true
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NSlider {
        id: nightSlider
        Layout.fillWidth: true
        from: 1000
        to: 6500
        value: GlobalConfig.nightLight.nightTemp

        onValueChanged: {
          var dayTemp = parseInt(GlobalConfig.nightLight.dayTemp);
          var v = Math.round(value);
          if (!isNaN(dayTemp)) {
            var maxNight = dayTemp - 500;
            v = Math.min(maxNight, Math.max(1000, v));
          } else {
            v = Math.max(1000, v);
          }
          if (v !== value)
            value = v;
        }

        onPressedChanged: {
          if (!pressed) {
            var dayTemp = parseInt(GlobalConfig.nightLight.dayTemp);
            var v = Math.round(value);
            if (!isNaN(dayTemp)) {
              var maxNight = dayTemp - 500;
              v = Math.min(maxNight, Math.max(1000, v));
            } else {
              v = Math.max(1000, v);
            }
            GlobalConfig.nightLight.nightTemp = v;
            GlobalConfig.save();
          }
        }
      }

      NText {
        text: nightSlider.value + "K"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignVCenter
      }
    }

    NLabel {
      label: I18n.tr("panels.display.night-light-temperature-day")
      description: I18n.tr("panels.display.night-light-temperature-day-description")
      Layout.fillWidth: true
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NSlider {
        id: daySlider
        Layout.fillWidth: true
        from: 1000
        to: 6500
        value: GlobalConfig.nightLight.dayTemp

        onValueChanged: {
          var nightTemp = parseInt(GlobalConfig.nightLight.nightTemp);
          var v = Math.round(value);
          if (!isNaN(nightTemp)) {
            var minDay = nightTemp + 500;
            v = Math.max(minDay, Math.min(6500, v));
          } else {
            v = Math.min(6500, v);
          }
          if (v !== value)
            value = v;
        }

        onPressedChanged: {
          if (!pressed) {
            var nightTemp = parseInt(GlobalConfig.nightLight.nightTemp);
            var v = Math.round(value);
            if (!isNaN(nightTemp)) {
              var minDay = nightTemp + 500;
              v = Math.max(minDay, Math.min(6500, v));
            } else {
              v = Math.min(6500, v);
            }
            GlobalConfig.nightLight.dayTemp = v;
            GlobalConfig.save();
          }
        }
      }

      NText {
        text: daySlider.value + "K"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignVCenter
      }
    }

    NToggle {
      label: I18n.tr("panels.display.night-light-auto-schedule-label")
      description: I18n.tr("panels.display.night-light-auto-schedule-description", {
                             "location": LocationService.stableName
                           })
      checked: GlobalConfig.nightLight.autoSchedule
      onToggled: checked => {
                   GlobalConfig.nightLight.autoSchedule = checked;
                   GlobalConfig.save();
                 }
    }

    ColumnLayout {
      spacing: Style.marginS
      Layout.fillWidth: true
      visible: !GlobalConfig.nightLight.autoSchedule && !GlobalConfig.nightLight.forced

      NLabel {
        label: I18n.tr("panels.display.night-light-manual-schedule-label")
        description: I18n.tr("panels.display.night-light-manual-schedule-description")
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: I18n.tr("panels.display.night-light-manual-schedule-sunrise")
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
          Layout.alignment: Qt.AlignVCenter
        }

        NComboBox {
          model: root.timeOptions
          currentKey: GlobalConfig.nightLight.manualSunrise
          placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-start")
          onSelected: key => {
            GlobalConfig.nightLight.manualSunrise = key;
            GlobalConfig.save();
          }
          Layout.fillWidth: true
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: I18n.tr("panels.display.night-light-manual-schedule-sunset")
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
          Layout.alignment: Qt.AlignVCenter
        }

        NComboBox {
          model: root.timeOptions
          currentKey: GlobalConfig.nightLight.manualSunset
          placeholder: I18n.tr("panels.display.night-light-manual-schedule-select-stop")
          onSelected: key => {
            GlobalConfig.nightLight.manualSunset = key;
            GlobalConfig.save();
          }
          Layout.fillWidth: true
        }
      }
    }

    NToggle {
      label: I18n.tr("panels.display.night-light-force-activation-label")
      description: I18n.tr("panels.display.night-light-force-activation-description")
      checked: GlobalConfig.nightLight.forced
      onToggled: checked => {
                   GlobalConfig.nightLight.forced = checked;
                   GlobalConfig.save();
                   if (checked && !GlobalConfig.nightLight.enabled) {
                     root.checkWlsunset();
                   } else {
                     NightLightService.apply();
                   }
                 }
    }
  }
}
