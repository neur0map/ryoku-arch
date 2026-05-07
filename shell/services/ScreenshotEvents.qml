pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool toastVisible: false
    property string toastText: ""
    property string lastFilePath: ""

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.toastVisible = false
    }

    function show(text: string, path: string): void {
        root.toastText = text;
        root.lastFilePath = path;
        root.toastVisible = true;
        hideTimer.restart();
    }

    IpcHandler {
        target: "screenshotEvents"
        function captured(text: string, path: string): void {
            root.show(text, path);
        }
    }
}
