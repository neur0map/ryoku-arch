pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import shell.services
import "../../components"

// One OSD: an icon, a value bar and a percentage, for volume-out, mic-in, or
// brightness. The content itself does not animate; the hosting window fades and
// slides the whole pill up as `flashing` turns true, holds it for 1000 ms, then
// eases it back down. A re-trigger restarts that hold. Volume and mic read
// PipeWire; brightness reads the daemon `osd` feed.
//
// Startup grace (contract 12 sec 4): a fresh shell reads its initial volume,
// mic and brightness as it connects, firing change signals that are not user
// actions. The OSD arms a short settle once its source first appears and
// swallows every flash until then, so it never pops for those login syncs while
// the first real change after arming shows at once.
Item {
    id: root

    property string kind: "volume"          // volume | mic | brightness
    property bool suppressed: false

    readonly property bool isVolume: kind === "volume"
    readonly property bool isMic: kind === "mic"
    readonly property bool isBrightness: kind === "brightness"

    // --- value and mute per kind -------------------------------------------
    readonly property var device: isVolume ? Pipewire.defaultAudioSink
        : isMic ? Pipewire.defaultAudioSource : null
    readonly property var audio: (device && device.audio) ? device.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property real value: isBrightness
        ? OsdFeed.brightness
        : (audio ? Math.max(0, Math.min(1, audio.volume)) : 0)

    // Bucket -> freedesktop symbolic glyph, muted winning, on the reference
    // thresholds (contract 12 sec 3): audio >66 high, >33 medium, >0 low, else
    // muted; mic identical on the microphone-sensitivity set; brightness >66
    // high, >33 medium, else low. Names are the shell's own glyph set
    // (framebars/icons), never a font.
    readonly property string iconName: {
        var pct = Math.round(value * 100);
        if (isBrightness)
            return pct > 66 ? "brightness-high" : pct > 33 ? "brightness-medium" : "brightness-low";
        if (isMic)
            return (muted || pct <= 0) ? "microphone-sensitivity-muted"
                : pct > 66 ? "microphone-sensitivity-high"
                : pct > 33 ? "microphone-sensitivity-medium"
                : "microphone-sensitivity-low";
        return (muted || pct <= 0) ? "audio-volume-muted"
            : pct > 66 ? "audio-volume-high"
            : pct > 33 ? "audio-volume-medium"
            : "audio-volume-low";
    }

    // --- flash state machine ------------------------------------------------
    property bool flashing: false

    // Startup grace: swallow flashes until a short settle after the source first
    // appears (see the note above). A fixed count gate ate real presses whenever
    // the login sync count came up short.
    property bool armed: false
    readonly property var gateSource: root.isBrightness ? OsdFeed : root.audio
    onGateSourceChanged: if (root.gateSource && !root.armed && !armTimer.running) armTimer.restart()
    Component.onCompleted: if (root.gateSource && !armTimer.running) armTimer.restart()
    Timer { id: armTimer; interval: 700; onTriggered: root.armed = true }

    function flash() {
        if (suppressed || !root.armed)
            return;
        flashing = true;
        hideTimer.restart();
    }

    onSuppressedChanged: if (suppressed) {
        hideTimer.stop();
        flashing = false;
    }

    // The 1000 ms auto-hide hold, restarted on every value change.
    Timer {
        id: hideTimer
        interval: Motion.osdHide
        onTriggered: root.flashing = false
    }

    // Audio triggers: any volume or mute change on the tracked default device.
    PwObjectTracker { objects: root.device ? [root.device] : [] }
    Connections {
        target: root.audio
        function onVolumesChanged() { root.flash(); }
        function onMutedChanged() { root.flash(); }
    }
    // Brightness trigger: the daemon feed bumps its sequence on each change.
    Connections {
        target: root.isBrightness ? OsdFeed : null
        function onBrightnessSeqChanged() { root.flash(); }
    }

    // --- content: icon + value bar + percentage (contract 12 sec 2) ---------
    // Fixed logical px: inner box width 250, spacing 16, icon 40, bar height 6,
    // percentage readout 46. No monitor or font scaling; the OSD is a
    // fixed-size readout the hosting window animates as one pill.
    implicitWidth: 250
    implicitHeight: 40

    SymbolIcon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: root.iconName
        size: 40
        color: Theme.onSurface
    }

    // Value bar: trough (surfaceContainerLow) + fill (secondary), min-height 8,
    // radius 8, thumb hidden. The live-reference palette resolves these tokens to
    // trough #1a1d1f and fill #a8adb0 under the Solitude defaults.
    Rectangle {
        id: trough
        anchors.left: glyph.right
        anchors.leftMargin: 16
        anchors.right: pct.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: Theme.radiusWidget
        color: Theme.surfaceContainerLow

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.value
            radius: parent.radius
            color: Theme.secondary
            visible: width > 0
        }
    }

    // Percentage readout (mono, the pill's data face): the same clamped 0..1
    // `value` the bar fills to, so the number and the bar never disagree. Fixed
    // width, right-aligned, so the bar edge holds still as the digit count
    // changes (5% -> 100%). Volume is capped at 100% upstream (wpctl -l 1).
    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: Theme.onSurface
        font.family: Theme.mono
        font.pixelSize: Theme.fontMd
    }
}
