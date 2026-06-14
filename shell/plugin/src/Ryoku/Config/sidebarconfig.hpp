#pragma once

#include "configobject.hpp"

namespace ryoku::config {

class SidebarConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, dragThreshold, 80)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(bool, shadow, false)

public:
    explicit SidebarConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
