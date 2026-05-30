pragma ComponentBehavior: Bound

import QtQuick
import ".."
import Ryoku.Config
import qs.components
import qs.services

// RYOKU: gaming-overlay toggle button bound to the GameMode service. Clicking
// flips GameMode.enabled (which applies/restores Hyprland dynamic confs); the
// card colour and label reflect the live bound state.
OverlayWidget {
    id: root

    widgetId: "gameMode"

    StyledRect {
        anchors.fill: parent
        implicitWidth: rowm.implicitWidth + Tokens.padding.large * 2
        implicitHeight: rowm.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.small
        color: GameMode.enabled ? Qt.alpha(Colours.palette.m3primary, 0.85) : Qt.alpha(Colours.palette.m3surface, 0.7)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: GameMode.enabled = !GameMode.enabled
        }

        Row {
            id: rowm

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "sports_esports"
                color: GameMode.enabled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.normal
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: GameMode.enabled ? qsTr("Game Mode: On") : qsTr("Game Mode: Off")
                color: GameMode.enabled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.normal
            }
        }
    }
}
