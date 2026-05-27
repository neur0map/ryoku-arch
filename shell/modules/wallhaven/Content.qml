pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

Item {
  id: root

  required property ShellScreen screen
  required property int panelWidth
  required property int panelHeight

  readonly property int columns: 3
  readonly property int visibleRows: 3
  readonly property int cellSpacing: Tokens.spacing.normal
  readonly property real cellPitch: Math.floor(grid.width / columns)
  readonly property real tileWidth: Math.max(1, cellPitch - cellSpacing)
  readonly property real tileHeight: Math.round(tileWidth * 0.58)

  implicitWidth: panelWidth
  implicitHeight: panelHeight

  function submitSearch(): void {
    Wallhaven.searchLatest(searchField.text);
    grid.positionViewAtBeginning();
  }

  function submitTopSearch(range: string): void {
    Wallhaven.query = searchField.text;
    Wallhaven.searchTop(range);
    grid.positionViewAtBeginning();
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Tokens.spacing.large

    RowLayout {
      Layout.fillWidth: true
      spacing: Tokens.spacing.normal

      StyledRect {
        implicitWidth: implicitHeight
        implicitHeight: titleIcon.implicitHeight + Tokens.padding.smaller * 2
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.28)

        MaterialIcon {
          id: titleIcon

          anchors.centerIn: parent
          text: "wallpaper"
          color: Colours.palette.m3primary
          font.pointSize: Tokens.font.size.large
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: qsTr("Wallhaven")
          font.pointSize: Tokens.font.size.normal
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: Wallhaven.searching ? qsTr("Searching") : Wallhaven.results.length > 0 ? qsTr("%1 images").arg(Wallhaven.results.length) : qsTr("Ready")
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: 34
        implicitWidth: pageControls.implicitWidth + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.18)

        RowLayout {
          id: pageControls

          anchors.centerIn: parent
          spacing: Tokens.spacing.smaller

          PagerButton {
            icon: "chevron_left"
            disabled: Wallhaven.searching || Wallhaven.page <= 1
            onClicked: {
              Wallhaven.previousPage();
              grid.positionViewAtBeginning();
            }
          }

          StyledText {
            text: `${Wallhaven.page}`
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
          }

          PagerButton {
            icon: "chevron_right"
            disabled: Wallhaven.searching || (Wallhaven.query.length === 0 && Wallhaven.topRange.length === 0) || Wallhaven.results.length === 0
            onClicked: {
              Wallhaven.nextPage();
              grid.positionViewAtBeginning();
            }
          }
        }
      }
    }

    StyledRect {
      Layout.fillWidth: true
      implicitHeight: Math.max(44, searchField.implicitHeight + Tokens.padding.small * 2)
      radius: Tokens.rounding.full
      color: searchHover.containsMouse || searchField.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 2) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
      border.width: 1
      border.color: searchField.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.26)

      Behavior on color {
        CAnim {}
      }

      Behavior on border.color {
        CAnim {}
      }

      MouseArea {
        id: searchHover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.normal
        anchors.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: "search"
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.large
        }

        StyledTextField {
          id: searchField

          Layout.fillWidth: true
          placeholderText: qsTr("Search Wallhaven")
          text: Wallhaven.query
          horizontalAlignment: TextInput.AlignLeft
          onAccepted: root.submitSearch()
        }

        IconButton {
          icon: "arrow_forward"
          type: IconButton.Text
          enabled: !Wallhaven.searching && searchField.text.trim().length > 0
          onClicked: root.submitSearch()
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      FilterChip {
        text: qsTr("Top week")
        icon: "calendar_view_week"
        checked: Wallhaven.topRange === "1w"
        disabled: Wallhaven.searching
        onClicked: root.submitTopSearch("1w")
      }

      FilterChip {
        text: qsTr("Top month")
        icon: "calendar_month"
        checked: Wallhaven.topRange === "1M"
        disabled: Wallhaven.searching
        onClicked: root.submitTopSearch("1M")
      }

      Item {
        Layout.fillWidth: true
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.tileHeight * root.visibleRows + root.cellSpacing * (root.visibleRows - 1)
      Layout.maximumHeight: Layout.preferredHeight
      clip: true

      GridView {
        id: grid

        anchors.fill: parent
        anchors.rightMargin: Tokens.padding.small
        visible: !Wallhaven.searching && Wallhaven.error.length === 0 && Wallhaven.results.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Wallhaven.results
        cellWidth: root.cellPitch
        cellHeight: root.tileHeight + root.cellSpacing

        StyledScrollBar.vertical: StyledScrollBar {
          flickable: grid
        }

        delegate: Item {
          id: cell

          required property var modelData
          required property int index

          width: grid.cellWidth
          height: grid.cellHeight

          StyledRect {
            id: tile

            width: root.tileWidth
            height: root.tileHeight
            radius: Tokens.rounding.small
            scale: tileMouse.containsMouse ? 0.985 : 1
            transformOrigin: Item.Center
            color: Colours.layer(Colours.palette.m3surfaceContainer, tileMouse.containsMouse ? 3 : 1)
            border.width: 1
            border.color: tileMouse.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.9) : Qt.alpha(Colours.palette.m3outline, 0.2)
            clip: true

            Behavior on color {
              CAnim {}
            }

            Behavior on border.color {
              CAnim {}
            }

            Behavior on scale {
              Anim {}
            }

            Image {
              anchors.fill: parent
              asynchronous: true
              cache: true
              fillMode: Image.PreserveAspectCrop
              source: cell.modelData.thumb || cell.modelData.path || ""
              sourceSize.width: width
              sourceSize.height: height
            }

            StyledRect {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              implicitHeight: imageMeta.implicitHeight + Tokens.padding.smaller * 2
              color: Qt.alpha(Colours.palette.m3surface, 0.72)
              bottomLeftRadius: parent.radius
              bottomRightRadius: parent.radius

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.large * 2
                spacing: Tokens.spacing.small

                StyledText {
                  id: imageMeta

                  Layout.fillWidth: true
                  text: cell.modelData.resolution || cell.modelData.name || cell.modelData.id || ""
                  color: Colours.palette.m3onSurface
                  font.pointSize: Tokens.font.size.small
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              id: tileMouse

              anchors.fill: parent
              acceptedButtons: Qt.RightButton
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPressed: event => {
                if (event.button === Qt.RightButton) {
                  imageMenu.expanded = true;
                  event.accepted = true;
                }
              }
            }

            StyledRect {
              id: menuButton

              z: 2
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: Tokens.padding.smaller
              implicitWidth: 28
              implicitHeight: 28
              radius: Tokens.rounding.full
              color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, menuClickArea.containsMouse ? 0.92 : 0.62)
              border.width: 1
              border.color: Qt.alpha(Colours.palette.m3outline, 0.24)

              Behavior on color {
                CAnim {}
              }

              MaterialIcon {
                anchors.centerIn: parent
                text: "more_vert"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.normal
              }

              MouseArea {
                id: menuClickArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: imageMenu.expanded = true
              }
            }

            Menu {
              id: imageMenu

              attachTo: tile
              attachSideX: Menu.Right
              attachSideY: Menu.Bottom
              thisSideX: Menu.Right
              thisSideY: Menu.Top
              marginY: Tokens.spacing.small

              items: [
                MenuItem {
                  icon: "open_in_new"
                  text: qsTr("Open in web")
                  onClicked: Wallhaven.openInWeb(cell.modelData)
                },
                MenuItem {
                  icon: "download"
                  text: qsTr("Download")
                  onClicked: Wallhaven.download(cell.modelData)
                },
                MenuItem {
                  icon: "wallpaper"
                  text: qsTr("Set as wallpaper")
                  separatorBefore: true
                  onClicked: Wallhaven.setAsWallpaper(cell.modelData)
                }
              ]
            }
          }
        }
      }

      StyledRect {
        anchors.fill: parent
        visible: Wallhaven.searching || Wallhaven.error.length > 0 || Wallhaven.results.length === 0
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.25)

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Tokens.padding.large * 2, 360)
          spacing: Tokens.spacing.normal

          BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: Wallhaven.searching
            visible: Wallhaven.searching
          }

          MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: !Wallhaven.searching
            text: Wallhaven.error.length > 0 ? "error" : "image_search"
            color: Wallhaven.error.length > 0 ? Colours.palette.m3error : Colours.palette.m3outline
            font.pointSize: Tokens.font.size.extraLarge
          }

          StyledText {
            Layout.fillWidth: true
            text: Wallhaven.searching ? qsTr("Searching") : Wallhaven.error.length > 0 ? Wallhaven.error : qsTr("No images")
            horizontalAlignment: Text.AlignHCenter
            color: Wallhaven.error.length > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component PagerButton: StyledRect {
    id: pagerButton

    property string icon
    property bool disabled

    signal clicked

    implicitWidth: 38
    implicitHeight: 34
    radius: Tokens.rounding.full
    color: disabled ? Qt.alpha(Colours.palette.m3onSurface, 0.08) : Colours.palette.m3secondaryContainer
    border.width: 1
    border.color: disabled ? Qt.alpha(Colours.palette.m3outline, 0.12) : Qt.alpha(Colours.palette.m3outline, 0.24)

    Behavior on color {
      CAnim {}
    }

    MaterialIcon {
      anchors.centerIn: parent
      text: pagerButton.icon
      color: pagerButton.disabled ? Qt.alpha(Colours.palette.m3onSurface, 0.36) : Colours.palette.m3onSecondaryContainer
      font.pointSize: Tokens.font.size.large
    }

    MouseArea {
      anchors.fill: parent
      enabled: !pagerButton.disabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pagerButton.clicked()
    }
  }

  component FilterChip: StyledRect {
    id: chip

    property string text
    property string icon
    property bool checked
    property bool disabled

    signal clicked

    implicitWidth: chipContent.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: Tokens.rounding.full
    color: checked ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 2)
    border.width: 1
    border.color: checked ? Qt.alpha(Colours.palette.m3secondary, 0.58) : Qt.alpha(Colours.palette.m3outline, 0.22)
    opacity: disabled ? 0.55 : 1

    Behavior on color {
      CAnim {}
    }

    Behavior on border.color {
      CAnim {}
    }

    RowLayout {
      id: chipContent

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        text: chip.icon
        color: chip.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.normal
      }

      StyledText {
        text: chip.text
        color: chip.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: !chip.disabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  Connections {
    target: Wallhaven

    function onResultsChanged(): void {
      grid.positionViewAtBeginning();
    }
  }
}
