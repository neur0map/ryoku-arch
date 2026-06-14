#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace ryoku::config {

using Qt::StringLiterals::operator""_s;

class SessionIcons : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, logout, u"logout"_s)
    CONFIG_PROPERTY(QString, shutdown, u"power_settings_new"_s)
    CONFIG_PROPERTY(QString, hibernate, u"downloading"_s)
    CONFIG_PROPERTY(QString, reboot, u"cached"_s)

public:
    explicit SessionIcons(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class SessionCommands : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QStringList, logout, { u"hyprctl"_s, u"dispatch"_s, u"exit"_s })
    CONFIG_PROPERTY(QStringList, shutdown, { u"systemctl"_s, u"poweroff"_s })
    CONFIG_PROPERTY(QStringList, hibernate, { u"systemctl"_s, u"hibernate"_s })
    CONFIG_PROPERTY(QStringList, reboot, { u"systemctl"_s, u"reboot"_s })

public:
    explicit SessionCommands(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class SessionConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, dragThreshold, 30)
    CONFIG_PROPERTY(bool, vimKeybinds, false)
    CONFIG_PROPERTY(bool, enableCountdown, true)
    CONFIG_PROPERTY(int, countdownDuration, 10000)
    CONFIG_PROPERTY(QString, position, u"center"_s)
    CONFIG_PROPERTY(bool, showHeader, true)
    CONFIG_PROPERTY(bool, showKeybinds, true)
    CONFIG_PROPERTY(bool, largeButtonsStyle, true)
    CONFIG_PROPERTY(QString, largeButtonsLayout, u"single-row"_s)
    CONFIG_PROPERTY(QVariantList, powerOptions,
        {
            vmap({ { u"action"_s, u"lock"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"1"_s } }),
            vmap({ { u"action"_s, u"suspend"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"2"_s } }),
            vmap({ { u"action"_s, u"hibernate"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"3"_s } }),
            vmap({ { u"action"_s, u"reboot"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"4"_s } }),
            vmap({ { u"action"_s, u"logout"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"5"_s } }),
            vmap({ { u"action"_s, u"shutdown"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"6"_s } }),
            vmap({ { u"action"_s, u"rebootToUefi"_s }, { u"enabled"_s, true }, { u"keybind"_s, u"7"_s } }),
        })
    CONFIG_SUBOBJECT(SessionIcons, icons)
    CONFIG_SUBOBJECT(SessionCommands, commands)

public:
    explicit SessionConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_icons(new SessionIcons(this))
        , m_commands(new SessionCommands(this)) {}
};

} // namespace ryoku::config
