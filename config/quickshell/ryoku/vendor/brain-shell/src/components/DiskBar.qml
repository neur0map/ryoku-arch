import QtQuick
import "../"

Item {
    id: root

    property string source:   ""
    property string mount:    ""
    property int    usedPct:  0
    property string usedStr:  "—"
    property string totalStr: "—"

    implicitWidth:  200
    implicitHeight: 40

    readonly property color barColor: {
        if (usedPct >= 90) return "#f38ba8"
        if (usedPct >= 75) return "#f5c47a"
        return Theme.active
    }

    // Mount label — left, fixed width
    Text {
        id: mountLabel
        anchors.left:           parent.left
        anchors.verticalCenter: barTrack.verticalCenter
        text:           root.mount
        font.pixelSize: 10
        color:          Qt.rgba(1, 1, 1, 0.5)
        width:          32
        elide:          Text.ElideRight
    }

    // Bar track + fill
    Item {
        id: barTrack
        anchors.left:    mountLabel.right
        anchors.right:   pctLabel.left
        anchors.top:     parent.top
        anchors.leftMargin:  6
        anchors.rightMargin: 6
        height: 6

        Rectangle {
            anchors.fill: parent
            radius:       height / 2
            color:        Qt.rgba(1, 1, 1, 0.07)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
        }

        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          parent.width * Math.max(0, Math.min(1, root.usedPct / 100))
            radius:         height / 2
            color:          root.barColor

            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation  { duration: 300 } }
        }
    }

    // Percentage — right of bar
    Text {
        id: pctLabel
        anchors.right:          parent.right
        anchors.verticalCenter: barTrack.verticalCenter
        text:           root.usedPct + "%"
        font.pixelSize: 10
        font.weight:    Font.Medium
        color:          root.barColor
        width:          28
        horizontalAlignment: Text.AlignRight
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    // Size info — below the bar, aligned with bar
    Text {
        anchors.horizontalCenter: barTrack.horizontalCenter
        anchors.top:     barTrack.bottom
        anchors.topMargin: 3
        text:           root.usedStr + " / " + root.totalStr + "  ·  " + root.source
        font.pixelSize: 8
        color:          Qt.rgba(1, 1, 1, 0.25)
    }
}
