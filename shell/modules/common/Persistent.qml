pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Ryoku Persistent: trimmed to states.overlay (the only state the overlay
// reads/writes). Same FileView + JsonAdapter persistence, backed by Ryoku's
// config dir. Per-widget defaults match the overlay's Persistent schema.
Singleton {
    id: root

    property alias states: persistentStatesJsonAdapter
    property string filePath: `${Paths.config}/overlay-state.json`
    property bool ready: false

    property bool _writeInFlight: false
    property bool _pendingReload: false

    function _completeWrite(): void {
        root._writeInFlight = false;
        if (root._pendingReload) {
            root._pendingReload = false;
            fileReloadTimer.restart();
        }
    }

    Timer {
        id: fileReloadTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (root._writeInFlight) {
                root._pendingReload = true;
                return;
            }
            persistentStatesFileView.reload();
        }
    }

    Timer {
        id: fileWriteTimer

        interval: 100
        repeat: false
        onTriggered: {
            root._writeInFlight = true;
            fileReloadTimer.stop();
            persistentStatesFileView.writeAdapter();
        }
    }

    FileView {
        id: persistentStatesFileView

        path: root.filePath
        watchChanges: true
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onSaved: root._completeWrite()
        onSaveFailed: error => {
            console.warn("[Persistent] Save failed:", error);
            root._completeWrite();
        }
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'));
                Quickshell.execDetached(["/usr/bin/mkdir", "-p", parentDir]);
                fileWriteTimer.restart();
            }
        }

        adapter: JsonAdapter {
            id: persistentStatesJsonAdapter

            property JsonObject overlay: JsonObject {
                property list<string> open: ["crosshair", "recorder", "volumeMixer", "resources"]

                property JsonObject crosshair: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 827
                    property real y: 441
                    property real width: 250
                    property real height: 100
                }
                property JsonObject floatingImage: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 1650
                    property real y: 390
                    property real width: 0
                    property real height: 0
                }
                property JsonObject fpsLimiter: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 1570
                    property real y: 615
                    property real width: 280
                    property real height: 80
                }
                property JsonObject recorder: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 80
                    property real width: 350
                    property real height: 130
                }
                property JsonObject resources: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 1500
                    property real y: 770
                    property real width: 350
                    property real height: 200
                    property int tabIndex: 0
                }
                property JsonObject volumeMixer: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 80
                    property real y: 280
                    property real width: 350
                    property real height: 600
                    property int tabIndex: 0
                }
                property JsonObject notes: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: true
                    property real x: 1400
                    property real y: 42
                    property real width: 460
                    property real height: 330
                }
                property JsonObject discord: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 1200
                    property real y: 560
                    property real width: 320
                    property real height: 160
                }
                property JsonObject notifications: JsonObject {
                    property bool pinned: false
                    property bool clickthrough: false
                    property real x: 1200
                    property real y: 80
                    property real width: 420
                    property real height: 500
                }
            }
        }
    }
}
