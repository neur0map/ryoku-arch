pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.components
import qs.services

// RYOKU: in-overlay widget toggle bar. One button per gaming widget id; each shows
// the widget's icon, is highlighted while that widget is enabled, and flips its
// enabled state on click. Visible only while the overlay is open.
Row {
    id: bar

    visible: Gaming.open
    spacing: Tokens.spacing.small

    readonly property var icons: ({
        "crosshair": "add",
        "stats": "monitor_heart",
        "recorder": "videocam",
        "music": "music_note",
        "gameMode": "sports_esports"
    })

    Repeater {
        model: Gaming.widgetIds

        delegate: StyledRect {
            id: btn

            required property string modelData
            readonly property bool on: Gaming.isEnabled(modelData)

            width: 40
            height: 40
            radius: Tokens.rounding.small
            color: on ? Colours.palette.m3primary : Colours.palette.m3surfaceVariant

            MaterialIcon {
                anchors.centerIn: parent
                text: bar.icons[btn.modelData] ?? "widgets"
                color: btn.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Gaming.setRecord(btn.modelData, {
                    "enabled": !btn.on
                })
            }
        }
    }
}
