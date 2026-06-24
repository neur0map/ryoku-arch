pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 力 CONTROL DECK: a wide, single-view dashboard that gathers Stash (file drop +
 * LocalSend), Tools (screen-capture helpers), and Utilities (recorder, keep-awake,
 * quick toggles, recordings) into one panel in the Ryoku Hub dossier language. No
 * sub-tabs: everything is visible at once across two hairline-split columns, Stash
 * on the left, Tools over Utilities on the right, framed by corner registration
 * ticks under a 力 masthead. The three keybinds (Super+D/Z/U) all open this one
 * surface. Exposes `implicitHeight` from its content; Ame stays off.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 18
    mRight: 18
    mBottom: 16

    ameForm: "off"

    readonly property real headerH: 30 * s
    readonly property real gutter: 20 * s

    implicitHeight: content.implicitHeight

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ── Masthead: 力 + CONTROL DECK ────────────────────────────────────
        Item {
            width: parent.width
            height: root.headerH

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 17 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CONTROL DECK"
                    color: Theme.subtle
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.4 * root.s
                    font.capitalization: Font.AllUppercase
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hair }

        Item { width: 1; height: 16 * root.s }

        // ── Body: two hairline-split columns ──────────────────────────────
        Item {
            id: bodyHolder
            width: parent.width
            height: bodyRow.height

            readonly property real colsW: width - root.gutter * 2 - 1
            readonly property real leftW: Math.floor(colsW * 0.52)
            readonly property real rightW: colsW - leftW
            readonly property real bodyH: Math.max(leftCol.minH, rightStack.implicitHeight)

            Row {
                id: bodyRow
                width: parent.width
                height: bodyHolder.bodyH
                spacing: root.gutter

                // Left: Stash (fills the column to balance the taller right side).
                Item {
                    id: leftCol
                    width: bodyHolder.leftW
                    height: bodyHolder.bodyH
                    readonly property real minH: stashLbl.implicitHeight + 12 * root.s + stashSec.implicitHeight

                    MicroLabel {
                        id: stashLbl
                        anchors.top: parent.top
                        anchors.left: parent.left
                        label: "Stash"
                        s: root.s
                    }
                    DeckStash {
                        id: stashSec
                        anchors.top: stashLbl.bottom
                        anchors.topMargin: 12 * root.s
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        s: root.s
                        active: root.open
                        onRequestClose: root.requestClose()
                    }
                }

                // Gutter divider.
                Rectangle {
                    width: 1
                    height: bodyHolder.bodyH
                    color: Theme.hair
                }

                // Right: Tools over Utilities.
                Column {
                    id: rightStack
                    width: bodyHolder.rightW
                    spacing: 18 * root.s

                    Column {
                        width: parent.width
                        spacing: 12 * root.s
                        MicroLabel { label: "Tools"; s: root.s }
                        DeckTools {
                            width: parent.width
                            s: root.s
                            onRequestClose: root.requestClose()
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.hair }

                    Column {
                        width: parent.width
                        spacing: 12 * root.s
                        MicroLabel { label: "Utilities"; s: root.s }
                        DeckUtilities {
                            width: parent.width
                            s: root.s
                            active: root.open
                            onRequestClose: root.requestClose()
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 4 * root.s }
    }

    // Registration ticks framing the dashboard like a specimen sheet.
    CornerTicks {
        anchors.fill: parent
        s: root.s
        z: -1
    }
}
