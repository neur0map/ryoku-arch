pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root

  required property ShellScreen screen

  readonly property var options: Config.options?.barFrameLab ?? {}
  readonly property color surfaceColor: options.barSurfaceColor ?? Appearance.colors.colLayer0
  readonly property color textColor: options.textColor ?? Appearance.colors.colOnLayer0
  readonly property color accentColor: options.accentColor ?? Appearance.colors.colAccent

  implicitWidth: 68

  function handleWheel(y: real, angleDelta: point): void {
    if (angleDelta.y > 0)
      Audio.incrementVolume()
    else if (angleDelta.y < 0)
      Audio.decrementVolume()
  }

  Rectangle {
    id: barSurface

    anchors.fill: parent
    color: ColorUtils.transparentize(root.surfaceColor, 0.08)
    radius: Math.min(18, width / 2)
    border.width: 1
    border.color: ColorUtils.transparentize(root.accentColor, 0.65)
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    onWheel: event => root.handleWheel(event.y, event.angleDelta)
  }

  ColumnLayout {
    anchors {
      fill: parent
      topMargin: 14
      bottomMargin: 14
    }
    spacing: 14

    Item {
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: parent.width
      implicitHeight: 54

      StyledText {
        anchors.centerIn: parent
        text: "力"
        color: root.textColor
        font.pixelSize: Appearance.font.pixelSize.title
        font.weight: Font.Bold
      }
    }

    BarFrameLabWorkspaces {
      Layout.alignment: Qt.AlignHCenter
      screen: root.screen
    }

    Item {
      Layout.fillHeight: true
      Layout.fillWidth: true

      StyledText {
        anchors.centerIn: parent
        rotation: 90
        text: activeTitle.length > 0 ? activeTitle : "Desktop"
        color: ColorUtils.transparentize(root.textColor, 0.22)
        font.pixelSize: Appearance.font.pixelSize.small
        elide: Text.ElideRight
        width: Math.min(260, parent.height)

        readonly property string activeTitle: {
          if (CompositorService.isNiri)
            return NiriService.activeWindow?.title ?? NiriService.activeWindow?.app_id ?? ""
          const active = ToplevelManager.activeToplevel
          return active?.title ?? active?.appId ?? ""
        }
      }
    }

    BarFrameLabStatusIcons {
      Layout.alignment: Qt.AlignHCenter
    }

    StyledText {
      Layout.alignment: Qt.AlignHCenter
      text: Qt.formatTime(clock.now, "HH:mm")
      color: root.textColor
      font.pixelSize: Appearance.font.pixelSize.small
      font.weight: Font.DemiBold
      rotation: 90

      QtObject {
        id: clock
        property date now: new Date()
      }

      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
      }
    }
  }
}
