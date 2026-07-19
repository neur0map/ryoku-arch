import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Closes a capped fleet preview: a "+N more" plate that taps through to the full
// page. Shares the FleetTile footprint so the dashboard grid stays even.
Item {
    id: more

    property int count: 0
    signal tapped()

    implicitHeight: 84

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius
        color: ma.containsMouse ? Tokens.tint5 : "transparent"
        border.width: Tokens.border
        border.color: ma.containsMouse ? Tokens.lineStrong : Tokens.line
        antialiasing: false
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "+" + more.count
                color: Tokens.ink
                font.family: Tokens.ui; font.pixelSize: 22; font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MORE →"
                color: Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: 10
                font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: more.tapped()
        }
    }
}
