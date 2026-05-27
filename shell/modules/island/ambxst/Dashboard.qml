pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.components
import qs.services

// Adapted from Ambxst modules/widgets/dashboard/Dashboard.qml.
StyledRect {
  id: root

  required property DrawerVisibilities visibilities
  required property var props

  signal requestLens
  signal requestColorPicker
  signal requestRecord

  focus: true
  implicitWidth: 900
  implicitHeight: 392
  radius: 18
  color: Colours.layer(Colours.palette.m3surface, 2)
  border.width: Math.max(1, Config.border.thickness)
  border.color: Qt.alpha(Colours.palette.m3outline, 0.2)
  clip: true

  WidgetsTab {
    anchors.fill: parent
    anchors.margins: 8
    visibilities: root.visibilities
    props: root.props
    onRequestLens: root.requestLens()
    onRequestColorPicker: root.requestColorPicker()
    onRequestRecord: root.requestRecord()
  }
}
