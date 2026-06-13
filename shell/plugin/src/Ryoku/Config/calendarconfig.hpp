#pragma once

#include "configobject.hpp"

#include <qvariant.h>

namespace ryoku::config {

// Calendar drawer card layout (header / month / weather cards and ordering).
// Drives the Calendar settings tab and the calendar dashboard widget. Migrated
// out of the legacy settings-gui store into the typed config (Stage 1).
class CalendarConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    // Format: [{ "id": "calendar-header-card", "enabled": true }, ...]
    CONFIG_PROPERTY(QVariantList, cards)

public:
    explicit CalendarConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
