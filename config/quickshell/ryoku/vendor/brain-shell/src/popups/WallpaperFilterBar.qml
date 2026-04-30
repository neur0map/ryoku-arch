import QtQuick
import QtQuick.Controls
import "../"
import "../services"

Item {
  id: root

  property string activeMode: "wallpaper"

  signal modeRequested(string mode)
  signal settingsRequested()
  signal rebuildRequested()
  signal searchSubmitted()
  signal tagCloudRequested()
  signal wallhavenRequested()

  implicitWidth: 860
  implicitHeight: root.activeMode === "wallpaper" ? 34 : 32
  height: implicitHeight
  clip: true

  function submitSearch() {
    if (root.activeMode === "wallpaper"
        && WallpaperService.selectedSourceFilter === "wallhaven"
        && searchInput.text.trim() !== "") {
      WallpaperService.searchWallhaven(searchInput.text, 1)
    }
    root.searchSubmitted()
  }

  function syncSearchTarget() {
    if (root.activeMode === "theme") {
      ThemeService.searchQuery = searchInput.text
    } else if (root.activeMode === "font") {
      FontService.searchQuery = searchInput.text
    } else if (root.activeMode === "cursor") {
      CursorService.searchQuery = searchInput.text
    } else {
      WallpaperService.searchQuery = searchInput.text
    }
  }

  function searchTextForMode() {
    if (root.activeMode === "theme") return ThemeService.searchQuery
    if (root.activeMode === "font") return FontService.searchQuery
    if (root.activeMode === "cursor") return CursorService.searchQuery
    return WallpaperService.searchQuery
  }

  function clearSearchText() {
    searchInput.text = ""
  }

  onActiveModeChanged: {
    searchInput.text = searchTextForMode()
  }

  Component.onCompleted: {
    searchInput.text = searchTextForMode()
  }

  Flickable {
    id: scroller
    anchors.fill: parent
    anchors.leftMargin: 2
    anchors.rightMargin: 2
    contentWidth: row.width
    contentHeight: row.implicitHeight
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Flow {
      id: row
      y: Math.max(0, (scroller.height - implicitHeight) / 2)
      width: scroller.width
      spacing: 7

      SkwdButton {
        label: "FAV"
        active: WallpaperService.favouriteFilterActive
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        onClicked: WallpaperService.favouriteFilterActive = !WallpaperService.favouriteFilterActive
      }

      SkwdButton {
        label: "RND"
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        onClicked: WallpaperService.randomApply()
      }

      SkwdButton {
        label: "TAG"
        active: WallpaperService.selectedTags.length > 0
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        onClicked: root.tagCloudRequested()
      }

      SkwdButton {
        label: "WH"
        active: WallpaperService.selectedSourceFilter === "wallhaven"
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        onClicked: {
          WallpaperService.selectedSourceFilter = "wallhaven"
          root.wallhavenRequested()
        }
      }

      Repeater {
        model: root.activeMode === "wallpaper" ? [
          { label: "LOCAL", source: "local" },
          { label: "WEB", source: "wallhaven" }
        ] : []

        SkwdButton {
          label: modelData.label
          active: WallpaperService.selectedSourceFilter === modelData.source
          height: 28
          horizontalPadding: 16
          onClicked: {
            WallpaperService.selectedSourceFilter = modelData.source
            if (modelData.source === "wallhaven" && searchInput.text.trim() !== "") {
              root.submitSearch()
            }
          }
        }
      }

      Repeater {
        model: root.activeMode === "wallpaper" ? [
          { label: "ALL", type: "" },
          { label: "PIC", type: "image" },
          { label: "VID", type: "video" }
        ] : []

        SkwdButton {
          label: modelData.label
          active: WallpaperService.selectedTypeFilter === modelData.type
          height: 28
          horizontalPadding: 16
          onClicked: WallpaperService.selectedTypeFilter = modelData.type
        }
      }

      Item {
        id: searchBox
        width: root.activeMode === "wallpaper" ? 174 : 210
        height: 28
        property int skew: 10

        Canvas {
          anchors.fill: parent

          property color fillColor: Qt.rgba(1, 1, 1, 0.07)
          property color strokeColor: searchInput.activeFocus
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.62)
            : Qt.rgba(1, 1, 1, 0.12)

          onStrokeColorChanged: requestPaint()
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d")
            var sk = searchBox.skew
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = fillColor
            ctx.beginPath()
            ctx.moveTo(sk, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width - sk, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fill()
            ctx.strokeStyle = strokeColor
            ctx.lineWidth = 1
            ctx.stroke()
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: searchBox.skew + 7
          anchors.verticalCenter: parent.verticalCenter
          text: root.activeMode === "wallpaper"
            ? (WallpaperService.selectedSourceFilter === "wallhaven" ? "Search web" : "Search local")
            : (root.activeMode === "theme" ? "Search themes" : (root.activeMode === "font" ? "Search fonts" : "Search cursors"))
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.32)
          font.pixelSize: 11
          visible: searchInput.text === ""
        }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: searchBox.skew + 7
          anchors.rightMargin: searchBox.skew + 7
          color: Theme.text
          selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
          font.pixelSize: 12
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          onTextChanged: root.syncSearchTarget()
          Keys.onReturnPressed: function(event) {
            root.submitSearch()
            event.accepted = true
          }
          Keys.onEscapePressed: Popups.wallpaperOpen = false
        }
      }

      SkwdButton {
        label: "CACHE"
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        onClicked: root.rebuildRequested()
      }

      SkwdButton {
        label: "SET"
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        onClicked: root.settingsRequested()
      }

      SkwdButton {
        label: WallpaperService.settingsSummary()
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
        interactive: false
      }

      SkwdButton {
        label: WallpaperService.cacheLoading ? "CACHE" : (WallpaperService.ollamaTaggingActive ? "OLLAMA" : "")
        active: WallpaperService.cacheLoading || WallpaperService.ollamaTaggingActive
        height: 28
        horizontalPadding: 16
        visible: root.activeMode === "wallpaper"
          && (WallpaperService.cacheLoading || WallpaperService.ollamaTaggingActive)
        interactive: false
      }

    }
  }
}
