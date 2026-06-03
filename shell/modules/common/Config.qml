pragma Singleton

import QtQuick
import Quickshell

// Ryoku Config: holds the overlay + crosshair option defaults the overlay widgets read.
Singleton {
    id: root

    readonly property bool ready: true

    readonly property QtObject options: QtObject {
        readonly property QtObject overlay: QtObject {
            readonly property bool openingZoomAnimation: true
            readonly property bool darkenScreen: true
            readonly property real clickthroughOpacity: 0.8
            readonly property real backgroundOpacity: 0.9
            readonly property int scrimDim: 35
            readonly property int animationDurationMs: 180
            readonly property int scrimAnimationDurationMs: 140
        }
        readonly property QtObject crosshair: QtObject {
            // Valorant crosshair code (default).
            readonly property string code: "0;P;d;1;0l;10;0o;2;1b;0"
        }
        readonly property QtObject resources: QtObject {
            readonly property int historyLength: 60
        }
        readonly property QtObject networking: QtObject {
            readonly property string userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
        }
        readonly property QtObject interactions: QtObject {
            readonly property QtObject scrolling: QtObject {
                readonly property real touchpadScrollFactor: 100
                readonly property real mouseScrollFactor: 50
                readonly property real mouseScrollDeltaThreshold: 120
                readonly property bool fasterTouchpadScroll: false
            }
        }
    }
}
