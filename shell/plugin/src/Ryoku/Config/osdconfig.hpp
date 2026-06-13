#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace ryoku::config {

class OsdConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, hideDelay, 2000)
    CONFIG_PROPERTY(bool, enableBrightness, true)
    CONFIG_PROPERTY(bool, enableMicrophone, false)
    CONFIG_PROPERTY(QString, location, QStringLiteral("top_right"))
    CONFIG_PROPERTY(int, autoHideMs, 2000)
    CONFIG_PROPERTY(bool, overlayLayer, true)
    CONFIG_PROPERTY(qreal, backgroundOpacity, 1.0)
    // OSD.Type enum values: Volume=0, InputVolume=1, Brightness=2, LockKey=3
    CONFIG_PROPERTY(QVariantList, enabledTypes, {0, 1, 2})
    CONFIG_PROPERTY(QStringList, monitors, {}) // holds osd visibility per monitor

public:
    explicit OsdConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
