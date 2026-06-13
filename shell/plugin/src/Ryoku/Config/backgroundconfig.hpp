#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qvariant.h>

namespace ryoku::config {

class DesktopClockBackground : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)

public:
    explicit DesktopClockBackground(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockShadow : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)

public:
    explicit DesktopClockShadow(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClock : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom-right"))
    CONFIG_PROPERTY(QString, style, QStringLiteral("modern"))
    CONFIG_PROPERTY(bool, invertColors, false)
    // Desktop-widget framework: when freePosition is true the clock uses the
    // dragged x/y; otherwise it falls back to the anchored `position` (legacy).
    CONFIG_PROPERTY(bool, freePosition, false)
    CONFIG_PROPERTY(qreal, x, 0)
    CONFIG_PROPERTY(qreal, y, 0)
    CONFIG_PROPERTY(bool, locked, false)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)

public:
    explicit DesktopClock(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_background(new DesktopClockBackground(this))
        , m_shadow(new DesktopClockShadow(this)) {}
};

// Common per-widget framework config (position/scale/lock) shared by every
// draggable desktop widget except the clock (which carries its own render
// settings on DesktopClock above).
class DesktopWidgetConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, freePosition, false)
    CONFIG_PROPERTY(QString, position, QStringLiteral("center"))
    CONFIG_PROPERTY(qreal, x, 0)
    CONFIG_PROPERTY(qreal, y, 0)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(bool, locked, false)
    CONFIG_PROPERTY(bool, background, true)
    CONFIG_PROPERTY(QString, style, QStringLiteral("default"))

public:
    explicit DesktopWidgetConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BackgroundWidgets : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, gridSize, 16)
    CONFIG_PROPERTY(bool, snap, true)
    CONFIG_SUBOBJECT(DesktopWidgetConfig, media)
    CONFIG_SUBOBJECT(DesktopWidgetConfig, resources)
    CONFIG_SUBOBJECT(DesktopWidgetConfig, weather)
    CONFIG_SUBOBJECT(DesktopWidgetConfig, battery)

public:
    explicit BackgroundWidgets(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_media(new DesktopWidgetConfig(this))
        , m_resources(new DesktopWidgetConfig(this))
        , m_weather(new DesktopWidgetConfig(this))
        , m_battery(new DesktopWidgetConfig(this)) {}
};

class BackgroundVisualiser : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(bool, blur, false)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(qreal, spacing, 1)
    // Render style for VisualiserBars: "bars" (symmetric bottom bars), "mirrored"
    // (center-out), or "dots".
    CONFIG_PROPERTY(QString, style, QStringLiteral("bars"))

public:
    explicit BackgroundVisualiser(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

// Desktop-widget placement layer: master enable, overview, grid snapping and the
// per-monitor widget layout. Migrated out of the legacy settings-gui store (Stage 1).
class DesktopWidgetsLayout : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, overviewEnabled, true)
    CONFIG_PROPERTY(bool, gridSnap, false)
    CONFIG_PROPERTY(bool, gridSnapScale, false)
    CONFIG_PROPERTY(QVariantList, monitorWidgets, {})

public:
    explicit DesktopWidgetsLayout(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BackgroundConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)
    CONFIG_SUBOBJECT(BackgroundWidgets, widgets)
    CONFIG_SUBOBJECT(DesktopWidgetsLayout, desktopWidgets)

public:
    explicit BackgroundConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_desktopClock(new DesktopClock(this))
        , m_visualiser(new BackgroundVisualiser(this))
        , m_widgets(new BackgroundWidgets(this))
        , m_desktopWidgets(new DesktopWidgetsLayout(this)) {}
};

} // namespace ryoku::config
