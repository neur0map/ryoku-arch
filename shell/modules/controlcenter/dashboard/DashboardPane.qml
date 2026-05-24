pragma ComponentBehavior: Bound

import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
  id: root

  required property Session session

  property bool enabled: Config.dashboard.enabled ?? true
  property bool showOnHover: Config.dashboard.showOnHover ?? true
  property int mediaUpdateInterval: GlobalConfig.dashboard.mediaUpdateInterval ?? 1000
  property int resourceUpdateInterval: GlobalConfig.dashboard.resourceUpdateInterval ?? 1000
  property int dragThreshold: Config.dashboard.dragThreshold ?? 50

  property bool showDashboard: Config.dashboard.showDashboard ?? true
  property bool showMedia: Config.dashboard.showMedia ?? true
  property bool showPerformance: Config.dashboard.showPerformance ?? true
  property bool showWeather: Config.dashboard.showWeather ?? true

  property bool showBattery: Config.dashboard.performance.showBattery ?? false
  property bool showGpu: Config.dashboard.performance.showGpu ?? true
  property bool showCpu: Config.dashboard.performance.showCpu ?? true
  property bool showMemory: Config.dashboard.performance.showMemory ?? true
  property bool showStorage: Config.dashboard.performance.showStorage ?? true
  property bool showNetwork: Config.dashboard.performance.showNetwork ?? true

  readonly property bool batteryAvailable: UPower.displayDevice.isLaptopBattery
  readonly property bool gpuAvailable: SystemUsage.gpuType !== "NONE"

  function saveConfig(): void {
    GlobalConfig.dashboard.enabled = root.enabled;
    GlobalConfig.dashboard.showOnHover = root.showOnHover;
    GlobalConfig.dashboard.mediaUpdateInterval = root.mediaUpdateInterval;
    GlobalConfig.dashboard.resourceUpdateInterval = root.resourceUpdateInterval;
    GlobalConfig.dashboard.dragThreshold = root.dragThreshold;
    GlobalConfig.dashboard.showDashboard = root.showDashboard;
    GlobalConfig.dashboard.showMedia = root.showMedia;
    GlobalConfig.dashboard.showPerformance = root.showPerformance;
    GlobalConfig.dashboard.showWeather = root.showWeather;
    GlobalConfig.dashboard.performance.showBattery = root.showBattery;
    GlobalConfig.dashboard.performance.showGpu = root.showGpu;
    GlobalConfig.dashboard.performance.showCpu = root.showCpu;
    GlobalConfig.dashboard.performance.showMemory = root.showMemory;
    GlobalConfig.dashboard.performance.showStorage = root.showStorage;
    GlobalConfig.dashboard.performance.showNetwork = root.showNetwork;
  }

  function intervalLabel(value: int): string {
    return value >= 1000 ? (value / 1000).toFixed(value % 1000 === 0 ? 0 : 1) + "s" : value + "ms";
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
        columns: width > 760 ? 3 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        ToggleTile {
          Layout.fillWidth: true
          icon: "dashboard"
          title: qsTr("Dashboard")
          detail: root.enabled ? qsTr("Enabled") : qsTr("Disabled")
          checked: root.enabled

          onToggled: checked => {
            root.enabled = checked;
            root.saveConfig();
          }
        }

        ToggleTile {
          Layout.fillWidth: true
          icon: "ads_click"
          title: qsTr("Hover")
          detail: root.showOnHover ? qsTr("Opens on hover") : qsTr("Click only")
          checked: root.showOnHover

          onToggled: checked => {
            root.showOnHover = checked;
            root.saveConfig();
          }
        }

        ToggleTile {
          Layout.fillWidth: true
          icon: "touch_app"
          title: qsTr("Drag")
          detail: qsTr("%1 px threshold").arg(root.dragThreshold)
          checked: root.dragThreshold > 0

          onToggled: checked => {
            root.dragThreshold = checked ? 50 : 0;
            root.saveConfig();
          }
        }
      }

      SettingsDeck {
        Layout.fillWidth: true
        title: qsTr("Tabs")
        detail: qsTr("Choose the dashboard pages that appear in the shell.")

        GridLayout {
          Layout.fillWidth: true
          columns: width > 640 ? 4 : 2
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          ResourceChip {
            Layout.fillWidth: true
            icon: "dashboard"
            title: qsTr("Dashboard")
            checked: root.showDashboard

            onToggled: checked => {
              root.showDashboard = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "music_note"
            title: qsTr("Media")
            checked: root.showMedia

            onToggled: checked => {
              root.showMedia = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "monitoring"
            title: qsTr("Performance")
            checked: root.showPerformance

            onToggled: checked => {
              root.showPerformance = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "partly_cloudy_day"
            title: qsTr("Weather")
            checked: root.showWeather

            onToggled: checked => {
              root.showWeather = checked;
              root.saveConfig();
            }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: width > 780 ? 3 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        RangeTile {
          Layout.fillWidth: true
          icon: "update"
          title: qsTr("Media Poll")
          value: root.mediaUpdateInterval
          from: 100
          to: 10000
          stepSize: 100
          valueText: root.intervalLabel(value)

          onValueModified: newValue => {
            root.mediaUpdateInterval = Math.round(newValue);
            root.saveConfig();
          }
        }

        RangeTile {
          Layout.fillWidth: true
          icon: "speed"
          title: qsTr("Drag Threshold")
          value: root.dragThreshold
          from: 0
          to: 100
          stepSize: 1
          valueText: Math.round(value) + "px"

          onValueModified: newValue => {
            root.dragThreshold = Math.round(newValue);
            root.saveConfig();
          }
        }

        RangeTile {
          Layout.fillWidth: true
          icon: "memory"
          title: qsTr("Resource Poll")
          value: root.resourceUpdateInterval
          from: 100
          to: 10000
          stepSize: 100
          valueText: root.intervalLabel(value)

          onValueModified: newValue => {
            root.resourceUpdateInterval = Math.round(newValue);
            root.saveConfig();
          }
        }
      }

      SettingsDeck {
        Layout.fillWidth: true
        title: qsTr("Resources")
        detail: qsTr("Pick the live metrics shown by the performance page.")

        GridLayout {
          Layout.fillWidth: true
          columns: width > 700 ? 3 : 2
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          ResourceChip {
            Layout.fillWidth: true
            visible: root.batteryAvailable
            icon: "battery_charging_full"
            title: qsTr("Battery")
            checked: root.showBattery

            onToggled: checked => {
              root.showBattery = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            visible: root.gpuAvailable
            icon: "developer_board"
            title: qsTr("GPU")
            checked: root.showGpu

            onToggled: checked => {
              root.showGpu = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "memory_alt"
            title: qsTr("CPU")
            checked: root.showCpu

            onToggled: checked => {
              root.showCpu = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "database"
            title: qsTr("Memory")
            checked: root.showMemory

            onToggled: checked => {
              root.showMemory = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "hard_drive"
            title: qsTr("Storage")
            checked: root.showStorage

            onToggled: checked => {
              root.showStorage = checked;
              root.saveConfig();
            }
          }

          ResourceChip {
            Layout.fillWidth: true
            icon: "lan"
            title: qsTr("Network")
            checked: root.showNetwork

            onToggled: checked => {
              root.showNetwork = checked;
              root.saveConfig();
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

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: deck.title
            font.pointSize: Tokens.font.size.normal
            font.weight: 650
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
      }

      ColumnLayout {
        id: deckContent

        Layout.fillWidth: true
        spacing: Tokens.spacing.small
      }
    }
  }

  component ToggleTile: StyledRect {
    id: tile

    property string icon: "toggle_on"
    property string title: ""
    property string detail: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitHeight: 78
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainer
    clip: true

    StateLayer {
      onClicked: tile.toggled(!tile.checked)

      color: tile.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: tile.icon
        color: tile.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.large
        fill: tile.checked ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        StyledText {
          Layout.fillWidth: true
          text: tile.title
          color: tile.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: tile.detail
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      StyledSwitch {
        Layout.alignment: Qt.AlignVCenter
        checked: tile.checked

        onToggled: tile.toggled(checked)
      }
    }
  }

  component RangeTile: StyledRect {
    id: range

    property string icon: "tune"
    property string title: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string valueText: Math.round(value).toString()

    signal valueModified(real newValue)

    function steppedValue(raw: real): real {
      if (range.stepSize <= 0)
        return raw;

      return Math.round(raw / range.stepSize) * range.stepSize;
    }

    implicitHeight: 92
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

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: range.icon
          color: Colours.palette.m3primary
          font.pointSize: Tokens.font.size.normal
          fill: 1
        }

        StyledText {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: range.title
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledRect {
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: valueLabel.implicitWidth + Tokens.padding.small * 2
          implicitHeight: valueLabel.implicitHeight + Tokens.padding.smaller * 2
          radius: Tokens.rounding.small
          color: Colours.palette.m3surfaceContainerHighest

          StyledText {
            id: valueLabel

            anchors.centerIn: parent
            text: range.valueText
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            font.weight: 650
          }
        }
      }

      StyledSlider {
        id: slider

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.normal * 2.5
        from: range.from
        to: range.to
        stepSize: range.stepSize

        onMoved: {
          range.valueModified(range.steppedValue(value));
        }

        Binding {
          target: slider
          property: "value"
          value: range.value
          when: !slider.pressed
        }
      }
    }
  }

  component ResourceChip: StyledRect {
    id: chip

    property string icon: "check"
    property string title: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitHeight: 38
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: chip.toggled(!chip.checked)

      color: chip.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: chip.icon
        color: chip.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: chip.checked ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: chip.title
        color: chip.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 650
      }
    }
  }
}
