pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
  id: root

  property string icon
  property real value
  property bool muted
  property bool vertical
  property color accentColor: Colours.palette.m3primary

  signal valueEdited(real newValue)
  signal toggleRequested

  function clamped(newValue: real): real {
    return Math.max(0, Math.min(1, newValue));
  }

  function editFromY(posY: real): void {
    root.valueEdited(clamped(1 - posY / Math.max(1, height)));
  }

  implicitWidth: 52
  implicitHeight: vertical ? 180 : 52
  radius: vertical ? 26 : implicitWidth / 2
  color: vertical ? "transparent" : Colours.palette.m3surfaceContainerLow

  Loader {
    anchors.fill: parent
    active: root.vertical
    sourceComponent: Item {
      StyledRect {
        id: iconButton

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 48
        height: 48
        radius: 24
        color: Colours.palette.m3surfaceContainerLow

        MaterialIcon {
          anchors.centerIn: parent
          text: root.icon
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.large
          fill: 1
        }
      }

      Item {
        id: sliderTrack

        anchors.top: iconButton.bottom
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        anchors.bottomMargin: 2
        width: 10

        StyledRect {
          anchors.fill: parent
          radius: width / 2
          color: Qt.alpha(Colours.palette.m3outline, 0.22)
        }

        StyledRect {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Math.max(width, parent.height * root.clamped(root.value))
          radius: width / 2
          color: root.accentColor
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.editFromY(mouse.y)
        onPositionChanged: mouse => {
          if (pressed)
            root.editFromY(mouse.y);
        }
        onWheel: wheel => root.valueEdited(root.clamped(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
      }
    }
  }

  Loader {
    anchors.fill: parent
    active: !root.vertical
    sourceComponent: Item {
      CircularProgress {
        anchors.fill: parent
        anchors.margins: 3
        value: root.clamped(root.value)
        strokeWidth: 4
        padding: 2
        fgColour: root.accentColor
        bgColour: Qt.alpha(Colours.palette.m3outline, 0.24)
      }

      MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: root.muted ? Colours.palette.m3outline : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.large
        fill: root.muted ? 0 : 1
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.toggleRequested()
        onWheel: wheel => root.valueEdited(root.clamped(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
      }
    }
  }
}
