pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

// Self-contained desktop weather card: large condition icon beside the
// temperature and a description line.
StyledRect {
    id: root

    implicitWidth: row.implicitWidth + Tokens.padding.large * 2
    implicitHeight: row.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.78)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Component.onCompleted: Weather.reload()

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            animate: true
            text: Weather.icon
            color: Colours.palette.m3secondary
            font.pointSize: Tokens.font.size.extraLarge * 1.9
            fill: 1
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                animate: true
                text: Weather.temp
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.extraLarge
                font.weight: Font.Medium
            }

            StyledText {
                Layout.maximumWidth: 180
                animate: true
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
            }
        }
    }
}
