pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// Recording indicator: self-hides unless a screen recording is active, drawn in
// the error colour role (a red glyph). Left click stops the
// recording. Contract 04 sec 3.2 (recording_indicator).
Item {
    id: root

    required property string edge
    required property real scale

    readonly property bool selfShown: Recorder.active
    visible: selfShown
    implicitWidth: selfShown ? btn.implicitWidth : 0
    implicitHeight: selfShown ? btn.implicitHeight : 0

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: "record"
        iconColor: Theme.error
        onClicked: Recorder.stop()
    }
}
