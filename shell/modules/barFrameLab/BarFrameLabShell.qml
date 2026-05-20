pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
  id: root

  readonly property var options: Config.options?.barFrameLab ?? {}
  readonly property bool enabled: options.enable ?? false
  readonly property int borderThickness: Math.max(1, options.borderThickness ?? 8)
  readonly property int barWidth: Math.max(48, options.barWidth ?? 68)
  readonly property int barExclusiveZone: barWidth + borderThickness
  readonly property int frameExclusiveZone: borderThickness
  readonly property color surfaceColor: options.surfaceColor ?? Appearance.colors.colLayer0
  readonly property color frameColor: options.frameColor ?? ColorUtils.transparentize(Appearance.colors.colLayer1, 0.12)
  readonly property bool shellVisible: enabled && !GameMode.shouldHidePanels && !GlobalStates.screenLocked

  component EmptyMask: Item {
    width: 0
    height: 0
  }

  component ExclusionZone: PanelWindow {
    id: exclusion

    required property ShellScreen targetScreen
    required property int zoneSize
    property bool pinTop: false
    property bool pinBottom: false
    property bool pinLeft: false
    property bool pinRight: false

    screen: targetScreen
    visible: root.shellVisible
    focusable: false
    color: "transparent"
    implicitWidth: (pinLeft || pinRight) ? zoneSize : 1
    implicitHeight: (pinTop || pinBottom) ? zoneSize : 1
    exclusiveZone: zoneSize
    WlrLayershell.namespace: "quickshell:barFrameLab:exclusion"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: exclusion.pinTop || exclusion.pinLeft || exclusion.pinRight
      bottom: exclusion.pinBottom || exclusion.pinLeft || exclusion.pinRight
      left: exclusion.pinLeft || exclusion.pinTop || exclusion.pinBottom
      right: exclusion.pinRight || exclusion.pinTop || exclusion.pinBottom
    }

    EmptyMask {
      id: emptyMask
    }

    mask: Region {
      item: emptyMask
    }
  }

  Variants {
    model: Quickshell.screens

    Scope {
      id: screenScope

      required property ShellScreen modelData

      PanelWindow {
        id: contentWindow

        screen: screenScope.modelData
        visible: root.shellVisible
        focusable: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:barFrameLab:content"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        mask: Region {
          item: labBar
        }

        Rectangle {
          id: connectedFrameSurface

          anchors.fill: parent
          color: root.frameColor

          Rectangle {
            x: root.barExclusiveZone
            y: root.borderThickness
            width: parent.width - root.barExclusiveZone - root.borderThickness
            height: parent.height - root.borderThickness * 2
            radius: Math.max(0, Appearance.rounding.screenRounding)
            color: "transparent"
            border.width: root.borderThickness
            border.color: root.surfaceColor
          }
        }

        BarFrameLabBar {
          id: labBar

          screen: screenScope.modelData
          width: root.barWidth
          anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            margins: root.borderThickness
            rightMargin: 0
          }
        }
      }

      ExclusionZone {
        targetScreen: screenScope.modelData
        zoneSize: root.barExclusiveZone
        pinLeft: true
      }

      ExclusionZone {
        targetScreen: screenScope.modelData
        zoneSize: root.frameExclusiveZone
        pinTop: true
      }

      ExclusionZone {
        targetScreen: screenScope.modelData
        zoneSize: root.frameExclusiveZone
        pinRight: true
      }

      ExclusionZone {
        targetScreen: screenScope.modelData
        zoneSize: root.frameExclusiveZone
        pinBottom: true
      }
    }
  }
}
