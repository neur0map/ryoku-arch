import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The one progress spec (DESIGN section 1), for create and instant alike: a 4px
// track drawn as a hairline outline with a square ink fill from zero, percent
// and rate right-aligned. Indeterminate work gets no sweeping bar: a 6px dot on
// a 1Hz square-wave blink beside the live log line in mono.
Column {
    id: p

    property string heading: ""
    property string phase: ""        // caps phase word
    property real progress: 0
    property real bps: 0
    property bool indeterminate: false
    property string log: ""
    signal cancelled()

    spacing: Tokens.s4

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: p.heading
        color: Tokens.ink
        font.family: Tokens.display
        font.pixelSize: 21
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: p.phase.toUpperCase()
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackLabel
    }

    // determinate: hairline track + square ink fill.
    Item {
        width: parent.width
        height: 4
        visible: !p.indeterminate
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Tokens.border
            border.color: Tokens.line
            antialiasing: false
        }
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, p.progress))
            height: parent.height
            color: Tokens.ink
            antialiasing: false
            Behavior on width { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
        }
    }
    Text {
        width: parent.width
        visible: !p.indeterminate
        horizontalAlignment: Text.AlignRight
        text: Math.round(p.progress * 100) + "%"
            + (p.bps > 0 ? "  ·  " + (p.bps / 1048576).toFixed(1) + " MB/s" : "")
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: 12
    }

    // indeterminate: a 6px dot on a 1Hz square blink beside the mono log line.
    Row {
        width: parent.width
        visible: p.indeterminate
        spacing: Tokens.s2
        Rectangle {
            id: blip
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6
            color: Tokens.ink
            antialiasing: false
            SequentialAnimation on opacity {
                running: p.indeterminate
                loops: Animation.Infinite
                PropertyAction { value: 1 }
                PauseAnimation { duration: 500 }
                PropertyAction { value: 0.2 }
                PauseAnimation { duration: 500 }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 14
            elide: Text.ElideRight
            text: p.log.length > 0 ? p.log : "Working…"
            color: Tokens.inkMuted
            font.family: Tokens.mono
            font.pixelSize: 11
        }
    }

    Btn {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "CANCEL"
        onAct: p.cancelled()
    }
}
