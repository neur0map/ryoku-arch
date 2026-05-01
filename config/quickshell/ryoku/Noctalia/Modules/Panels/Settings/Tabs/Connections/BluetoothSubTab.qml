import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell

import qs.Noctalia.Commons
import qs.Noctalia.Services.Hardware
import qs.Noctalia.Services.Networking
import qs.Noctalia.Services.System
import qs.Noctalia.Services.UI
import qs.Noctalia.Widgets

Item {
  id: root
  Layout.fillWidth: true
  implicitHeight: mainLayout.implicitHeight

  // Configuration for shared use (e.g. by BluetoothPanel)
  property bool showOnlyLists: false

  readonly property bool advancedBluetoothControlsSupported: false
  readonly property string unsupportedAdvancedControlText: "Unavailable in Ryoku"
  readonly property bool isScanningActive: RyokuBluetoothService.scanningActive
  readonly property bool isDiscoverable: RyokuBluetoothService.discoverable

  // Device lists with local filtering logic
  readonly property var connectedDevices: {
    if (!RyokuBluetoothService.adapter || !RyokuBluetoothService.adapter.devices)
      return [];
    var filtered = RyokuBluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && dev.connected);
    filtered = RyokuBluetoothService.dedupeDevices(filtered);
    return RyokuBluetoothService.sortDevices(filtered);
  }

  readonly property var pairedDevices: {
    if (!RyokuBluetoothService.adapter || !RyokuBluetoothService.adapter.devices)
      return [];
    var filtered = RyokuBluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && !dev.connected && (dev.paired || dev.trusted));
    filtered = RyokuBluetoothService.dedupeDevices(filtered);
    return RyokuBluetoothService.sortDevices(filtered);
  }

  readonly property var unnamedAvailableDevices: {
    if (!RyokuBluetoothService.adapter || !RyokuBluetoothService.adapter.devices)
      return [];
    return RyokuBluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && !dev.paired && !dev.trusted);
  }

  readonly property var availableDevices: {
    var list = root.unnamedAvailableDevices;

    if (Settings.data.network.bluetoothHideUnnamedDevices) {
      list = list.filter(function (dev) {
        var dn = dev.name || dev.deviceName || "";
        var s = String(dn).trim();
        if (s.length === 0)
          return false;
        var lower = s.toLowerCase();
        if (lower === "unknown" || lower === "unnamed" || lower === "n/a" || lower === "na")
          return false;
        var addr = dev.address || dev.bdaddr || dev.mac || "";
        if (addr.length > 0) {
          var normName = s.toLowerCase().replace(/[^0-9a-z]/g, "");
          var normAddr = String(addr).toLowerCase().replace(/[^0-9a-z]/g, "");
          if (normName.length > 0 && normName === normAddr)
            return false;
        }
        var macRegexComb = /^(([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}|([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}|[0-9A-Fa-f]{12})$/;
        if (macRegexComb.test(s)) {
          return false;
        }
        return true;
      });
    }
    list = RyokuBluetoothService.dedupeDevices(list);
    return RyokuBluetoothService.sortDevices(list);
  }

  // For managing expanded device details
  property string expandedDeviceKey: ""
  property bool detailsGrid: (Settings.data.network.bluetoothDetailsViewMode === "grid")

  // Combined visibility check: tab must be visible AND the window must be visible
  readonly property bool effectivelyVisible: root.visible && Window.window && Window.window.visible

  Connections {
    target: RyokuBluetoothService
    function onEnabledChanged() {
      stateChangeDebouncer.restart();
    }
    function onDiscoverableChanged() {
      stateChangeDebouncer.restart();
    }
  }

  onEffectivelyVisibleChanged: stateChangeDebouncer.restart()

  Timer {
    id: stateChangeDebouncer
    interval: 100 // 100ms debounce
    repeat: false
    onTriggered: root._updateScanningState()
  }

  function _updateScanningState() {
    if (effectivelyVisible && RyokuBluetoothService.enabled && !showOnlyLists) {
      Logger.d("BluetoothPrefs", "Panel/tab active");
      if (!isScanningActive) {
        RyokuBluetoothService.setScanActive(true);
      }
      if (!Settings.data.network.disableDiscoverability && !isDiscoverable) {
        RyokuBluetoothService.setDiscoverable(true);
      }
    } else {
      Logger.d("BluetoothPrefs", "Panel/tab inactive");
      if (isScanningActive && !showOnlyLists) {
        RyokuBluetoothService.setScanActive(false);
      }
      if (isDiscoverable && !showOnlyLists) {
        RyokuBluetoothService.setDiscoverable(false);
      }
    }
  }

  Component.onDestruction: {
    // Ensure scanning is stopped when component is closed
    if (isScanningActive && !showOnlyLists) {
      RyokuBluetoothService.setScanActive(false);
    }
    // Ensure discoverable is disabled when component is closed
    if (isDiscoverable && !showOnlyLists) {
      RyokuBluetoothService.setDiscoverable(false);
    }
    Logger.d("BluetoothPrefs", "Panel closed");
  }

  ColumnLayout {
    id: mainLayout
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: root.showOnlyLists ? Style.marginM : Style.marginL

    // Master Control Section
    NBox {
      visible: !root.showOnlyLists
      Layout.fillWidth: true
      Layout.preferredHeight: masterControlCol.implicitHeight + Style.margin2L
      color: Color.mSurface

      ColumnLayout {
        id: masterControlCol
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NToggle {
            label: I18n.tr("common.bluetooth")
            icon: RyokuBluetoothService.enabled ? "bluetooth" : "bluetooth-off"
            checked: RyokuBluetoothService.enabled
            enabled: !RyokuNetworkService.airplaneModeEnabled && RyokuBluetoothService.bluetoothAvailable && !RyokuBluetoothService.blocked
            onToggled: checked => RyokuBluetoothService.setBluetoothEnabled(checked)
            Layout.alignment: Qt.AlignVCenter
          }
        }

        NDivider {
          Layout.fillWidth: true
          visible: RyokuBluetoothService.enabled && isDiscoverable
        }

        NText {
          visible: RyokuBluetoothService.enabled && isDiscoverable
          Layout.fillWidth: true
          text: I18n.tr("panels.connections.bluetooth-discoverable", {
                          hostName: HostService.hostName
                        })
          color: Color.mOnSurfaceVariant
          richTextEnabled: true
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    Item {
      visible: !showOnlyLists
      Layout.fillWidth: true
    }

    // Device List [1] (Connected)
    NBox {
      id: connectedDevicesBox
      visible: root.connectedDevices.length > 0 && RyokuBluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: connectedDevicesCol.implicitHeight + Style.margin2M
      border.color: showOnlyLists ? Style.boxBorderColor : "transparent"
      color: showOnlyLists ? Color.mSurfaceVariant : "transparent"

      ColumnLayout {
        id: connectedDevicesCol
        anchors.fill: parent
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        anchors.leftMargin: showOnlyLists ? Style.marginL : 0
        anchors.rightMargin: showOnlyLists ? Style.marginL : 0
        spacing: Style.marginM

        NLabel {
          label: I18n.tr("bluetooth.panel.connected-devices")
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
        }

        Repeater {
          model: root.connectedDevices
          delegate: nboxDelegate
        }
      }
    }

    // Devices List [2] (Paired)
    NBox {
      id: pairedDevicesBox
      visible: root.pairedDevices.length > 0 && RyokuBluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: pairedDevicesCol.implicitHeight + Style.margin2M
      border.color: showOnlyLists ? Style.boxBorderColor : "transparent"
      color: showOnlyLists ? Color.mSurfaceVariant : "transparent"

      ColumnLayout {
        id: pairedDevicesCol
        anchors.fill: parent
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        anchors.leftMargin: showOnlyLists ? Style.marginL : 0
        anchors.rightMargin: showOnlyLists ? Style.marginL : 0
        spacing: Style.marginM

        NLabel {
          label: I18n.tr("bluetooth.panel.paired-devices")
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
        }

        Repeater {
          model: root.pairedDevices
          delegate: nboxDelegate
        }
      }
    }

    // Device List [3] (Available)
    NBox {
      id: availableDevicesBox
      visible: !root.showOnlyLists && root.unnamedAvailableDevices.length > 0 && RyokuBluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: availableDevicesCol.implicitHeight + Style.margin2M
      border.color: "transparent"
      color: showOnlyLists ? Color.mSurfaceVariant : "transparent"

      ColumnLayout {
        id: availableDevicesCol
        anchors.fill: parent
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
          spacing: Style.marginS

          NLabel {
            label: I18n.tr("bluetooth.panel.available-devices")
            description: RyokuBluetoothService.scanningActive ? I18n.tr("bluetooth.panel.scanning") : ""
            Layout.fillWidth: true
          }
        }

        Repeater {
          model: root.availableDevices
          delegate: nboxDelegate
        }

        NText {
          visible: root.availableDevices.length === 0 && root.unnamedAvailableDevices.length > 0
          text: I18n.tr("panels.connections.bluetooth-devices-unnamed")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
          Layout.margins: Style.marginL
        }
      }
    }

    Item {
      visible: !showOnlyLists
      Layout.fillWidth: true
    }

    NBox {
      id: miscSettingsBox
      visible: !root.showOnlyLists && RyokuBluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: miscSettingsCol.implicitHeight + Style.margin2XL
      color: Color.mSurface

      ColumnLayout {
        id: miscSettingsCol
        anchors.fill: parent
        anchors.margins: Style.marginXL
        spacing: Style.marginM

        NToggle {
          label: I18n.tr("panels.connections.bluetooth-auto-connect-label")
          description: root.advancedBluetoothControlsSupported ? I18n.tr("panels.connections.bluetooth-auto-connect-description") : root.unsupportedAdvancedControlText
          enabled: root.advancedBluetoothControlsSupported
          checked: Settings.data.network.bluetoothAutoConnect
          onToggled: checked => Settings.data.network.bluetoothAutoConnect = checked
        }

        NToggle {
          label: I18n.tr("panels.connections.hide-unnamed-devices-label")
          description: I18n.tr("panels.connections.hide-unnamed-devices-description")
          checked: Settings.data.network.bluetoothHideUnnamedDevices
          onToggled: checked => Settings.data.network.bluetoothHideUnnamedDevices = checked
        }

        NToggle {
          label: I18n.tr("panels.connections.disable-discoverability-label")
          description: I18n.tr("panels.connections.disable-discoverability-description")
          checked: Settings.data.network.disableDiscoverability
          onToggled: checked => {
                       Settings.data.network.disableDiscoverability = checked;
                       RyokuBluetoothService.setDiscoverable(!checked);
                     }
        }

        // RSSI Polling
        NToggle {
          label: I18n.tr("panels.connections.bluetooth-rssi-polling-label")
          description: root.advancedBluetoothControlsSupported ? I18n.tr("panels.connections.bluetooth-rssi-polling-description") : root.unsupportedAdvancedControlText
          enabled: root.advancedBluetoothControlsSupported
          checked: Settings.data.network.bluetoothRssiPollingEnabled
          onToggled: checked => Settings.data.network.bluetoothRssiPollingEnabled = checked
        }
        NSpinBox {
          label: I18n.tr("panels.connections.bluetooth-rssi-polling-interval-label")
          description: I18n.tr("panels.connections.bluetooth-rssi-polling-interval-description")
          from: 10000
          to: 120000
          stepSize: 1000
          value: Settings.data.network.bluetoothRssiPollIntervalMs
          defaultValue: Settings.getDefaultValue("network.bluetoothRssiPollIntervalMs")
          onValueChanged: Settings.data.network.bluetoothRssiPollIntervalMs = value
          suffix: " ms"
          enabled: root.advancedBluetoothControlsSupported
          Layout.alignment: Qt.AlignVCenter
          visible: root.advancedBluetoothControlsSupported && Settings.data.network.bluetoothRssiPollingEnabled
        }
      }
    }
  }

  // Shared Delegate
  Component {
    id: nboxDelegate
    NBox {
      id: device

      readonly property bool canConnect: RyokuBluetoothService.canConnect(modelData)
      readonly property bool canDisconnect: RyokuBluetoothService.canDisconnect(modelData)
      readonly property bool canPair: RyokuBluetoothService.canPair(modelData)
      readonly property bool isBusy: RyokuBluetoothService.isDeviceBusy(modelData)
      readonly property bool isExpanded: root.expandedDeviceKey === RyokuBluetoothService.deviceKey(modelData)
      readonly property string statusKey: RyokuBluetoothService.getStatusKey(modelData)

      function getContentColors(defaultColors = [Color.mSurface, Color.mOnSurface]) {
        if (modelData.pairing || statusKey === "connecting") {
          return [Color.mPrimary, Color.mOnPrimary];
        }
        if (modelData.connected && statusKey !== "disconnecting") {
          return [Color.mPrimary, Color.mOnPrimary];
        }
        if (modelData.blocked || statusKey === "disconnecting") {
          return [Color.mError, Color.mOnError];
        }
        return defaultColors;
      }

      Layout.fillWidth: true
      Layout.preferredHeight: deviceColumn.implicitHeight + (Style.marginXL)
      radius: Style.radiusM
      clip: true
      forceOpaque: true
      color: device.getContentColors()[0]

      ColumnLayout {
        id: deviceColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        RowLayout {
          id: deviceLayout
          Layout.fillWidth: true
          spacing: Style.marginM
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            icon: RyokuBluetoothService.getDeviceIcon(modelData)
            pointSize: Style.fontSizeXXL
            color: device.getContentColors()[1]
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: modelData.name || modelData.deviceName
              pointSize: Style.fontSizeM
              font.weight: modelData.connected ? Style.fontWeightBold : Style.fontWeightMedium
              elide: Text.ElideRight
              color: device.getContentColors()[1]
              Layout.fillWidth: true
            }

            NText {
              text: {
                const k = RyokuBluetoothService.getStatusKey(modelData);
                if (k === "pairing")
                  return I18n.tr("common.pairing");
                if (k === "blocked")
                  return I18n.tr("bluetooth.panel.blocked");
                if (k === "connecting")
                  return I18n.tr("common.connecting");
                if (k === "disconnecting")
                  return I18n.tr("common.disconnecting");
                return "";
              }
              visible: text !== ""
              pointSize: Style.fontSizeXS
              color: Qt.alpha(device.getContentColors([Color.mSurfaceVariant, Color.mOnSurfaceVariant])[1], Style.opacityHeavy)
            }

            RowLayout {
              visible: modelData.batteryAvailable
              spacing: Style.marginS
              NIcon {
                icon: {
                  var b = RyokuBluetoothService.getBatteryPercent(modelData);
                  return BatteryService.getIcon(b !== null ? b : 0, false, false, b !== null);
                }
                pointSize: Style.fontSizeXS
                color: Qt.alpha(device.getContentColors()[1], Style.opacityHeavy)
              }
              NText {
                text: {
                  var b = RyokuBluetoothService.getBatteryPercent(modelData);
                  return b === null ? "-" : (b + "%");
                }
                pointSize: Style.fontSizeXS
                color: Qt.alpha(device.getContentColors([Color.mSurfaceVariant, Color.mOnSurfaceVariant])[1], Style.opacityHeavy)
              }
            }
          }

          Item {
            Layout.fillWidth: true
          }

          RowLayout {
            spacing: Style.marginS

            NBusyIndicator {
              visible: isBusy
              running: visible && root.effectivelyVisible
              color: device.getContentColors()[1]
              size: Style.baseWidgetSize * 0.5
            }

            NIconButton {
              visible: modelData.connected && device.statusKey !== "disconnecting"
              icon: "info"
              tooltipText: I18n.tr("common.info")
              baseSize: Style.baseWidgetSize * 0.75
              colorBg: Color.mSurfaceVariant
              colorFg: Color.mOnSurface
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: {
                const key = RyokuBluetoothService.deviceKey(modelData);
                root.expandedDeviceKey = (root.expandedDeviceKey === key) ? "" : key;
              }
            }

            NIconButton {
              visible: !root.showOnlyLists && (modelData.paired || modelData.trusted) && !modelData.connected && !isBusy && !modelData.blocked
              icon: "trash"
              tooltipText: I18n.tr("common.unpair")
              baseSize: Style.baseWidgetSize * 0.75
              colorBg: Color.mPrimary
              colorFg: Color.mOnPrimary
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: RyokuBluetoothService.unpairDevice(modelData)
            }

            NButton {
              id: button
              visible: device.statusKey !== "connecting" && device.statusKey !== "disconnecting"
              enabled: (canConnect || canDisconnect || (root.showOnlyLists ? false : canPair)) && !isBusy
              fontSize: Style.fontSizeS
              backgroundColor: modelData.connected ? Color.mSurfaceVariant : Color.mPrimary
              textColor: modelData.connected ? Color.mOnSurface : Color.mOnPrimary
              text: {
                if (modelData.pairing)
                  return I18n.tr("common.pairing");
                if (modelData.blocked)
                  return I18n.tr("bluetooth.panel.blocked");
                if (modelData.connected)
                  return I18n.tr("common.disconnect");
                if (!root.showOnlyLists && device.canPair)
                  return I18n.tr("common.pair");
                return I18n.tr("common.connect");
              }
              onClicked: {
                if (modelData.connected) {
                  RyokuBluetoothService.disconnectDevice(modelData);
                } else {
                  if (!root.showOnlyLists && device.canPair) {
                    RyokuBluetoothService.pairDevice(modelData);
                  } else {
                    RyokuBluetoothService.connectDeviceWithTrust(modelData);
                  }
                }
              }
            }
          }
        }

        // Expanded info section
        Rectangle {
          visible: device.isExpanded
          Layout.fillWidth: true
          implicitHeight: infoColumn.implicitHeight + Style.margin2S
          radius: Style.radiusXS
          color: Color.mSurfaceVariant
          border.width: Style.borderS
          border.color: Style.boxBorderColor
          clip: true

          NIconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.marginS
            icon: root.detailsGrid ? "layout-list" : "layout-grid"
            tooltipText: root.detailsGrid ? I18n.tr("tooltips.list-view") : I18n.tr("tooltips.grid-view")
            baseSize: Style.baseWidgetSize * 0.65
            onClicked: {
              root.detailsGrid = !root.detailsGrid;
              Settings.data.network.bluetoothDetailsViewMode = root.detailsGrid ? "grid" : "list";
            }
            z: 1
          }

          GridLayout {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: Style.marginS
            flow: root.detailsGrid ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.detailsGrid ? 3 : 6
            columns: root.detailsGrid ? 2 : 1
            columnSpacing: Style.marginM
            rowSpacing: Style.marginXS

            // --- Item 1: Signal Strength ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: RyokuBluetoothService.getSignalIcon(modelData)
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: RyokuBluetoothService.getSignalStrength(modelData)
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }

            // --- Item 2: Battery ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: {
                  var b = RyokuBluetoothService.getBatteryPercent(modelData);
                  return BatteryService.getIcon(b !== null ? b : 0, false, false, b !== null);
                }
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: {
                  var b = RyokuBluetoothService.getBatteryPercent(modelData);
                  return b === null ? "-" : (b + "%");
                }
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 3: Pair state ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "link"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: modelData.paired ? I18n.tr("common.yes") : I18n.tr("common.no")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 4: Trust state ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "shield-check"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: modelData.trusted ? I18n.tr("common.yes") : I18n.tr("common.no")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 5: Address ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "hash"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: modelData.address || "-"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 6: Auto-connect ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.topMargin: -Style.marginXXS
              spacing: Style.marginXS
              visible: root.advancedBluetoothControlsSupported && Settings.data.network.bluetoothAutoConnect
              NIcon {
                icon: RyokuBluetoothService.getDeviceAutoConnect(modelData) ? "repeat" : "repeat-off"
                pointSize: Style.fontSizeXS
              }
              NCheckbox {
                label: I18n.tr("common.auto-connect")
                labelSize: Style.fontSizeXS
                baseSize: Style.baseWidgetSize * 0.5
                enabled: root.advancedBluetoothControlsSupported
                checked: RyokuBluetoothService.getDeviceAutoConnect(modelData)
                onToggled: checked => RyokuBluetoothService.setDeviceAutoConnect(modelData, checked)
              }
            }
          }
        }
      }
    }
  }

  // PIN Authentication Overlay (This part needs some love :P)
  Rectangle {
    id: pinOverlay
    visible: !root.showOnlyLists && RyokuBluetoothService.pinRequired
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 400)
    height: pinCol.implicitHeight + Style.margin2L
    color: Color.mSurface
    radius: Style.radiusM
    border.color: Style.boxBorderColor
    border.width: Style.borderS
    z: 1000

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: mouse => mouse.accepted = true
      onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
      id: pinCol
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      NIcon {
        icon: "lock"
        pointSize: 48
        color: Color.mPrimary
        Layout.alignment: Qt.AlignHCenter
      }
      NText {
        text: I18n.tr("panels.connections.authentication-required")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      NText {
        text: I18n.tr("panels.connections.pin-instructions")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      NTextInput {
        id: pinInput
        Layout.fillWidth: true
        placeholderText: "123456"
        inputIconName: "key"
        onVisibleChanged: {
          if (visible) {
            text = "";
            inputItem.forceActiveFocus();
          }
        }
        inputItem.onEditingFinished: {
          if (text.length > 0) {
            RyokuBluetoothService.submitPin(text);
            text = "";
          }
        }
      }
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM
        NButton {
          text: I18n.tr("common.cancel")
          icon: "x"
          onClicked: RyokuBluetoothService.cancelPairing()
        }
        NButton {
          text: I18n.tr("common.confirm")
          icon: "check"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          enabled: pinInput.text.length > 0
          onClicked: {
            RyokuBluetoothService.submitPin(pinInput.text);
            pinInput.text = "";
          }
        }
      }
    }
  }
}
