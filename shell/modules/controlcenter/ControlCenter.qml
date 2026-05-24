pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.services

Item {
  id: root

  required property ShellScreen screen
  readonly property int rounding: floating ? 0 : Tokens.rounding.large

  property alias floating: session.floating
  property alias active: session.active
  property alias navExpanded: session.navExpanded

  readonly property bool initialOpeningComplete: panes.initialOpeningComplete
  readonly property Session session: Session {
    id: session

    root: root
  }

  signal close

  implicitWidth: Math.min(screen.width * 0.62, 1220)
  implicitHeight: Math.min(screen.height * 0.58, 820)

  ColumnLayout {
    anchors.fill: parent

    spacing: 0

    Loader {
      Layout.fillWidth: true

      asynchronous: true
      active: root.floating
      visible: active

      sourceComponent: WindowTitle {
        screen: root.screen
        session: root.session
      }
    }

    StyledRect {
      Layout.fillWidth: true

      topLeftRadius: root.floating ? 0 : root.rounding
      topRightRadius: root.floating ? 0 : root.rounding
      implicitHeight: navRail.implicitHeight
      color: Colours.palette.m3surfaceContainer

      NavRail {
        id: navRail

        anchors.fill: parent
        screen: root.screen
        session: root.session
        initialOpeningComplete: root.initialOpeningComplete
      }
    }

    Panes {
      id: panes

      Layout.fillWidth: true
      Layout.fillHeight: true

      bottomLeftRadius: root.rounding
      bottomRightRadius: root.rounding
      session: root.session
    }
  }
}
