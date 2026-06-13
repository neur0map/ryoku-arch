#pragma once

#include "configobject.hpp"

#include <qvariant.h>

namespace ryoku::config {

// Application theming templates (gtk, qt, terminals, ...) and user-template
// opt-in. Drives the Color Scheme > Templates sub-tab and the theming services
// (AppThemeService / TemplateRegistry / TemplateProcessor). Migrated out of the
// legacy settings-gui store into the typed config (Stage 1).
class TemplatesConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    // Format: [{ "id": "gtk", "enabled": true }, { "id": "qt", "enabled": true }, ...]
    CONFIG_PROPERTY(QVariantList, activeTemplates)
    CONFIG_PROPERTY(bool, enableUserTheming, false)

public:
    explicit TemplatesConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
