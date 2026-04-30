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
  readonly property int selectorMaxWidth: 1120
  readonly property int selectorHeight: 480
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
    content.setMode(Popups.wallpaperMode, true)
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
        content.setMode(Popups.wallpaperMode, false)
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
      property string selectedFontFamily: ""
      property string selectedCursorName: ""
      property bool settingsOpen: false
      property bool tagCloudOpen: false
      property bool wallhavenBrowserOpen: false
      property bool steamWorkshopBrowserOpen: false
      property bool monitorPickerOpen: false
      readonly property int modeRailWidth: 108
      readonly property int modeGap: 14

      function setMode(mode, resetSearch) {
        var nextMode = (mode === "theme" || mode === "font" || mode === "cursor") ? mode : "wallpaper"
        activeMode = nextMode
        Popups.wallpaperMode = nextMode
        settingsOpen = false
        tagCloudOpen = false
        wallhavenBrowserOpen = false
        steamWorkshopBrowserOpen = false
        monitorPickerOpen = false
        if (resetSearch) clearTransientSearch()

        if (nextMode === "theme") {
          WallpaperService.previewWall = ""
          selectedThemeName = ThemeService.currentTheme
          ThemeService.refresh()
          syncThemeSelection()
        } else if (nextMode === "font") {
          WallpaperService.previewWall = ""
          selectedFontFamily = FontService.currentFont
          FontService.refresh()
          syncFontSelection()
        } else if (nextMode === "cursor") {
          WallpaperService.previewWall = ""
          selectedCursorName = CursorService.currentCursor
          CursorService.refresh()
          syncCursorSelection()
        } else {
          WallpaperService.refresh()
          WallpaperService.previewWall = ""
          selectedPath = WallpaperService.currentWall
          syncSelection()
        }

        keyScope.forceActiveFocus()
      }

      function clearTransientSearch() {
        WallpaperService.searchQuery = ""
        WallpaperService.activeWallhavenQuery = ""
        WallpaperService.selectedSourceFilter = "local"
        ThemeService.searchQuery = ""
        FontService.searchQuery = ""
        CursorService.searchQuery = ""
        if (filterBar) filterBar.clearSearchText()
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

      function fontItemAt(index) {
        if (index < 0 || index >= FontService.filteredModel.count) return null
        return FontService.filteredModel.get(index)
      }

      function fontSelectedIndex() {
        for (var i = 0; i < FontService.filteredModel.count; i++) {
          var item = FontService.filteredModel.get(i)
          if (item.family === selectedFontFamily) return i
        }

        for (var j = 0; j < FontService.filteredModel.count; j++) {
          var activeItem = FontService.filteredModel.get(j)
          if (activeItem.active) return j
        }

        return FontService.filteredModel.count > 0 ? 0 : -1
      }

      function selectedFontItem() {
        var idx = fontSelectedIndex()
        return idx >= 0 ? fontItemAt(idx) : null
      }

      function selectFontItem(item, index) {
        if (!item || !item.family) return
        selectedFontFamily = item.family
        fontList.currentIndex = index
        fontList.positionViewAtIndex(index, ListView.Center)
      }

      function cursorItemAt(index) {
        if (index < 0 || index >= CursorService.filteredModel.count) return null
        return CursorService.filteredModel.get(index)
      }

      function cursorSelectedIndex() {
        for (var i = 0; i < CursorService.filteredModel.count; i++) {
          var item = CursorService.filteredModel.get(i)
          if (item.name === selectedCursorName) return i
        }

        for (var j = 0; j < CursorService.filteredModel.count; j++) {
          var activeItem = CursorService.filteredModel.get(j)
          if (activeItem.active) return j
        }

        return CursorService.filteredModel.count > 0 ? 0 : -1
      }

      function selectedCursorItem() {
        var idx = cursorSelectedIndex()
        return idx >= 0 ? cursorItemAt(idx) : null
      }

      function selectCursorItem(item, index) {
        if (!item || !item.name) return
        selectedCursorName = item.name
        cursorList.currentIndex = index
        cursorList.positionViewAtIndex(index, ListView.Center)
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

        if (activeMode === "font") {
          var fontCount = FontService.filteredModel.count
          if (fontCount <= 0) return
          var fontIndex = fontSelectedIndex()
          fontIndex = fontIndex < 0 ? 0 : (fontIndex + delta + fontCount) % fontCount
          selectFontItem(fontItemAt(fontIndex), fontIndex)
          return
        }

        if (activeMode === "cursor") {
          var cursorCount = CursorService.filteredModel.count
          if (cursorCount <= 0) return
          var cursorIndex = cursorSelectedIndex()
          cursorIndex = cursorIndex < 0 ? 0 : (cursorIndex + delta + cursorCount) % cursorCount
          selectCursorItem(cursorItemAt(cursorIndex), cursorIndex)
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
          finishApplyAction()
          return
        }

        if (activeMode === "font") {
          var fontItem = selectedFontItem()
          if (!fontItem || FontService.applying) return
          FontService.applyItem(fontItem)
          finishApplyAction()
          return
        }

        if (activeMode === "cursor") {
          var cursorItem = selectedCursorItem()
          if (!cursorItem || CursorService.applying) return
          CursorService.applyItem(cursorItem)
          finishApplyAction()
          return
        }

        var item = selectedItem()
        if (!item || WallpaperService.applying) return
        WallpaperService.applyItem(item)
        finishApplyAction()
      }

      function finishApplyAction() {
        clearTransientSearch()
        if (WallpaperService.closeOnSelection) {
          Popups.wallpaperOpen = false
        } else {
          keyScope.forceActiveFocus()
        }
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

      function syncFontSelection() {
        if (activeMode !== "font") return
        var idx = fontSelectedIndex()
        if (idx < 0) return
        selectFontItem(fontItemAt(idx), idx)
      }

      function syncCursorSelection() {
        if (activeMode !== "cursor") return
        var idx = cursorSelectedIndex()
        if (idx < 0) return
        selectCursorItem(cursorItemAt(idx), idx)
      }

      function statusText() {
        if (activeMode === "theme") {
          if (ThemeService.loading) return "Loading"
          if (ThemeService.applying) return "Applying"
          return ThemeService.statusText
        }

        if (activeMode === "font") {
          if (FontService.loading) return "Loading"
          if (FontService.applying) return "Applying"
          return FontService.statusText
        }

        if (activeMode === "cursor") {
          if (CursorService.loading) return "Loading"
          if (CursorService.applying) return "Applying"
          return CursorService.statusText
        }

        if (WallpaperService.cacheLoading) return "Loading"
        if (WallpaperService.wallhavenLoading) return "Searching"
        return WallpaperService.statusText
      }

      function applying() {
        if (activeMode === "theme") return ThemeService.applying
        if (activeMode === "font") return FontService.applying
        if (activeMode === "cursor") return CursorService.applying
        return WallpaperService.applying
      }

      function applyLabel() {
        if (applying()) return "Applying"
        if (activeMode === "font") {
          var fontItem = selectedFontItem()
          return fontItem && !fontItem.installed ? "Install" : "Apply"
        }
        if (activeMode === "cursor") {
          var cursorItem = selectedCursorItem()
          return cursorItem && !cursorItem.installed ? "Install" : "Apply"
        }
        return "Apply"
      }

      function boostedScroll(list, event) {
        var delta = 0
        if (event.pixelDelta.x !== 0) {
          delta = event.pixelDelta.x
        } else if (event.pixelDelta.y !== 0) {
          delta = event.pixelDelta.y
        } else if (event.angleDelta.x !== 0) {
          delta = event.angleDelta.x / 3
        } else {
          delta = event.angleDelta.y / 3
        }

        if (delta === 0) return

        var maxX = Math.max(0, list.contentWidth - list.width)
        list.contentX = Math.max(0, Math.min(maxX, list.contentX - delta * 2.4))
        event.accepted = true
      }

      Column {
        id: modeRail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 12
        width: content.modeRailWidth
        spacing: 8

        Repeater {
          model: [
            { label: "Walls", mode: "wallpaper" },
            { label: "Themes", mode: "theme" },
            { label: "Fonts", mode: "font" },
            { label: "Cursors", mode: "cursor" }
          ]

          Rectangle {
            width: modeRail.width
            height: 42
            radius: 0
            color: "transparent"

            property bool hovered: false
            readonly property bool active: content.activeMode === modelData.mode

            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.active ? 3 : 1
              height: parent.active ? 26 : 14
              radius: 2
              color: parent.active
                ? Theme.active
                : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, parent.hovered ? 0.34 : 0.16)

              Behavior on height {
                NumberAnimation {
                  duration: Theme.animDuration
                  easing.type: Easing.OutCubic
                }
              }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.leftMargin: 14
              height: 1
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, parent.hovered ? 0.14 : 0.07)
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 16
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: parent.active ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, parent.hovered ? 0.76 : 0.52)
              font.pixelSize: 13
              font.weight: parent.active ? Font.DemiBold : Font.Normal
            }

            HoverHandler {
              cursorShape: Qt.PointingHandCursor
              onHoveredChanged: parent.hovered = hovered
            }

            TapHandler {
              onTapped: content.setMode(modelData.mode)
            }
          }
        }
      }

      WallpaperFilterBar {
        id: filterBar
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: parent.top
        activeMode: content.activeMode
        onModeRequested: function(mode) {
          content.setMode(mode)
        }
        onSettingsRequested: content.settingsOpen = !content.settingsOpen
        onTagCloudRequested: content.tagCloudOpen = !content.tagCloudOpen
        onWallhavenRequested: {
          content.wallhavenBrowserOpen = !content.wallhavenBrowserOpen
          content.steamWorkshopBrowserOpen = false
          content.monitorPickerOpen = false
          content.tagCloudOpen = false
          content.settingsOpen = false
        }
        onRebuildRequested: WallpaperService.rebuildCache()
        onSearchSubmitted: keyScope.forceActiveFocus()
      }

      WallpaperTagCloud {
        id: tagCloud
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: filterBar.bottom
        anchors.topMargin: open ? 10 : 0
        open: content.activeMode === "wallpaper" && content.tagCloudOpen
        service: WallpaperService
        onCloseRequested: content.tagCloudOpen = false
      }

      WallpaperWallhavenBrowser {
        id: wallhavenBrowser
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: filterBar.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        z: 20
        open: content.activeMode === "wallpaper" && content.wallhavenBrowserOpen
        service: WallpaperService
        onCloseRequested: {
          content.wallhavenBrowserOpen = false
          keyScope.forceActiveFocus()
        }
      }

      WallpaperSteamWorkshopBrowser {
        id: steamWorkshopBrowser
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: filterBar.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        z: 20
        open: content.activeMode === "wallpaper" && content.steamWorkshopBrowserOpen
        service: WallpaperService
        onCloseRequested: {
          content.steamWorkshopBrowserOpen = false
          keyScope.forceActiveFocus()
        }
      }

      WallpaperMonitorPicker {
        id: monitorPicker
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: filterBar.bottom
        anchors.topMargin: 12
        height: 154
        z: 21
        open: content.activeMode === "wallpaper" && content.monitorPickerOpen
        service: WallpaperService
        onCloseRequested: {
          content.monitorPickerOpen = false
          keyScope.forceActiveFocus()
        }
      }

      ListView {
        id: wallList
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: content.settingsOpen ? settingsPane.left : parent.right
        anchors.rightMargin: content.settingsOpen ? 18 : 0
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        orientation: ListView.Horizontal
        spacing: WallpaperService.sliceSpacing
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(width, 900)
        reuseItems: true
        preferredHighlightBegin: width / 2 - 172
        preferredHighlightEnd: width / 2 + 172
        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Theme.animDuration + 90
        highlightResizeDuration: Theme.animDuration + 90
        currentIndex: 0
        visible: content.activeMode === "wallpaper"
          && WallpaperService.displayMode === "slices"
          && !content.wallhavenBrowserOpen
          && !content.steamWorkshopBrowserOpen
          && !content.monitorPickerOpen
        model: WallpaperService.filteredModel
        onCountChanged: content.syncSelection()

        Behavior on contentX {
          NumberAnimation {
            duration: Theme.animDuration + 90
            easing.type: Easing.OutCubic
          }
        }

        add: Transition {
          NumberAnimation {
            properties: "opacity,scale"
            from: 0
            to: 1
            duration: Theme.animDuration + 80
            easing.type: Easing.OutCubic
          }
        }

        populate: Transition {
          NumberAnimation {
            properties: "opacity,scale"
            from: 0
            to: 1
            duration: Theme.animDuration + 120
            easing.type: Easing.OutCubic
          }
        }

        displaced: Transition {
          NumberAnimation {
            properties: "x,y"
            duration: Theme.animDuration + 80
            easing.type: Easing.OutCubic
          }
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            content.boostedScroll(wallList, event)
          }
        }

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
            height: Math.min(WallpaperService.sliceHeight, wallList.height)
            expandedWidth: Math.min(WallpaperService.expandedWidth, Math.max(300, wallList.width * 0.46))
            hoverWidth: WallpaperService.hoverWidth
            sliceWidth: WallpaperService.sliceWidth
            skewOffset: WallpaperService.skewOffset
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

      GridView {
        id: wallGrid
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: content.settingsOpen ? settingsPane.left : parent.right
        anchors.rightMargin: content.settingsOpen ? 18 : 0
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        cellWidth: WallpaperService.gridThumbWidth
        cellHeight: WallpaperService.gridThumbHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(height, 520)
        visible: content.activeMode === "wallpaper"
          && WallpaperService.displayMode === "wall"
          && !content.wallhavenBrowserOpen
          && !content.steamWorkshopBrowserOpen
          && !content.monitorPickerOpen
        model: WallpaperService.filteredModel

        delegate: WallpaperMosaicCard {
          required property int index
          required property string path
          required property string type
          required property string thumb
          required property string source
          required property string name

          itemData: ({
            path: path,
            type: type,
            thumb: thumb,
            source: source,
            name: name
          })
          cardWidth: wallGrid.cellWidth - 18
          cardHeight: wallGrid.cellHeight - 14
          selected: content.selectedPath === path
          onActivated: {
            if (content.selectedPath === path) {
              content.applySelected()
            } else {
              content.selectItem(itemData, index)
            }
          }
        }
      }

      GridView {
        id: hexGrid
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: content.settingsOpen ? settingsPane.left : parent.right
        anchors.rightMargin: content.settingsOpen ? 18 : 0
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        cellWidth: WallpaperService.hexThumbWidth
        cellHeight: WallpaperService.hexThumbHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(height, 520)
        visible: content.activeMode === "wallpaper"
          && WallpaperService.displayMode === "hex"
          && !content.wallhavenBrowserOpen
          && !content.steamWorkshopBrowserOpen
          && !content.monitorPickerOpen
        model: WallpaperService.filteredModel

        delegate: WallpaperHexCard {
          required property int index
          required property string path
          required property string type
          required property string thumb
          required property string source
          required property string name

          itemData: ({
            path: path,
            type: type,
            thumb: thumb,
            source: source,
            name: name
          })
          selected: content.selectedPath === path
          onActivated: {
            if (content.selectedPath === path) {
              content.applySelected()
            } else {
              content.selectItem(itemData, index)
            }
          }
        }
      }

      GridView {
        id: mosaicGrid
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: content.settingsOpen ? settingsPane.left : parent.right
        anchors.rightMargin: content.settingsOpen ? 18 : 0
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        cellWidth: WallpaperService.mosaicThumbWidth
        cellHeight: WallpaperService.mosaicThumbHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(height, 520)
        visible: content.activeMode === "wallpaper"
          && WallpaperService.displayMode === "mosaic"
          && !content.wallhavenBrowserOpen
          && !content.steamWorkshopBrowserOpen
          && !content.monitorPickerOpen
        model: WallpaperService.filteredModel

        delegate: WallpaperMosaicCard {
          required property int index
          required property string path
          required property string type
          required property string thumb
          required property string source
          required property string name

          itemData: ({
            path: path,
            type: type,
            thumb: thumb,
            source: source,
            name: name
          })
          cardWidth: mosaicGrid.cellWidth - 18
          cardHeight: mosaicGrid.cellHeight - 14
          selected: content.selectedPath === path
          onActivated: {
            if (content.selectedPath === path) {
              content.applySelected()
            } else {
              content.selectItem(itemData, index)
            }
          }
        }
      }

      ListView {
        id: themeList
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        preferredHighlightBegin: width / 2 - 160
        preferredHighlightEnd: width / 2 + 160
        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Theme.animDuration + 90
        highlightResizeDuration: Theme.animDuration + 90
        currentIndex: 0
        visible: content.activeMode === "theme"
        model: ThemeService.filteredModel
        onCountChanged: content.syncThemeSelection()

        Behavior on contentX {
          NumberAnimation {
            duration: Theme.animDuration + 90
            easing.type: Easing.OutCubic
          }
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            content.boostedScroll(themeList, event)
          }
        }

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
            height: Math.min(282, themeList.height)
            expandedWidth: Math.min(338, Math.max(292, themeList.width * 0.44))
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

      ListView {
        id: fontList
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        preferredHighlightBegin: width / 2 - 112
        preferredHighlightEnd: width / 2 + 112
        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Theme.animDuration + 90
        highlightResizeDuration: Theme.animDuration + 90
        currentIndex: 0
        visible: content.activeMode === "font"
        model: FontService.filteredModel
        onCountChanged: content.syncFontSelection()

        Behavior on contentX {
          NumberAnimation {
            duration: Theme.animDuration + 90
            easing.type: Easing.OutCubic
          }
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            content.boostedScroll(fontList, event)
          }
        }

        delegate: Item {
          id: fontDelegateRoot

          required property int index
          required property string fontId
          required property string display
          required property string family
          required property string packageName
          required property string source
          required property string preview
          required property bool installed
          required property bool active

          readonly property var item: ({
            fontId: fontId,
            display: display,
            family: family,
            packageName: packageName,
            source: source,
            preview: preview,
            installed: installed,
            active: active
          })

          width: card.width
          height: fontList.height

          AppearanceChoiceCard {
            id: card
            anchors.verticalCenter: parent.verticalCenter
            height: Math.min(262, fontList.height)
            itemData: fontDelegateRoot.item
            kind: "font"
            selected: content.selectedFontFamily === fontDelegateRoot.family
              || (content.selectedFontFamily === "" && fontDelegateRoot.active)
            onActivated: {
              if (content.selectedFontFamily === fontDelegateRoot.family) {
                content.applySelected()
              } else {
                content.selectFontItem(fontDelegateRoot.item, fontDelegateRoot.index)
              }
            }
          }
        }
      }

      ListView {
        id: cursorList
        anchors.left: modeRail.right
        anchors.leftMargin: content.modeGap
        anchors.right: parent.right
        anchors.top: tagCloud.bottom
        anchors.topMargin: 12
        anchors.bottom: applyBar.top
        anchors.bottomMargin: 14
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        preferredHighlightBegin: width / 2 - 112
        preferredHighlightEnd: width / 2 + 112
        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: Theme.animDuration + 90
        highlightResizeDuration: Theme.animDuration + 90
        currentIndex: 0
        visible: content.activeMode === "cursor"
        model: CursorService.filteredModel
        onCountChanged: content.syncCursorSelection()

        Behavior on contentX {
          NumberAnimation {
            duration: Theme.animDuration + 90
            easing.type: Easing.OutCubic
          }
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            content.boostedScroll(cursorList, event)
          }
        }

        delegate: Item {
          id: cursorDelegateRoot

          required property int index
          required property string name
          required property string display
          required property string packageName
          required property string source
          required property string preview
          required property bool installed
          required property bool active

          readonly property var item: ({
            name: name,
            display: display,
            packageName: packageName,
            source: source,
            preview: preview,
            installed: installed,
            active: active
          })

          width: card.width
          height: cursorList.height

          AppearanceChoiceCard {
            id: card
            anchors.verticalCenter: parent.verticalCenter
            height: Math.min(262, cursorList.height)
            itemData: cursorDelegateRoot.item
            kind: "cursor"
            selected: content.selectedCursorName === cursorDelegateRoot.name
              || (content.selectedCursorName === "" && cursorDelegateRoot.active)
            onActivated: {
              if (content.selectedCursorName === cursorDelegateRoot.name) {
                content.applySelected()
              } else {
                content.selectCursorItem(cursorDelegateRoot.item, cursorDelegateRoot.index)
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

      Text {
        anchors.centerIn: fontList
        visible: content.activeMode === "font" && !FontService.loading && fontList.count === 0
        text: FontService.statusText !== "" ? FontService.statusText : "No fonts found"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 13
      }

      Text {
        anchors.centerIn: cursorList
        visible: content.activeMode === "cursor" && !CursorService.loading && cursorList.count === 0
        text: CursorService.statusText !== "" ? CursorService.statusText : "No cursors found"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 13
      }

      WallpaperSettingsPane {
        id: settingsPane
        anchors.top: filterBar.bottom
        anchors.topMargin: 14
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        open: content.activeMode === "wallpaper" && content.settingsOpen
        onCloseRequested: content.settingsOpen = false
        onSteamWorkshopRequested: {
          content.steamWorkshopBrowserOpen = true
          content.wallhavenBrowserOpen = false
          content.monitorPickerOpen = false
          content.tagCloudOpen = false
          content.settingsOpen = false
        }
        onMonitorPickerRequested: {
          content.monitorPickerOpen = true
          content.wallhavenBrowserOpen = false
          content.steamWorkshopBrowserOpen = false
          content.tagCloudOpen = false
          content.settingsOpen = false
        }
      }

      Row {
        id: applyBar
        x: modeRail.width + content.modeGap + ((parent.width - modeRail.width - content.modeGap) - width) / 2
        anchors.bottom: parent.bottom
        spacing: 8

        SkwdButton {
          label: content.statusText()
          height: 30
          interactive: false
          visible: content.statusText() !== ""
        }

        SkwdButton {
          id: applyButton
          width: 104
          height: 30
          label: content.applyLabel()
          active: true
          interactive: !content.applying()
          onClicked: content.applySelected()
        }
      }
    }
  }
}
