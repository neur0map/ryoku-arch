pragma ComponentBehavior: Bound

import "bluetooth"
import "network"
import "audio"
import "appearance"
import "taskbar"
import "notifications"
import "launcher"
import "dashboard"
import "about"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.controlcenter

ClippingRectangle {
  id: root

  required property Session session

  property bool initialOpeningComplete: false
  readonly property var activeEntry: PaneRegistry.getByLabel(session.active)
  readonly property string activeComponent: activeEntry ? activeEntry.component : ""

  function loadActivePane(): void {
    if (root.activeComponent === "")
      return;

    activePaneLoader.opacity = 0;
    activePaneLoader.setSource(root.activeComponent, {
      "session": root.session
    });
  }

  color: Colours.palette.m3surface
  clip: true
  focus: false
  activeFocusOnTab: false

  Component.onCompleted: {
    Qt.callLater(root.loadActivePane);
  }

  onActiveComponentChanged: {
    Qt.callLater(root.loadActivePane);
  }

  Timer {
    id: initialOpeningTimer

    interval: Tokens.anim.durations.normal
    running: true
    onTriggered: {
      root.initialOpeningComplete = true;
    }
  }

  MouseArea {
    anchors.fill: parent
    z: -1

    onPressed: function (mouse) {
      root.focus = true;
      mouse.accepted = false;
    }
  }

  Connections {
    function onActiveIndexChanged(): void {
      root.focus = true;
    }

    target: root.session
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Tokens.padding.normal
    spacing: Tokens.spacing.small

    PaneToolbar {
      Layout.fillWidth: true
    }

    ClippingRectangle {
      id: viewport

      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Tokens.rounding.small
      color: Colours.palette.m3surfaceContainerLow
      clip: true

      Loader {
        id: activePaneLoader

        anchors.fill: parent
        asynchronous: true
        clip: true

        onLoaded: {
          activePaneLoader.opacity = 1;
        }

        Behavior on opacity {
          Anim {}
        }
      }
    }
  }

  component PaneToolbar: StyledRect {
    id: toolbar

    implicitHeight: 36
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerLow

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.small
      anchors.rightMargin: Tokens.padding.small
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 26
        implicitHeight: 26
        radius: Tokens.rounding.small
        color: Colours.palette.m3secondaryContainer

        MaterialIcon {
          anchors.centerIn: parent
          text: root.activeEntry ? root.activeEntry.icon : "settings"
          color: Colours.palette.m3onSecondaryContainer
          font.pointSize: Tokens.font.size.small
          fill: 1
        }
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: root.activeEntry ? root.activeEntry.label : root.session.active
        font.capitalization: Font.Capitalize
        font.weight: 700
        elide: Text.ElideRight
      }

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: groupLabel.implicitWidth + Tokens.padding.small * 2
        implicitHeight: 24
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh

        StyledText {
          id: groupLabel

          anchors.centerIn: parent
          text: root.activeEntry ? PaneRegistry.groupLabel(root.activeEntry.group) : ""
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          font.weight: 650
        }
      }

      Item {
        Layout.fillWidth: true
      }
    }
  }
}
