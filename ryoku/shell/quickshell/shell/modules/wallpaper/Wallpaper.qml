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
 * four edges anchored, no input) draws this output's wallpaper. The ryoku-shell
 * daemon copies each chosen image into a cache file, bumps a revision, and
 * streams one coalesced full-state frame on the `wallpaper` topic:
 * {default: ENTRY, outputs: {connector: ENTRY}}. This surface applies
 * outputs[screen.name] or, absent an override, default -- so a broadcast set and
 * a per-monitor set feed the same topic. The window crossfades (200 ms) to every
 * new revision. This replaces the external wallpaper daemon so wallpaper state,
 * the colour scheme, and the shell all live in one place. Contract 08 sec 1, 2.6,
 * 3.1, 5, 7.
 *
 * The wallpaper switcher (modules/wallpaper/switcher) still sets wallpapers
 * through `ryoku-shell wallpaper set [--screen <name>]`, which feeds this topic.
 */
Item {
    id: root

    // The monitor this backdrop paints, supplied by the shell root's per-screen
    // scope (contract 08 sec 7: hotplug adds a monitor -> a new instance here).
    required property var screen

    WallpaperFrame {
        id: frame
        screenName: root.screen ? root.screen.name : ""
    }
    readonly property string wallpaperUrl: frame.path.length > 0
        ? "file://" + frame.path + "?v=" + frame.revision : ""
    readonly property string fit: frame.fit
    readonly property var transition: frame.transition
    readonly property bool live: frame.live
    readonly property bool ready: frame.ready
    property bool reloadDecoded: false
    readonly property bool reloadReady: frame.ready && (frame.live || reloadDecoded)

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function apply(line: string): void {
        frame.apply(line);
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
        color: root.ready && !root.live ? Theme.paper : "transparent"
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
            id: backdrop
            anchors.fill: parent
            visible: root.ready && !root.live
            url: root.wallpaperUrl
            fit: root.fit
            transition: root.transition
            onDecodedChanged: root.reloadDecoded = decoded
        }
    }
}
