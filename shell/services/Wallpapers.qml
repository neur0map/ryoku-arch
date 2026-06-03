pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import Ryoku.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property string currentTypePath: `${Paths.state}/wallpaper/type.txt`
    property string currentType: "image"
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent

    // Overlay widgets read Wallpapers.effectiveWallpaperUrl.
    readonly property url effectiveWallpaperUrl: Qt.resolvedUrl(root.current)

    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool smartInitialised: false

    function setWallpaper(path: string): void {
        actualCurrent = path;
        Quickshell.execDetached(["ryoku", "wallpaper", "-f", path, ...smartArg]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (!previewColourLock)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    // RYOKU: regenerate wallpaper colours a moment after the wallpaper changes,
    // so it auto-applies on any switch (picker, rotation, CLI). Debounced to give
    // the extractor time to think and to coalesce rapid changes.
    Timer {
        id: smartSchemeTimer
        interval: 500
        onTriggered: Quickshell.execDetached(["ryoku", "scheme", "from-wallpaper"])
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.actualCurrent = text().trim();
            root.previewColourLock = false;
            // Skip the very first load at startup — Colours.qml already derives
            // wallpaper colours on launch; only react to subsequent changes.
            if (root.smartInitialised) {
                if (GlobalConfig.services.smartScheme)
                    smartSchemeTimer.restart();
            } else {
                root.smartInitialised = true;
            }
        }
    }

    FileView {
        path: root.currentTypePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.currentType = text().trim() || "image"
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    Process {
        id: getPreviewColoursProc

        command: ["ryoku", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
