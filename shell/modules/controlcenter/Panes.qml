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
  readonly property var activeGroupPanes: activeEntry ? PaneRegistry.getByGroup(activeEntry.group) : []
  readonly property string activeComponent: activeEntry ? activeEntry.component : ""
  readonly property string relatedLabel: activeEntry ? PaneRegistry.groupLabel(activeEntry.group) : qsTr("Related")

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

    RowLayout {
      id: header

      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(titleColumn.implicitHeight, activeIcon.implicitHeight)
      spacing: Tokens.spacing.small

      StyledRect {
        id: activeIcon

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 34
        implicitHeight: 34
        radius: Tokens.rounding.small
        color: Colours.palette.m3secondaryContainer

        MaterialIcon {
          anchors.centerIn: parent
          text: root.activeEntry ? root.activeEntry.icon : "settings"
          color: Colours.palette.m3onSecondaryContainer
          font.pointSize: Tokens.font.size.normal
          fill: 1
        }
      }

      ColumnLayout {
        id: titleColumn

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        StyledText {
          Layout.fillWidth: true
          text: root.activeEntry ? root.activeEntry.label : root.session.active
          font.capitalization: Font.Capitalize
          font.pointSize: Tokens.font.size.normal
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: root.activeEntry ? root.activeEntry.description : ""
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        visible: relatedFlickable.visible
        text: root.relatedLabel
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.smaller
        font.weight: 600
        elide: Text.ElideRight
      }
    }

    Flickable {
      id: relatedFlickable

      Layout.fillWidth: true
      Layout.preferredHeight: visible ? tabRow.implicitHeight : 0
      visible: root.activeGroupPanes.length > 1
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: tabRow.implicitWidth
      contentHeight: tabRow.implicitHeight
      flickableDirection: Flickable.HorizontalFlick

      RowLayout {
        id: tabRow

        spacing: Tokens.spacing.smaller

        Repeater {
          model: root.activeGroupPanes

          StyledRect {
            id: tab

            required property var modelData
            readonly property bool active: root.session.active === modelData.label

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: tabContent.implicitWidth + Tokens.padding.small * 2
            implicitHeight: 30
            radius: Tokens.rounding.small
            color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

            StateLayer {
              onClicked: {
                if (!root.initialOpeningComplete)
                  return;

                root.session.active = tab.modelData.label;
              }

              color: tab.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
              radius: tab.radius
            }

            RowLayout {
              id: tabContent

              anchors.centerIn: parent
              spacing: Tokens.spacing.smaller

              MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: tab.modelData.icon
                color: tab.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                fill: tab.active ? 1 : 0
              }

              StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: tab.modelData.label
                color: tab.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.capitalization: Font.Capitalize
                font.pointSize: Tokens.font.size.small
                font.weight: tab.active ? 650 : 550
              }
            }
          }
        }
      }
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
}
