pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import qs.modules.launcher.services

Item {
  id: root

  required property ShellScreen screen
  required property DrawerVisibilities visibilities
  required property var panels

  readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled
  readonly property int closedW: 700
  readonly property int closedH: 68
  readonly property int fallbackOpenW: 720
  readonly property int startY: 0
  readonly property int targetY: Math.max(86, Math.round(((parent ? parent.height : screen.height) - openHeight) / 2))
  readonly property real openHeight: Math.min(maxHeight, Math.max(closedH, content.item?.implicitHeight ?? closedH))
  readonly property real openWidth: Math.max(fallbackOpenW, content.item?.implicitWidth ?? fallbackOpenW)
  readonly property real maxHeight: {
    let max = screen.height - Config.border.thickness * 2 - Tokens.spacing.large;
    if (visibilities.utilities)
      max -= panels.utilities.implicitHeight;
    return max;
  }
  readonly property bool contentReady: openProgress > 0.92
  readonly property real frameProgress: Math.min(1, openProgress * 4)
  readonly property real shellWidth: closedW * frameProgress + (openWidth - closedW) * openProgress
  readonly property real shellHeight: closedH * frameProgress + (openHeight - closedH) * openProgress

  property real openProgress: shouldBeActive ? 1 : 0

  visible: openProgress > 0.001
  clip: true
  width: shellWidth
  height: shellHeight
  implicitWidth: shellWidth
  implicitHeight: shellHeight
  y: startY + (targetY - startY) * openProgress
  opacity: 1

  Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init.

  Behavior on openProgress {
    NumberAnimation {
      duration: Math.round(Tokens.anim.durations.expressiveDefaultSpatial * 0.82)
      easing.type: Easing.BezierSpline
      // Closing with DefaultSpatial feels right. Opening uses the time-reverse
      // of that curve so it follows the exact same path backwards.
      easing.bezierCurve: root.shouldBeActive
        ? [0.78, 0.0, 0.62, -0.21, 1.0, 1.0]
        : [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
    }
  }

  Loader {
    id: content

    anchors.fill: parent
    active: true
    opacity: root.contentReady ? 1 : 0

    sourceComponent: Content {
      visibilities: root.visibilities
      panels: root.panels
      maxHeight: root.maxHeight
      contentReady: root.contentReady
    }

    Behavior on opacity {
      Anim {
        type: Anim.Standard
      }
    }
  }
}
