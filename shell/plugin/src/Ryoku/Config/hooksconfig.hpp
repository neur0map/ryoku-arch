#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// User-defined hook commands executed on system events (wallpaper change, dark
// mode toggle, screen lock/unlock, performance mode, color generation, startup
// and session actions). Driven by HooksService, which runs each command via the
// shell. Migrated out of the legacy settings-gui store into the typed config
// (Stage 1).
class HooksConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(QString, wallpaperChange, QStringLiteral(""))
    CONFIG_PROPERTY(QString, darkModeChange, QStringLiteral(""))
    CONFIG_PROPERTY(QString, screenLock, QStringLiteral(""))
    CONFIG_PROPERTY(QString, screenUnlock, QStringLiteral(""))
    CONFIG_PROPERTY(QString, performanceModeEnabled, QStringLiteral(""))
    CONFIG_PROPERTY(QString, performanceModeDisabled, QStringLiteral(""))
    CONFIG_PROPERTY(QString, startup, QStringLiteral(""))
    CONFIG_PROPERTY(QString, session, QStringLiteral(""))
    CONFIG_PROPERTY(QString, colorGeneration, QStringLiteral(""))

public:
    explicit HooksConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
