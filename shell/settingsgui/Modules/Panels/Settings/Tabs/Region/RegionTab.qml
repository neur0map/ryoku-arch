import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property bool autoLocate: GlobalConfig.services.weatherLocation === ""

  NLabel {
    label: I18n.tr("common.weather")
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.location.auto-locate-label")
      description: I18n.tr("panels.location.auto-locate-description")
      checked: root.autoLocate
      onToggled: checked => {
        root.autoLocate = checked;
        if (checked) {
          GlobalConfig.services.weatherLocation = "";
          GlobalConfig.save();
          Weather.reload();
        }
      }
    }

    NButton {
      text: I18n.tr("panels.location.geolocate-now-button")
      icon: "current-location"
      enabled: root.autoLocate
      onClicked: Weather.reload()
    }
  }

  NTextInput {
    visible: !root.autoLocate
    Layout.maximumWidth: root.width / 2
    label: I18n.tr("panels.location.location-search-label")
    description: I18n.tr("panels.location.location-search-description")
    text: GlobalConfig.services.weatherLocation
    placeholderText: I18n.tr("panels.location.location-search-placeholder")
    onEditingFinished: {
      var v = text.trim();
      if (v !== GlobalConfig.services.weatherLocation) {
        GlobalConfig.services.weatherLocation = v;
        GlobalConfig.save();
      }
    }
  }

  NText {
    visible: Weather.city !== ""
    text: Weather.loc ? Weather.city + " (" + Weather.loc + ")" : Weather.city
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    font.italic: true
  }

  NToggle {
    label: I18n.tr("panels.location.weather-fahrenheit-label")
    description: I18n.tr("panels.location.weather-fahrenheit-description")
    checked: GlobalConfig.services.useFahrenheit
    onToggled: checked => {
      GlobalConfig.services.useFahrenheit = checked;
      GlobalConfig.save();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NLabel {
    label: "Time"
    Layout.fillWidth: true
  }

  NToggle {
    label: I18n.tr("panels.location.date-time-12hour-format-label")
    description: "Use 12-hour (AM/PM) time across the bar clock, dashboard, desktop clock and weather."
    checked: GlobalConfig.services.useTwelveHourClock
    onToggled: checked => {
      GlobalConfig.services.useTwelveHourClock = checked;
      GlobalConfig.save();
    }
  }
}
