pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services
import ".."
import "layout.js" as CalendarLayout

StyledRect {
  id: root

  property int monthShift: 0
  property date currentDate: new Date()
  property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift, currentDate)
  property var calendarLayoutData: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
  property var calendarLayout: calendarLayoutData.calendar
  property int currentWeekRow: calendarLayoutData.currentWeekRow
  property int currentDayOfWeek: monthShift !== 0 ? -1 : (currentDate.getDay() + 6) % 7

  function getDayAbbrev(dayIndex: int): string {
    const d = new Date(2024, 0, 1 + dayIndex);
    const dayName = d.toLocaleDateString(Qt.locale(), "ddd");
    return (dayName.charAt(0).toUpperCase() + dayName.slice(1, 2)).replace(".", "");
  }

  radius: 18
  color: Colours.palette.m3surfaceContainerLow
  clip: true

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.currentDate = new Date()
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 4
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      spacing: 4

      StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 14
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        Text {
          anchors.centerIn: parent
          text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
          color: Colours.palette.m3onSurface
          font.pixelSize: Tokens.font.size.normal
          font.weight: Font.Bold
          horizontalAlignment: Text.AlignHCenter
        }
      }

      ControlButton {
        Layout.preferredWidth: 32
        Layout.fillHeight: true
        iconName: "chevron_left"
        onClicked: root.monthShift--
      }

      ControlButton {
        Layout.preferredWidth: 32
        Layout.fillHeight: true
        iconName: "chevron_right"
        onClicked: root.monthShift++
      }
    }

    StyledRect {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 14
      color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0

        RowLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          spacing: 0

          Repeater {
            model: 7

            CalendarDayButton {
              required property int index

              day: root.getDayAbbrev(index)
              isToday: 0
              bold: true
              isCurrentDayOfWeek: index === root.currentDayOfWeek
            }
          }
        }

        StyledRect {
          Layout.fillWidth: true
          Layout.leftMargin: 8
          Layout.rightMargin: 8
          Layout.preferredHeight: 1
          color: Qt.alpha(Colours.palette.m3outline, 0.22)
        }

        Repeater {
          model: 6

          StyledRect {
            id: weekRow

            required property int index

            property int rowIndex: index

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            radius: 12
            color: index === root.currentWeekRow ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.65) : "transparent"

            RowLayout {
              anchors.fill: parent
              spacing: 0

              Repeater {
                model: 7

                CalendarDayButton {
                  required property int index

                  day: `${root.calendarLayout[weekRow.rowIndex][index].day}`
                  isToday: root.calendarLayout[weekRow.rowIndex][index].today
                }
              }
            }
          }
        }
      }
    }
  }
}
