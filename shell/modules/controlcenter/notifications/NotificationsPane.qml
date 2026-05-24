pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
  id: root

  required property Session session

  property bool notificationsExpire: GlobalConfig.notifs.expire ?? true
  property string notificationsFullscreen: GlobalConfig.notifs.fullscreen ?? "on"
  property bool notificationsOpenExpanded: Config.notifs.openExpanded ?? false
  property int notificationsDefaultExpireTimeout: GlobalConfig.notifs.defaultExpireTimeout ?? 5000
  property int notificationsGroupPreviewNum: Config.notifs.groupPreviewNum ?? 3

  property int maxToasts: Config.utilities.maxToasts ?? 4
  property string toastsFullscreen: Config.utilities.toasts.fullscreen ?? "off"
  property bool chargingChanged: GlobalConfig.utilities.toasts.chargingChanged ?? true
  property bool gameModeChanged: GlobalConfig.utilities.toasts.gameModeChanged ?? true
  property bool dndChanged: GlobalConfig.utilities.toasts.dndChanged ?? true
  property bool audioOutputChanged: GlobalConfig.utilities.toasts.audioOutputChanged ?? true
  property bool audioInputChanged: GlobalConfig.utilities.toasts.audioInputChanged ?? true
  property bool capsLockChanged: GlobalConfig.utilities.toasts.capsLockChanged ?? true
  property bool numLockChanged: GlobalConfig.utilities.toasts.numLockChanged ?? true
  property bool kbLayoutChanged: GlobalConfig.utilities.toasts.kbLayoutChanged ?? true
  property bool vpnChanged: GlobalConfig.utilities.toasts.vpnChanged ?? true
  property bool nowPlaying: GlobalConfig.utilities.toasts.nowPlaying ?? false

  function saveConfig(): void {
    GlobalConfig.notifs.expire = root.notificationsExpire;
    GlobalConfig.notifs.fullscreen = root.notificationsFullscreen;
    GlobalConfig.notifs.openExpanded = root.notificationsOpenExpanded;
    GlobalConfig.notifs.defaultExpireTimeout = root.notificationsDefaultExpireTimeout;
    GlobalConfig.notifs.groupPreviewNum = root.notificationsGroupPreviewNum;

    GlobalConfig.utilities.maxToasts = root.maxToasts;
    GlobalConfig.utilities.toasts.fullscreen = root.toastsFullscreen;
    GlobalConfig.utilities.toasts.chargingChanged = root.chargingChanged;
    GlobalConfig.utilities.toasts.gameModeChanged = root.gameModeChanged;
    GlobalConfig.utilities.toasts.dndChanged = root.dndChanged;
    GlobalConfig.utilities.toasts.audioOutputChanged = root.audioOutputChanged;
    GlobalConfig.utilities.toasts.audioInputChanged = root.audioInputChanged;
    GlobalConfig.utilities.toasts.capsLockChanged = root.capsLockChanged;
    GlobalConfig.utilities.toasts.numLockChanged = root.numLockChanged;
    GlobalConfig.utilities.toasts.kbLayoutChanged = root.kbLayoutChanged;
    GlobalConfig.utilities.toasts.vpnChanged = root.vpnChanged;
    GlobalConfig.utilities.toasts.nowPlaying = root.nowPlaying;
  }

  function clamp(value, low, high) {
    return Math.max(low, Math.min(high, Math.round(value)));
  }

  function timeoutLabel(value) {
    return value >= 1000 ? (value / 1000).toFixed(value % 1000 === 0 ? 0 : 1) + "s" : value + "ms";
  }

  function setNotificationsFullscreen(mode) {
    root.notificationsFullscreen = mode;
    root.saveConfig();
  }

  function setToastsFullscreen(mode) {
    root.toastsFullscreen = mode;
    root.saveConfig();
  }

  function setNotificationTimeout(value) {
    root.notificationsDefaultExpireTimeout = root.clamp(value, 1000, 60000);
    root.saveConfig();
  }

  function setGroupPreviewCount(value) {
    root.notificationsGroupPreviewNum = root.clamp(value, 1, 10);
    root.saveConfig();
  }

  function setMaxToasts(value) {
    root.maxToasts = root.clamp(value, 1, 10);
    root.saveConfig();
  }

  anchors.fill: parent

  ClippingRectangle {
    id: notificationsClippingRect

    anchors.fill: parent
    anchors.margins: Tokens.padding.normal
    anchors.leftMargin: 0
    anchors.rightMargin: Tokens.padding.normal

    color: "transparent"
    radius: notificationsBorder.innerRadius

    Loader {
      id: notificationsLoader

      anchors.fill: parent
      anchors.margins: Tokens.padding.large + Tokens.padding.normal
      anchors.leftMargin: Tokens.padding.large
      anchors.rightMargin: Tokens.padding.large

      sourceComponent: notificationsContentComponent
    }
  }

  InnerBorder {
    id: notificationsBorder

    leftThickness: 0
    rightThickness: Tokens.padding.normal
  }

  Component {
    id: notificationsContentComponent

    StyledFlickable {
      id: flickable

      anchors.fill: parent
      clip: true
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: content.implicitHeight

      StyledScrollBar.vertical: StyledScrollBar {
        flickable: flickable
      }

      ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.normal

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.small

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Notifications")
            font.pointSize: Tokens.font.size.large
            font.weight: 700
            elide: Text.ElideRight
          }

          ModeBadge {
            icon: Notifs.dnd ? "do_not_disturb_on" : "notifications"
            title: Notifs.dnd ? qsTr("DND") : qsTr("Live")
            active: !Notifs.dnd
          }
        }

        NotificationConsole {
          Layout.fillWidth: true
        }

        GridLayout {
          Layout.fillWidth: true
          columns: root.width > 820 ? 2 : 1
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          ToastStackPreview {
            Layout.fillWidth: true
          }

          ConsolePanel {
            Layout.fillWidth: true
            title: qsTr("Toast signals")
            detail: qsTr("Event stream")

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              SignalChip {
                icon: "battery_charging_full"
                title: qsTr("Charging")
                checked: root.chargingChanged

                onToggled: checked => {
                  root.chargingChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "sports_esports"
                title: qsTr("Game mode")
                checked: root.gameModeChanged

                onToggled: checked => {
                  root.gameModeChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "do_not_disturb_on"
                title: qsTr("DND")
                checked: root.dndChanged

                onToggled: checked => {
                  root.dndChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "speaker"
                title: qsTr("Output")
                checked: root.audioOutputChanged

                onToggled: checked => {
                  root.audioOutputChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "mic"
                title: qsTr("Input")
                checked: root.audioInputChanged

                onToggled: checked => {
                  root.audioInputChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "keyboard_capslock"
                title: qsTr("Caps")
                checked: root.capsLockChanged

                onToggled: checked => {
                  root.capsLockChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "looks_one"
                title: qsTr("Num")
                checked: root.numLockChanged

                onToggled: checked => {
                  root.numLockChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "keyboard"
                title: qsTr("Layout")
                checked: root.kbLayoutChanged

                onToggled: checked => {
                  root.kbLayoutChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "vpn_lock"
                title: qsTr("VPN")
                checked: root.vpnChanged

                onToggled: checked => {
                  root.vpnChanged = checked;
                  root.saveConfig();
                }
              }

              SignalChip {
                icon: "music_note"
                title: qsTr("Playing")
                checked: root.nowPlaying

                onToggled: checked => {
                  root.nowPlaying = checked;
                  root.saveConfig();
                }
              }
            }
          }
        }
      }
    }
  }

  component NotificationConsole: StyledRect {
    id: notificationConsole

    implicitHeight: 224
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.fillWidth: false
        Layout.preferredWidth: Math.min(330, notificationConsole.width * 0.38)
        Layout.minimumWidth: 260
        Layout.fillHeight: true
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh
        clip: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Tokens.padding.normal
          spacing: Tokens.spacing.small

          RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
              Layout.alignment: Qt.AlignVCenter
              text: "notifications"
              color: Colours.palette.m3primary
              font.pointSize: Tokens.font.size.large
              fill: 1
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 0

              StyledText {
                Layout.fillWidth: true
                text: qsTr("Popup card")
                font.weight: 700
                elide: Text.ElideRight
              }

              StyledText {
                Layout.fillWidth: true
                text: root.timeoutLabel(root.notificationsDefaultExpireTimeout)
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
              }
            }

            ModeBadge {
              icon: root.notificationsExpire ? "timer" : "keep"
              title: root.notificationsExpire ? qsTr("Expires") : qsTr("Held")
              active: root.notificationsExpire
            }
          }

          StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHighest

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Tokens.padding.small
              spacing: Tokens.spacing.smaller

              StyledText {
                Layout.fillWidth: true
                text: qsTr("Ryoku Shell")
                font.weight: 700
                elide: Text.ElideRight
              }

              StyledText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.notificationsOpenExpanded ? qsTr("Expanded notification body") : qsTr("Compact notification body")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                wrapMode: Text.WordWrap
                maximumLineCount: root.notificationsOpenExpanded ? 3 : 2
                elide: Text.ElideRight
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.smaller

                Repeater {
                  model: Math.min(root.notificationsGroupPreviewNum, 6)

                  StyledRect {
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: index === 0 ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
                  }
                }
              }
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        ConsolePanel {
          Layout.fillWidth: true
          title: qsTr("Fullscreen")
          detail: root.notificationsFullscreen

          RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.smaller

            FullscreenOption {
              Layout.fillWidth: true
              icon: "notifications_off"
              title: qsTr("Off")
              active: root.notificationsFullscreen === "off"

              onSelected: root.setNotificationsFullscreen("off")
            }

            FullscreenOption {
              Layout.fillWidth: true
              icon: "notifications"
              title: qsTr("On")
              active: root.notificationsFullscreen === "on"

              onSelected: root.setNotificationsFullscreen("on")
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Tokens.spacing.small

          SignalChip {
            Layout.fillWidth: true
            icon: "timer"
            title: qsTr("Auto expire")
            checked: root.notificationsExpire

            onToggled: checked => {
              root.notificationsExpire = checked;
              root.saveConfig();
            }
          }

          SignalChip {
            Layout.fillWidth: true
            icon: "unfold_more"
            title: qsTr("Expanded")
            checked: root.notificationsOpenExpanded

            onToggled: checked => {
              root.notificationsOpenExpanded = checked;
              root.saveConfig();
            }
          }
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          StepperTile {
            Layout.fillWidth: true
            icon: "pace"
            title: qsTr("Timeout")
            value: root.notificationsDefaultExpireTimeout
            from: 1000
            to: 60000
            step: 500
            valueText: root.timeoutLabel(root.notificationsDefaultExpireTimeout)

            onValueModified: value => root.setNotificationTimeout(value)
          }

          StepperTile {
            Layout.fillWidth: true
            icon: "view_carousel"
            title: qsTr("Preview")
            value: root.notificationsGroupPreviewNum
            from: 1
            to: 10
            step: 1
            valueText: root.notificationsGroupPreviewNum.toString()

            onValueModified: value => root.setGroupPreviewCount(value)
          }
        }
      }
    }
  }

  component ToastStackPreview: StyledRect {
    id: preview

    Layout.alignment: Qt.AlignTop

    implicitHeight: 262
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
          Layout.fillWidth: true
          text: qsTr("Toast stack")
          font.weight: 700
          elide: Text.ElideRight
        }

        ModeBadge {
          icon: "layers"
          title: root.maxToasts.toString()
          active: true
        }
      }

      StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh
        clip: true

        Repeater {
          model: Math.min(root.maxToasts, 4)

          StyledRect {
            required property int index

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Tokens.padding.normal + index * 10
            anchors.rightMargin: Tokens.padding.normal + (3 - index) * 10
            anchors.topMargin: Tokens.padding.normal + index * 28
            implicitHeight: 54
            height: implicitHeight
            radius: Tokens.rounding.small
            color: index === 0 ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHighest
            opacity: 1 - index * 0.14

            RowLayout {
              anchors.fill: parent
              anchors.margins: Tokens.padding.small
              spacing: Tokens.spacing.small

              MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: index === 0 ? "bolt" : "notifications"
                color: index === 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.normal
                fill: index === 0 ? 1 : 0
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                  Layout.fillWidth: true
                  text: index === 0 ? qsTr("Event toast") : qsTr("Queued toast")
                  font.weight: 700
                  font.pointSize: Tokens.font.size.small
                  elide: Text.ElideRight
                }

                StyledText {
                  Layout.fillWidth: true
                  text: root.toastsFullscreen === "all" ? qsTr("Fullscreen enabled") : root.toastsFullscreen === "important" ? qsTr("Important only") : qsTr("Fullscreen off")
                  color: Colours.palette.m3onSurfaceVariant
                  font.pointSize: Tokens.font.size.smaller
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }

      ConsolePanel {
        Layout.fillWidth: true
        title: qsTr("Fullscreen")
        detail: root.toastsFullscreen

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.smaller

          FullscreenOption {
            Layout.fillWidth: true
            icon: "notifications_off"
            title: qsTr("Off")
            active: root.toastsFullscreen === "off"

            onSelected: root.setToastsFullscreen("off")
          }

          FullscreenOption {
            Layout.fillWidth: true
            icon: "priority_high"
            title: qsTr("Important")
            active: root.toastsFullscreen === "important"

            onSelected: root.setToastsFullscreen("important")
          }

          FullscreenOption {
            Layout.fillWidth: true
            icon: "notifications"
            title: qsTr("All")
            active: root.toastsFullscreen === "all"

            onSelected: root.setToastsFullscreen("all")
          }
        }
      }

      StepperTile {
        Layout.fillWidth: true
        icon: "filter_4"
        title: qsTr("Visible toasts")
        value: root.maxToasts
        from: 1
        to: 10
        step: 1
        valueText: root.maxToasts.toString()

        onValueModified: value => root.setMaxToasts(value)
      }
    }
  }

  component ConsolePanel: StyledRect {
    id: panel

    property string title: ""
    property string detail: ""
    default property alias content: body.data

    Layout.alignment: Qt.AlignTop

    implicitHeight: panelLayout.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      id: panelLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        StyledText {
          Layout.fillWidth: true
          text: panel.title
          font.pointSize: Tokens.font.size.small
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.alignment: Qt.AlignVCenter
          text: panel.detail
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.smaller
          elide: Text.ElideRight
        }
      }

      ColumnLayout {
        id: body

        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller
      }
    }
  }

  component FullscreenOption: StyledRect {
    id: option

    property string icon: ""
    property string title: ""
    property bool active: false

    signal selected

    implicitHeight: 34
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
    clip: true

    StateLayer {
      onClicked: option.selected()

      color: option.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: option.icon
        color: option.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: option.active ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: option.title
        color: option.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideRight
      }
    }
  }

  component SignalChip: StyledRect {
    id: chip

    property string icon: ""
    property string title: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(106, label.implicitWidth + 44)
    implicitHeight: 36
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest
    clip: true

    StateLayer {
      onClicked: chip.toggled(!chip.checked)

      color: chip.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: chip.icon
        color: chip.checked ? Colours.palette.m3secondary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: chip.checked ? 1 : 0
      }

      StyledText {
        id: label

        Layout.alignment: Qt.AlignVCenter
        text: chip.title
        color: chip.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideRight
      }
    }
  }

  component StepperTile: StyledRect {
    id: stepper

    property string icon: ""
    property string title: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    property string valueText: value.toString()

    signal valueModified(int value)

    implicitHeight: 78
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: stepper.icon
          color: Colours.palette.m3primary
          font.pointSize: Tokens.font.size.small
          fill: 1
        }

        StyledText {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: stepper.title
          font.pointSize: Tokens.font.size.small
          font.weight: 700
          elide: Text.ElideRight
        }

        StepButton {
          icon: "remove"
          enabled: stepper.value > stepper.from

          onClicked: stepper.valueModified(stepper.value - stepper.step)
        }

        StyledRect {
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: Math.max(44, stepperValue.implicitWidth + Tokens.padding.small * 2)
          implicitHeight: 24
          radius: Tokens.rounding.small
          color: Colours.palette.m3surfaceContainerHighest

          StyledText {
            id: stepperValue

            anchors.centerIn: parent
            text: stepper.valueText
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            font.weight: 700
          }
        }

        StepButton {
          icon: "add"
          enabled: stepper.value < stepper.to

          onClicked: stepper.valueModified(stepper.value + stepper.step)
        }
      }

      StyledSlider {
        id: slider

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.normal * 2
        from: stepper.from
        to: stepper.to
        stepSize: stepper.step

        onMoved: stepper.valueModified(Math.round(value))

        Binding {
          target: slider
          property: "value"
          value: stepper.value
          when: !slider.pressed
        }
      }
    }
  }

  component StepButton: StyledRect {
    id: button

    property string icon: ""
    signal clicked

    implicitWidth: 24
    implicitHeight: 24
    radius: Tokens.rounding.small
    color: enabled ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainer
    opacity: enabled ? 1 : 0.42

    StateLayer {
      enabled: button.enabled

      onClicked: button.clicked()

      color: Colours.palette.m3onSurface
      radius: parent.radius
    }

    MaterialIcon {
      anchors.centerIn: parent
      text: button.icon
      color: Colours.palette.m3onSurfaceVariant
      font.pointSize: Tokens.font.size.small
    }
  }

  component ModeBadge: StyledRect {
    id: badge

    property string icon: ""
    property string title: ""
    property bool active: false

    implicitWidth: Math.max(82, label.implicitWidth + 44)
    implicitHeight: 32
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainer

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: badge.icon
        color: badge.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: badge.active ? 1 : 0
      }

      StyledText {
        id: label

        Layout.alignment: Qt.AlignVCenter
        text: badge.title
        color: badge.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        font.weight: 700
      }
    }
  }
}
