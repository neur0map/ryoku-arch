pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons as Ui

// Thin reader of the daemon palette for the visualiser. The theme daemon is the
// sole author of colour in Ryoku: a fixed named theme publishes its palette into
// shell.json's themePalette key, and follow-the-wallpaper mode writes the live
// palette to ~/.cache/ryoku/colors.json. This reads both and resolves each
// role exactly the way the pill's Theme does -- a named scheme wins, then the
// live wallpaper palette, then the compiled default -- so the spectrum retints
// on ANY scheme change, static named theme or wallpaper-follow. The compiled
// defaults (Everforest) only paint the first frames before the daemon's first
// write.
//
// The spectrum has no panel under it, so the resolved roles are seeds, not
// paint: Ink turns them into tones that clear the wallpaper behind the bars.
Singleton {
    id: root

    // The follow-the-wallpaper master (theme.json, the single colour source the
    // daemon and window borders also read).
    property bool matchWallpaper: true

    // The static named scheme's palette (shell.json themePalette; null for the
    // dynamic Default/Wallpaper variants) and the live wallpaper roles
    // (colors.json). Both are parsed straight from the file text: half the role
    // names start with "on", which JsonAdapter's signal-handler grammar rejects,
    // a removed themePalette key only reads as absent from raw text, and a bare
    // JsonAdapter does not repopulate reliably for a lazily-created singleton.
    property var namedScheme: null
    property var wall: ({})

    // A palette value is only usable when it is a non-empty hex string; a null,
    // missing or half-written role falls through to the next layer, so a partial
    // colors.json (mid-write) or a scheme missing a role never paints black.
    function usable(v) { return typeof v === "string" && v.length > 0; }

    // Resolve one role through the layer chain: a selected named scheme wins,
    // then the live wallpaper palette while Match wallpaper is on, then the base.
    function role(key, base) {
        if (namedScheme && usable(namedScheme[key]))
            return namedScheme[key];
        if (matchWallpaper && usable(wall[key]))
            return wall[key];
        return base;
    }

    // Seed colours, not paint: a role is a tone chosen to read on a surface, and
    // consumed as-is they collapse with the scheme -- a light high-contrast
    // palette puts every accent near black, hence the black spectrum.
    readonly property color accent:    role("primary",   "#a7c080")
    readonly property color secondary: role("secondary", "#7fbbb3")
    // The sweep is ramp names, and only the wallpaper's own hue: matugen's
    // primary and secondary both derive from the source colour, so every band
    // reads as the picture behind it. tertiary (a +60 hue rotation) and error
    // (a fixed red) are Material accents the wallpaper itself never contains, so
    // a spectrum built from them paints colours nowhere in the picture. `seeds`
    // are the matching roles, re-lit when no ramps are published.
    readonly property var ramps: ["secondary", "primary", "primary", "primary", "primary", "secondary"]
    readonly property var seeds: [secondary, accent, accent, accent, accent, secondary]

    // 45 L* (~3.7:1) reads as a lit bar; the 55 a run of text needs turns a band
    // of saturated colour neon.
    readonly property int barDelta:  45
    readonly property int leadDelta: 55

    // The lead accent: the floor glow, the oscilloscope filament, the polar ring.
    function accentOn(bgL, dir) {
        return Ui.Ink.accentOver("primary", root.accent, bgL, root.leadDelta, dir);
    }

    // The sweep at t in [0,1]: both neighbouring ramps sampled at the
    // background's tone, then interpolated, so the blend cannot dip mid-band.
    function colorAt(t, bgL, dir) {
        var n = root.ramps.length;
        var x = Math.max(0, Math.min(0.999999, t)) * (n - 1);
        var i = Math.floor(x);
        var f = x - i;
        var a = root.stopAt(i, bgL, dir);
        var b = root.stopAt(Math.min(n - 1, i + 1), bgL, dir);
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, 1);
    }

    function stopAt(i, bgL, dir) {
        return Ui.Ink.accentOver(root.ramps[i], root.seeds[i], bgL, root.barDelta, dir);
    }

    // Ink reaches the renderer through here. A file that imports the module
    // loses the local Scheme singleton to QtQuick's own Scheme type, so this
    // is the one place in the config that imports it.
    readonly property var inkTones: Ui.Ink.tones
    readonly property real wallLstar: Ui.Ink.wallLstar
    function lstarAt(nx, ny, nw, nh) { return Ui.Ink.lstarAt(nx, ny, nw, nh); }
    function side(bgL) { return Ui.Ink.side(bgL); }

    function refreshWall() {
        try {
            const t = wallFile.text();
            root.wall = t && t.length ? (JSON.parse(t) || {}) : {};
        } catch (e) {
            root.wall = {};
        }
    }
    function refreshNamed() {
        var pal = null;
        try {
            const t = shellFile.text();
            if (t) {
                const o = JSON.parse(t);
                if (o && typeof o.themePalette === "object" && o.themePalette !== null)
                    pal = o.themePalette;
            }
        } catch (e) {
            pal = null;
        }
        root.namedScheme = pal;
    }
    function refreshMatch() {
        try {
            const t = themeFile.text();
            const o = t ? JSON.parse(t) : null;
            // Default ON when theme.json is absent or omits the key, matching
            // services/Config.qml and the daemon's matchWallpaperOn: a fresh box
            // follows the wallpaper. Only an explicit false locks it off.
            root.matchWallpaper = (o && typeof o.followWallpaper === "boolean") ? o.followWallpaper : true;
        } catch (e) {
            root.matchWallpaper = true;
        }
    }

    FileView {
        id: wallFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshWall()
    }
    FileView {
        id: shellFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshNamed()
    }
    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshMatch()
    }

    Component.onCompleted: {
        refreshWall();
        refreshNamed();
        refreshMatch();
    }
}
