#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// Night light (wlsunset) control. Enforced live by
// shell/settingsgui/Services/Location/NightLightService.qml (schedule/forced
// modes + manual times). Migrated out of the legacy settings-gui store into the
// typed config (Stage 1).
class NightLightConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, forced, false)
    CONFIG_PROPERTY(bool, autoSchedule, true)
    CONFIG_PROPERTY(QString, nightTemp, QStringLiteral("4000"))
    CONFIG_PROPERTY(QString, dayTemp, QStringLiteral("6500"))
    CONFIG_PROPERTY(QString, manualSunrise, QStringLiteral("06:30"))
    CONFIG_PROPERTY(QString, manualSunset, QStringLiteral("18:30"))

public:
    explicit NightLightConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
