import QtQuick
import "../"
import "../services"

Rectangle {
  id: root

  property bool open: false
  property string activeTab: "selector"

  signal closeRequested()
  signal steamWorkshopRequested()
  signal monitorPickerRequested()

  width: open ? 620 : 0
  opacity: open ? 1 : 0
  color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95)
  border.width: 1
  border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.26)
  clip: true

  Behavior on width {
    NumberAnimation {
      duration: Theme.animDuration + 80
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    NumberAnimation { duration: Theme.animDuration }
  }

  Column {
    anchors.fill: parent
    anchors.margins: root.open ? 16 : 0
    spacing: 12
    visible: root.open || root.width >= 80

    Flickable {
      id: tabScroll
      width: parent.width
      height: 32
      contentWidth: tabRow.implicitWidth
      contentHeight: tabRow.implicitHeight
      flickableDirection: Flickable.HorizontalFlick
      clip: true

      Row {
        id: tabRow
        spacing: -4

        Repeater {
          model: [
            { key: "selector", label: "SELECTOR" },
            { key: "general", label: "GENERAL" },
            { key: "paths", label: "PATHS" },
            { key: "performance", label: "PERFORMANCE" },
            { key: "external", label: "EXTERNAL" },
            { key: "keybinds", label: "KEYBINDS" },
            { key: "theme", label: "THEME" },
            { key: "wallhaven", label: "WALLHAVEN" },
            { key: "steam", label: "STEAM" },
            { key: "ollama", label: "OLLAMA" },
            { key: "matugen", label: "MATUGEN" }
          ]

          SkwdButton {
            label: modelData.label
            active: root.activeTab === modelData.key
            height: 28
            onClicked: root.activeTab = modelData.key
          }
        }
      }
    }

    Flickable {
      width: parent.width
      height: parent.height - y - 42
      contentWidth: width
      contentHeight: settingsContent.implicitHeight
      clip: true

      Column {
        id: settingsContent
        width: parent.width
        spacing: 14

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "selector"

          Repeater {
            model: [
              { label: "Slices", mode: "slices" },
              { label: "Hex", mode: "hex" },
              { label: "Wall", mode: "wall" },
              { label: "Mosaic", mode: "mosaic" }
            ]

            SettingsChoice {
              label: modelData.label
              checked: WallpaperService.displayMode === modelData.mode
              radio: true
              onClicked: WallpaperService.displayMode = modelData.mode
            }
          }

          Repeater {
            model: [
              { label: "Newest first", mode: "date" },
              { label: "Color groups", mode: "color" }
            ]

            SettingsChoice {
              label: modelData.label
              checked: WallpaperService.sortMode === modelData.mode
              radio: true
              onClicked: WallpaperService.sortMode = modelData.mode
            }
          }

          Repeater {
            model: 13

            Item {
              width: 28
              height: 28

              Rectangle {
                id: colorChoice
                anchors.centerIn: parent
                width: WallpaperService.selectedColorFilter === (index === 12 ? 99 : index) ? 22 : 18
                height: 18
                color: index === 12 ? "#777777" : Qt.hsla(index / 12.0, 0.72, 0.52, 1.0)
                border.width: WallpaperService.selectedColorFilter === (index === 12 ? 99 : index) ? 2 : 1
                border.color: Theme.text
                rotation: -8

                Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

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

          SettingsLine { label: "Selected layout"; value: WallpaperService.displayMode }
          SettingsLine { label: "Sort mode"; value: WallpaperService.sortMode }
          SettingsLine { label: "Visible items"; value: String(WallpaperService.filteredModel.count) }
          SettingsLine { label: "Slice width"; value: WallpaperService.sliceWidth + " / " + WallpaperService.hoverWidth + " / " + WallpaperService.expandedWidth }
          SettingsLine { label: "Slice geometry"; value: WallpaperService.sliceHeight + "h, skew " + WallpaperService.skewOffset }
          SettingsLine { label: "Grid thumbs"; value: WallpaperService.gridThumbWidth + " x " + WallpaperService.gridThumbHeight }
          SettingsLine { label: "Hex thumbs"; value: WallpaperService.hexThumbWidth + " x " + WallpaperService.hexThumbHeight }
          SettingsLine { label: "Mosaic thumbs"; value: WallpaperService.mosaicThumbWidth + " x " + WallpaperService.mosaicThumbHeight }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "general"

          SettingsLine { label: "Close on selection"; value: WallpaperService.closeOnSelection ? "On" : "Off" }
          SettingsChoice {
            label: WallpaperService.closeOnSelection ? "Close On Apply" : "Stay Open"
            checked: WallpaperService.closeOnSelection
            radio: false
            onClicked: WallpaperService.setSetting("closeOnSelection", !WallpaperService.closeOnSelection)
          }
          SettingsChoice {
            label: "Last Selection"
            checked: WallpaperService.reopenAtLastSelection
            radio: false
            onClicked: WallpaperService.setSetting("reopenAtLastSelection", !WallpaperService.reopenAtLastSelection)
          }
          SettingsChoice {
            label: "Mute Videos"
            checked: WallpaperService.wallpaperMute
            radio: false
            onClicked: WallpaperService.setSetting("wallpaperMute", !WallpaperService.wallpaperMute)
          }
          SettingsChoice {
            label: WallpaperService.randomRotationActive ? "Stop Random" : "Start Random"
            checked: WallpaperService.randomRotationActive
            radio: false
            onClicked: WallpaperService.toggleRandomRotation()
          }
          SettingsLine { label: "Filter bar"; value: "Bottom sheet" }
          SettingsLine { label: "Random interval"; value: WallpaperService.randomInterval + "s" }
          SettingsLine { label: "Favourites"; value: Object.keys(WallpaperService.favouritesDb).length + " saved" }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "paths"

          SettingsLine { label: "Wallpaper path"; value: WallpaperService.wallpaperDir }
          SettingsLine { label: "Metadata path"; value: WallpaperService.metaPath }
          SettingsLine { label: "Cache"; value: WallpaperService.cacheLoading ? "Rebuilding" : "Ready" }
          SettingsLine { label: "Steam root"; value: WallpaperService.steamRoot }
          SettingsLine { label: "Selected monitor"; value: WallpaperService.selectedMonitor !== "" ? WallpaperService.selectedMonitor : "all monitors" }
          SkwdButton {
            label: "Pick Monitor"
            onClicked: root.monitorPickerRequested()
          }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "performance"

          SkwdButton {
            label: WallpaperService.cacheLoading ? "Rebuilding" : "Rebuild Cache"
            active: WallpaperService.cacheLoading
            interactive: !WallpaperService.cacheLoading
            onClicked: WallpaperService.rebuildCache()
          }
          SkwdButton {
            label: WallpaperService.imageOptimizeRunning ? "Optimizing" : "Optimize Images"
            active: WallpaperService.imageOptimizeRunning
            interactive: !WallpaperService.imageOptimizeRunning
            onClicked: WallpaperService.optimizeImages()
          }
          SkwdButton {
            label: WallpaperService.videoConvertRunning ? "Converting" : "Convert Videos"
            active: WallpaperService.videoConvertRunning
            interactive: !WallpaperService.videoConvertRunning
            onClicked: WallpaperService.convertVideos()
          }
          SkwdButton {
            label: "Auto Image"
            active: WallpaperService.autoOptimizeImages
            onClicked: WallpaperService.setSetting("autoOptimizeImages", !WallpaperService.autoOptimizeImages)
          }
          SkwdButton {
            label: "Auto Video"
            active: WallpaperService.autoConvertVideos
            onClicked: WallpaperService.setSetting("autoConvertVideos", !WallpaperService.autoConvertVideos)
          }
          SettingsLine { label: "Image optimization"; value: WallpaperService.imageOptimizePreset + " / " + WallpaperService.imageOptimizeResolution }
          SettingsLine { label: "Video conversion"; value: WallpaperService.videoConvertPreset + " / " + WallpaperService.videoConvertResolution }
          SettingsLine { label: "Retention"; value: WallpaperService.imageTrashDays + "d images, " + WallpaperService.videoTrashDays + "d videos" }
          SettingsLine { label: "Video backend"; value: "mpvpaper" }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "external"

          SettingsLine { label: "Postprocessing"; value: "Ryoku theme refresh" }
          SettingsLine { label: "Apply command"; value: "ryoku-ipc wallpaper apply" }
          SettingsLine { label: "External command"; value: WallpaperService.externalWallpaperCommand !== "" ? WallpaperService.externalWallpaperCommand : "disabled" }
          SettingsLine { label: "Wallpaper Engine"; value: WallpaperService.steamEnabled ? "Steam Workshop tab" : "disabled" }
          SettingsLine { label: "Postprocessing slots"; value: WallpaperService.postProcessingCommands.length + " configured" }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "keybinds"

          SettingsLine { label: "Left / Right"; value: "Move selection" }
          SettingsLine { label: "Enter"; value: "Apply selected" }
          SettingsLine { label: "Escape"; value: "Close" }
          SettingsLine { label: "Shift + Up"; value: "Filter bar" }
          SettingsLine { label: "Shift + Down"; value: "Tags" }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "theme"

          SettingsLine { label: "Matugen scheme"; value: WallpaperService.scheme }
          SettingsChoice {
            label: "Matugen"
            checked: WallpaperService.matugenEnabled
            radio: false
            onClicked: WallpaperService.setSetting("matugenEnabled", !WallpaperService.matugenEnabled)
          }
          SettingsChoice {
            label: "Light"
            checked: WallpaperService.matugenMode === "light"
            radio: true
            onClicked: WallpaperService.setSetting("matugenMode", "light")
          }
          SettingsChoice {
            label: "Dark"
            checked: WallpaperService.matugenMode === "dark"
            radio: true
            onClicked: WallpaperService.setSetting("matugenMode", "dark")
          }
          SettingsLine { label: "Theme integration"; value: "Ryoku themes section" }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "wallhaven"

          SettingsChoice {
            label: "Wallhaven"
            checked: WallpaperService.wallhavenEnabled
            radio: false
            onClicked: WallpaperService.setSetting("wallhavenEnabled", !WallpaperService.wallhavenEnabled)
          }
          SettingsLine { label: "Browser"; value: WallpaperService.wallhavenEnabled ? "Enabled" : "Disabled" }
          SettingsLine { label: "Search priority"; value: "Local first, Web on request" }
          SettingsLine { label: "Results"; value: WallpaperService.wallhavenLoading ? "Searching" : "Ready" }
          SettingsLine { label: "Sorting"; value: WallpaperService.wallhavenSorting + " / " + WallpaperService.wallhavenOrder }
          SettingsLine { label: "Purity"; value: WallpaperService.wallhavenPurity }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "steam"

          SettingsChoice {
            label: "Steam Workshop"
            checked: WallpaperService.steamEnabled
            radio: false
            onClicked: WallpaperService.setSetting("steamEnabled", !WallpaperService.steamEnabled)
          }
          SkwdButton {
            label: "Browse Steam"
            onClicked: root.steamWorkshopRequested()
          }
          SettingsLine { label: "Steam Workshop"; value: WallpaperService.steamEnabled ? "Enabled" : "Disabled" }
          SettingsLine { label: "Wallpaper Engine"; value: WallpaperService.steamEnabled ? "Browse tab enabled" : "Backend disabled" }
          SettingsLine { label: "Steam user"; value: WallpaperService.steamUsername !== "" ? WallpaperService.steamUsername : "not set" }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "ollama"

          SettingsChoice {
            label: "Ollama"
            checked: WallpaperService.ollamaEnabled
            radio: false
            onClicked: WallpaperService.setSetting("ollamaEnabled", !WallpaperService.ollamaEnabled)
          }
          SettingsChoice {
            label: WallpaperService.ollamaTaggingActive ? "Stop Tagging" : "Start Tagging"
            checked: WallpaperService.ollamaTaggingActive
            radio: false
            onClicked: WallpaperService.startOllamaTagging()
          }
          SettingsLine { label: "Automated tagging"; value: WallpaperService.ollamaEnabled ? "Available" : "Disabled" }
          SettingsLine { label: "Model"; value: WallpaperService.ollamaModel }
          SettingsLine { label: "URL"; value: WallpaperService.ollamaUrl }
        }

        Flow {
          width: parent.width
          spacing: 10
          visible: root.activeTab === "matugen"

          SettingsLine { label: "Colour extraction"; value: "Ryoku theme pipeline" }
          SettingsLine { label: "Mode"; value: WallpaperService.matugenMode }
          SettingsLine { label: "Scheme"; value: WallpaperService.scheme }
          SettingsLine { label: "Scheme type"; value: WallpaperService.matugenSchemeType }
        }
      }
    }

    Row {
      width: parent.width
      spacing: 8

      SkwdButton {
        label: WallpaperService.statusText !== "" ? WallpaperService.statusText : "Ready"
        interactive: false
      }

      SkwdButton {
        label: "Close"
        onClicked: root.closeRequested()
      }
    }
  }

  component SettingsLine: Item {
    property string label: ""
    property string value: ""

    width: 184
    height: 48

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(1, 1, 1, 0.055)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.10)
    }

    Column {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      anchors.topMargin: 7
      spacing: 5

      Text {
        width: parent.width
        text: label
        color: Theme.text
        font.pixelSize: 11
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: value
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.48)
        font.pixelSize: 10
        elide: Text.ElideMiddle
      }
    }
  }

  component SettingsChoice: Item {
    id: choice

    property string label: ""
    property bool checked: false
    property bool radio: false

    signal clicked()

    width: 184
    height: 34

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(1, 1, 1, choice.checked ? 0.075 : 0.045)
      border.width: 1
      border.color: choice.checked
        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.48)
        : Qt.rgba(1, 1, 1, 0.10)
    }

    Rectangle {
      id: choiceDot
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      height: 14
      radius: choice.radio ? 7 : 3
      color: "transparent"
      border.width: 1
      border.color: choice.checked ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)

      Rectangle {
        anchors.centerIn: parent
        width: choice.checked ? 8 : 0
        height: choice.checked ? 8 : 0
        radius: choice.radio ? 4 : 2
        color: Theme.active

        Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
      }
    }

    Text {
      anchors.left: choiceDot.right
      anchors.leftMargin: 8
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: choice.label
      color: choice.checked ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.58)
      font.pixelSize: 11
      font.weight: choice.checked ? Font.DemiBold : Font.Medium
      elide: Text.ElideRight
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: choice.clicked() }
  }
}
