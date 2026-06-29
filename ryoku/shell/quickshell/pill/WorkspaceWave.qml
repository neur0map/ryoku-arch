pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "Singletons"

/**
 * ryoku's workspace mark: an orange wave under the clock (the house signature,
 * replacing the inherited soul-bead here). one segment per occupied workspace
 * on this monitor, so the line grows with the count; the focused workspace is
 * a taller, brighter crest that glides to the new spot on switch.
 *
 * Static Canvas -- repaints only on a workspace/focus/size change, and only
 * while the host pill is shown. The old 30fps idle ripple repainted the Canvas
 * forever and leaked memory (the idle-Canvas leak already fixed in WaveMeter
 * and the visualiser); the crest still glides on switch, it just no longer
 * shimmers at rest, so a hidden pill costs nothing.
 */
Item {
    id: root

    property string screenName: ""
    property real s: 1
    // set by the host pill: true while the pill is actually shown. hidden ->
    // the wave skips repaints, so an auto-hidden pill costs nothing.
    property bool live: true

    readonly property real per: 15 * s          // line per ws
    readonly property real wavelength: 9 * s     // ripple period
    readonly property real baseAmp: 1.2 * s      // calm height away from focus
    readonly property real peakAmp: 3 * s        // extra height at the crest

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

    // crest glides to the focused ws instead of a bead hopping to it.
    property real activeCenter: (Math.max(0, activeIndex) + 0.5) * per
    Behavior on activeCenter { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    implicitWidth: Math.max(per, wsList.length * per)
    implicitHeight: 12 * s

    // repaint only on change, and only while shown: a static wave never accrues
    // the continuous-Canvas leak, and a hidden pill paints nothing.
    function repaint() { if (root.visible && root.live) canvas.requestPaint(); }
    onWsListChanged: root.repaint()
    onActiveCenterChanged: root.repaint()
    onVisibleChanged: root.repaint()
    onLiveChanged: root.repaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: root.repaint()
        onHeightChanged: root.repaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const mid = height / 2;
            const k = 6.28318 / root.wavelength;
            const hasActive = root.activeIndex >= 0;
            const cx = root.activeCenter;
            const sigma = root.per * 0.7;

            // brightness rises toward focus, dim at the ends.
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
                const y = mid + a * Math.sin(x * k);
                if (x === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }
}
