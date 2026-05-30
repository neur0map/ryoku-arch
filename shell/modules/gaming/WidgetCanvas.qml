import QtQuick
import "widgets"

// RYOKU: gaming overlay widget canvas. Hosts the overlay widgets; later tasks
// add the stats, recorder, music and game-mode widgets alongside the crosshair.
Item {
    id: canvas

    Crosshair {}
    Stats {}
    Recorder {}
    Music {}
    GameModeButton {}

    WidgetToggleBar {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 24
    }
}
