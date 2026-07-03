pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The desktop strip along the top: each card is a "desktop", a block of
 * workspace IDs holding its own set of workspaces (Hyprland has no native
 * space-group, so a desktop is just ids [d*10+1 .. d*10+10]). Click a card to
 * view that desktop's workspaces in the grid below; the trailing card is an
 * empty desktop to move into for a different kind of work. The active desktop
 * wears the vermillion accent, the viewed one a lighter ring. Every card carries
 * the hard offset shadow. Dragging a window tile onto a card moves it to that
 * desktop (Overview drives the hit-test; this just reflects dropHot).
 */
Row {
    id: strip
    property real s: 1
    property var ov: null
    spacing: 14 * strip.s

    Repeater {
        model: strip.ov ? strip.ov.deskList : []
        delegate: Item {
            id: dcard
            required property var modelData
            required property int index
            readonly property int deskIdx: dcard.modelData
            readonly property var dots: strip.ov ? strip.ov.deskDots(dcard.deskIdx) : []
            readonly property bool isNew: dcard.dots.length === 0
            readonly property bool viewed: !!strip.ov && strip.ov.viewedDesktop === dcard.deskIdx
            readonly property bool activeD: !!strip.ov && strip.ov.activeDesktop === dcard.deskIdx
            readonly property bool dropHot: !!strip.ov && strip.ov.dragging && strip.ov.dragTargetDesk === dcard.deskIdx
            property bool hovered: false
            readonly property bool lit: dcard.viewed || dcard.activeD || dcard.hovered || dcard.dropHot

            width: 122 * strip.s
            height: 58 * strip.s

            // subtle hard offset shadow (small chrome; a heavy one reads as a box).
            Rectangle {
                x: 3 * strip.s
                y: 3 * strip.s
                width: face.width
                height: face.height
                radius: Theme.radius
                color: Theme.shadow
                opacity: dcard.activeD ? 0.5 : 0.32
                antialiasing: false
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            Rectangle {
                id: face
                anchors.fill: parent
                radius: Theme.radius
                color: (dcard.dropHot || dcard.viewed || dcard.activeD) ? Qt.alpha(Theme.brand, 0.09) : Theme.cardBot
                border.width: (dcard.viewed || dcard.activeD || dcard.dropHot) ? 2 : 1
                border.color: dcard.dropHot ? Theme.brand
                    : dcard.activeD ? Theme.brand
                    : dcard.viewed ? Theme.vermLit
                    : dcard.hovered ? Theme.frameBorder
                    : Theme.border
                Behavior on border.color { ColorAnimation { duration: Motion.highlight } }
                Behavior on color { ColorAnimation { duration: Motion.highlight } }

                Column {
                    anchors.centerIn: parent
                    spacing: 7 * strip.s

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dcard.isNew ? "NEW" : ("0" + (dcard.deskIdx + 1)).slice(-2)
                        color: dcard.activeD ? Theme.brand : (dcard.isNew ? Theme.faint : Theme.cream)
                        font.family: Theme.mono
                        font.pixelSize: 13 * strip.s
                        font.letterSpacing: 2 * strip.s
                        font.weight: Font.DemiBold
                    }

                    // workspace dots: one per space in this desktop, filled if it
                    // holds windows.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4 * strip.s
                        visible: !dcard.isNew
                        Repeater {
                            model: dcard.dots
                            delegate: Rectangle {
                                required property var modelData
                                width: 6 * strip.s
                                height: 6 * strip.s
                                radius: width / 2
                                color: modelData ? (dcard.activeD ? Theme.brand : Theme.cream) : Theme.faint
                            }
                        }
                    }

                    // the "+" mark for the empty NEW desktop.
                    Item {
                        visible: dcard.isNew
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 14 * strip.s
                        height: 14 * strip.s
                        Rectangle { anchors.centerIn: parent; width: 13 * strip.s; height: 2 * strip.s; radius: 1; color: dcard.lit ? Theme.brand : Theme.faint }
                        Rectangle { anchors.centerIn: parent; width: 2 * strip.s; height: 13 * strip.s; radius: 1; color: dcard.lit ? Theme.brand : Theme.faint }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: dcard.hovered = true
                    onExited: dcard.hovered = false
                    onClicked: if (strip.ov) strip.ov.switchToDesktop(dcard.deskIdx)
                }
            }
        }
    }
}
