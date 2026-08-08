pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// A row with three targets (contract 16 sec 2.5, contract 06 sec 2.3): a fixed
// 48x48 action button on the left (its own click, kept full colour when
// insensitive per the reference no-disabled), a middle content slot that takes
// the slack (a label or a volume slider), and a 36x48 reveal button on the
// right whose chevron turns 90 degrees over 200ms as it toggles the card below.
// The card sits 10px under the row, outlined 2px, 4px padded, and fades in over
// 200ms while its height slides. Reveal is local; a host binds/forces
// `revealed` and starts/stops watchers on the toggled() edges.
Item {
    id: root

    property bool revealed: false
    property string actionIconName: ""
    property bool actionSensitive: true

    property alias middle: middleHold.data
    default property alias revealedContent: revealHold.data

    signal actionClicked()
    signal toggled(bool revealed)

    implicitWidth: 200
    implicitHeight: header.height + revealArea.height

    Item {
        id: header
        width: root.width
        height: 48

        MenuButton {
            id: action
            minW: 48
            minH: 48
            enabled: root.actionSensitive
            keepEnabledLook: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.actionClicked()
            MaterialIcon {
                anchors.centerIn: parent
                width: Theme.iconMd
                height: Theme.iconMd
                font.pixelSize: Theme.iconMd
                text: root.actionIconName
                color: action.contentColor
            }
        }

        Item {
            id: middleHold
            anchors.left: action.right
            anchors.leftMargin: 10
            anchors.right: reveal.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
        }

        MenuButton {
            id: reveal
            minW: 36
            minH: 48
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                root.revealed = !root.revealed;
                root.toggled(root.revealed);
            }
            MaterialIcon {
                anchors.centerIn: parent
                width: Theme.iconMd
                height: Theme.iconMd
                font.pixelSize: Theme.iconMd
                text: "chevron_right"
                color: reveal.contentColor
                rotation: root.revealed ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: Motion.chevronRotate; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }
            }
        }
    }

    Item {
        id: revealArea
        anchors.top: header.bottom
        width: root.width
        clip: true
        height: root.revealed ? (10 + card.implicitHeight) : 0
        Behavior on height { NumberAnimation { duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve } }

        Rectangle {
            id: card
            y: 10
            width: parent.width
            implicitHeight: revealHold.childrenRect.height + Theme.paddingSm * 2
            radius: Theme.radiusWidget
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.outline
            opacity: root.revealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.rowFade; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

            Item {
                id: revealHold
                x: Theme.paddingSm
                y: Theme.paddingSm
                width: parent.width - Theme.paddingSm * 2
            }
        }
    }
}
