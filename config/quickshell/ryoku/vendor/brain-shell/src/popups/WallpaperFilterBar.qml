import QtQuick
import QtQuick.Controls
import "../"
import "../services"

Rectangle {
  id: root

  property string activeMode: "wallpaper"

  signal modeRequested(string mode)
  signal settingsRequested()
  signal rebuildRequested()
  signal searchSubmitted()

  implicitWidth: Math.min(row.implicitWidth + 18, 820)
  implicitHeight: 36
  height: implicitHeight
  radius: 18
  color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.88)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.08)
  clip: true

  function submitWallhavenSearch() {
    if (root.activeMode !== "wallpaper") {
      root.searchSubmitted()
      return
    }

    WallpaperService.searchWallhaven(searchInput.text, 1)
    root.searchSubmitted()
  }

  function syncSearchTarget() {
    if (root.activeMode === "theme") {
      ThemeService.searchQuery = searchInput.text
    } else {
      WallpaperService.searchQuery = searchInput.text
    }
  }

  onActiveModeChanged: {
    searchInput.text = root.activeMode === "theme"
      ? ThemeService.searchQuery
      : WallpaperService.searchQuery
  }

  Component.onCompleted: {
    searchInput.text = root.activeMode === "theme"
      ? ThemeService.searchQuery
      : WallpaperService.searchQuery
  }

  Flickable {
    id: scroller
    anchors.fill: parent
    anchors.leftMargin: 9
    anchors.rightMargin: 9
    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Row {
      id: row
      y: Math.max(0, (scroller.height - implicitHeight) / 2)
      spacing: 6

      Repeater {
        model: [
          { label: "Walls", mode: "wallpaper" },
          { label: "Themes", mode: "theme" }
        ]

        Rectangle {
          width: label.implicitWidth + 16
          height: 24
          radius: 7
          color: root.activeMode === modelData.mode
            ? Theme.active
            : Qt.rgba(1, 1, 1, 0.08)

          Text {
            id: label
            anchors.centerIn: parent
            text: modelData.label
            color: root.activeMode === modelData.mode ? Theme.background : Theme.text
            font.pixelSize: 11
            font.weight: Font.Medium
          }

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: root.modeRequested(modelData.mode)
          }
        }
      }

      Rectangle {
        width: 1
        height: 20
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.10)
      }

      Repeater {
        model: root.activeMode === "wallpaper" ? [
          { label: "Local", source: "local" },
          { label: "Web", source: "wallhaven" }
        ] : []

        Rectangle {
          width: label.implicitWidth + 14
          height: 24
          radius: 7
          color: WallpaperService.selectedSourceFilter === modelData.source
            ? Theme.active
            : Qt.rgba(1, 1, 1, 0.08)

          Text {
            id: label
            anchors.centerIn: parent
            text: modelData.label
            color: WallpaperService.selectedSourceFilter === modelData.source ? Theme.background : Theme.text
            font.pixelSize: 11
          }

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: {
              WallpaperService.selectedSourceFilter = modelData.source
              if (modelData.source === "wallhaven" && searchInput.text.trim() !== "") {
                root.submitWallhavenSearch()
              }
            }
          }
        }
      }

      Repeater {
        model: root.activeMode === "wallpaper" ? [
          { label: "All", type: "" },
          { label: "Img", type: "image" },
          { label: "Vid", type: "video" }
        ] : []

        Rectangle {
          width: label.implicitWidth + 14
          height: 24
          radius: 7
          color: WallpaperService.selectedTypeFilter === modelData.type
            ? Theme.active
            : Qt.rgba(1, 1, 1, 0.08)

          Text {
            id: label
            anchors.centerIn: parent
            text: modelData.label
            color: WallpaperService.selectedTypeFilter === modelData.type ? Theme.background : Theme.text
            font.pixelSize: 11
          }

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: WallpaperService.selectedTypeFilter = modelData.type
          }
        }
      }

      Rectangle {
        width: root.activeMode === "theme" ? 210 : 176
        height: 24
        radius: 7
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: searchInput.activeFocus ? Theme.active : Qt.rgba(1, 1, 1, 0.10)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 9
          anchors.verticalCenter: parent.verticalCenter
          text: root.activeMode === "theme" ? "Search themes" : "Search"
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.32)
          font.pixelSize: 11
          visible: searchInput.text === ""
        }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: 9
          anchors.rightMargin: 9
          color: Theme.text
          selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
          font.pixelSize: 12
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          onTextChanged: root.syncSearchTarget()
          Keys.onReturnPressed: function(event) {
            if (root.activeMode === "wallpaper") {
              root.submitWallhavenSearch()
            } else {
              root.searchSubmitted()
            }
            event.accepted = true
          }
          Keys.onEscapePressed: Popups.wallpaperOpen = false
        }
      }

      Repeater {
        model: 13

        Item {
          width: root.activeMode === "wallpaper" ? 14 : 0
          height: 24
          visible: root.activeMode === "wallpaper"

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: index === 12 ? "#777777" : Qt.hsla(index / 12.0, 0.72, 0.52, 1.0)
            border.width: WallpaperService.selectedColorFilter === (index === 12 ? 99 : index) ? 2 : 1
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
      }

      Rectangle {
        width: rebuildLabel.implicitWidth + 14
        height: 24
        radius: 7
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: root.activeMode === "wallpaper"

        Text {
          id: rebuildLabel
          anchors.centerIn: parent
          text: "Rebuild"
          color: Theme.text
          font.pixelSize: 11
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: root.rebuildRequested()
        }
      }

      Rectangle {
        width: settingsLabel.implicitWidth + 14
        height: 24
        radius: 7
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: root.activeMode === "wallpaper"

        Text {
          id: settingsLabel
          anchors.centerIn: parent
          text: "Settings"
          color: Theme.text
          font.pixelSize: 11
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: root.settingsRequested()
        }
      }
    }
  }
}
