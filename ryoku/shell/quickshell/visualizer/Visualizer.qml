pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * The desktop spectrum. A full-width cava analyser rising from the bottom of the
 * wallpaper: every band is a vivified wallust colour (so the whole sweep retunes
 * per wallpaper), with a soft bloom behind it and a fading reflection below the
 * baseline. It blooms to life while audio plays and settles to a calm breathing
 * line when the system is silent, so the desktop is never dead but never noisy.
 */
Item {
    id: root

    readonly property int bands: Spectrum.bars
    readonly property real ui: Math.max(0.75, height / 1080)

    // Vertical budget: the tallest a bar can reach, the baseline it grows from,
    // and the reflection band beneath it.
    readonly property real reflectionH: Math.round(height * 0.10)
    readonly property real maxBarH: Math.round(height * 0.42)
    readonly property real baseY: height - reflectionH
    readonly property real slotW: bands > 0 ? width / bands : width
    readonly property real barW: Math.max(2, slotW * 0.58)

    // "Playing" with hysteresis so the bloom does not flicker on quiet passages.
    // Spectrum.energy settles to 0 when cava stops emitting.
    property bool playing: false
    readonly property real liveEnergy: Spectrum.energy
    onLiveEnergyChanged: {
        if (liveEnergy > 0.05)
            playing = true;
        else if (liveEnergy < 0.02)
            playing = false;
    }

    // Slow phase for the resting wave, only while idle.
    property real idlePhase: 0
    NumberAnimation on idlePhase {
        from: 0
        to: Math.PI * 2
        duration: 6000
        loops: Animation.Infinite
        running: !root.playing
    }

    // Per-band level: the real spectrum (gamma-lifted so quiet detail shows and
    // peaks still tower) while playing, a gentle travelling wave at rest.
    function levelAt(i) {
        if (root.playing) {
            var l = Spectrum.levels;
            var v = (l && i < l.length) ? l[i] : 0;
            return Math.pow(v, 0.72);
        }
        return 0.016 + 0.022 * (0.5 + 0.5 * Math.sin(i * 0.4 + root.idlePhase));
    }

    function bandColor(i) {
        return Wallust.colorAt(root.bands > 1 ? i / (root.bands - 1) : 0.5);
    }

    // Ambient floor glow grounding the bars; warms with overall energy.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.maxBarH * 0.7
        opacity: 0.08 + 0.32 * Spectrum.energy
        Behavior on opacity { NumberAnimation { duration: 220 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(Wallust.accent, 0.5) }
        }
    }

    // Soft bloom: a blurred copy of the crisp bars sitting just behind them.
    MultiEffect {
        source: bars
        x: bars.x
        y: bars.y
        width: bars.width
        height: bars.height
        z: 0
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        autoPaddingEnabled: true
        opacity: root.playing ? 0.6 : 0.32
        Behavior on opacity { NumberAnimation { duration: 320 } }
    }

    // Reflection: the bars mirrored below the baseline, each fading downward.
    Item {
        id: reflection
        x: 0
        y: root.baseY
        width: root.width
        height: root.reflectionH
        opacity: 0.45

        Repeater {
            model: root.bands
            Rectangle {
                required property int index
                readonly property color c: root.bandColor(index)
                width: root.barW
                x: index * root.slotW + (root.slotW - root.barW) / 2
                y: 0
                height: Math.min(root.reflectionH, Math.max(2, root.maxBarH * root.levelAt(index) * 0.5))
                radius: width / 2
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(c, 0.32) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }
        }
    }

    // The crisp bars rising from the baseline.
    Item {
        id: bars
        x: 0
        y: 0
        width: root.width
        height: root.baseY
        z: 1

        Repeater {
            model: root.bands
            Rectangle {
                required property int index
                readonly property color c: root.bandColor(index)
                readonly property real h: Math.max(2 * root.ui, root.maxBarH * root.levelAt(index))
                width: root.barW
                x: index * root.slotW + (root.slotW - root.barW) / 2
                height: h
                y: root.baseY - h
                radius: width / 2
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(c, 1.25) }
                    GradientStop { position: 0.55; color: c }
                    GradientStop { position: 1.0; color: Qt.alpha(c, 0.35) }
                }
                Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }
        }
    }
}
