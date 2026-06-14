#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qvariant.h>

namespace ryoku::config {

// Control-center layout: panel position, the monitored disk, the left/right
// quick-shortcut rows and the ordered card list. Migrated out of the legacy
// settings-gui store into the typed config (Stage 1).
class ControlCenterShortcuts : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QVariantList, left,
        { vmap({ { QStringLiteral("id"), QStringLiteral("Network") } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("Bluetooth") } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("WallpaperSelector") } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("PerformanceMode") } }) })
    CONFIG_PROPERTY(QVariantList, right,
        { vmap({ { QStringLiteral("id"), QStringLiteral("Notifications") } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("PowerProfile") } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("KeepAwake") } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("NightLight") } }) })

public:
    explicit ControlCenterShortcuts(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class ControlCenterConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, position, QStringLiteral("close_to_bar_button"))
    CONFIG_PROPERTY(QString, diskPath, QStringLiteral("/"))
    CONFIG_SUBOBJECT(ControlCenterShortcuts, shortcuts)
    CONFIG_PROPERTY(QVariantList, cards,
        { vmap({ { QStringLiteral("id"), QStringLiteral("profile-card") }, { QStringLiteral("enabled"), true } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("shortcuts-card") }, { QStringLiteral("enabled"), true } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("audio-card") }, { QStringLiteral("enabled"), true } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("brightness-card") }, { QStringLiteral("enabled"), false } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("weather-card") }, { QStringLiteral("enabled"), true } }),
            vmap({ { QStringLiteral("id"), QStringLiteral("media-sysmon-card") }, { QStringLiteral("enabled"), true } }) })

public:
    explicit ControlCenterConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_shortcuts(new ControlCenterShortcuts(this)) {}
};

} // namespace ryoku::config
