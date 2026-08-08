pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What colour reads on THIS background?
//
// A Material role already answers that for a panel: onSurface reads on surface.
// It answers nothing for a surface that floats on the wallpaper -- the desktop
// clock, the spectrum, a widget with its backing set to none. Handed onSurface
// they paint the tone Material chose for a panel that is not there, which on a
// light scheme is near-black.
//
// Two answers, for the two kinds of background: `legible` corrects a role
// against a colour you have (a panel, a translucent frame over a wallpaper
// tone); `ramped` picks a tone off matugen's own tonal ramps against the
// wallpaper luminance the daemon publishes. Both work in CIE L*, where a tone
// distance is a contrast budget: 40 apart clears 3:1, 50 apart clears 4.5:1.
Singleton {
    id: ink

    // ── contrast maths ───────────────────────────────────────────────────────

    function relLum(c) {
        function lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // WCAG contrast ratio between two opaque colours (1..21).
    function ratio(a, b) {
        const la = ink.relLum(a), lb = ink.relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Composite over an opaque background, so an alpha-tinted fill resolves to
    // the flat tone the eye actually reads.
    function blend(over, base) {
        const a = over.a;
        return Qt.rgba(over.r * a + base.r * (1 - a),
                       over.g * a + base.g * (1 - a),
                       over.b * a + base.b * (1 - a), 1);
    }

    function lstar(c) { return ink.lstarFromY(ink.relLum(c)); }

    function lstarFromY(y) {
        return y <= 216 / 24389 ? y * 24389 / 27 : Math.cbrt(y) * 116 - 16;
    }

    function yFromLstar(l) {
        return l > 8 ? Math.pow((l + 16) / 116, 3) : l * 27 / 24389;
    }

    // A translucent plate laid over a background known only by its tone: what a
    // card or glass backing does to the wallpaper measured under it.
    function overLstar(bgL, plate) {
        return ink.lstarFromY(ink.relLum(plate) * plate.a + ink.yFromLstar(bgL) * (1 - plate.a));
    }

    // A hex string as a colour. QML converts one on assignment, but a caller
    // interpolating a gradient needs the channels.
    function hex(h) {
        if (typeof h !== "string" || h.length < 7)
            return Qt.rgba(0, 0, 0, 1);
        return Qt.rgba(parseInt(h.substr(1, 2), 16) / 255,
                       parseInt(h.substr(3, 2), 16) / 255,
                       parseInt(h.substr(5, 2), 16) / 255, 1);
    }

    // Keep `role` when it already clears `minRatio` against `bg` -- the common
    // case, so a sound palette renders exactly as before -- else walk it toward
    // the pole `bg` needs until it does. Hue survives the first steps; only a
    // pathological pairing reaches a near-neutral, and black or white clears
    // 4.58:1 against anything, so the walk always lands.
    function legible(bg, role, minRatio) {
        const target = (minRatio === undefined) ? 4.5 : minRatio;
        if (ink.ratio(role, bg) >= target)
            return role;
        const pole = ink.relLum(bg) > 0.179 ? 0 : 1;
        let r = role.r, g = role.g, b = role.b;
        for (let i = 0; i < 12; ++i) {
            r += (pole - r) * 0.18;
            g += (pole - g) * 0.18;
            b += (pole - b) * 0.18;
            const c = Qt.rgba(r, g, b, 1);
            if (ink.ratio(c, bg) >= target)
                return c;
        }
        return Qt.rgba(pole, pole, pole, 1);
    }

    // ── the wallpaper as a background ────────────────────────────────────────

    // The daemon's luminance map: L* per cell, row-major from the top-left, plus
    // the frame mean. Parsed from the file text; JsonAdapter does not reliably
    // repopulate a lazily-created singleton.
    property var wall: ({})

    // 50 before the first write, so neither pole is assumed.
    readonly property real wallLstar: (typeof ink.wall.lstar === "number") ? ink.wall.lstar : 50

    // Mean L* under a rect in screen-normalised coordinates. Cells average
    // whole, so a rect spanning a bright sky and a dark tree resolves to the mid
    // tone that has to satisfy both.
    //
    // ponytail: assumes the picture fills the screen, so a screen fraction is an
    // image fraction. A wallpaper of another aspect is cropped, which at eight
    // cells across is under one cell of error. Publish the aspect and map
    // through the crop if that ever shows.
    function lstarAt(nx, ny, nw, nh) {
        const g = ink.wall.grid;
        const cols = ink.wall.cols | 0;
        const rows = ink.wall.rows | 0;
        if (!g || cols <= 0 || rows <= 0 || g.length < cols * rows)
            return ink.wallLstar;
        const x0 = ink.cell(nx, cols), x1 = Math.max(x0, ink.cell(nx + nw, cols));
        const y0 = ink.cell(ny, rows), y1 = Math.max(y0, ink.cell(ny + nh, rows));
        let sum = 0, n = 0;
        for (let y = y0; y <= y1; ++y) {
            for (let x = x0; x <= x1; ++x) {
                sum += g[y * cols + x];
                ++n;
            }
        }
        return n > 0 ? sum / n : ink.wallLstar;
    }

    // Clamped so an off-screen or mid-drag rect still samples a real cell.
    function cell(v, n) { return Math.max(0, Math.min(n - 1, Math.floor(v * n))); }

    // ── matugen's tonal ramps ────────────────────────────────────────────────

    // ramp -> tone -> hex. Empty under a fixed named theme (a catalog theme has
    // no ramps) and before the first write.
    property var tones: ({})

    // Which way to move off a background: darker on a light one, lighter on a
    // dark one. Fix it once per field. Deciding it per element makes neighbours
    // over a mid-tone picture flip between near-white and near-black, since a
    // background either side of 50 is a coin toss.
    function side(bgL) { return bgL >= 50 ? -1 : 1; }

    function toneOf(bgL, delta, dir, lo, hi) {
        return Math.max(lo, Math.min(hi, bgL + dir * delta));
    }

    // Nearest published tone, or "" with no ramps. matugen emits a fixed set of
    // stops, so the snap moves a couple of L* and never crosses the background.
    function tone(ramp, t) {
        const r = ink.tones[ramp];
        if (!r)
            return "";
        let best = "", bestD = Infinity;
        for (const k in r) {
            const d = Math.abs(Number(k) - t);
            if (d < bestD) {
                bestD = d;
                best = r[k];
            }
        }
        return best;
    }

    // Ink for a run of text over `bgL`: the full tone range, since near-black
    // and near-white are exactly what text wants.
    function inkOver(ramp, seed, bgL, delta) {
        return ink.at(ramp, seed, ink.toneOf(bgL, delta, ink.side(bgL), 0, 100));
    }

    // An accent over `bgL`, moving in `dir`. Held to where the ramps still carry
    // chroma: below 30 and above 88 every hue reads as black or white, so a
    // mid-tone wallpaper would otherwise turn a spectrum into bars of soot.
    function accentOver(ramp, seed, bgL, delta, dir) {
        return ink.at(ramp, seed, ink.toneOf(bgL, delta, dir, 30, 88));
    }

    // `ramp` at `t`, or `seed` (the caller's own role, so the theme's hue
    // survives) re-lit to the same tone when no ramps are published. HSL
    // lightness is not L*, but it lands on the right side of the background.
    function at(ramp, seed, t) {
        const h = ink.tone(ramp, t);
        return h.length > 0 ? ink.hex(h) : Qt.hsla(seed.hslHue, seed.hslSaturation, t / 100, 1);
    }

    // ── sources ──────────────────────────────────────────────────────────────

    function refreshWall() {
        try {
            const t = wallFile.text();
            ink.wall = t && t.length ? (JSON.parse(t) || {}) : {};
        } catch (e) {
            ink.wall = {};
        }
    }
    function refreshTones() {
        try {
            const t = tonesFile.text();
            ink.tones = t && t.length ? (JSON.parse(t) || {}) : {};
        } catch (e) {
            ink.tones = {};
        }
    }

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/"

    FileView {
        id: wallFile
        path: ink.cacheDir + "wallpaper-tone.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: ink.refreshWall()
    }
    FileView {
        id: tonesFile
        path: ink.cacheDir + "tones.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: ink.refreshTones()
    }

    Component.onCompleted: {
        refreshWall();
        refreshTones();
    }
}
