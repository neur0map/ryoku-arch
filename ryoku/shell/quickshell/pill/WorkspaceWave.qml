pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "Singletons"

/**
 * Ryoku's workspace mark: a live orange wave under the clock, the house motion
 * signature (it replaces the inherited soul-bead here). The line carries one
 * segment per occupied workspace on this monitor and grows with the count, so a
 * single workspace is a short wave and the line lengthens as more fill. The
 * focused workspace is not a dot: the wave swells taller and brightens over it
 * (an energy crest) and that live region flows to the new spot when you switch.
 * Centred, so it grows symmetrically; travels continuously while at rest.
 */
Item {
    id: root

    property string screenName: ""
    property real s: 1
    property bool live: true

    readonly property real per: 15 * s          // line length per workspace
    readonly property real wavelength: 9 * s     // ripple period
    readonly property real baseAmp: 1.2 * s      // calm height away from focus
    readonly property real peakAmp: 3 * s        // extra height at the focus crest

    readonly property string activeName: {
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++)
            if (mons[i].name === root.screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.name : "";
        return "";
    }

    readonly property var wsList: {
        const out = [];
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++) {
            const w = all[i];
            if (w && w.id > 0 && w.monitor && w.monitor.name === root.screenName)
                out.push(w);
        }
        out.sort((a, b) => a.id - b.id);
        return out;
    }

    readonly property int activeIndex: {
        for (let i = 0; i < wsList.length; i++)
            if (wsList[i] && wsList[i].name === root.activeName)
                return i;
        return -1;
    }

    // The crest glides to the focused workspace instead of a bead hopping to it.
    property real activeCenter: (Math.max(0, activeIndex) + 0.5) * per
    Behavior on activeCenter { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    implicitWidth: Math.max(per, wsList.length * per)
    implicitHeight: 12 * s

    onWsListChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        property real phase: 0

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const mid = height / 2;
            const k = 6.28318 / root.wavelength;
            const hasActive = root.activeIndex >= 0;
            const cx = root.activeCenter;
            const sigma = root.per * 0.7;

            // Brightness rises toward the focused workspace, dim at the ends.
            ctx.strokeStyle = Qt.alpha(Theme.brand, 0.22);
            if (hasActive && w > 0) {
                const c = Math.min(0.999, Math.max(0.001, cx / w));
                const grad = ctx.createLinearGradient(0, 0, w, 0);
                grad.addColorStop(0, Qt.alpha(Theme.brand, 0.22));
                grad.addColorStop(c, Theme.brand);
                grad.addColorStop(1, Qt.alpha(Theme.brand, 0.22));
                ctx.strokeStyle = grad;
            }

            ctx.lineWidth = 2 * root.s;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            for (let x = 0; x <= w; x += 1.5) {
                const swell = hasActive ? root.peakAmp * Math.exp(-((x - cx) * (x - cx)) / (2 * sigma * sigma)) : 0;
                const a = root.baseAmp + swell;
                const y = mid + a * Math.sin(x * k + phase);
                if (x === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();
        }

        Timer {
            interval: 33
            running: root.visible && root.live
            repeat: true
            onTriggered: {
                canvas.phase = (canvas.phase + 0.11) % 6.28318;
                canvas.requestPaint();
            }
        }
    }
}
