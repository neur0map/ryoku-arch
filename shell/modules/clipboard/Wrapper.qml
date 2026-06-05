pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import "../../dashboard/modules/widgets/dashboard/clipboard" as Clip

// RYOKU: dedicated, image-capable clipboard overlay (Super+V). Hosts the dashboard's
// ClipboardTab directly — the only place in ryoku that surfaces it — and reuses
// the launcher's open/close motion so it feels native.
Item {
  id: root

  required property ShellScreen screen
  required property DrawerVisibilities visibilities

  readonly property bool shouldBeActive: visibilities.clipboard
  readonly property int leftPanelWidth: 300
  readonly property int closedW: 700
  readonly property int closedH: 68
  readonly property int startY: 0
  readonly property real maxHeight: screen.height - Config.border.thickness * 2 - Tokens.spacing.large
  readonly property real openWidth: 820
  readonly property real openHeight: Math.min(maxHeight, 460)
  readonly property int targetY: Math.max(86, Math.round(((parent ? parent.height : screen.height) - openHeight) / 2))
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

  onContentReadyChanged: {
    if (contentReady && content.item && content.item.focusSearchInput)
      content.item.focusSearchInput();
  }

  Behavior on openProgress {
    NumberAnimation {
      duration: Math.round(Tokens.anim.durations.expressiveDefaultSpatial * 0.82)
      easing.type: Easing.BezierSpline
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

    sourceComponent: Clip.ClipboardTab {
      leftPanelWidth: root.leftPanelWidth
      prefixIcon: ""
      onRequestClose: root.visibilities.clipboard = false
      onBackspaceOnEmpty: root.visibilities.clipboard = false
    }

    Behavior on opacity {
      Anim {
        type: Anim.Standard
      }
    }
  }
}
