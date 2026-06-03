pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

Rectangle {
  id: button

  required property string day
  required property int isToday
  property bool bold: false
  property bool isCurrentDayOfWeek: false

  Layout.fillWidth: true
  Layout.fillHeight: true
  Layout.preferredWidth: 28
  Layout.preferredHeight: 28

  color: "transparent"

  StyledRect {
    anchors.centerIn: parent
    width: Math.min(parent.width, parent.height, 30)
    height: width
    radius: width / 2
    color: button.isToday === 1 ? Colours.palette.m3primary : "transparent"

    Text {
      anchors.fill: parent
      text: button.day
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font.weight: Font.Bold
      font.pixelSize: Tokens.font.size.small
      color: {
        if (button.isToday === 1)
          return Colours.palette.m3onPrimary;
        if (button.bold)
          return button.isCurrentDayOfWeek ? Colours.palette.m3onSurface : Colours.palette.m3outline;
        if (button.isToday === 0)
          return Colours.palette.m3onSurfaceVariant;
        return Qt.alpha(Colours.palette.m3outline, 0.45);
      }
    }
  }
}
