pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components

Item {
  id: root

  required property ShellScreen screen
  required property DrawerVisibilities visibilities
  property matrix4x4 deformMatrix

  readonly property bool shouldBeActive: visibilities.wallhaven
  readonly property int tileTargetWidth: Math.min(260, Math.max(210, Math.round(screen.width * 0.12)))
  readonly property int tileTargetHeight: Math.round(tileTargetWidth * 0.58)
  readonly property int gridTargetWidth: tileTargetWidth * 3 + Tokens.spacing.normal * 2
  readonly property int gridTargetHeight: tileTargetHeight * 3 + Tokens.spacing.normal * 2
  readonly property int panelWidth: Math.min(Math.max(680, gridTargetWidth + Tokens.padding.large * 2 + Tokens.padding.small), Math.max(640, screen.width - 180))
  readonly property int panelHeight: Math.min(Math.max(600, gridTargetHeight + 220), Math.max(560, screen.height - 120))
  property real offsetScale: shouldBeActive ? 0 : 1

  visible: offsetScale < 1
  anchors.topMargin: (-implicitHeight - 5) * offsetScale
  implicitWidth: panelWidth
  implicitHeight: panelHeight
  opacity: 1 - offsetScale

  Behavior on offsetScale {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Loader {
    id: content

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Tokens.padding.large

    asynchronous: true
    active: root.shouldBeActive || root.visible

    sourceComponent: Content {
      screen: root.screen
      panelWidth: root.panelWidth - content.anchors.margins * 2
      panelHeight: root.panelHeight - content.anchors.margins * 2
    }
  }
}
