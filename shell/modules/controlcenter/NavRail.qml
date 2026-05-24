pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
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
  readonly property string activeGroup: activeEntry ? activeEntry.group : ""
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

  function selectPane(label: string): void {
    if (!root.initialOpeningComplete)
      return;

    root.session.active = label;
  }

  function selectGroup(group: string): void {
    if (!root.initialOpeningComplete)
      return;

    const panes = PaneRegistry.getByGroup(group);
    if (panes.length > 0)
      root.session.active = panes[0].label;
  }

  implicitHeight: navLayout.implicitHeight + Tokens.padding.normal * 2

  ColumnLayout {
    id: navLayout

    anchors.fill: parent
    anchors.margins: Tokens.padding.normal
    spacing: Tokens.spacing.small

    RowLayout {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: brandRow.implicitWidth + Tokens.padding.small * 2
        implicitHeight: 36
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        RowLayout {
          id: brandRow

          anchors.centerIn: parent
          spacing: Tokens.spacing.smaller

          StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 24
            implicitHeight: 24
            radius: Tokens.rounding.small
            color: Colours.palette.m3primary

            MaterialIcon {
              anchors.centerIn: parent
              text: "tune"
              color: Colours.palette.m3onPrimary
              font.pointSize: Tokens.font.size.small
              fill: 1
            }
          }

          StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: qsTr("Settings")
            font.pointSize: Tokens.font.size.normal
            font.weight: 700
          }
        }
      }

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Math.min(320, root.width * 0.3)
        Layout.minimumWidth: 200
        implicitHeight: 36
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

      Flickable {
        id: groupFlickable

        Layout.fillWidth: true
        Layout.preferredHeight: groupStrip.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: groupStrip.implicitWidth
        contentHeight: groupStrip.implicitHeight
        flickableDirection: Flickable.HorizontalFlick

        RowLayout {
          id: groupStrip

          spacing: Tokens.spacing.small

          Repeater {
            model: PaneRegistry.groups

            GroupPill {
              required property string modelData

              label: PaneRegistry.groupLabel(modelData)
              detail: PaneRegistry.groupDescription(modelData)
              active: root.activeGroup === modelData

              onClicked: root.selectGroup(modelData)
            }
          }
        }
      }

      Loader {
        Layout.alignment: Qt.AlignVCenter
        asynchronous: true
        active: !root.session.floating
        visible: active

        sourceComponent: IconButton {
          icon: "select_window"
          type: IconButton.Text

          onClicked: {
            root.session.root.close();
            WindowFactory.close();
            WindowFactory.open(null, {
              active: root.session.active,
              navExpanded: root.session.navExpanded
            });
          }
        }
      }
    }

    Flickable {
      id: paneFlickable

      Layout.fillWidth: true
      Layout.preferredHeight: paneStrip.implicitHeight
      visible: root.filteredPanes.length > 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: paneStrip.implicitWidth
      contentHeight: paneStrip.implicitHeight
      flickableDirection: Flickable.HorizontalFlick

      RowLayout {
        id: paneStrip

        spacing: Tokens.spacing.small

        Repeater {
          model: root.filteredPanes

          PaneChip {
            required property var modelData

            entry: modelData
            active: root.session.active === modelData.label

            onClicked: root.selectPane(modelData.label)
          }
        }
      }
    }

    StyledText {
      Layout.fillWidth: true
      visible: root.filteredPanes.length === 0
      text: qsTr("No settings match this search")
      color: Colours.palette.m3onSurfaceVariant
      font.pointSize: Tokens.font.size.small
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  component GroupPill: StyledRect {
    id: groupPill

    property string label: ""
    property string detail: ""
    property bool active: false

    signal clicked

    implicitWidth: groupContent.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: Tokens.rounding.full
    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: groupPill.clicked()

      color: groupPill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: groupContent

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: groupPill.label
        color: groupPill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        visible: groupPill.active
        text: groupPill.detail
        color: Colours.palette.m3onPrimary
        font.pointSize: Tokens.font.size.small
        opacity: 0.75
        elide: Text.ElideRight
      }
    }
  }

  component PaneChip: StyledRect {
    id: chip

    required property var entry
    property bool active: false

    signal clicked

    implicitWidth: chipContent.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: chip.clicked()

      color: chip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: chipContent

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: chip.entry.icon
        color: chip.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: chip.active ? 1 : 0

        Behavior on fill {
          Anim {}
        }
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: chip.entry.label
        color: chip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.capitalization: Font.Capitalize
        font.pointSize: Tokens.font.size.small
        font.weight: chip.active ? 700 : 600
      }
    }
  }
}
