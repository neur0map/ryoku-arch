import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU: the Control Center is a hub for what runs *underneath* the desktop —
// packages, background processes and the system-control tools ryoku ships
// (install/ryoku-base.packages). Frontend/appearance lives in the other settings
// tabs; this launches the real apps rather than reimplementing them.
ColumnLayout {
  id: root
  spacing: Style.marginM
  Layout.fillWidth: true

  // gpk is a TUI (GlazePKG) → open it in the terminal; everything else is a GUI.
  function launch(cmd) {
    Quickshell.execDetached(["sh", "-lc", cmd]);
  }

  NText {
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginS
    text: qsTr("Manage packages, background processes and system hardware. Appearance and behaviour live in the other tabs — this opens the full tools for the deeper stuff.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  SectionHeader {
    text: qsTr("Packages & system")
  }
  ToolRow {
    title: qsTr("GPK — Package manager")
    desc: qsTr("Install, update and remove packages and their dependencies across pacman, the AUR and Flatpak — one place for every package manager.")
    iconName: "package"
    launchCmd: "kitty -e gpk || alacritty -e gpk || foot gpk"
  }
  ToolRow {
    title: qsTr("Mission Center — System monitor")
    desc: qsTr("Watch CPU, memory, disk and network live, and see every running service/daemon with what it's for — start, stop or restart them.")
    iconName: "activity"
    launchCmd: "missioncenter || mission-center || resources || gnome-system-monitor"
  }

  SectionHeader {
    text: qsTr("Devices & hardware")
  }
  ToolRow {
    title: qsTr("Network")
    desc: qsTr("Manage Wi-Fi, wired and VPN connections, and edit connection profiles.")
    iconName: "network"
    launchCmd: "nm-connection-editor"
  }
  ToolRow {
    title: qsTr("Bluetooth")
    desc: qsTr("Pair, connect and manage Bluetooth devices.")
    iconName: "bluetooth"
    launchCmd: "blueman-manager"
  }
  ToolRow {
    title: qsTr("Sound")
    desc: qsTr("Set per-app volume and choose input/output audio devices.")
    iconName: "volume"
    launchCmd: "pavucontrol"
  }
  ToolRow {
    title: qsTr("Disks")
    desc: qsTr("Inspect partitions and mounts, format drives and check disk health (SMART).")
    iconName: "server"
    launchCmd: "gnome-disks || gnome-disk-utility"
  }

  SectionHeader {
    text: qsTr("Shell")
  }
  ToolRow {
    title: qsTr("Restart Ryoku shell")
    desc: qsTr("Restart the desktop shell (bar, desktop widgets, drawers). Use this if something gets stuck or after a manual change.")
    iconName: "refresh"
    buttonText: qsTr("Restart")
    launchCmd: "systemctl --user restart ryoku-shell.service"
  }

  component SectionHeader: NText {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  component ToolRow: NBox {
    id: tool

    property string title: ""
    property string desc: ""
    property string iconName: "apps"
    property string launchCmd: ""
    property string buttonText: qsTr("Open")

    Layout.fillWidth: true
    implicitHeight: toolRow.implicitHeight + Style.margin2L
    color: Color.mSurface

    RowLayout {
      id: toolRow
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      NIcon {
        Layout.alignment: Qt.AlignVCenter
        icon: tool.iconName
        pointSize: Style.fontSizeXXXL
        color: Color.mPrimary
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginXXS

        NText {
          Layout.fillWidth: true
          text: tool.title
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }
        NText {
          Layout.fillWidth: true
          text: tool.desc
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
        }
      }

      NButton {
        Layout.alignment: Qt.AlignVCenter
        text: tool.buttonText
        icon: "external-link"
        outlined: true
        onClicked: root.launch(tool.launchCmd)
      }
    }
  }
}
