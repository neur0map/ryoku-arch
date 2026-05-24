pragma ComponentBehavior: Bound

import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
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

  function secondsLabel(value: int): string {
    return qsTr("%1s").arg((value / 1000).toFixed(value % 1000 === 0 ? 0 : 1));
  }

  anchors.fill: parent

  StyledFlickable {
    id: flickable

    anchors.fill: parent
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentHeight: content.implicitHeight + Tokens.padding.normal * 2

    StyledScrollBar.vertical: StyledScrollBar {
      flickable: flickable
    }

    ColumnLayout {
      id: content

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      GridLayout {
        Layout.fillWidth: true
        columns: width > 820 ? 2 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        HeroPreview {
          Layout.fillWidth: true
          Layout.preferredHeight: 178
          Layout.rowSpan: width > 820 ? 2 : 1
          notificationFullscreen: root.notificationsFullscreen
          toastFullscreen: root.toastsFullscreen
          maxToasts: root.maxToasts
          expires: root.notificationsExpire
        }

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Notification Center")
          detail: qsTr("Delivery, expansion, and grouping")

          RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ModePill {
              Layout.fillWidth: true
              icon: "notifications_off"
              title: qsTr("Hide")
              detail: qsTr("Fullscreen")
              active: root.notificationsFullscreen === "off"

              onClicked: {
                root.notificationsFullscreen = "off";
                root.saveConfig();
              }
            }

            ModePill {
              Layout.fillWidth: true
              icon: "notifications_active"
              title: qsTr("Show")
              detail: qsTr("Fullscreen")
              active: root.notificationsFullscreen === "on"

              onClicked: {
                root.notificationsFullscreen = "on";
                root.saveConfig();
              }
            }
          }

          GridLayout {
            Layout.fillWidth: true
            columns: width > 540 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleChip {
              Layout.fillWidth: true
              icon: "timer"
              title: qsTr("Expire")
              detail: root.notificationsExpire ? qsTr("Auto dismiss") : qsTr("Stay visible")
              checked: root.notificationsExpire

              onToggled: checked => {
                root.notificationsExpire = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "unfold_more"
              title: qsTr("Expanded")
              detail: root.notificationsOpenExpanded ? qsTr("Open expanded") : qsTr("Compact first")
              checked: root.notificationsOpenExpanded

              onToggled: checked => {
                root.notificationsOpenExpanded = checked;
                root.saveConfig();
              }
            }
          }

          GridLayout {
            Layout.fillWidth: true
            columns: width > 540 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            NumberStepper {
              Layout.fillWidth: true
              icon: "schedule"
              title: qsTr("Timeout")
              valueText: root.secondsLabel(root.notificationsDefaultExpireTimeout)
              value: root.notificationsDefaultExpireTimeout
              min: 1000
              max: 60000
              step: 500

              onValueModified: value => {
                root.notificationsDefaultExpireTimeout = Math.round(value);
                root.saveConfig();
              }
            }

            NumberStepper {
              Layout.fillWidth: true
              icon: "stacks"
              title: qsTr("Group Preview")
              valueText: root.notificationsGroupPreviewNum.toString()
              value: root.notificationsGroupPreviewNum
              min: 1
              max: 10
              step: 1

              onValueModified: value => {
                root.notificationsGroupPreviewNum = Math.round(value);
                root.saveConfig();
              }
            }
          }
        }

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Toast Rules")
          detail: qsTr("Small alerts and fullscreen priority")

          RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ModePill {
              Layout.fillWidth: true
              icon: "notifications_off"
              title: qsTr("Off")
              detail: qsTr("Fullscreen")
              active: root.toastsFullscreen === "off"

              onClicked: {
                root.toastsFullscreen = "off";
                root.saveConfig();
              }
            }

            ModePill {
              Layout.fillWidth: true
              icon: "priority_high"
              title: qsTr("Important")
              detail: qsTr("Fullscreen")
              active: root.toastsFullscreen === "important"

              onClicked: {
                root.toastsFullscreen = "important";
                root.saveConfig();
              }
            }

            ModePill {
              Layout.fillWidth: true
              icon: "notifications"
              title: qsTr("All")
              detail: qsTr("Fullscreen")
              active: root.toastsFullscreen === "all"

              onClicked: {
                root.toastsFullscreen = "all";
                root.saveConfig();
              }
            }
          }

          NumberStepper {
            Layout.fillWidth: true
            icon: "filter_4"
            title: qsTr("Visible Toasts")
            valueText: root.maxToasts.toString()
            value: root.maxToasts
            min: 1
            max: 10
            step: 1

            onValueModified: value => {
              root.maxToasts = Math.round(value);
              root.saveConfig();
            }
          }
        }
      }

      SettingsDeck {
        Layout.fillWidth: true
        title: qsTr("Event Toasts")
        detail: qsTr("Choose which system changes appear as compact alerts")

        GridLayout {
          Layout.fillWidth: true
          columns: width > 900 ? 5 : width > 640 ? 4 : width > 420 ? 2 : 1
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          ToggleChip {
            Layout.fillWidth: true
            icon: "battery_charging_full"
            title: qsTr("Charging")
            detail: qsTr("Power state")
            checked: root.chargingChanged

            onToggled: checked => {
              root.chargingChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "stadia_controller"
            title: qsTr("Game Mode")
            detail: qsTr("Performance")
            checked: root.gameModeChanged

            onToggled: checked => {
              root.gameModeChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "do_not_disturb_on"
            title: qsTr("DND")
            detail: qsTr("Quiet mode")
            checked: root.dndChanged

            onToggled: checked => {
              root.dndChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "volume_up"
            title: qsTr("Output")
            detail: qsTr("Audio")
            checked: root.audioOutputChanged

            onToggled: checked => {
              root.audioOutputChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "mic"
            title: qsTr("Input")
            detail: qsTr("Audio")
            checked: root.audioInputChanged

            onToggled: checked => {
              root.audioInputChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "keyboard_capslock"
            title: qsTr("Caps")
            detail: qsTr("Lock key")
            checked: root.capsLockChanged

            onToggled: checked => {
              root.capsLockChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "looks_one"
            title: qsTr("Num")
            detail: qsTr("Lock key")
            checked: root.numLockChanged

            onToggled: checked => {
              root.numLockChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "keyboard"
            title: qsTr("Layout")
            detail: qsTr("Keyboard")
            checked: root.kbLayoutChanged

            onToggled: checked => {
              root.kbLayoutChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "vpn_key"
            title: qsTr("VPN")
            detail: qsTr("Tunnel")
            checked: root.vpnChanged

            onToggled: checked => {
              root.vpnChanged = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "music_note"
            title: qsTr("Playing")
            detail: qsTr("Media")
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

  component HeroPreview: StyledRect {
    id: preview

    property string notificationFullscreen: "on"
    property string toastFullscreen: "off"
    property int maxToasts: 4
    property bool expires: true

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

        StyledRect {
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: 34
          implicitHeight: 34
          radius: Tokens.rounding.full
          color: Colours.palette.m3primary

          MaterialIcon {
            anchors.centerIn: parent
            text: "notifications"
            color: Colours.palette.m3onPrimary
            font.pointSize: Tokens.font.size.normal
            fill: 1
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Notifications")
            font.pointSize: Tokens.font.size.large
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            text: preview.expires ? qsTr("Alerts expire automatically") : qsTr("Alerts stay until dismissed")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        ToastMock {
          Layout.fillWidth: true
          Layout.fillHeight: true
          icon: "chat"
          title: qsTr("Center")
          detail: preview.notificationFullscreen === "on" ? qsTr("Fullscreen on") : qsTr("Fullscreen off")
          active: preview.notificationFullscreen === "on"
        }

        ToastMock {
          Layout.fillWidth: true
          Layout.fillHeight: true
          icon: "bolt"
          title: qsTr("Toasts")
          detail: qsTr("%1 visible").arg(preview.maxToasts)
          active: preview.toastFullscreen !== "off"
        }
      }
    }
  }

  component ToastMock: StyledRect {
    id: mock

    property string icon: "notifications"
    property string title: ""
    property string detail: ""
    property bool active: false

    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: mock.icon
        color: mock.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.extraLarge
        fill: mock.active ? 1 : 0
      }

      StyledText {
        Layout.fillWidth: true
        text: mock.title
        color: mock.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.weight: 700
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        text: mock.detail
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }

  component SettingsDeck: StyledRect {
    id: deck

    property string title: ""
    property string detail: ""
    default property alias content: deckContent.data

    implicitHeight: deckLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: deckLayout

      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: deck.title
          font.pointSize: Tokens.font.size.normal
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: deck.detail
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      ColumnLayout {
        id: deckContent

        Layout.fillWidth: true
        spacing: Tokens.spacing.small
      }
    }
  }

  component ModePill: StyledRect {
    id: pill

    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool active: false

    signal clicked

    implicitHeight: 50
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: pill.clicked()

      color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: pill.icon
        color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.normal
        fill: pill.active ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: pill.title
          color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: pill.detail
          color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }
    }
  }

  component ToggleChip: StyledRect {
    id: chip

    property string icon: "toggle_on"
    property string title: ""
    property string detail: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitHeight: 50
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: chip.toggled(!chip.checked)

      color: chip.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: chip.icon
        color: chip.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.normal
        fill: chip.checked ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: chip.title
          color: chip.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: chip.detail
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      StyledSwitch {
        Layout.alignment: Qt.AlignVCenter
        checked: chip.checked

        onToggled: chip.toggled(checked)
      }
    }
  }

  component NumberStepper: StyledRect {
    id: stepper

    property string icon: "numbers"
    property string title: ""
    property string valueText: value.toString()
    property real value: 0
    property real min: 0
    property real max: 100
    property real step: 1

    signal valueModified(real value)

    implicitHeight: 62
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: stepper.icon
        color: Colours.palette.m3primary
        font.pointSize: Tokens.font.size.normal
        fill: 1
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: stepper.title
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: stepper.valueText
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      CustomSpinBox {
        Layout.alignment: Qt.AlignVCenter
        min: stepper.min
        max: stepper.max
        step: stepper.step
        value: stepper.value

        onValueModified: value => stepper.valueModified(value)
      }
    }
  }
}
