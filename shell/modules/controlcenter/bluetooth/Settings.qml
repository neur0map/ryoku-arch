pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

GridLayout {
  id: root

  required property Session session

  implicitHeight: childrenRect.height
  columns: width > 620 ? 2 : 1
  columnSpacing: Tokens.spacing.small
  rowSpacing: Tokens.spacing.small

  AdapterDock {
    icon: "settings_bluetooth"
    title: qsTr("Adapter controls")
    detail: Bluetooth.defaultAdapter ? BluetoothAdapterState.toString(Bluetooth.defaultAdapter.state) : qsTr("Unavailable")

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      TogglePill {
        icon: "power_settings_new"
        title: qsTr("Power")
        checked: Bluetooth.defaultAdapter?.enabled ?? false

        onToggled: checked => {
          const adapter = Bluetooth.defaultAdapter;
          if (adapter)
            adapter.enabled = checked;
        }
      }

      TogglePill {
        icon: "group_search"
        title: qsTr("Visible")
        checked: Bluetooth.defaultAdapter?.discoverable ?? false

        onToggled: checked => {
          const adapter = Bluetooth.defaultAdapter;
          if (adapter)
            adapter.discoverable = checked;
        }
      }

      TogglePill {
        icon: "missing_controller"
        title: qsTr("Pairable")
        checked: Bluetooth.defaultAdapter?.pairable ?? false

        onToggled: checked => {
          const adapter = Bluetooth.defaultAdapter;
          if (adapter)
            adapter.pairable = checked;
        }
      }

      TogglePill {
        icon: "bluetooth_searching"
        title: qsTr("Scan")
        checked: Bluetooth.defaultAdapter?.discovering ?? false

        onToggled: checked => {
          const adapter = Bluetooth.defaultAdapter;
          if (adapter)
            adapter.discovering = checked;
        }
      }
    }
  }

  AdapterDock {
    icon: "settings_input_component"
    title: qsTr("Current adapter")
    detail: root.session.bt.currentAdapter?.name ?? qsTr("None")

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      Repeater {
        model: Bluetooth.adapters

        AdapterChip {
        }
      }
    }
  }

  AdapterDock {
    icon: "badge"
    title: qsTr("Identity")
    detail: qsTr("Name and discovery timeout")

    GridLayout {
      Layout.fillWidth: true
      columns: width > 520 ? 2 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      StyledRect {
        Layout.fillWidth: true
        implicitHeight: timeoutRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        RowLayout {
          id: timeoutRow

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Tokens.padding.small
          spacing: Tokens.spacing.small

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Discoverable")
            font.weight: 650
            elide: Text.ElideRight
          }

          CustomSpinBox {
            min: 0
            value: root.session.bt.currentAdapter?.discoverableTimeout ?? 0
            onValueModified: value => {
              if (root.session.bt.currentAdapter)
                root.session.bt.currentAdapter.discoverableTimeout = value;
            }
          }
        }
      }

      StyledRect {
        Layout.fillWidth: true
        implicitHeight: renameRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        RowLayout {
          id: renameRow

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Tokens.padding.small
          spacing: Tokens.spacing.small

          StyledTextField {
            id: adapterNameEdit

            Layout.fillWidth: true
            text: root.session.bt.currentAdapter?.name ?? ""
            readOnly: !root.session.bt.editingAdapterName
            onAccepted: {
              root.session.bt.editingAdapterName = false;
            }

            background: StyledRect {
              radius: Tokens.rounding.small
              color: root.session.bt.editingAdapterName ? Colours.palette.m3surfaceContainerHighest : "transparent"
              border.width: root.session.bt.editingAdapterName ? 1 : 0
              border.color: Colours.palette.m3primary
            }
          }

          IconButton {
            icon: root.session.bt.editingAdapterName ? "check_circle" : "edit"
            onClicked: {
              root.session.bt.editingAdapterName = !root.session.bt.editingAdapterName;
              if (root.session.bt.editingAdapterName)
                adapterNameEdit.forceActiveFocus();
              else
                adapterNameEdit.accepted();
            }
          }
        }
      }
    }
  }

  AdapterDock {
    icon: "info"
    title: qsTr("Adapter info")
    detail: Bluetooth.defaultAdapter?.adapterId ?? qsTr("Unknown")

    GridLayout {
      Layout.fillWidth: true
      columns: width > 560 ? 3 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      FactPill {
        label: qsTr("State")
        value: Bluetooth.defaultAdapter ? BluetoothAdapterState.toString(Bluetooth.defaultAdapter.state) : qsTr("Unknown")
      }

      FactPill {
        label: qsTr("Adapter")
        value: Bluetooth.defaultAdapter?.adapterId ?? qsTr("None")
      }

      FactPill {
        label: qsTr("Dbus")
        value: Bluetooth.defaultAdapter?.dbusPath ?? qsTr("None")
      }
    }
  }

  component AdapterDock: StyledRect {
    id: dock

    Layout.fillWidth: true

    required property string icon
    required property string title
    property string detail: ""
    default property alias content: dockBody.data

    implicitHeight: dockLayout.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: dockLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: dock.icon
          color: Colours.palette.m3primary
          fill: 1
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: dock.title
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            visible: dock.detail !== ""
            text: dock.detail
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      ColumnLayout {
        id: dockBody

        Layout.fillWidth: true
        spacing: Tokens.spacing.small
      }
    }
  }

  component TogglePill: StyledRect {
    id: pill

    required property string icon
    required property string title
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(116, pillContent.implicitWidth + Tokens.padding.small * 2)
    implicitHeight: 36
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: pill.toggled(!pill.checked)
      color: pill.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: pillContent

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: pill.icon
        color: pill.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: pill.checked ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: pill.title
        color: pill.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 650
      }
    }
  }

  component AdapterChip: StyledRect {
    id: chip

    required property BluetoothAdapter modelData
    readonly property bool active: root.session.bt.currentAdapter === chip.modelData

    implicitWidth: Math.max(118, chipContent.implicitWidth + Tokens.padding.small * 2)
    implicitHeight: 34
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: root.session.bt.currentAdapter = chip.modelData
      color: chip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: chipContent

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: chip.active ? "check_circle" : "settings_input_component"
        color: chip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: chip.active ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: chip.modelData.name
        color: chip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 650
        elide: Text.ElideRight
      }
    }
  }

  component FactPill: StyledRect {
    id: fact

    required property string label
    required property string value

    Layout.fillWidth: true
    implicitHeight: 46
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Tokens.padding.small
      spacing: 0

      StyledText {
        Layout.fillWidth: true
        text: fact.label
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        text: fact.value
        font.weight: 650
        elide: Text.ElideRight
      }
    }
  }
}
