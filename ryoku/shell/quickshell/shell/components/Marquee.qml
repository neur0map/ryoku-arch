import QtQuick
import shell.services

// single-line text that ping-pongs when it's wider than its space. long track
// + artist names stay readable. caller sets width (anchors etc.) and `active`
// gates the motion.
Item {
    id: root

    property string text: ""
    property color color: Theme.onSurface
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
        font.family: Theme.fontPrimary
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
     * fully imperative start/stop. a `running` binding gets severed by the
     * first imperative stop() and would leave the loop running forever inside
     * a hidden surface. re-syncing on overflow changes also refreshes the
     * captured from/to after a width change.
     */
    function sync() {
        anim.stop();
        label.x = 0;
        if (overflowing && active)
            anim.start();
    }
}
