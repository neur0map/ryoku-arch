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
import qs.utils

Item {
  id: root

  required property Session session

  property bool activeWindowCompact: Config.bar.activeWindow.compact ?? false
  property bool activeWindowInverted: Config.bar.activeWindow.inverted ?? false
  property bool clockShowIcon: Config.bar.clock.showIcon ?? true
  property bool clockBackground: Config.bar.clock.background ?? false
  property bool clockShowDate: Config.bar.clock.showDate ?? false
  property bool persistent: Config.bar.persistent ?? true
  property bool showOnHover: Config.bar.showOnHover ?? true
  property int dragThreshold: Config.bar.dragThreshold ?? 20
  property bool showAudio: Config.bar.status.showAudio ?? true
  property bool showMicrophone: Config.bar.status.showMicrophone ?? true
  property bool showKbLayout: Config.bar.status.showKbLayout ?? false
  property bool showNetwork: Config.bar.status.showNetwork ?? true
  property bool showWifi: Config.bar.status.showWifi ?? true
  property bool showBluetooth: Config.bar.status.showBluetooth ?? true
  property bool showBattery: Config.bar.status.showBattery ?? true
  property bool showLockStatus: Config.bar.status.showLockStatus ?? true
  property bool trayBackground: Config.bar.tray.background ?? false
  property bool trayCompact: Config.bar.tray.compact ?? false
  property bool trayRecolour: Config.bar.tray.recolour ?? false
  property int workspacesShown: Config.bar.workspaces.shown ?? 5
  property bool workspacesActiveIndicator: Config.bar.workspaces.activeIndicator ?? true
  property bool workspacesOccupiedBg: Config.bar.workspaces.occupiedBg ?? false
  property bool workspacesShowWindows: Config.bar.workspaces.showWindows ?? false
  property int workspacesMaxWindowIcons: Config.bar.workspaces.maxWindowIcons ?? 0
  property bool workspacesPerMonitor: GlobalConfig.bar.workspaces.perMonitorWorkspaces ?? true
  property bool scrollWorkspaces: Config.bar.scrollActions.workspaces ?? true
  property bool scrollVolume: Config.bar.scrollActions.volume ?? true
  property bool scrollBrightness: Config.bar.scrollActions.brightness ?? true
  property bool popoutActiveWindow: Config.bar.popouts.activeWindow ?? true
  property bool popoutTray: Config.bar.popouts.tray ?? true
  property bool popoutStatusIcons: Config.bar.popouts.statusIcons ?? true
  property list<string> monitorNames: Hypr.monitorNames()
  property list<string> excludedScreens: Config.bar.excludedScreens ?? []

  function saveConfig(entryIndex, entryEnabled) {
    GlobalConfig.bar.activeWindow.compact = root.activeWindowCompact;
    GlobalConfig.bar.activeWindow.inverted = root.activeWindowInverted;
    GlobalConfig.bar.clock.background = root.clockBackground;
    GlobalConfig.bar.clock.showDate = root.clockShowDate;
    GlobalConfig.bar.clock.showIcon = root.clockShowIcon;
    GlobalConfig.bar.persistent = root.persistent;
    GlobalConfig.bar.showOnHover = root.showOnHover;
    GlobalConfig.bar.dragThreshold = root.dragThreshold;
    GlobalConfig.bar.status.showAudio = root.showAudio;
    GlobalConfig.bar.status.showMicrophone = root.showMicrophone;
    GlobalConfig.bar.status.showKbLayout = root.showKbLayout;
    GlobalConfig.bar.status.showNetwork = root.showNetwork;
    GlobalConfig.bar.status.showWifi = root.showWifi;
    GlobalConfig.bar.status.showBluetooth = root.showBluetooth;
    GlobalConfig.bar.status.showBattery = root.showBattery;
    GlobalConfig.bar.status.showLockStatus = root.showLockStatus;
    GlobalConfig.bar.tray.background = root.trayBackground;
    GlobalConfig.bar.tray.compact = root.trayCompact;
    GlobalConfig.bar.tray.recolour = root.trayRecolour;
    GlobalConfig.bar.workspaces.shown = root.workspacesShown;
    GlobalConfig.bar.workspaces.activeIndicator = root.workspacesActiveIndicator;
    GlobalConfig.bar.workspaces.occupiedBg = root.workspacesOccupiedBg;
    GlobalConfig.bar.workspaces.showWindows = root.workspacesShowWindows;
    GlobalConfig.bar.workspaces.maxWindowIcons = root.workspacesMaxWindowIcons;
    GlobalConfig.bar.workspaces.perMonitorWorkspaces = root.workspacesPerMonitor;
    GlobalConfig.bar.scrollActions.workspaces = root.scrollWorkspaces;
    GlobalConfig.bar.scrollActions.volume = root.scrollVolume;
    GlobalConfig.bar.scrollActions.brightness = root.scrollBrightness;
    GlobalConfig.bar.popouts.activeWindow = root.popoutActiveWindow;
    GlobalConfig.bar.popouts.tray = root.popoutTray;
    GlobalConfig.bar.popouts.statusIcons = root.popoutStatusIcons;
    GlobalConfig.bar.excludedScreens = root.excludedScreens;

    const entries = [];
    for (let i = 0; i < entriesModel.count; i++) {
      const entry = entriesModel.get(i);
      let enabled = entry.enabled;
      if (entryIndex !== undefined && i === entryIndex)
        enabled = entryEnabled;

      entries.push({
        id: entry.id,
        enabled: enabled
      });
    }
    GlobalConfig.bar.entries = entries;
  }

  function enabledCount(values: var): int {
    let total = 0;
    for (const value of values) {
      if (value)
        total++;
    }
    return total;
  }

  function statusIconCount(): int {
    return enabledCount([
      root.showAudio,
      root.showMicrophone,
      root.showKbLayout,
      root.showNetwork,
      root.showWifi,
      root.showBluetooth,
      root.showBattery,
      root.showLockStatus
    ]);
  }

  function monitorEnabled(name: string): bool {
    return !Strings.testRegexList(root.excludedScreens, name);
  }

  function setMonitorEnabled(name: string, enabled: bool): void {
    const index = root.excludedScreens.indexOf(name);
    if (enabled && index !== -1) {
      root.excludedScreens.splice(index, 1);
    } else if (!enabled && index === -1) {
      root.excludedScreens.push(name);
    }
    root.saveConfig();
  }

  anchors.fill: parent

  Component.onCompleted: {
    if (Config.bar.entries) {
      entriesModel.clear();
      for (let i = 0; i < Config.bar.entries.length; i++) {
        const entry = Config.bar.entries[i];
        entriesModel.append({
          id: entry.id,
          enabled: entry.enabled !== false
        });
      }
    }
  }

  ListModel {
    id: entriesModel
  }

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
        columns: width > 860 ? 2 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        BarPreview {
          Layout.fillWidth: true
          Layout.preferredHeight: 176
          persistent: root.persistent
          statusCount: root.statusIconCount()
          workspacesShown: root.workspacesShown
          clockDate: root.clockShowDate
          trayCompact: root.trayCompact
        }

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Bar Behavior")
          detail: root.persistent ? qsTr("Pinned by default") : qsTr("Can hide when idle")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleChip {
              Layout.fillWidth: true
              icon: "keep"
              title: qsTr("Persistent")
              detail: root.persistent ? qsTr("Always visible") : qsTr("Auto hide allowed")
              checked: root.persistent

              onToggled: checked => {
                root.persistent = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "ads_click"
              title: qsTr("Hover")
              detail: root.showOnHover ? qsTr("Reveal on hover") : qsTr("Manual reveal")
              checked: root.showOnHover

              onToggled: checked => {
                root.showOnHover = checked;
                root.saveConfig();
              }
            }
          }

          NumberStepper {
            Layout.fillWidth: true
            icon: "open_with"
            title: qsTr("Drag Threshold")
            valueText: qsTr("%1 px").arg(root.dragThreshold)
            value: root.dragThreshold
            min: 0
            max: 100
            step: 1

            onValueModified: value => {
              root.dragThreshold = Math.round(value);
              root.saveConfig();
            }
          }
        }
      }

      SettingsDeck {
        Layout.fillWidth: true
        title: qsTr("Status Icons")
        detail: qsTr("%1 enabled").arg(root.statusIconCount())

        GridLayout {
          Layout.fillWidth: true
          columns: width > 900 ? 4 : width > 520 ? 2 : 1
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          ToggleChip {
            Layout.fillWidth: true
            icon: "volume_up"
            title: qsTr("Speakers")
            detail: qsTr("Output")
            checked: root.showAudio

            onToggled: checked => {
              root.showAudio = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "mic"
            title: qsTr("Microphone")
            detail: qsTr("Input")
            checked: root.showMicrophone

            onToggled: checked => {
              root.showMicrophone = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "keyboard"
            title: qsTr("Keyboard")
            detail: qsTr("Layout")
            checked: root.showKbLayout

            onToggled: checked => {
              root.showKbLayout = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "settings_ethernet"
            title: qsTr("Network")
            detail: qsTr("Status")
            checked: root.showNetwork

            onToggled: checked => {
              root.showNetwork = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "wifi"
            title: qsTr("WiFi")
            detail: qsTr("Wireless")
            checked: root.showWifi

            onToggled: checked => {
              root.showWifi = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "bluetooth"
            title: qsTr("Bluetooth")
            detail: qsTr("Devices")
            checked: root.showBluetooth

            onToggled: checked => {
              root.showBluetooth = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "battery_full"
            title: qsTr("Battery")
            detail: qsTr("Power")
            checked: root.showBattery

            onToggled: checked => {
              root.showBattery = checked;
              root.saveConfig();
            }
          }

          ToggleChip {
            Layout.fillWidth: true
            icon: "keyboard_capslock"
            title: qsTr("Caps")
            detail: qsTr("Lock status")
            checked: root.showLockStatus

            onToggled: checked => {
              root.showLockStatus = checked;
              root.saveConfig();
            }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: width > 860 ? 2 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Workspaces")
          detail: qsTr("Count, indicators, and window marks")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            NumberStepper {
              Layout.fillWidth: true
              icon: "view_column"
              title: qsTr("Shown")
              valueText: root.workspacesShown.toString()
              value: root.workspacesShown
              min: 1
              max: 20
              step: 1

              onValueModified: value => {
                root.workspacesShown = Math.round(value);
                root.saveConfig();
              }
            }

            NumberStepper {
              Layout.fillWidth: true
              icon: "select_window"
              title: qsTr("Window Icons")
              valueText: root.workspacesMaxWindowIcons === 0 ? qsTr("Off") : root.workspacesMaxWindowIcons.toString()
              value: root.workspacesMaxWindowIcons
              min: 0
              max: 20
              step: 1

              onValueModified: value => {
                root.workspacesMaxWindowIcons = Math.round(value);
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "radio_button_checked"
              title: qsTr("Active")
              detail: qsTr("Indicator")
              checked: root.workspacesActiveIndicator

              onToggled: checked => {
                root.workspacesActiveIndicator = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "texture"
              title: qsTr("Occupied")
              detail: qsTr("Background")
              checked: root.workspacesOccupiedBg

              onToggled: checked => {
                root.workspacesOccupiedBg = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "window"
              title: qsTr("Windows")
              detail: qsTr("Show marks")
              checked: root.workspacesShowWindows

              onToggled: checked => {
                root.workspacesShowWindows = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "monitor"
              title: qsTr("Per Monitor")
              detail: qsTr("Separate sets")
              checked: root.workspacesPerMonitor

              onToggled: checked => {
                root.workspacesPerMonitor = checked;
                root.saveConfig();
              }
            }
          }
        }

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Clock and Window")
          detail: qsTr("Compact labels on the bar")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleChip {
              Layout.fillWidth: true
              icon: "wallpaper"
              title: qsTr("Clock Fill")
              detail: qsTr("Background")
              checked: root.clockBackground

              onToggled: checked => {
                root.clockBackground = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "today"
              title: qsTr("Date")
              detail: qsTr("Show date")
              checked: root.clockShowDate

              onToggled: checked => {
                root.clockShowDate = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "schedule"
              title: qsTr("Clock Icon")
              detail: qsTr("Prefix")
              checked: root.clockShowIcon

              onToggled: checked => {
                root.clockShowIcon = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "compress"
              title: qsTr("Compact")
              detail: qsTr("Active window")
              checked: root.activeWindowCompact

              onToggled: checked => {
                root.activeWindowCompact = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "invert_colors"
              title: qsTr("Inverted")
              detail: qsTr("Active window")
              checked: root.activeWindowInverted

              onToggled: checked => {
                root.activeWindowInverted = checked;
                root.saveConfig();
              }
            }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: width > 860 ? 2 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Tray and Popouts")
          detail: qsTr("Surface behavior for bar extras")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleChip {
              Layout.fillWidth: true
              icon: "featured_play_list"
              title: qsTr("Tray Fill")
              detail: qsTr("Background")
              checked: root.trayBackground

              onToggled: checked => {
                root.trayBackground = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "compress"
              title: qsTr("Tray Compact")
              detail: qsTr("Tighter icons")
              checked: root.trayCompact

              onToggled: checked => {
                root.trayCompact = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "palette"
              title: qsTr("Recolour")
              detail: qsTr("Tray icons")
              checked: root.trayRecolour

              onToggled: checked => {
                root.trayRecolour = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "select_window"
              title: qsTr("Window")
              detail: qsTr("Popout")
              checked: root.popoutActiveWindow

              onToggled: checked => {
                root.popoutActiveWindow = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "inventory_2"
              title: qsTr("Tray")
              detail: qsTr("Popout")
              checked: root.popoutTray

              onToggled: checked => {
                root.popoutTray = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "toggle_on"
              title: qsTr("Status")
              detail: qsTr("Popout")
              checked: root.popoutStatusIcons

              onToggled: checked => {
                root.popoutStatusIcons = checked;
                root.saveConfig();
              }
            }
          }
        }

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Scroll Actions")
          detail: qsTr("Wheel gestures on bar modules")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 3 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleChip {
              Layout.fillWidth: true
              icon: "view_carousel"
              title: qsTr("Spaces")
              detail: qsTr("Scroll")
              checked: root.scrollWorkspaces

              onToggled: checked => {
                root.scrollWorkspaces = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "volume_up"
              title: qsTr("Volume")
              detail: qsTr("Scroll")
              checked: root.scrollVolume

              onToggled: checked => {
                root.scrollVolume = checked;
                root.saveConfig();
              }
            }

            ToggleChip {
              Layout.fillWidth: true
              icon: "brightness_medium"
              title: qsTr("Brightness")
              detail: qsTr("Scroll")
              checked: root.scrollBrightness

              onToggled: checked => {
                root.scrollBrightness = checked;
                root.saveConfig();
              }
            }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: width > 860 ? 2 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Modules")
          detail: qsTr("Toggle bar entries without changing order")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
              model: entriesModel

              ModuleChip {
                required property int index
                required property string id
                required property bool enabled

                Layout.fillWidth: true
                title: id
                checked: enabled

                onToggled: checked => {
                  entriesModel.setProperty(index, "enabled", checked);
                  root.saveConfig(index, checked);
                }
              }
            }
          }
        }

        SettingsDeck {
          Layout.fillWidth: true
          title: qsTr("Monitors")
          detail: qsTr("Choose which screens show the bar")

          GridLayout {
            Layout.fillWidth: true
            columns: width > 520 ? 2 : 1
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
              model: root.monitorNames

              MonitorChip {
                required property string modelData

                Layout.fillWidth: true
                title: modelData
                checked: root.monitorEnabled(modelData)

                onToggled: checked => root.setMonitorEnabled(modelData, checked)
              }
            }
          }
        }
      }
    }
  }

  component BarPreview: StyledRect {
    id: preview

    property bool persistent: true
    property int statusCount: 0
    property int workspacesShown: 5
    property bool clockDate: false
    property bool trayCompact: false

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
            text: "dock_to_bottom"
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
            text: qsTr("Taskbar")
            font.pointSize: Tokens.font.size.large
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            text: preview.persistent ? qsTr("Pinned bar layout") : qsTr("Auto-hide bar layout")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        RowLayout {
          anchors.fill: parent
          anchors.margins: Tokens.padding.normal
          spacing: Tokens.spacing.small

          RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.smaller

            Repeater {
              model: Math.min(preview.workspacesShown, 6)

              StyledRect {
                required property int index

                implicitWidth: index === 0 ? 34 : 24
                implicitHeight: 24
                radius: Tokens.rounding.full
                color: index === 0 ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
              }
            }
          }

          StyledRect {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 30
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainer

            StyledText {
              anchors.centerIn: parent
              text: qsTr("Focused window")
              color: Colours.palette.m3onSurfaceVariant
              font.pointSize: Tokens.font.size.small
              elide: Text.ElideRight
            }
          }

          StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 76
            implicitHeight: 30
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHighest

            StyledText {
              anchors.centerIn: parent
              text: preview.clockDate ? qsTr("09:35 Sun") : qsTr("09:35")
              font.pointSize: Tokens.font.size.small
              font.weight: 650
            }
          }

          StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: preview.trayCompact ? 52 : 72
            implicitHeight: 30
            radius: Tokens.rounding.full
            color: Colours.palette.m3primaryContainer

            StyledText {
              anchors.centerIn: parent
              text: qsTr("%1 icons").arg(preview.statusCount)
              color: Colours.palette.m3onPrimaryContainer
              font.pointSize: Tokens.font.size.small
              font.weight: 650
            }
          }
        }
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

  component ModuleChip: ToggleChip {
    icon: "drag_indicator"
    detail: checked ? qsTr("Enabled") : qsTr("Hidden")
  }

  component MonitorChip: ToggleChip {
    icon: "desktop_windows"
    detail: checked ? qsTr("Showing bar") : qsTr("Excluded")
  }
}
