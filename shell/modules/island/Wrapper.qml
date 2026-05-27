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

  visible: offsetScale < 1
  anchors.topMargin: (-implicitHeight - 5) * offsetScale
  implicitHeight: content.implicitHeight
  implicitWidth: content.implicitWidth || 560
  width: implicitWidth
  height: implicitHeight
  opacity: 1 - offsetScale

  Behavior on offsetScale {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Loader {
    id: content

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    active: root.shouldBeActive || root.visible

    sourceComponent: Content {
      visibilities: root.visibilities
      popouts: root.popouts
      props: root.props
      deformMatrix: root.deformMatrix
    }
  }
}
