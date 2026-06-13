#pragma once

#include "configobject.hpp"

namespace ryoku::config {

// Plugin-manager preferences: auto-update installed plugins and notify when
// updates are available. Migrated out of the legacy settings-gui store (Stage 1).
class PluginsConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, autoUpdate, false)
    CONFIG_PROPERTY(bool, notifyUpdates, true)

public:
    explicit PluginsConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
