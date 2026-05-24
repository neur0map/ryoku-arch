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

  function entryIcon(entryId) {
    switch (entryId) {
    case "logo":
      return "deployed_code";
    case "workspaces":
      return "grid_view";
    case "spacer":
      return "space_bar";
    case "activeWindow":
      return "title";
    case "tray":
      return "apps";
    case "clock":
      return "schedule";
    case "statusIcons":
      return "tune";
    case "power":
      return "power_settings_new";
    default:
      return "widgets";
    }
  }

  function entryLabel(entryId) {
    switch (entryId) {
    case "logo":
      return qsTr("Logo");
    case "workspaces":
      return qsTr("Workspaces");
    case "spacer":
      return qsTr("Spacer");
    case "activeWindow":
      return qsTr("Window");
    case "tray":
      return qsTr("Tray");
    case "clock":
      return qsTr("Clock");
    case "statusIcons":
      return qsTr("Status");
    case "power":
      return qsTr("Power");
    default:
      return entryId;
    }
  }

  function entryDetail(entryId) {
    switch (entryId) {
    case "spacer":
      return qsTr("flex");
    case "activeWindow":
      return root.activeWindowCompact ? qsTr("compact") : qsTr("wide");
    case "clock":
      return root.clockShowDate ? qsTr("date") : qsTr("time");
    case "statusIcons":
      return qsTr("cluster");
    case "workspaces":
      return root.workspacesShown.toString();
    default:
      return qsTr("module");
    }
  }

  function clamp(value, low, high) {
    return Math.max(low, Math.min(high, Math.round(value)));
  }

  function setEntryEnabled(index, checked) {
    if (index < 0 || index >= entriesModel.count)
      return;

    entriesModel.setProperty(index, "enabled", checked);
    root.saveConfig(index, checked);
  }

  function setWorkspacesShown(value) {
    root.workspacesShown = root.clamp(value, 1, 20);
    root.saveConfig();
  }

  function setWorkspacesMaxWindowIcons(value) {
    root.workspacesMaxWindowIcons = root.clamp(value, 0, 20);
    root.saveConfig();
  }

  function setDragThreshold(value) {
    root.dragThreshold = root.clamp(value, 0, 100);
    root.saveConfig();
  }

  function setMonitorIncluded(name, included) {
    const screens = root.excludedScreens.slice();
    const index = screens.indexOf(name);
    if (included && index !== -1)
      screens.splice(index, 1);
    if (!included && index === -1)
      screens.push(name);

    root.excludedScreens = screens;
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

  ClippingRectangle {
    id: taskbarClippingRect

    anchors.fill: parent
    anchors.margins: Tokens.padding.normal
    anchors.leftMargin: 0
    anchors.rightMargin: Tokens.padding.normal

    radius: taskbarBorder.innerRadius
    color: "transparent"

    Loader {
      id: taskbarLoader

      anchors.fill: parent
      anchors.margins: Tokens.padding.large + Tokens.padding.normal
      anchors.leftMargin: Tokens.padding.large
      anchors.rightMargin: Tokens.padding.large

      asynchronous: true
      sourceComponent: taskbarContentComponent
    }
  }

  InnerBorder {
    id: taskbarBorder

    leftThickness: 0
    rightThickness: Tokens.padding.normal
  }

  Component {
    id: taskbarContentComponent

    StyledFlickable {
      id: flickable

      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
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
            text: qsTr("Taskbar")
            font.pointSize: Tokens.font.size.large
            font.weight: 700
            elide: Text.ElideRight
          }

          ModeBadge {
            icon: root.persistent ? "keep" : "visibility_off"
            title: root.persistent ? qsTr("Pinned") : qsTr("Hover")
            active: root.persistent
          }
        }

        BarCanvas {
          Layout.fillWidth: true
        }

        GridLayout {
          Layout.fillWidth: true
          columns: root.width > 880 ? 3 : root.width > 560 ? 2 : 1
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          BarPanel {
            Layout.fillWidth: true
            title: qsTr("Modules")
            detail: qsTr("Saved order")

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              Repeater {
                model: entriesModel

                ModuleToken {
                  required property int index

                  moduleId: entriesModel.get(index).id
                  icon: root.entryIcon(moduleId)
                  title: root.entryLabel(moduleId)
                  detail: root.entryDetail(moduleId)
                  checked: entriesModel.get(index).enabled

                  onToggled: checked => root.setEntryEnabled(index, checked)
                }
              }
            }
          }

          BarPanel {
            Layout.fillWidth: true
            title: qsTr("Status")
            detail: qsTr("Cluster icons")

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              StatusToken {
                icon: "volume_up"
                title: qsTr("Audio")
                checked: root.showAudio

                onToggled: checked => {
                  root.showAudio = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "mic"
                title: qsTr("Mic")
                checked: root.showMicrophone

                onToggled: checked => {
                  root.showMicrophone = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "keyboard"
                title: qsTr("Keys")
                checked: root.showKbLayout

                onToggled: checked => {
                  root.showKbLayout = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "lan"
                title: qsTr("Network")
                checked: root.showNetwork

                onToggled: checked => {
                  root.showNetwork = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "wifi"
                title: qsTr("Wifi")
                checked: root.showWifi

                onToggled: checked => {
                  root.showWifi = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "bluetooth"
                title: qsTr("BT")
                checked: root.showBluetooth

                onToggled: checked => {
                  root.showBluetooth = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "battery_full"
                title: qsTr("Battery")
                checked: root.showBattery

                onToggled: checked => {
                  root.showBattery = checked;
                  root.saveConfig();
                }
              }

              StatusToken {
                icon: "lock"
                title: qsTr("Caps")
                checked: root.showLockStatus

                onToggled: checked => {
                  root.showLockStatus = checked;
                  root.saveConfig();
                }
              }
            }
          }

          BarPanel {
            Layout.fillWidth: true
            title: qsTr("Workspaces")
            detail: root.workspacesShown + qsTr(" visible")

            WorkspaceRail {
              Layout.fillWidth: true
            }

            DialControl {
              Layout.fillWidth: true
              icon: "pin"
              title: qsTr("Visible")
              value: root.workspacesShown
              from: 1
              to: 20
              valueText: root.workspacesShown.toString()

              onValueModified: value => root.setWorkspacesShown(value)
            }

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              FeatureChip {
                icon: "radio_button_checked"
                title: qsTr("Active")
                checked: root.workspacesActiveIndicator

                onToggled: checked => {
                  root.workspacesActiveIndicator = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "layers"
                title: qsTr("Occupied")
                checked: root.workspacesOccupiedBg

                onToggled: checked => {
                  root.workspacesOccupiedBg = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "tab_group"
                title: qsTr("Windows")
                checked: root.workspacesShowWindows

                onToggled: checked => {
                  root.workspacesShowWindows = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "desktop_windows"
                title: qsTr("Per screen")
                checked: root.workspacesPerMonitor

                onToggled: checked => {
                  root.workspacesPerMonitor = checked;
                  root.saveConfig();
                }
              }
            }

            DialControl {
              Layout.fillWidth: true
              icon: "select_window"
              title: qsTr("Window icons")
              value: root.workspacesMaxWindowIcons
              from: 0
              to: 20
              valueText: root.workspacesMaxWindowIcons.toString()

              onValueModified: value => root.setWorkspacesMaxWindowIcons(value)
            }
          }

          BarPanel {
            Layout.fillWidth: true
            title: qsTr("Window + clock")
            detail: qsTr("Center strip")

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              FeatureChip {
                icon: "crop_16_9"
                title: qsTr("Compact")
                checked: root.activeWindowCompact

                onToggled: checked => {
                  root.activeWindowCompact = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "rotate_left"
                title: qsTr("Inverted")
                checked: root.activeWindowInverted

                onToggled: checked => {
                  root.activeWindowInverted = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "calendar_month"
                title: qsTr("Date")
                checked: root.clockShowDate

                onToggled: checked => {
                  root.clockShowDate = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "schedule"
                title: qsTr("Clock icon")
                checked: root.clockShowIcon

                onToggled: checked => {
                  root.clockShowIcon = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "background_dot_large"
                title: qsTr("Clock plate")
                checked: root.clockBackground

                onToggled: checked => {
                  root.clockBackground = checked;
                  root.saveConfig();
                }
              }
            }
          }

          BarPanel {
            Layout.fillWidth: true
            title: qsTr("Tray + popouts")
            detail: qsTr("Right strip")

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              FeatureChip {
                icon: "background_dot_small"
                title: qsTr("Tray plate")
                checked: root.trayBackground

                onToggled: checked => {
                  root.trayBackground = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "compress"
                title: qsTr("Compact tray")
                checked: root.trayCompact

                onToggled: checked => {
                  root.trayCompact = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "palette"
                title: qsTr("Recolour")
                checked: root.trayRecolour

                onToggled: checked => {
                  root.trayRecolour = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "title"
                title: qsTr("Window popout")
                checked: root.popoutActiveWindow

                onToggled: checked => {
                  root.popoutActiveWindow = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "apps"
                title: qsTr("Tray popout")
                checked: root.popoutTray

                onToggled: checked => {
                  root.popoutTray = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "tune"
                title: qsTr("Status popout")
                checked: root.popoutStatusIcons

                onToggled: checked => {
                  root.popoutStatusIcons = checked;
                  root.saveConfig();
                }
              }
            }
          }

          BarPanel {
            Layout.fillWidth: true
            title: qsTr("Behavior")
            detail: qsTr("Reveal + scroll")

            Flow {
              Layout.fillWidth: true
              spacing: Tokens.spacing.smaller

              FeatureChip {
                icon: "keep"
                title: qsTr("Pinned")
                checked: root.persistent

                onToggled: checked => {
                  root.persistent = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "ads_click"
                title: qsTr("Hover reveal")
                checked: root.showOnHover

                onToggled: checked => {
                  root.showOnHover = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "swap_vert"
                title: qsTr("Workspace scroll")
                checked: root.scrollWorkspaces

                onToggled: checked => {
                  root.scrollWorkspaces = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "volume_up"
                title: qsTr("Volume scroll")
                checked: root.scrollVolume

                onToggled: checked => {
                  root.scrollVolume = checked;
                  root.saveConfig();
                }
              }

              FeatureChip {
                icon: "brightness_medium"
                title: qsTr("Brightness")
                checked: root.scrollBrightness

                onToggled: checked => {
                  root.scrollBrightness = checked;
                  root.saveConfig();
                }
              }
            }

            DialControl {
              Layout.fillWidth: true
              icon: "drag_pan"
              title: qsTr("Drag threshold")
              value: root.dragThreshold
              from: 0
              to: 100
              valueText: root.dragThreshold + "px"

              onValueModified: value => root.setDragThreshold(value)
            }
          }
        }

        BarPanel {
          Layout.fillWidth: true
          title: qsTr("Monitors")
          detail: root.monitorNames.length > 0 ? root.monitorNames.join(" / ") : qsTr("Current screen")

          Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.smaller

            Repeater {
              model: root.monitorNames

              MonitorPill {
                required property string modelData

                title: modelData
                checked: !Strings.testRegexList(root.excludedScreens, modelData)

                onToggled: checked => root.setMonitorIncluded(modelData, checked)
              }
            }
          }
        }
      }
    }
  }

  component BarCanvas: StyledRect {
    id: canvas

    implicitHeight: 176
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
          text: qsTr("Layout")
          font.pointSize: Tokens.font.size.normal
          font.weight: 700
          elide: Text.ElideRight
        }

        ModeBadge {
          icon: root.showOnHover ? "ads_click" : "visibility"
          title: root.showOnHover ? qsTr("Hover") : qsTr("Always")
          active: root.showOnHover
        }
      }

      StyledRect {
        Layout.fillWidth: true
        implicitHeight: 58
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh
        clip: true

        RowLayout {
          anchors.fill: parent
          anchors.margins: Tokens.padding.small
          spacing: Tokens.spacing.smaller

          Repeater {
            model: entriesModel

            PreviewModule {
              required property int index

              moduleId: entriesModel.get(index).id
              icon: root.entryIcon(moduleId)
              title: root.entryLabel(moduleId)
              enabled: entriesModel.get(index).enabled
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        WorkspaceRail {
          Layout.fillWidth: true
          Layout.fillHeight: true
          compact: true
        }

        StyledRect {
          Layout.fillWidth: false
          Layout.preferredWidth: 232
          Layout.fillHeight: true
          radius: Tokens.rounding.small
          color: Colours.palette.m3surfaceContainerHigh

          Flow {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.smaller

            StatusDot {
              icon: "volume_up"
              active: root.showAudio
            }

            StatusDot {
              icon: "mic"
              active: root.showMicrophone
            }

            StatusDot {
              icon: "lan"
              active: root.showNetwork
            }

            StatusDot {
              icon: "wifi"
              active: root.showWifi
            }

            StatusDot {
              icon: "bluetooth"
              active: root.showBluetooth
            }

            StatusDot {
              icon: "battery_full"
              active: root.showBattery
            }
          }
        }
      }
    }
  }

  component BarPanel: StyledRect {
    id: panel

    property string title: ""
    property string detail: ""
    default property alias content: body.data

    Layout.alignment: Qt.AlignTop

    implicitHeight: bodyLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: bodyLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
          Layout.fillWidth: true
          text: panel.title
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.alignment: Qt.AlignVCenter
          text: panel.detail
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      ColumnLayout {
        id: body

        Layout.fillWidth: true
        spacing: Tokens.spacing.small
      }
    }
  }

  component ModuleToken: StyledRect {
    id: token

    property string moduleId: ""
    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(108, tokenLabel.implicitWidth + tokenDetail.implicitWidth + 54)
    implicitHeight: 38
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true
    opacity: checked ? 1 : 0.62

    StateLayer {
      onClicked: token.toggled(!token.checked)

      color: token.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: token.icon
        color: token.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: token.checked ? 1 : 0
      }

      StyledText {
        id: tokenLabel

        Layout.alignment: Qt.AlignVCenter
        text: token.title
        color: token.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideRight
      }

      StyledText {
        id: tokenDetail

        Layout.alignment: Qt.AlignVCenter
        text: token.detail
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.smaller
        elide: Text.ElideRight
      }
    }
  }

  component PreviewModule: StyledRect {
    id: item

    property string moduleId: ""
    property string icon: ""
    property string title: ""
    property bool enabled: true

    Layout.fillWidth: moduleId === "spacer" && enabled
    Layout.preferredWidth: moduleId === "activeWindow" ? 132 : Math.max(34, previewLabel.implicitWidth + 34)
    Layout.fillHeight: true
    radius: Tokens.rounding.small
    color: enabled ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainer
    opacity: enabled ? 1 : 0.34

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: item.icon
        color: item.enabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: item.enabled ? 1 : 0
      }

      StyledText {
        id: previewLabel

        Layout.alignment: Qt.AlignVCenter
        visible: item.moduleId !== "spacer"
        text: item.title
        color: item.enabled ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.smaller
        font.weight: 650
        elide: Text.ElideRight
      }
    }
  }

  component WorkspaceRail: StyledRect {
    id: rail

    property bool compact: false

    implicitHeight: compact ? 62 : 82
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

        StyledText {
          Layout.fillWidth: true
          text: qsTr("Rail")
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          text: root.workspacesShown.toString()
          color: Colours.palette.m3primary
          font.pointSize: Tokens.font.size.small
          font.weight: 700
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.smaller

        Repeater {
          model: Math.min(root.workspacesShown, 12)

          StyledRect {
            id: workspaceCell

            required property int index

            readonly property bool current: index === 0
            readonly property bool occupied: root.workspacesOccupiedBg && index % 2 === 1

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.small
            color: current ? Colours.palette.m3primary : occupied ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest

            MaterialIcon {
              anchors.centerIn: parent
              text: root.workspacesActiveIndicator && workspaceCell.current ? "radio_button_checked" : "radio_button_unchecked"
              color: workspaceCell.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
              font.pointSize: Tokens.font.size.smaller
              fill: workspaceCell.current ? 1 : 0
            }
          }
        }
      }
    }
  }

  component StatusToken: StyledRect {
    id: token

    property string icon: ""
    property string title: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(88, label.implicitWidth + 42)
    implicitHeight: 34
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: token.toggled(!token.checked)

      color: token.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: token.icon
        color: token.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: token.checked ? 1 : 0
      }

      StyledText {
        id: label

        Layout.alignment: Qt.AlignVCenter
        text: token.title
        color: token.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideRight
      }
    }
  }

  component StatusDot: StyledRect {
    id: dot

    property string icon: ""
    property bool active: false

    implicitWidth: 32
    implicitHeight: 32
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainer
    opacity: active ? 1 : 0.44

    MaterialIcon {
      anchors.centerIn: parent
      text: dot.icon
      color: dot.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
      font.pointSize: Tokens.font.size.small
      fill: dot.active ? 1 : 0
    }
  }

  component FeatureChip: StyledRect {
    id: chip

    property string icon: ""
    property string title: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(106, chipLabel.implicitWidth + 42)
    implicitHeight: 34
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh
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
        id: chipLabel

        Layout.alignment: Qt.AlignVCenter
        text: chip.title
        color: chip.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 650
        elide: Text.ElideRight
      }
    }
  }

  component MonitorPill: StyledRect {
    id: pill

    property string title: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(132, titleLabel.implicitWidth + 52)
    implicitHeight: 36
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3tertiaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: pill.toggled(!pill.checked)

      color: pill.checked ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: "monitor"
        color: pill.checked ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: pill.checked ? 1 : 0
      }

      StyledText {
        id: titleLabel

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: pill.title
        color: pill.checked ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideMiddle
      }
    }
  }

  component DialControl: StyledRect {
    id: dial

    property string icon: "tune"
    property string title: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property string valueText: value.toString()

    signal valueModified(int value)

    implicitHeight: 84
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
          text: dial.icon
          color: Colours.palette.m3primary
          font.pointSize: Tokens.font.size.small
          fill: 1
        }

        StyledText {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: dial.title
          font.pointSize: Tokens.font.size.small
          font.weight: 700
          elide: Text.ElideRight
        }

        StepButton {
          icon: "remove"
          enabled: dial.value > dial.from

          onClicked: dial.valueModified(dial.value - 1)
        }

        StyledRect {
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: Math.max(46, dialValue.implicitWidth + Tokens.padding.small * 2)
          implicitHeight: 26
          radius: Tokens.rounding.small
          color: Colours.palette.m3surfaceContainerHighest

          StyledText {
            id: dialValue

            anchors.centerIn: parent
            text: dial.valueText
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            font.weight: 700
          }
        }

        StepButton {
          icon: "add"
          enabled: dial.value < dial.to

          onClicked: dial.valueModified(dial.value + 1)
        }
      }

      StyledSlider {
        id: slider

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.normal * 2.2
        from: dial.from
        to: dial.to
        stepSize: 1

        onMoved: dial.valueModified(Math.round(value))

        Binding {
          target: slider
          property: "value"
          value: dial.value
          when: !slider.pressed
        }
      }
    }
  }

  component StepButton: StyledRect {
    id: button

    property string icon: ""
    signal clicked

    implicitWidth: 26
    implicitHeight: 26
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

    implicitWidth: Math.max(96, label.implicitWidth + 44)
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
