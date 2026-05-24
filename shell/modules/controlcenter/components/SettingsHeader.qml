pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

StyledRect {
  id: root

  required property string icon
  required property string title

  Layout.fillWidth: true
  implicitHeight: row.implicitHeight + Tokens.padding.large * 2
  radius: Tokens.rounding.normal
  color: Colours.palette.m3surfaceContainerHigh
  clip: true

  RowLayout {
    id: row

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Tokens.padding.large
    spacing: Tokens.spacing.normal

    StyledRect {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 52
      implicitHeight: 52
      radius: Tokens.rounding.small
      color: Colours.palette.m3primaryContainer

      MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: Colours.palette.m3onPrimaryContainer
        font.pointSize: Tokens.font.size.extraLarge
        fill: 1
      }
    }

    StyledText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: root.title
      font.pointSize: Tokens.font.size.large
      font.weight: 700
      elide: Text.ElideRight
    }
  }
}
