import QtQuick
import "Singletons"

// A guarded destructive switch: the verb lives under a flip-up cover plate,
// like a missile switch. First click lifts the cover and arms the red switch;
// clicking the armed switch fires; the cover slams shut by itself after 3s of
// hesitation. Destruction requires two distinct, deliberate motions.
Item {
    id: gs

    property string label: "DELETE"
    property string armedLabel: "CONFIRM"
    property bool enabled: true
    signal fired()

    property bool armed: false

    implicitWidth: 128
    implicitHeight: 36
    opacity: gs.enabled ? 1 : 0.4

    onArmedChanged: if (armed) slam.restart(); else slam.stop()
    Timer { id: slam; interval: 3000; onTriggered: gs.armed = false }

    // hard shadow.
    Rectangle {
        x: 3; y: 3
        width: gs.width - 3
        height: gs.height - 3
        color: Theme.shadow
        antialiasing: false
    }

    // the armed switch bed: red, waiting.
    Rectangle {
        id: bed
        width: gs.width - 3
        height: gs.height - 3
        color: gs.armed ? Theme.emberDeep : Theme.surfaceLo
        border.width: 1
        border.color: gs.armed ? Theme.ember : Theme.line
        antialiasing: false

        Text {
            anchors.centerIn: parent
            text: gs.armed ? gs.armedLabel : ""
            color: Theme.onAccent
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        TapHandler {
            enabled: gs.enabled && gs.armed
            onTapped: { gs.armed = false; gs.fired(); }
        }
        HoverHandler { enabled: gs.enabled && gs.armed; cursorShape: Qt.PointingHandCursor }
    }

    // the cover plate: hinged on its top edge, striped like machine guards.
    Item {
        id: coverPivot
        width: gs.width - 3
        height: gs.height - 3
        transform: Rotation {
            id: hinge
            origin.x: 0
            origin.y: 0
            axis { x: 1; y: 0; z: 0 }
            angle: gs.armed ? 78 : 0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        }
        visible: hinge.angle < 89

        Rectangle {
            anchors.fill: parent
            color: Theme.keyTop
            border.width: 1
            border.color: Theme.lineStrong
            antialiasing: false

            // caution stripe along the bottom edge of the guard.
            Row {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 4
                clip: true
                Repeater {
                    model: Math.ceil(gs.width / 8)
                    delegate: Item {
                        required property int index
                        width: 8; height: 4
                        Rectangle {
                            width: 6; height: 10
                            rotation: 45
                            y: -3
                            color: index % 2 === 0 ? Qt.alpha(Theme.ember, 0.55) : "transparent"
                            antialiasing: false
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: gs.label
                color: gh.hovered && gs.enabled ? Theme.bright : Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }
        }

        TapHandler {
            enabled: gs.enabled && !gs.armed
            onTapped: gs.armed = true
        }
        HoverHandler { id: gh; enabled: gs.enabled && !gs.armed; cursorShape: Qt.PointingHandCursor }
    }
}
