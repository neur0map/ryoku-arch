#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// Clipboard history management (cliphist / clipboard.db). Enforced live by
// shell/modules/ClipboardMaintenance.qml (size trim + scheduled wipe). Migrated
// out of the legacy settings-gui store into the typed config (Stage 1a).
class ClipboardConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, maxEntries, 100)
    CONFIG_PROPERTY(QString, autoCleanup, QStringLiteral("off")) // off | daily | weekly

public:
    explicit ClipboardConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
