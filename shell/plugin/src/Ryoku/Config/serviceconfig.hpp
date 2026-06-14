#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qvariant.h>
#include <qstringlist.h>

namespace ryoku::config {

using Qt::StringLiterals::operator""_s;

class ServiceConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QString, weatherLocation)
    // Guess based on locale
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheit,
        QLocale().measurementSystem() == QLocale::ImperialUSSystem ||
            QLocale().measurementSystem() == QLocale::ImperialUKSystem)
    // This is always false by default cause apparently even imperial system users don't use it for perf temps?
    CONFIG_GLOBAL_PROPERTY(bool, useFahrenheitPerformance, false)
    // Attempt to guess based on locale
    CONFIG_GLOBAL_PROPERTY(
        bool, useTwelveHourClock, QLocale().timeFormat(QLocale::ShortFormat).toLower().contains(u"a"_s))
    CONFIG_GLOBAL_PROPERTY(QString, gpuType)
    CONFIG_GLOBAL_PROPERTY(int, visualiserBars, 45)
    // cava noise_reduction (0.0-1.0): higher = smoother/slower bars. Lower = snappier.
    CONFIG_GLOBAL_PROPERTY(qreal, visualiserSmoothing, 0.85)
    // cava autosens: auto-scale levels to the signal so quiet audio still moves the bars.
    CONFIG_GLOBAL_PROPERTY(bool, visualiserAutoSens, true)
    CONFIG_GLOBAL_PROPERTY(qreal, audioIncrement, 0.1)
    CONFIG_GLOBAL_PROPERTY(qreal, brightnessIncrement, 0.1)
    // Use DDC/CI (ddcutil) to control external monitor brightness. Off falls back to
    // the internal backlight (brightnessctl).
    CONFIG_GLOBAL_PROPERTY(bool, brightnessDdc, true)
    // Clamp the lowest brightness to 1% so panels that switch off at 0% stay lit.
    CONFIG_GLOBAL_PROPERTY(bool, brightnessEnforceMin, false)
    // Manual output->backlight device overrides set in the brightness card
    // (format: [{ "output": "...", "device": "..." }]). Runtime-discovered
    // mappings are persisted here so user choices survive restarts.
    CONFIG_GLOBAL_PROPERTY(QVariantList, backlightDeviceMappings, {})
    CONFIG_GLOBAL_PROPERTY(qreal, maxVolume, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, smartScheme, true)
    // Mirror the active light/dark theme to the system (GNOME/GTK) toolkit theme.
    // Gates the ryoku-theme-set-gnome call in the ryoku-theme-set pipeline.
    CONFIG_GLOBAL_PROPERTY(bool, syncSystemTheme, true)
    // Recolor GTK/Qt apps (libadwaita gtk.css + kdeglobals) to the active scheme.
    // Gates the ryoku-theme-set-qtgtk apply step in the theme/scheme pipeline.
    CONFIG_GLOBAL_PROPERTY(bool, syncAppColors, true)
    CONFIG_GLOBAL_PROPERTY(QString, defaultPlayer, u"Spotify"_s)
    CONFIG_GLOBAL_PROPERTY(QVariantList, playerAliases,
        { vmap({ { u"from"_s, u"com.github.th_ch.youtube_music"_s }, { u"to"_s, u"YT Music"_s } }) })
    CONFIG_GLOBAL_PROPERTY(bool, showLyrics, false)
    CONFIG_GLOBAL_PROPERTY(QString, lyricsBackend, u"Auto"_s)
    // Bar audio-visualiser widget style + spectrum rendering, plus volume-change
    // feedback (migrated from the legacy settings-gui audio domain).
    CONFIG_GLOBAL_PROPERTY(QString, visualizerType, u"linear"_s)
    CONFIG_GLOBAL_PROPERTY(bool, spectrumMirrored, true)
    CONFIG_GLOBAL_PROPERTY(int, spectrumFrameRate, 30)
    CONFIG_GLOBAL_PROPERTY(QStringList, mprisBlacklist, {})
    CONFIG_GLOBAL_PROPERTY(bool, volumeFeedback, false)
    CONFIG_GLOBAL_PROPERTY(QString, volumeFeedbackSoundFile)

public:
    explicit ServiceConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
