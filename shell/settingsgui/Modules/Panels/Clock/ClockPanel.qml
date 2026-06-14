import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Cards
import qs.settingsgui.Modules.MainScreen
import qs.settingsgui.Services.Location
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets
import Ryoku.Config

SmartPanel {
  id: root

  panelContent: Item {
    id: panelContent
    anchors.fill: parent

    readonly property real contentPreferredWidth: Math.round((GlobalConfig.calendar.showWeekNumberInCalendar ? 440 : 420) * Style.uiScaleRatio)
    readonly property real contentPreferredHeight: content.implicitHeight + Style.margin2L

    ColumnLayout {
      id: content
      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: Style.marginM

      Repeater {
        model: GlobalConfig.calendar.cards
        Loader {
          active: modelData.enabled && (modelData.id !== "weather-card" || Settings.data.location.weatherEnabled)
          visible: active
          Layout.fillWidth: true
          sourceComponent: {
            switch (modelData.id) {
            case "calendar-header-card":
              return calendarHeaderCard;
            case "calendar-month-card":
              return calendarMonthCard;
            case "weather-card":
              return weatherCard;
            default:
              return null;
            }
          }
        }
      }
    }
  }

  Component {
    id: calendarHeaderCard
    CalendarHeaderCard {
      Layout.fillWidth: true
    }
  }

  Component {
    id: calendarMonthCard
    CalendarMonthCard {
      Layout.fillWidth: true
    }
  }

  Component {
    id: weatherCard
    WeatherCard {
      Layout.fillWidth: true
      forecastDays: 5
      showLocation: false
    }
  }
}
