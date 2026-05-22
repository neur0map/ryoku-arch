pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property string type: ""     // "volume" | "brightness"
    property real value: 0       // 0..1 for volume, 0..100 for brightness
    property bool visible: false

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: visible = false
    }

    function show(t, v) {
        type = t
        value = v
        visible = true
        hideTimer.restart()
    }
}
