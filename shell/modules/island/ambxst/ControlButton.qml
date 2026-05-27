pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.components
import qs.services

StyledRect {
  id: root

  property string iconName
  property string tooltipText
  property bool isActive
  property bool disabled

  signal clicked(var mouse)
  signal rightClicked
  signal longPressed

  implicitWidth: 48
  implicitHeight: 48
  radius: isActive ? 14 : 20
  color: disabled ? Qt.alpha(Colours.palette.m3onSurface, 0.08)
    : isActive ? Colours.palette.m3primary
    : hoverHandler.hovered ? Colours.palette.m3surfaceContainerHighest
    : Colours.palette.m3surfaceContainer

  HoverHandler {
    id: hoverHandler
  }

  MaterialIcon {
    anchors.centerIn: parent
    text: root.iconName
    color: root.disabled ? Qt.alpha(Colours.palette.m3onSurface, 0.38)
      : root.isActive ? Colours.palette.m3onPrimary
      : Colours.palette.m3onSurfaceVariant
    font.pointSize: Tokens.font.size.large
    fill: root.isActive ? 1 : 0
  }

  MouseArea {
    id: mouseArea

    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    enabled: !root.disabled
    hoverEnabled: true
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.rightClicked();
      else
        root.clicked(mouse);
    }
    onPressAndHold: root.longPressed()
  }

  Behavior on color {
    Anim {}
  }

  Behavior on radius {
    Anim {
      type: Anim.FastSpatial
    }
  }
}
