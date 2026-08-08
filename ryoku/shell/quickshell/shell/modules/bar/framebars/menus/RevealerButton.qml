pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// A collapsible surface row (contract 16 sec 2.4, contract 06 sec 2.1): a full
// width `ok-button-surface` header whose whole face toggles a revealed card
// below it. The card sits 10px under the header, is outlined 2px and 8px
// padded, and fades its content 0..1 over 200ms on the CSS ease curve while its
// height slides 0..natural over 200ms ease-out-cubic, both reversing on
// re-toggle. Reveal is local state; a host may still bind or force `revealed`.
Item {
    id: root

    property bool revealed: false
    property string iconName: ""
    property string label: ""
    property string secondaryIconName: ""
    property color iconColor: Theme.ink(Theme.effectiveSurface)

    default property alias revealedContent: revealHold.data

    signal toggled(bool revealed)

    implicitWidth: 200
    implicitHeight: header.implicitHeight + revealArea.height

    MenuButton {
        id: header
        width: root.width
        minH: headerContent.implicitHeight + header.pad * 2
        onClicked: {
            root.revealed = !root.revealed;
            root.toggled(root.revealed);
        }
        RevealerIconLabel {
            id: headerContent
            anchors.fill: parent
            iconName: root.iconName
            label: root.label
            secondaryIconName: root.secondaryIconName
            iconColor: root.iconColor
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
            implicitHeight: revealHold.childrenRect.height + Theme.paddingMd * 2
            radius: Theme.radiusWidget
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.outline
            opacity: root.revealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.rowFade; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

            Item {
                id: revealHold
                x: Theme.paddingMd
                y: Theme.paddingMd
                width: parent.width - Theme.paddingMd * 2
            }
        }
    }
}
