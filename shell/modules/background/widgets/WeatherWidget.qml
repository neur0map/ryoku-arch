pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

// Self-contained desktop weather card: large condition icon beside the
// temperature and a description line. Scales by re-rendering at the target
// size (sizeScale) rather than an Item transform, so it stays crisp.
StyledRect {
    id: root

    property bool showBackground: true
    property real sizeScale: 1

    readonly property real pad: Tokens.padding.large * sizeScale

    implicitWidth: row.implicitWidth + pad * 2
    implicitHeight: row.implicitHeight + pad * 2
    radius: Tokens.rounding.large * sizeScale
    color: showBackground ? Qt.alpha(Colours.palette.m3surfaceContainer, 0.78) : "transparent"
    border.width: showBackground ? 1 : 0
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Component.onCompleted: Weather.reload()

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.normal * root.sizeScale

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            animate: true
            text: Weather.icon
            color: Colours.palette.m3secondary
            font.pointSize: Tokens.font.size.extraLarge * 1.9 * root.sizeScale
            fill: 1
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                animate: true
                text: Weather.temp
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
                font.weight: Font.Medium
            }

            StyledText {
                Layout.maximumWidth: 180 * root.sizeScale
                animate: true
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small * root.sizeScale
                elide: Text.ElideRight
            }
        }
    }
}
