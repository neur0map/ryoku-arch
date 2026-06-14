#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

using Qt::StringLiterals::operator""_s;

// Settings-gui panel/widget UI options: settings-panel layout mode, panel
// background opacity, and scrollbar / tooltip / border / translucency toggles.
// Migrated out of the legacy settings-gui store into the typed config (Stage 1).
// The font keys of the legacy `ui` domain stay in the legacy store pending the
// font-system reconciliation (they are a separate cross-layer concern).
class UiConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(bool, tooltipsEnabled, true)
    CONFIG_GLOBAL_PROPERTY(bool, scrollbarAlwaysVisible, true)
    CONFIG_GLOBAL_PROPERTY(bool, boxBorderEnabled, false)
    CONFIG_GLOBAL_PROPERTY(qreal, panelBackgroundOpacity, 0.93)
    CONFIG_GLOBAL_PROPERTY(bool, translucentWidgets, false)
    CONFIG_GLOBAL_PROPERTY(bool, panelsAttachedToBar, true)
    // "centered", "attached", or "window"
    CONFIG_GLOBAL_PROPERTY(QString, settingsPanelMode, u"attached"_s)
    CONFIG_GLOBAL_PROPERTY(bool, settingsPanelSideBarCardStyle, false)

public:
    explicit UiConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
