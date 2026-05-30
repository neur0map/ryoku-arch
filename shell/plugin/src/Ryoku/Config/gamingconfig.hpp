#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

using Qt::StringLiterals::operator""_s;

class CrosshairConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, style, u"dot"_s)
    CONFIG_PROPERTY(int, size, 6)
    CONFIG_PROPERTY(int, lineLength, 10)
    CONFIG_PROPERTY(int, lineThickness, 2)
    CONFIG_PROPERTY(int, gap, 4)
    CONFIG_PROPERTY(QString, color, u"#00ff00"_s)
    CONFIG_PROPERTY(bool, outline, true)
    CONFIG_PROPERTY(QString, outlineColor, u"#000000"_s)

public:
    explicit CrosshairConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GamingConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_SUBOBJECT(CrosshairConfig, crosshair)

public:
    explicit GamingConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_crosshair(new CrosshairConfig(this)) {}
};

} // namespace ryoku::config
