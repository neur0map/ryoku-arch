import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../services"
import "../"

PanelWindow {
  id: root

  Binding { target: Popups; property: "wallpaperVisible"; value: selector.visible }

  anchors.left:   true
  anchors.right:  true
  anchors.top:    true
  anchors.bottom: true

  implicitHeight: root.overlayHeight
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  visible: windowVisible

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  readonly property int overlayHeight: 1080
  readonly property int selectorMaxWidth: 1040
  readonly property int selectorHeight: 380
  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius

  property bool windowVisible: false
  property bool selfHovered: true
  property bool allowHover: false

  Timer {
    id: closeTimer
    interval: Theme.animDuration + 20
    onTriggered: {
      if (!Popups.wallpaperOpen) root.windowVisible = false
    }
  }

  Timer {
    id: hoverCloseTimer
    interval: Popups.hoverCloseDelay * 2
    onTriggered: {
      if (!Popups.wallpaperTriggerHovered && !root.selfHovered) {
        Popups.wallpaperOpen = false
      }
    }
  }

  function openSelector() {
    closeTimer.stop()
    hoverCloseTimer.stop()
    root.windowVisible = true
    content.setMode(Popups.wallpaperMode)
    keyScope.forceActiveFocus()
  }

  onSelfHoveredChanged: {
    if (!selfHovered && !Popups.wallpaperTriggerHovered) {
      hoverCloseTimer.restart()
    } else {
      hoverCloseTimer.stop()
    }
  }

  Connections {
    target: Popups

    function onWallpaperTriggerHoveredChanged() {
      if (Popups.wallpaperTriggerHovered && root.allowHover) {
        if (!Popups.wallpaperOpen) {
          Popups.wallpaperOpen = true
          root.openSelector()
        }
      } else if (!root.selfHovered) {
        hoverCloseTimer.restart()
      }
    }

    function onWallpaperOpenChanged() {
      if (Popups.wallpaperOpen) {
        root.openSelector()
      } else {
        closeTimer.restart()
      }
    }

    function onWallpaperModeChanged() {
      if (Popups.wallpaperOpen) {
        content.setMode(Popups.wallpaperMode)
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: Popups.wallpaperOpen
    onClicked: Popups.wallpaperOpen = false
  }

  FocusScope {
    id: keyScope
    anchors.fill: parent
    focus: Popups.wallpaperOpen

    Keys.onEscapePressed: Popups.wallpaperOpen = false
    Keys.onReturnPressed: content.applySelected()
    Keys.onLeftPressed: content.selectRelative(-1)
    Keys.onRightPressed: content.selectRelative(1)
  }

  Item {
    id: selector
    anchors.horizontalCenter: parent.horizontalCenter
    y: Popups.wallpaperOpen ? parent.height - height : parent.height + Theme.borderWidth
    width: Math.max(0, Math.min(root.selectorMaxWidth + 2 * root.fw, parent.width - 32))
    height: root.selectorHeight + root.fh
    visible: root.windowVisible
    clip: true

    Behavior on y {
      NumberAnimation {
        duration: Theme.animDuration + 80
        easing.type: Easing.OutCubic
      }
    }

    HoverHandler {
      onHoveredChanged: root.selfHovered = hovered
    }

    PopupShape {
      anchors.fill: parent
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.92)
      radius: Theme.cornerRadius
      flareWidth: root.fw
      flareHeight: root.fh
      attachedEdge: "bottom"
    }

    MouseArea {
      anchors.fill: parent
      onClicked: function(mouse) {
        mouse.accepted = true
      }
    }

    Item {
      id: content
      anchors {
        fill: parent
        leftMargin: root.fw + 16
        rightMargin: root.fw + 16
        topMargin: 14
        bottomMargin: root.fh + 14
      }

      property string activeMode: "wallpaper"
      property string selectedPath: ""
      property string selectedThemeName: ""
      property bool settingsOpen: false

      function setMode(mode) {
        var nextMode = mode === "theme" ? "theme" : "wallpaper"
        activeMode = nextMode
        Popups.wallpaperMode = nextMode
        settingsOpen = false

        if (nextMode === "theme") {
          WallpaperService.previewWall = ""
          selectedThemeName = ThemeService.currentTheme
          ThemeService.refresh()
          syncThemeSelection()
        } else {
          WallpaperService.refresh()
          WallpaperService.previewWall = ""
          selectedPath = WallpaperService.currentWall
          syncSelection()
        }

        keyScope.forceActiveFocus()
      }

      function itemAt(index) {
        if (index < 0 || index >= WallpaperService.filteredModel.count) return null
        return WallpaperService.filteredModel.get(index)
      }

      function selectedIndex() {
        for (var i = 0; i < WallpaperService.filteredModel.count; i++) {
          var item = WallpaperService.filteredModel.get(i)
          if (item.path === selectedPath) return i
        }
        return WallpaperService.filteredModel.count > 0 ? 0 : -1
      }

      function selectedItem() {
        var idx = selectedIndex()
        return idx >= 0 ? itemAt(idx) : null
      }

      function selectItem(item, index) {
        if (!item || !item.path) return
        selectedPath = item.path
        WallpaperService.previewWall = item.path
        wallList.currentIndex = index
        wallList.positionViewAtIndex(index, ListView.Center)
      }

      function themeItemAt(index) {
        if (index < 0 || index >= ThemeService.filteredModel.count) return null
        return ThemeService.filteredModel.get(index)
      }

      function themeSelectedIndex() {
        for (var i = 0; i < ThemeService.filteredModel.count; i++) {
          var item = ThemeService.filteredModel.get(i)
          if (item.name === selectedThemeName) return i
        }

        for (var j = 0; j < ThemeService.filteredModel.count; j++) {
          var activeItem = ThemeService.filteredModel.get(j)
          if (activeItem.active) return j
        }

        return ThemeService.filteredModel.count > 0 ? 0 : -1
      }

      function selectedThemeItem() {
        var idx = themeSelectedIndex()
        return idx >= 0 ? themeItemAt(idx) : null
      }

      function selectThemeItem(item, index) {
        if (!item || !item.name) return
        selectedThemeName = item.name
        themeList.currentIndex = index
        themeList.positionViewAtIndex(index, ListView.Center)
      }

      function selectRelative(delta) {
        if (activeMode === "theme") {
          var themeCount = ThemeService.filteredModel.count
          if (themeCount <= 0) return
          var themeIndex = themeSelectedIndex()
          themeIndex = themeIndex < 0 ? 0 : (themeIndex + delta + themeCount) % themeCount
          selectThemeItem(themeItemAt(themeIndex), themeIndex)
          return
        }

        var count = WallpaperService.filteredModel.count
        if (count <= 0) return
        var idx = selectedIndex()
        idx = idx < 0 ? 0 : (idx + delta + count) % count
        selectItem(itemAt(idx), idx)
      }

      function applySelected() {
        if (activeMode === "theme") {
          var item = selectedThemeItem()
          if (!item || ThemeService.applying) return
          ThemeService.applyItem(item)
          Popups.wallpaperOpen = false
          return
        }

        var item = selectedItem()
        if (!item || WallpaperService.applying) return
        WallpaperService.applyItem(item)
        Popups.wallpaperOpen = false
      }

      function syncSelection() {
        if (activeMode !== "wallpaper") return
        var idx = selectedIndex()
        if (idx < 0) return
        selectItem(itemAt(idx), idx)
      }

      function syncThemeSelection() {
        if (activeMode !== "theme") return
        var idx = themeSelectedIndex()
        if (idx < 0) return
        selectThemeItem(themeItemAt(idx), idx)
      }

      function statusText() {
        if (activeMode === "theme") {
          if (ThemeService.loading) return "Loading"
          if (ThemeService.applying) return "Applying"
          return ThemeService.statusText
        }

        if (WallpaperService.cacheLoading) return "Loading"
        if (WallpaperService.wallhavenLoading) return "Searching"
        return WallpaperService.statusText
      }

      function applying() {
        return activeMode === "theme" ? ThemeService.applying : WallpaperService.applying
      }

      WallpaperFilterBar {
        id: filterBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.min(implicitWidth, parent.width)
        activeMode: content.activeMode
        onModeRequested: function(mode) {
          content.setMode(mode)
        }
        onSettingsRequested: content.settingsOpen = !content.settingsOpen
        onRebuildRequested: WallpaperService.rebuildCache()
        onSearchSubmitted: keyScope.forceActiveFocus()
      }

      ListView {
        id: wallList
        anchors.left: parent.left
        anchors.right: content.settingsOpen ? settingsPane.left : parent.right
        anchors.rightMargin: content.settingsOpen ? 18 : 0
        anchors.top: filterBar.bottom
        anchors.topMargin: 18
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 12
        orientation: ListView.Horizontal
        spacing: -22
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        preferredHighlightBegin: width / 2 - 180
        preferredHighlightEnd: width / 2 + 180
        highlightRangeMode: ListView.ApplyRange
        currentIndex: 0
        visible: content.activeMode === "wallpaper"
        model: WallpaperService.filteredModel
        onCountChanged: content.syncSelection()

        delegate: Item {
          id: delegateRoot

          required property int index
          required property string path
          required property string type
          required property string thumb
          required property string source
          required property string name

          readonly property var item: ({
            path: path,
            type: type,
            thumb: thumb,
            source: source,
            name: name
          })

          width: card.width
          height: wallList.height

          WallpaperSkewCard {
            id: card
            anchors.verticalCenter: parent.verticalCenter
            itemData: delegateRoot.item
            selected: content.selectedPath === delegateRoot.path
              || (content.selectedPath === "" && WallpaperService.currentWall === delegateRoot.path)
            onActivated: {
              if (content.selectedPath === delegateRoot.path) {
                content.applySelected()
              } else {
                content.selectItem(delegateRoot.item, delegateRoot.index)
              }
            }
          }
        }
      }

      ListView {
        id: themeList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: filterBar.bottom
        anchors.topMargin: 18
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 12
        orientation: ListView.Horizontal
        spacing: -6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        preferredHighlightBegin: width / 2 - 118
        preferredHighlightEnd: width / 2 + 118
        highlightRangeMode: ListView.ApplyRange
        currentIndex: 0
        visible: content.activeMode === "theme"
        model: ThemeService.filteredModel
        onCountChanged: content.syncThemeSelection()

        delegate: Item {
          id: themeDelegateRoot

          required property int index
          required property string source
          required property string name
          required property string display
          required property string path
          required property string preview
          required property bool active

          readonly property var item: ({
            source: source,
            name: name,
            display: display,
            path: path,
            preview: preview,
            active: active
          })

          width: card.width
          height: themeList.height

          ThemeCard {
            id: card
            anchors.verticalCenter: parent.verticalCenter
            itemData: themeDelegateRoot.item
            selected: content.selectedThemeName === themeDelegateRoot.name
              || (content.selectedThemeName === "" && themeDelegateRoot.active)
            onActivated: {
              if (content.selectedThemeName === themeDelegateRoot.name) {
                content.applySelected()
              } else {
                content.selectThemeItem(themeDelegateRoot.item, themeDelegateRoot.index)
              }
            }
          }
        }
      }

      Text {
        anchors.centerIn: wallList
        visible: content.activeMode === "wallpaper" && !WallpaperService.cacheLoading && wallList.count === 0
        text: WallpaperService.statusText
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 13
      }

      Text {
        anchors.centerIn: themeList
        visible: content.activeMode === "theme" && !ThemeService.loading && themeList.count === 0
        text: ThemeService.statusText !== "" ? ThemeService.statusText : "No themes found"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 13
      }

      WallpaperSettingsPane {
        id: settingsPane
        anchors.top: filterBar.bottom
        anchors.topMargin: 18
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        open: content.activeMode === "wallpaper" && content.settingsOpen
        onCloseRequested: content.settingsOpen = false
      }

      Row {
        id: applyBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 8

        Rectangle {
          width: statusLabel.implicitWidth + 24
          height: 30
          radius: 7
          color: Qt.rgba(1, 1, 1, 0.07)
          visible: content.statusText() !== ""

          Text {
            id: statusLabel
            anchors.centerIn: parent
            text: content.statusText()
            color: Theme.subtext
            font.pixelSize: 12
          }
        }

        Rectangle {
          id: applyButton
          width: 104
          height: 30
          radius: 7
          color: content.applying()
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
            : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
          border.width: 1
          border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.42)

          Text {
            anchors.centerIn: parent
            text: content.applying() ? "Applying" : "Apply"
            color: Theme.active
            font.pixelSize: 12
            font.weight: Font.Medium
          }

          HoverHandler {
            cursorShape: content.applying() ? Qt.ArrowCursor : Qt.PointingHandCursor
          }

          TapHandler {
            enabled: !content.applying()
            onTapped: content.applySelected()
          }
        }
      }
    }
  }
}
