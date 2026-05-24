pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
  id: networkActionRoot

  property string icon
  property string title
  property string subtitle
  property bool primary: false
  property bool destructive: false
  signal clicked()

  readonly property color actionColor: destructive ? Colours.palette.m3errorContainer : (primary ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh)
  readonly property color actionOnColor: destructive ? Colours.palette.m3onErrorContainer : (primary ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface)

  implicitHeight: 52
  radius: Tokens.rounding.small
  color: actionColor
  clip: true

  StateLayer {
    color: networkActionRoot.actionOnColor

    onClicked: {
      networkActionRoot.clicked();
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tokens.padding.normal
    anchors.rightMargin: Tokens.padding.normal
    spacing: Tokens.spacing.small

    MaterialIcon {
      Layout.alignment: Qt.AlignVCenter
      text: networkActionRoot.icon
      color: networkActionRoot.actionOnColor
      fill: networkActionRoot.primary ? 1 : 0
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 0

      StyledText {
        Layout.fillWidth: true
        text: networkActionRoot.title
        color: networkActionRoot.actionOnColor
        font.weight: 700
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        visible: networkActionRoot.subtitle !== ""
        text: networkActionRoot.subtitle
        color: networkActionRoot.actionOnColor
        opacity: 0.78
        font.pointSize: Tokens.font.size.small
        elide: Text.ElideRight
      }
    }
  }
}
