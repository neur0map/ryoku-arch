import QtQuick
import "Singletons"

/**
 * Single-line text that ping-pong scrolls when wider than the available width,
 * so long track and artist names stay readable. Caller sets the width (e.g.
 * via anchors) and `active` to gate the motion.
 */
Item {
    id: root

    property string text: ""
    property color color: Theme.cream
    property real pixelSize: 14
    property int weight: Font.Normal
    property bool active: true

    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool overflowing: label.implicitWidth > width

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        text: root.text
        color: root.color
        font.family: Theme.font
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        elide: root.overflowing ? Text.ElideNone : Text.ElideRight
        width: root.overflowing ? implicitWidth : root.width

        SequentialAnimation {
            id: anim
            loops: Animation.Infinite
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                target: label
                property: "x"
                from: 0
                to: -(label.implicitWidth - root.width)
                duration: Math.max(1, label.implicitWidth - root.width) * 22
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                target: label
                property: "x"
                from: -(label.implicitWidth - root.width)
                to: 0
                duration: Math.max(1, label.implicitWidth - root.width) * 22
                easing.type: Easing.InOutSine
            }
        }

        onTextChanged: root.sync()
    }

    onActiveChanged: sync()
    onOverflowingChanged: sync()
    Component.onCompleted: sync()

    /**
     * Fully imperative start/stop: a `running` binding here would be severed
     * by the first imperative stop() and leave the loop animating forever
     * inside a hidden surface. Re-syncing on overflow changes also refreshes
     * the captured from/to endpoints after a width change.
     */
    function sync() {
        anim.stop();
        label.x = 0;
        if (overflowing && active)
            anim.start();
    }
}
