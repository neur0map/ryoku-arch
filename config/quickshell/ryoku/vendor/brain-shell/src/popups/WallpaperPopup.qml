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
    WallpaperService.refresh()
    WallpaperService.previewWall = ""
    content.selectedPath = WallpaperService.currentWall
    content.settingsOpen = false
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
      onClicked: mouse.accepted = true
    }

    Item {
      id: content
      anchors {
        fill: parent
        leftMargin: root.fw + 16
        rightMargin: root.fw + 16
        topMargin: 16
        bottomMargin: root.fh + 14
      }

      property string selectedPath: ""
      property bool settingsOpen: false

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

      function selectRelative(delta) {
        var count = WallpaperService.filteredModel.count
        if (count <= 0) return
        var idx = selectedIndex()
        idx = idx < 0 ? 0 : (idx + delta + count) % count
        selectItem(itemAt(idx), idx)
      }

      function applySelected() {
        var item = selectedItem()
        if (!item || WallpaperService.applying) return
        WallpaperService.applyItem(item)
        Popups.wallpaperOpen = false
      }

      function syncSelection() {
        var idx = selectedIndex()
        if (idx < 0) return
        selectItem(itemAt(idx), idx)
      }

      WallpaperFilterBar {
        id: filterBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.min(implicitWidth, parent.width)
        onSettingsRequested: content.settingsOpen = !content.settingsOpen
        onRebuildRequested: WallpaperService.rebuildCache()
        onSearchSubmitted: keyScope.forceActiveFocus()
      }

      ListView {
        id: wallList
        anchors.left: parent.left
        anchors.right: settingsPane.left
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

      Text {
        anchors.centerIn: wallList
        visible: !WallpaperService.cacheLoading && wallList.count === 0
        text: WallpaperService.statusText
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 13
      }

      WallpaperSettingsPane {
        id: settingsPane
        anchors.top: filterBar.bottom
        anchors.topMargin: 18
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        open: content.settingsOpen
        onCloseRequested: content.settingsOpen = false
      }

      Row {
        id: applyBar
        anchors.horizontalCenter: wallList.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 8

        Rectangle {
          width: statusLabel.implicitWidth + 24
          height: 30
          radius: 7
          color: Qt.rgba(1, 1, 1, 0.07)
          visible: WallpaperService.statusText !== "" || WallpaperService.cacheLoading || WallpaperService.wallhavenLoading

          Text {
            id: statusLabel
            anchors.centerIn: parent
            text: WallpaperService.cacheLoading
              ? "Loading"
              : WallpaperService.wallhavenLoading
                ? "Searching"
                : WallpaperService.statusText
            color: Theme.subtext
            font.pixelSize: 12
          }
        }

        Rectangle {
          width: 104
          height: 30
          radius: 7
          color: WallpaperService.applying
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
            : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
          border.width: 1
          border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.42)

          Text {
            anchors.centerIn: parent
            text: WallpaperService.applying ? "Applying" : "Apply"
            color: Theme.active
            font.pixelSize: 12
            font.weight: Font.Medium
          }

          HoverHandler {
            cursorShape: WallpaperService.applying ? Qt.ArrowCursor : Qt.PointingHandCursor
          }

          TapHandler {
            enabled: !WallpaperService.applying
            onTapped: content.applySelected()
          }
        }
      }
    }
  }
}
