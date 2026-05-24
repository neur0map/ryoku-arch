pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.controlcenter

Item {
  id: root

  required property ShellScreen screen
  required property Session session
  required property bool initialOpeningComplete

  property string searchText: ""

  readonly property var activeEntry: PaneRegistry.getByLabel(session.active)
  readonly property var filteredPanes: {
    const result = [];
    for (let groupIndex = 0; groupIndex < PaneRegistry.groups.length; groupIndex++) {
      const group = PaneRegistry.groups[groupIndex];
      for (let paneIndex = 0; paneIndex < PaneRegistry.panes.length; paneIndex++) {
        const pane = PaneRegistry.panes[paneIndex];
        if (pane.group === group && paneMatches(pane))
          result.push(pane);
      }
    }
    return result;
  }

  function paneMatches(pane: var): bool {
    const query = root.searchText.trim().toLowerCase();
    if (!query)
      return true;

    const group = PaneRegistry.groupLabel(pane.group) + " " + PaneRegistry.groupDescription(pane.group);
    const haystack = [pane.label, pane.description, group].join(" ").toLowerCase();
    return haystack.indexOf(query) >= 0;
  }

  function isFirstInGroup(index: int): bool {
    if (index <= 0)
      return true;
    const current = root.filteredPanes[index];
    const previous = root.filteredPanes[index - 1];
    return !current || !previous || current.group !== previous.group;
  }

  function selectPane(label: string): void {
    if (!root.initialOpeningComplete)
      return;

    root.session.active = label;
  }

  implicitWidth: 168
  implicitHeight: layout.implicitHeight + Tokens.padding.normal * 2

  ColumnLayout {
    id: layout

    anchors.fill: parent
    anchors.margins: Tokens.padding.small
    spacing: Tokens.spacing.smaller

    RowLayout {
      Layout.fillWidth: true
      Layout.bottomMargin: Tokens.spacing.smaller
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 28
        implicitHeight: 28
        radius: Tokens.rounding.small
        color: Colours.palette.m3primary

        MaterialIcon {
          anchors.centerIn: parent
          text: "tune"
          color: Colours.palette.m3onPrimary
          font.pointSize: Tokens.font.size.normal
          fill: 1
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: qsTr("Settings")
          font.pointSize: Tokens.font.size.normal
          font.weight: 650
          elide: Text.ElideRight
        }
      }
    }

    StyledRect {
      Layout.fillWidth: true
      implicitHeight: 32
      radius: Tokens.rounding.small
      color: Colours.palette.m3surfaceContainerHigh

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.small
        anchors.rightMargin: Tokens.padding.smaller
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: "search"
          color: searchField.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.normal

          Behavior on color {
            CAnim {}
          }
        }

        StyledTextField {
          id: searchField

          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: root.searchText
          placeholderText: qsTr("Search settings")

          onTextChanged: {
            if (root.searchText !== text)
              root.searchText = text;
          }
        }

        IconButton {
          Layout.alignment: Qt.AlignVCenter
          visible: root.searchText !== ""
          icon: "close"
          type: IconButton.Text
          padding: Tokens.padding.small / 2

          onClicked: root.searchText = ""
        }
      }
    }

    StyledFlickable {
      id: navFlickable

      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentHeight: navContent.implicitHeight

      StyledScrollBar.vertical: StyledScrollBar {
        flickable: navFlickable
      }

      ColumnLayout {
        id: navContent

        width: navFlickable.width
        spacing: Tokens.spacing.smaller

        Repeater {
          model: root.filteredPanes

          ColumnLayout {
            id: paneBlock

            required property int index
            required property var modelData

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
              Layout.fillWidth: true
              Layout.topMargin: paneBlock.index === 0 ? 0 : Tokens.spacing.smaller
              Layout.leftMargin: Tokens.padding.smaller
              visible: root.isFirstInGroup(paneBlock.index)
              text: PaneRegistry.groupLabel(paneBlock.modelData.group)
              color: Colours.palette.m3primary
              font.pointSize: Tokens.font.size.small
              font.weight: 650
              elide: Text.ElideRight
            }

            PaneItem {
              Layout.fillWidth: true
              entry: paneBlock.modelData
              active: root.session.active === paneBlock.modelData.label
            }
          }
        }

        StyledText {
          Layout.fillWidth: true
          Layout.topMargin: Tokens.spacing.large
          Layout.leftMargin: Tokens.padding.small
          Layout.rightMargin: Tokens.padding.small
          visible: root.filteredPanes.length === 0
          text: qsTr("No settings match this search")
          color: Colours.palette.m3onSurfaceVariant
          wrapMode: Text.WordWrap
        }
      }
    }

    Loader {
      Layout.fillWidth: true
      asynchronous: true
      active: !root.session.floating
      visible: active

      sourceComponent: StyledRect {
        Layout.fillWidth: true
        implicitHeight: 34
        color: Colours.palette.m3secondaryContainer
        radius: Tokens.rounding.small

        StateLayer {
          onClicked: {
            root.session.root.close();
            WindowFactory.close();
            WindowFactory.open(null, {
              active: root.session.active,
              navExpanded: root.session.navExpanded
            });
          }

          color: Colours.palette.m3onSecondaryContainer
          radius: parent.radius
        }

        RowLayout {
          anchors.centerIn: parent
          spacing: Tokens.spacing.small

          MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "select_window"
            color: Colours.palette.m3onSecondaryContainer
            font.pointSize: Tokens.font.size.normal
            fill: 1
          }

          StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: qsTr("Float window")
            color: Colours.palette.m3onSecondaryContainer
            font.weight: 600
          }
        }
      }
    }
  }

  component PaneItem: StyledRect {
    id: item

    required property var entry
    required property bool active

    implicitHeight: 36
    radius: Tokens.rounding.small
    color: item.active ? Colours.palette.m3primaryContainer : "transparent"

    StateLayer {
      onClicked: root.selectPane(item.entry.label)

      color: item.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: row

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 24
        implicitHeight: 24
        radius: Tokens.rounding.small
        color: item.active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

        MaterialIcon {
          anchors.centerIn: parent
          text: item.entry.icon
          color: item.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          fill: item.active ? 1 : 0

          Behavior on fill {
            Anim {}
          }
        }
      }

      StyledText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: item.entry.label
        color: item.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.capitalization: Font.Capitalize
        font.weight: item.active ? 650 : 550
        elide: Text.ElideRight
      }
    }
  }
}
