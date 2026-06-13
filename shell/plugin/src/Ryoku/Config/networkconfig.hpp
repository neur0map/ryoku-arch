#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// Network / Bluetooth panel + connection preferences. Drives the Wi-Fi,
// Ethernet and Bluetooth panels and their settings tabs (auto-connect, RSSI
// polling, discoverability, view modes). Migrated out of the legacy
// settings-gui store into the typed config (Stage 1).
class NetworkConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, bluetoothRssiPollingEnabled, false)
    CONFIG_PROPERTY(int, bluetoothRssiPollIntervalMs, 60000)
    CONFIG_PROPERTY(QString, networkPanelView, QStringLiteral("wifi"))
    CONFIG_PROPERTY(QString, wifiDetailsViewMode, QStringLiteral("grid"))       // grid | list
    CONFIG_PROPERTY(QString, bluetoothDetailsViewMode, QStringLiteral("grid"))  // grid | list
    CONFIG_PROPERTY(bool, bluetoothHideUnnamedDevices, false)
    CONFIG_PROPERTY(bool, disableDiscoverability, false)
    CONFIG_PROPERTY(bool, bluetoothAutoConnect, true)

public:
    explicit NetworkConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
