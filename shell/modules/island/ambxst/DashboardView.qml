pragma ComponentBehavior: Bound

import QtQuick
import qs.components

Item {
  id: root

  required property DrawerVisibilities visibilities
  required property var props

  signal requestLens
  signal requestColorPicker
  signal requestRecord

  implicitWidth: 900
  implicitHeight: 392

  Dashboard {
    id: dashboardItem

    anchors.fill: parent
    visibilities: root.visibilities
    props: root.props
    onRequestLens: root.requestLens()
    onRequestColorPicker: root.requestColorPicker()
    onRequestRecord: root.requestRecord()

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        root.visibilities.island = false;
        event.accepted = true;
      } else if (event.key === Qt.Key_Space) {
        event.accepted = false;
      }
    }

    Component.onCompleted: Qt.callLater(() => forceActiveFocus())
  }
}
