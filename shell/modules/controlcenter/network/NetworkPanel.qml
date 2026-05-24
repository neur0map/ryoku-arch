pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
  id: networkPanelRoot

  property string icon
  property string title
  property string subtitle
  default property alias content: networkPanelBody.data

  implicitHeight: networkPanelLayout.implicitHeight + Tokens.padding.small * 2
  radius: Tokens.rounding.small
  color: Colours.palette.m3surfaceContainer
  clip: true

  ColumnLayout {
    id: networkPanelLayout

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Tokens.padding.small
    spacing: Tokens.spacing.small

    RowLayout {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: networkPanelRoot.icon
        color: Colours.palette.m3primary
        fill: 1
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: networkPanelRoot.title
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          visible: networkPanelRoot.subtitle !== ""
          text: networkPanelRoot.subtitle
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }
    }

    ColumnLayout {
      id: networkPanelBody

      Layout.fillWidth: true
      spacing: Tokens.spacing.small
    }
  }
}
