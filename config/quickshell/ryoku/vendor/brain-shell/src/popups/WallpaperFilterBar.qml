import QtQuick
import QtQuick.Controls
import "../"
import "../services"

Rectangle {
  id: root

  signal settingsRequested()
  signal rebuildRequested()

  implicitWidth: Math.min(row.implicitWidth + 24, 980)
  implicitHeight: 46
  height: implicitHeight
  radius: 23
  color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.86)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.08)
  clip: true

  Flickable {
    id: scroller
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Row {
      id: row
      y: Math.max(0, (scroller.height - implicitHeight) / 2)
      spacing: 10

      Repeater {
        model: [
          { label: "Local", source: "local" },
          { label: "Web", source: "wallhaven" }
        ]

        Rectangle {
          width: label.implicitWidth + 18
          height: 28
          radius: 6
          color: WallpaperService.selectedSourceFilter === modelData.source ? Theme.active : Qt.rgba(1, 1, 1, 0.08)

          Text {
            id: label
            anchors.centerIn: parent
            text: modelData.label
            color: WallpaperService.selectedSourceFilter === modelData.source ? Theme.background : Theme.text
            font.pixelSize: 12
          }

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: WallpaperService.selectedSourceFilter = modelData.source
          }
        }
      }

      Repeater {
        model: [
          { label: "All", type: "" },
          { label: "Images", type: "image" },
          { label: "Videos", type: "video" }
        ]

        Rectangle {
          width: label.implicitWidth + 18
          height: 28
          radius: 6
          color: WallpaperService.selectedTypeFilter === modelData.type ? Theme.active : Qt.rgba(1, 1, 1, 0.08)

          Text {
            id: label
            anchors.centerIn: parent
            text: modelData.label
            color: WallpaperService.selectedTypeFilter === modelData.type ? Theme.background : Theme.text
            font.pixelSize: 12
          }

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: WallpaperService.selectedTypeFilter = modelData.type
          }
        }
      }

      Rectangle {
        width: 260
        height: 30
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: searchInput.activeFocus ? Theme.active : Qt.rgba(1, 1, 1, 0.10)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "Search"
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.32)
          font.pixelSize: 12
          visible: searchInput.text === ""
        }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          color: Theme.text
          selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
          font.pixelSize: 13
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          onTextChanged: WallpaperService.searchQuery = text
          Keys.onReturnPressed: WallpaperService.searchWallhaven(text, 1)
          Keys.onEscapePressed: Popups.wallpaperOpen = false
        }
      }

      Repeater {
        model: 13

        Rectangle {
          width: 22
          height: 22
          radius: 11
          color: index === 12 ? "#777777" : Qt.hsla(index / 12.0, 0.72, 0.52, 1.0)
          border.width: WallpaperService.selectedColorFilter === (index === 12 ? 99 : index) ? 3 : 1
          border.color: Theme.text

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: {
              var value = index === 12 ? 99 : index
              WallpaperService.selectedColorFilter =
                WallpaperService.selectedColorFilter === value ? -1 : value
            }
          }
        }
      }

      Rectangle {
        width: rebuildLabel.implicitWidth + 18
        height: 28
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.08)

        Text {
          id: rebuildLabel
          anchors.centerIn: parent
          text: "Rebuild"
          color: Theme.text
          font.pixelSize: 12
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: root.rebuildRequested()
        }
      }

      Rectangle {
        width: settingsLabel.implicitWidth + 18
        height: 28
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.08)

        Text {
          id: settingsLabel
          anchors.centerIn: parent
          text: "Settings"
          color: Theme.text
          font.pixelSize: 12
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: root.settingsRequested()
        }
      }
    }
  }
}
