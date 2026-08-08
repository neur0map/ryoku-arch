import QtQuick
import Ryoku.Ui.Singletons

// The Section grammar (4px ink dot, section/11 caps, lineSoft leader) with one
// addition the app-class contract needs and the module Section does not carry:
// an action slot on the header line (the RESET EDITS / RESET TO DEFAULT Btn,
// per 2.3). Every cell inside is still a module Cell; only the header differs.
Column {
    id: sect
    property string title: ""
    property int gutter: Tokens.s2
    default property alias cells: flow.data
    property alias action: actionSlot.data

    readonly property real colWidth: (width - (12 - 1) * gutter) / 12
    function span(n) { return n * colWidth + (n - 1) * gutter }

    spacing: Tokens.s3

    Item {
        width: parent.width
        height: 32

        Row {
            id: hdr
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s2
            Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: sect.title
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium
                font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            anchors.left: hdr.right
            anchors.leftMargin: Tokens.s2
            anchors.right: actionSlot.left
            anchors.rightMargin: Tokens.s2
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Tokens.lineSoft
        }
        Item {
            id: actionSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: parent.height
        }
    }

    Flow {
        id: flow
        width: parent.width
        spacing: sect.gutter
    }
}
