pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

StyledRect {
  id: networkSwitchRoot

  property string icon
  property string title
  property string subtitle
  property bool checked
  signal toggled(bool checked)

  implicitHeight: 44
  radius: Tokens.rounding.small
  color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
  clip: true

  StateLayer {
    color: networkSwitchRoot.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

    onClicked: {
      networkSwitchRoot.toggled(!networkSwitchRoot.checked);
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tokens.padding.small
    anchors.rightMargin: Tokens.padding.small
    spacing: Tokens.spacing.small

    MaterialIcon {
      Layout.alignment: Qt.AlignVCenter
      text: networkSwitchRoot.icon
      color: networkSwitchRoot.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
      fill: networkSwitchRoot.checked ? 1 : 0
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 0

      StyledText {
        Layout.fillWidth: true
        text: networkSwitchRoot.title
        color: networkSwitchRoot.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.weight: 700
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        text: networkSwitchRoot.subtitle
        color: networkSwitchRoot.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        opacity: networkSwitchRoot.checked ? 0.78 : 1
        font.pointSize: Tokens.font.size.small
        elide: Text.ElideRight
      }
    }

    StyledRect {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 42
      implicitHeight: 24
      radius: Tokens.rounding.full
      color: networkSwitchRoot.checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

      StyledRect {
        anchors.verticalCenter: parent.verticalCenter
        x: networkSwitchRoot.checked ? parent.width - width - 4 : 4
        implicitWidth: 16
        implicitHeight: 16
        radius: Tokens.rounding.full
        color: networkSwitchRoot.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

        Behavior on x {
          Anim {}
        }
      }
    }
  }
}
