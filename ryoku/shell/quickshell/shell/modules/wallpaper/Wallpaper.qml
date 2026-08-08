pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

/**
 * Ryoku desktop backdrop: the in-shell wallpaper surface, one instance per
 * monitor (the shell root's per-screen scope constructs it with `screen`).
 *
 * A Background layer window (namespace ryoku-wallpaper, exclusive zone -1, all
 * four edges anchored, no input) draws the single global wallpaper on this
 * output. The ryoku-shell daemon copies the chosen image into a cache file,
 * bumps a revision, and streams {path, revision, fit} on the `wallpaper` topic;
 * the window crossfades (200 ms) to every new revision. This replaces the
 * external wallpaper daemon so wallpaper state, the colour scheme, and the
 * shell all live in one place. Contract 08 sec 1, 2.6, 3.1, 5, 7.
 *
 * The wallpaper switcher (modules/wallpaper/switcher) still sets wallpapers
 * through `ryoku-shell wallpaper set`, which feeds this same topic.
 */
Item {
    id: root

    // The monitor this backdrop paints, supplied by the shell root's per-screen
    // scope (contract 08 sec 7: hotplug adds a monitor -> a new instance here).
    required property var screen

    // The full file url the surface paints, folded from the topic's path +
    // revision so the query busts Qt's pixmap cache on every change (contract 08
    // sec 3.1). "" until the first frame; the window's paper colour shows.
    property string wallpaperUrl: ""
    // content_fit -> Image.fillMode (contract 08 sec 3.3); Cover is the default.
    property string fit: "Cover"
    // The reveal preset for the current revision (null = plain crossfade), streamed
    // on the same wallpaper topic frame and handed to the backdrop's reveal shader.
    property var transition: null

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function apply(line) {
        try {
            const f = JSON.parse(line);
            root.fit = f.fit || "Cover";
            root.transition = f.transition || null; // set before url so onUrlChanged sees the matching preset
            root.wallpaperUrl = (f.path && f.path.length > 0) ? "file://" + f.path + "?v=" + (f.revision || 0) : "";
        } catch (e) {
            // A malformed frame must never blank the desktop; keep the last image.
        }
    }

    // Subscribe once, then stream, mirroring the Tray/Clipboard singletons. A
    // second write would half-close the stream (daemon rule), so nothing else
    // writes here.
    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser {
            onRead: line => root.apply(line)
        }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe wallpaper\n");
                flush();
            } else {
                retry.restart();
            }
        }
    }

    // The daemon may be down when the surface loads (or restart under it); retry
    // quietly so the desktop repaints once it returns.
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected)
            sub.connected = true
    }

    PanelWindow {
        id: win

        screen: root.screen
        color: Theme.paper
        exclusiveZone: -1
        WlrLayershell.namespace: "ryoku-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        // A wallpaper takes no input: clicks pass through to the desktop and
        // the widgets that ride this layer (same as the frame edge surfaces).
        mask: Region {}

        Backdrop {
            anchors.fill: parent
            url: root.wallpaperUrl
            fit: root.fit
            transition: root.transition
        }
    }
}
