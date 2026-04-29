import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../services/"
import "../shapes"

// Dedicated Super+Space app launcher. It reuses Brain Shell's
// AppLauncher content but gives Ryoku a launcher-only popup instead of
// restoring the old multi-page dashboard.

PanelWindow {
  id: root

  Binding { target: Popups; property: "launcherVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property real launcherWidth: Math.min(420, Theme.dashboardWidth)
  readonly property real launcherHeight: Math.min(320, Theme.dashboardHeight)
  readonly property real fullCardWidth: root.launcherWidth + 2 * root.fw
  readonly property real fullCardHeight: Theme.notchHeight + root.launcherHeight
  readonly property real initialCardWidth: ShellState.topBarCWidth + 2 * root.fw
  readonly property real initialCardHeight: Theme.notchHeight

  property bool windowVisible: false
  property real openProgress: Popups.launcherOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.launcherOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.15
    }
  }

  color: "transparent"
  visible: root.windowVisible
  implicitHeight: root.fullCardHeight + 8
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Connections {
    target: Popups
    function onLauncherOpenChanged() {
      if (Popups.launcherOpen) {
        closeTimer.stop()
        root.windowVisible = true
      } else {
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: Theme.motionExpandDuration + 50
    onTriggered: root.windowVisible = false
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.windowVisible
    onClicked: Popups.closeAll()
  }

  Item {
    id: card

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top

    width: root.initialCardWidth
           + (root.fullCardWidth - root.initialCardWidth) * root.openProgress
    height: root.initialCardHeight
            + (root.fullCardHeight - root.initialCardHeight) * root.openProgress
    visible: root.openProgress > 0
    clip: true

    PopupShape {
      anchors.fill: parent
      attachedEdge: "top"
      color: Theme.background
      radius: Theme.cornerRadius
      flareWidth: root.fw
      flareHeight: root.fh
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Item {
      anchors {
        fill: parent
        topMargin: Theme.notchHeight + 8
        leftMargin: root.fw + 8
        rightMargin: root.fw + 8
        bottomMargin: 8
      }

      opacity: Math.min(1, root.openProgress * 1.25)

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      AppLauncher {
        anchors.fill: parent
        active: Popups.launcherOpen
        visible: card.visible
      }
    }
  }
}
