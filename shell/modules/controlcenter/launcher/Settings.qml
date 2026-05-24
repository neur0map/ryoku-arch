pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

ColumnLayout {
  id: root

  required property Session session

  spacing: Tokens.spacing.normal

  LauncherConsole {
    Layout.fillWidth: true
  }

  GridLayout {
    Layout.fillWidth: true
    columns: width > 620 ? 2 : 1
    columnSpacing: Tokens.spacing.small
    rowSpacing: Tokens.spacing.small

    FuzzyLane {
      Layout.fillWidth: true
    }

    StyledRect {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      implicitHeight: metricLayout.implicitHeight + Tokens.padding.normal * 2
      radius: Tokens.rounding.small
      color: Colours.palette.m3surfaceContainer
      clip: true

      GridLayout {
        id: metricLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.normal
        columns: 2
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        LauncherMetric {
          Layout.fillWidth: true
          icon: "format_list_numbered"
          title: qsTr("Shown")
          value: Config.launcher.maxShown.toString()
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "image"
          title: qsTr("Walls")
          value: Config.launcher.maxWallpapers.toString()
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "drag_pan"
          title: qsTr("Drag")
          value: qsTr("%1px").arg(Config.launcher.dragThreshold)
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "visibility_off"
          title: qsTr("Hidden")
          value: (GlobalConfig.launcher.hiddenApps ? GlobalConfig.launcher.hiddenApps.length : 0).toString()
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "alternate_email"
          title: qsTr("Special")
          value: GlobalConfig.launcher.specialPrefix || qsTr("None")
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "terminal"
          title: qsTr("Action")
          value: GlobalConfig.launcher.actionPrefix || qsTr("None")
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "width"
          title: qsTr("Item")
          value: qsTr("%1x%2").arg(Tokens.sizes.launcher.itemWidth).arg(Tokens.sizes.launcher.itemHeight)
        }

        LauncherMetric {
          Layout.fillWidth: true
          icon: "wallpaper"
          title: qsTr("Wall")
          value: qsTr("%1x%2").arg(Tokens.sizes.launcher.wallpaperWidth).arg(Tokens.sizes.launcher.wallpaperHeight)
        }
      }
    }
  }

  component LauncherConsole: StyledRect {
    id: consolePanel

    implicitHeight: 204
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.fillWidth: false
        Layout.preferredWidth: Math.min(250, consolePanel.width * 0.42)
        Layout.minimumWidth: 200
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
              text: "apps"
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
                text: qsTr("Launcher")
                font.weight: 700
                elide: Text.ElideRight
              }

              StyledText {
                Layout.fillWidth: true
                text: GlobalConfig.launcher.specialPrefix + qsTr(" commands")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
              }
            }
          }

          StyledRect {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHighest

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Tokens.padding.normal
              anchors.rightMargin: Tokens.padding.normal
              spacing: Tokens.spacing.small

              MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "search"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
              }

              StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("Search apps, actions, schemes")
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

            PreviewTile {
              Layout.fillWidth: true
              icon: "apps"
              title: qsTr("Apps")
              active: GlobalConfig.launcher.useFuzzy.apps
            }

            PreviewTile {
              Layout.fillWidth: true
              icon: "palette"
              title: qsTr("Schemes")
              active: GlobalConfig.launcher.useFuzzy.schemes
            }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 2
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        LauncherToggle {
          Layout.fillWidth: true
          icon: "power_settings_new"
          title: qsTr("Enabled")
          detail: qsTr("Launcher surface")
          checked: Config.launcher.enabled

          onToggled: checked => {
            GlobalConfig.launcher.enabled = checked;
          }
        }

        LauncherToggle {
          Layout.fillWidth: true
          icon: "ads_click"
          title: qsTr("Hover")
          detail: qsTr("Reveal behavior")
          checked: Config.launcher.showOnHover

          onToggled: checked => {
            GlobalConfig.launcher.showOnHover = checked;
          }
        }

        LauncherToggle {
          Layout.fillWidth: true
          icon: "keyboard"
          title: qsTr("Vim")
          detail: qsTr("Navigation keys")
          checked: GlobalConfig.launcher.vimKeybinds

          onToggled: checked => {
            GlobalConfig.launcher.vimKeybinds = checked;
          }
        }

        LauncherToggle {
          Layout.fillWidth: true
          icon: "warning"
          title: qsTr("Danger")
          detail: qsTr("Power actions")
          checked: GlobalConfig.launcher.enableDangerousActions

          onToggled: checked => {
            GlobalConfig.launcher.enableDangerousActions = checked;
          }
        }
      }
    }
  }

  component FuzzyLane: StyledRect {
    implicitHeight: laneLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: laneLayout

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
          text: qsTr("Fuzzy lanes")
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.alignment: Qt.AlignVCenter
          text: qsTr("Ranking")
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        LauncherToggle {
          icon: "apps"
          title: qsTr("Apps")
          detail: qsTr("Names")
          checked: GlobalConfig.launcher.useFuzzy.apps

          onToggled: checked => {
            GlobalConfig.launcher.useFuzzy.apps = checked;
          }
        }

        LauncherToggle {
          icon: "bolt"
          title: qsTr("Actions")
          detail: qsTr("Commands")
          checked: GlobalConfig.launcher.useFuzzy.actions

          onToggled: checked => {
            GlobalConfig.launcher.useFuzzy.actions = checked;
          }
        }

        LauncherToggle {
          icon: "palette"
          title: qsTr("Schemes")
          detail: qsTr("Colours")
          checked: GlobalConfig.launcher.useFuzzy.schemes

          onToggled: checked => {
            GlobalConfig.launcher.useFuzzy.schemes = checked;
          }
        }

        LauncherToggle {
          icon: "colors"
          title: qsTr("Variants")
          detail: qsTr("Modes")
          checked: GlobalConfig.launcher.useFuzzy.variants

          onToggled: checked => {
            GlobalConfig.launcher.useFuzzy.variants = checked;
          }
        }

        LauncherToggle {
          icon: "wallpaper"
          title: qsTr("Walls")
          detail: qsTr("Images")
          checked: GlobalConfig.launcher.useFuzzy.wallpapers

          onToggled: checked => {
            GlobalConfig.launcher.useFuzzy.wallpapers = checked;
          }
        }
      }
    }
  }

  component LauncherToggle: StyledRect {
    id: tile

    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(132, label.implicitWidth + detailLabel.implicitWidth + 60)
    implicitHeight: 54
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: tile.toggled(!tile.checked)

      color: tile.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: tile.icon
        color: tile.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: tile.checked ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          id: label

          Layout.fillWidth: true
          text: tile.title
          color: tile.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.small
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          id: detailLabel

          Layout.fillWidth: true
          visible: tile.width > 150
          text: tile.detail
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.smaller
          elide: Text.ElideRight
        }
      }
    }
  }

  component LauncherMetric: StyledRect {
    id: metric

    property string icon: ""
    property string title: ""
    property string value: ""

    implicitHeight: 48
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: metric.icon
        color: Colours.palette.m3tertiary
        font.pointSize: Tokens.font.size.small
        fill: 1
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: metric.title
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.smaller
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: metric.value
          font.pointSize: Tokens.font.size.small
          font.weight: 700
          elide: Text.ElideRight
        }
      }
    }
  }

  component PreviewTile: StyledRect {
    id: preview

    property string icon: ""
    property string title: ""
    property bool active: false

    implicitHeight: 44
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest

    RowLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: preview.icon
        color: preview.active ? Colours.palette.m3secondary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: preview.active ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: preview.title
        color: preview.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 700
      }
    }
  }
}
