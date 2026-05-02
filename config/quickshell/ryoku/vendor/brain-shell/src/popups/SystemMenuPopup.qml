import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../shapes"

PanelWindow {
  id: root

  Binding { target: Popups; property: "systemMenuVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property int menuWidth: 440
  readonly property int shortcutsHeight: 52
  readonly property int systemLabelHeight: 22
  readonly property int noctaliaMarginS: 6
  readonly property int noctaliaMarginL: 13
  readonly property int noctaliaRadiusM: 16
  readonly property int noctaliaInteractiveRadiusL: 20
  readonly property int noctaliaBorderS: 1
  readonly property int noctaliaBaseWidgetSize: 33
  readonly property int menuHeight: root.noctaliaMarginS + root.shortcutsHeight + root.noctaliaMarginS + root.systemLabelHeight + root.noctaliaMarginS
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: root.menuHeight
  readonly property int closeAnimationDuration: 140
  readonly property color noctaliaSurfaceVariant: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
  readonly property color noctaliaOutline: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.070)
  readonly property color noctaliaHover: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
  readonly property color noctaliaDangerHover: Qt.rgba(0.93, 0.47, 0.55, 0.20)
  readonly property color noctaliaPrimary: Theme.active
  readonly property color noctaliaDanger: "#ed8796"
  readonly property color noctaliaOnHover: Theme.text
  readonly property color noctaliaOnPrimary: Theme.background
  readonly property string noctaliaIconFont: noctaliaTablerIcons.name !== "" ? noctaliaTablerIcons.name : "sans-serif"

  property bool windowVisible: false
  property real openProgress: Popups.systemMenuOpen ? 1 : 0
  property string hoveredSystemAction: ""
  property string focusedSystemAction: ""
  property string lastSystemAction: ""

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Popups.systemMenuOpen ? Theme.motionExpandDuration : root.closeAnimationDuration
      easing.type: Popups.systemMenuOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.06
    }
  }

  color: "transparent"
  visible: root.windowVisible
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: Popups.systemMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  FontLoader {
    id: noctaliaTablerIcons
    source: "../assets/fonts/noctalia-tabler-icons.ttf"
  }

  ListModel {
    id: systemActions

    ListElement { label: "Screensaver"; hint: "Start now"; icon: "moon-stars"; action: "screensaver"; danger: false }
    ListElement { label: "Update";      hint: "System";    icon: "refresh"; action: "update";      danger: false }
    ListElement { label: "Snapshot";    hint: "Create";    icon: "camera"; action: "snapshot";    danger: false }
    ListElement { label: "Lock";        hint: "Secure";    icon: "lock"; action: "lock";        danger: false }
    ListElement { label: "Suspend";     hint: "Sleep";     icon: "moon"; action: "suspend";     danger: false }
    ListElement { label: "Hibernate";   hint: "Disk";      icon: "zzz"; action: "hibernate";   danger: false }
    ListElement { label: "Log Out";     hint: "Session";   icon: "logout"; action: "logout";      danger: true }
    ListElement { label: "Restart";     hint: "Reboot";    icon: "rotate-clockwise"; action: "reboot";      danger: true }
    ListElement { label: "Shutdown";    hint: "Power off"; icon: "power"; action: "shutdown";    danger: true }
  }

  Connections {
    target: Popups

    function onSystemMenuOpenChanged() {
      if (Popups.systemMenuOpen) {
        closeTimer.stop()
        root.windowVisible = true
      } else {
        root.hoveredSystemAction = ""
        root.focusedSystemAction = ""
        root.lastSystemAction = ""
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: root.closeAnimationDuration + 40
    onTriggered: root.windowVisible = false
  }

  Process {
    id: actionRunner
    command: []
    running: false
    onRunningChanged: if (!running) command = []
  }

  function systemIconGlyph(icon) {
    switch (icon) {
    case "moon-stars": return "\u{ece7}"
    case "refresh": return "\u{eb13}"
    case "camera": return "\u{ea54}"
    case "lock": return "\u{eae2}"
    case "moon": return "\u{eaf8}"
    case "zzz": return "\u{f228}"
    case "logout": return "\u{eba8}"
    case "rotate-clockwise": return "\u{eb15}"
    case "power": return "\u{eb0d}"
    default: return "\u{eb20}"
    }
  }

  function selectedSystemAction() {
    if (root.hoveredSystemAction !== "") return root.hoveredSystemAction
    if (root.focusedSystemAction !== "") return root.focusedSystemAction
    if (root.lastSystemAction !== "") return root.lastSystemAction
    return ""
  }

  function systemActionName(action) {
    if (action === "") return "System"
    for (var i = 0; i < systemActions.count; i++) {
      var item = systemActions.get(i)
      if (item.action === action) {
        return item.label
      }
    }
    return "System"
  }

  function runAction(action) {
    root.lastSystemAction = action

    switch (action) {
    case "screensaver":
      actionRunner.command = ["ryoku-launch-screensaver", "force"]
      break
    case "update":
      actionRunner.command = ["ryoku-launch-floating-terminal-with-presentation", "ryoku-update"]
      break
    case "snapshot":
      actionRunner.command = ["ryoku-launch-floating-terminal-with-presentation", "ryoku-snapshot", "create"]
      break
    case "lock":
      actionRunner.command = ["ryoku-lock-screen"]
      break
    case "suspend":
      actionRunner.command = ["systemctl", "suspend"]
      break
    case "hibernate":
      actionRunner.command = ["systemctl", "hibernate"]
      break
    case "logout":
      Popups.closeAll()
      Popups.showConfirm(
        "Log Out?",
        "You will be logged out of your session. Save your work before continuing.",
        "Log Out",
        "logout"
      )
      return
    case "reboot":
      Popups.closeAll()
      Popups.showConfirm(
        "Restart?",
        "Your computer will restart. Save your work before continuing.",
        "Restart",
        "reboot"
      )
      return
    case "shutdown":
      Popups.closeAll()
      Popups.showConfirm(
        "Shut Down?",
        "Your computer will power off. Save your work before continuing.",
        "Shut Down",
        "shutdown"
      )
      return
    default:
      return
    }

    actionRunner.running = true
    Popups.closeAll()
  }

  component SystemIcon: Text {
    id: iconText

    required property string icon
    property real pointSize: 13

    visible: iconText.icon !== ""
    text: root.systemIconGlyph(iconText.icon)
    font.family: root.noctaliaIconFont
    font.pixelSize: Math.max(1, Math.round(iconText.pointSize))
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
  }

  component SystemIconButtonHot: Rectangle {
    id: button

    required property string buttonLabel
    required property string iconName
    required property string actionName
    property bool danger: false
    property bool hovering: false
    property bool pressed: false
    property real baseSize: root.noctaliaBaseWidgetSize

    signal activated(string action)
    signal hoverChanged(string action, bool hovered)
    signal quickFocusChanged(string action, bool focused)

    implicitWidth: Math.round(button.baseSize)
    implicitHeight: Math.round(button.baseSize)
    radius: Math.min(root.noctaliaInteractiveRadiusL, width / 2)
    activeFocusOnTab: true

    color: {
      if ((button.enabled && button.hovering) || button.pressed || button.activeFocus) {
        return button.danger ? root.noctaliaDangerHover : root.noctaliaHover
      }
      return root.noctaliaSurfaceVariant
    }
    border.width: root.noctaliaBorderS
    border.color: (button.hovering || button.activeFocus)
      ? Qt.rgba((button.danger ? root.noctaliaDanger : root.noctaliaPrimary).r, (button.danger ? root.noctaliaDanger : root.noctaliaPrimary).g, (button.danger ? root.noctaliaDanger : root.noctaliaPrimary).b, 0.30)
      : root.noctaliaOutline

    Behavior on color {
      enabled: !Theme.staticMode
      ColorAnimation {
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }

    Behavior on border.color {
      enabled: !Theme.staticMode
      ColorAnimation {
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }

    SystemIcon {
      icon: button.iconName
      pointSize: Math.max(1, Math.round(button.width * 0.48))
      color: button.danger ? root.noctaliaDanger : root.noctaliaPrimary
      x: (button.width - width) / 2
      y: (button.height - height) / 2 + (height - contentHeight) / 2
    }

    MouseArea {
      id: systemButtonMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true

      onEntered: {
        button.hovering = true
        button.hoverChanged(button.actionName, true)
      }

      onExited: {
        button.hovering = false
        button.hoverChanged(button.actionName, false)
      }

      onPressed: {
        button.pressed = true
        button.forceActiveFocus()
      }

      onReleased: button.pressed = false
      onCanceled: {
        button.hovering = false
        button.pressed = false
      }
      onClicked: button.activated(button.actionName)
    }

    onActiveFocusChanged: button.quickFocusChanged(button.actionName, activeFocus)
    Keys.onReturnPressed: button.activated(button.actionName)
    Keys.onEnterPressed: button.activated(button.actionName)
    Keys.onSpacePressed: button.activated(button.actionName)
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.windowVisible
    onClicked: Popups.closeAll()
  }

  Item {
    id: card

    anchors.left: parent.left
    anchors.top: parent.top

    width: root.fullCardWidth
    height: root.fullCardHeight
    visible: root.openProgress > 0
    opacity: root.openProgress
    transformOrigin: Item.TopLeft
    scale: 0.94 + 0.06 * root.openProgress
    clip: true

    PopupShape {
      anchors.fill: parent
      attachedEdge: "top"
      color: Theme.background
      strokeColor: Theme.background
      strokeWidth: 0
      radius: 8
      flareWidth: root.fw
      flareHeight: root.fh
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    ColumnLayout {
      anchors {
        fill: parent
        topMargin: root.noctaliaMarginS
        leftMargin: root.fw + root.noctaliaMarginL
        rightMargin: root.fw + root.noctaliaMarginL
        bottomMargin: root.noctaliaMarginS
      }
      spacing: root.noctaliaMarginS

      Rectangle {
        id: systemShortcutsCard

        Layout.fillWidth: true
        Layout.preferredHeight: root.shortcutsHeight
        radius: root.noctaliaRadiusM
        color: root.noctaliaSurfaceVariant
        border.color: root.noctaliaOutline
        border.width: root.noctaliaBorderS

        RowLayout {
          anchors.fill: parent
          spacing: root.noctaliaMarginS

          Item {
            Layout.fillWidth: true
          }

          Repeater {
            model: systemActions

            delegate: SystemIconButtonHot {
              required property int index
              required property string label
              required property string icon
              required property string action
              required property bool danger

              Layout.fillWidth: false
              Layout.alignment: Qt.AlignVCenter
              buttonLabel: label
              iconName: icon
              actionName: action
              danger: danger

              onActivated: function(action) {
                root.runAction(action)
              }
              onHoverChanged: function(action, hovered) {
                root.hoveredSystemAction = hovered ? action : (root.hoveredSystemAction === action ? "" : root.hoveredSystemAction)
              }
              onQuickFocusChanged: function(action, focused) {
                root.focusedSystemAction = focused ? action : (root.focusedSystemAction === action ? "" : root.focusedSystemAction)
              }
            }
          }

          Item {
            Layout.fillWidth: true
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.systemLabelHeight

        Text {
          anchors.centerIn: parent
          text: root.systemActionName(root.selectedSystemAction())
          color: root.selectedSystemAction() === "shutdown" || root.selectedSystemAction() === "reboot" || root.selectedSystemAction() === "logout"
            ? root.noctaliaDanger : Theme.text
          font.pixelSize: 11
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter

          Behavior on color {
            enabled: !Theme.staticMode
            ColorAnimation {
              duration: 120
              easing.type: Easing.InOutQuad
            }
          }
        }
      }
    }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: Popups.closeAll()
  }
}
