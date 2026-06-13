#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// Color scheme / theming preferences. Drives dark mode, wallpaper-based color
// extraction (matugen), predefined scheme selection, generation method and the
// dark/light scheduling. Consumed by the theming services (AppThemeService,
// ColorSchemeService, TemplateProcessor) and the appearance/wallpaper panels.
// Migrated out of the legacy settings-gui store into the typed config (Stage 1).
class ColorSchemesConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, useWallpaperColors, false)
    CONFIG_PROPERTY(QString, predefinedScheme, QStringLiteral("Ryoku (default)"))
    CONFIG_PROPERTY(bool, darkMode, true)
    CONFIG_PROPERTY(QString, schedulingMode, QStringLiteral("off"))
    CONFIG_PROPERTY(QString, manualSunrise, QStringLiteral("06:30"))
    CONFIG_PROPERTY(QString, manualSunset, QStringLiteral("18:30"))
    CONFIG_PROPERTY(QString, generationMethod, QStringLiteral("tonal-spot"))
    CONFIG_PROPERTY(QString, monitorForColors, QStringLiteral(""))
    CONFIG_PROPERTY(bool, syncGsettings, true)

public:
    explicit ColorSchemesConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
