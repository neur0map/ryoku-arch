pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
  id: networkFactRoot

  property string icon
  property string label
  property string value
  property bool active: false

  implicitHeight: 40
  radius: Tokens.rounding.small
  color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
  clip: true

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tokens.padding.small
    anchors.rightMargin: Tokens.padding.small
    spacing: Tokens.spacing.small

    MaterialIcon {
      Layout.alignment: Qt.AlignVCenter
      text: networkFactRoot.icon
      color: networkFactRoot.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
      fill: networkFactRoot.active ? 1 : 0
    }

    StyledText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: networkFactRoot.label
      color: networkFactRoot.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      font.weight: 600
      elide: Text.ElideRight
    }

    StyledText {
      Layout.alignment: Qt.AlignVCenter
      text: networkFactRoot.value
      color: networkFactRoot.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
      font.pointSize: Tokens.font.size.small
      font.weight: 700
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}
