pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts

Item {
  id: root

  required property DrawerVisibilities visibilities
  required property BarPopouts.Wrapper popouts
  property matrix4x4 deformMatrix

  readonly property PersistentProperties props: PersistentProperties {
    property bool recordingListExpanded: false
    property string recordingConfirmDelete
    property string recordingMode

    reloadableId: "islandUtilities"
  }
  readonly property bool shouldBeActive: visibilities.island && Config.dashboard.enabled
  property real offsetScale: shouldBeActive ? 0 : 1

  // The panel's own box grows from a zero-height strip at the bar's centre-notch
  // width to the full panel (width: notch → full, height: 0 → full), top pinned
  // at the bar's inner edge. The blob behind it (islandBg, pinReach) keeps the
  // neck fused to the notch the whole time, so the clock/notch pill reads as
  // expanding straight down into the panel, not a surface appearing below it.
  property real collapsedWidth: 0
  readonly property real startWidth: collapsedWidth > 0 ? collapsedWidth : implicitWidth

  visible: offsetScale < 1
  implicitHeight: content.implicitHeight
  implicitWidth: content.implicitWidth || 560
  width: startWidth + (implicitWidth - startWidth) * (1 - offsetScale)
  height: implicitHeight * (1 - offsetScale)
  clip: true

  Behavior on offsetScale {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Loader {
    id: content

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top

    active: root.shouldBeActive || root.visible

    sourceComponent: Content {
      visibilities: root.visibilities
      popouts: root.popouts
      props: root.props
      deformMatrix: root.deformMatrix
    }
  }
}
