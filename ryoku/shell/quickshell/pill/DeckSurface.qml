pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// 力 CONTROL DECK = the single-view dashboard. two hairline-split columns under
// a 力 masthead with corner ticks: Stash left (file drop + LocalSend), a
// Tools / Controls / Record stack right. Tools = screen-capture launchers;
// Controls = the unified control centre (Keep-Awake + Game-Mode session tiles
// over the wifi/bt/mic/dnd/night quick-toggles); Record = capture + recordings
// list. zones are grouped by whitespace, not rules. Super+D opens it.
// implicitHeight comes from content; Ame is off.
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 14

    ameForm: "off"

    readonly property real headerH: 24 * s
    readonly property real gutter: 18 * s

    implicitHeight: content.implicitHeight

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // masthead: 力 + CONTROL DECK.
        Item {
            width: parent.width
            height: root.headerH

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 15 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CONTROL DECK"
                    color: Theme.subtle
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.4 * root.s
                    font.capitalization: Font.AllUppercase
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hair }

        Item { width: 1; height: 14 * root.s }

        // body: two hairline-split columns.
        Item {
            id: bodyHolder
            width: parent.width
            height: bodyRow.height

            readonly property real colsW: width - root.gutter * 2 - 1
            readonly property real leftW: Math.floor(colsW * 0.50)
            readonly property real rightW: colsW - leftW
            readonly property real bodyH: Math.max(leftCol.minH, rightStack.implicitHeight)

            Row {
                id: bodyRow
                width: parent.width
                height: bodyHolder.bodyH
                spacing: root.gutter

                // left: Stash, fills the column to balance the taller right.
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

                // gutter divider.
                Rectangle {
                    width: 1
                    height: bodyHolder.bodyH
                    color: Theme.hair
                }

                // right: Tools / Controls / Record, grouped by whitespace.
                Column {
                    id: rightStack
                    width: bodyHolder.rightW
                    spacing: 16 * root.s

                    Column {
                        width: parent.width
                        spacing: 10 * root.s
                        MicroLabel { label: "Tools"; s: root.s }
                        DeckTools {
                            width: parent.width
                            s: root.s
                            onRequestClose: root.requestClose()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 10 * root.s
                        MicroLabel { label: "Controls"; s: root.s }
                        DeckControls {
                            width: parent.width
                            s: root.s
                            active: root.open
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 10 * root.s

                        Item {
                            width: parent.width
                            height: recEye.implicitHeight

                            MicroLabel { id: recEye; label: "Record"; s: root.s }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: recEye.verticalCenter
                                visible: recordZone.recCount > 0
                                text: recordZone.recCount < 10 ? "0" + recordZone.recCount : String(recordZone.recCount)
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.4 * root.s
                                font.features: { "tnum": 1 }
                            }
                        }

                        DeckRecord {
                            id: recordZone
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

    // corner registration ticks around the dashboard.
    CornerTicks {
        anchors.fill: parent
        s: root.s
        z: -1
    }
}
