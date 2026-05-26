pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.misc
import qs.services

// Self-contained desktop resources card: CPU / memory / disk as labelled
// rows with a thin progress track each. Designed to read well standalone.
StyledRect {
    id: root

    property bool showBackground: true

    implicitWidth: 248
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: showBackground ? Qt.alpha(Colours.palette.m3surfaceContainer, 0.78) : "transparent"
    border.width: showBackground ? 1 : 0
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Ref {
        service: SystemUsage
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        Stat {
            icon: "memory"
            label: qsTr("CPU")
            value: SystemUsage.cpuPerc
            colour: Colours.palette.m3primary
        }

        Stat {
            icon: "memory_alt"
            label: qsTr("Memory")
            value: SystemUsage.memPerc
            colour: Colours.palette.m3secondary
        }

        Stat {
            icon: "hard_disk"
            label: qsTr("Disk")
            value: SystemUsage.storagePerc
            colour: Colours.palette.m3tertiary
        }
    }

    component Stat: ColumnLayout {
        id: stat

        required property string icon
        required property string label
        required property real value
        required property color colour

        Layout.fillWidth: true
        spacing: Tokens.spacing.smaller

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: stat.icon
                color: stat.colour
                font.pointSize: Tokens.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: stat.label
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                text: Math.round(stat.value * 100) + "%"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                font.weight: Font.DemiBold
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 5
            radius: Tokens.rounding.full
            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                implicitWidth: Math.max(parent.height, stat.value * parent.width)
                radius: Tokens.rounding.full
                color: stat.colour

                Behavior on implicitWidth {
                    Anim {
                        type: Anim.StandardLarge
                    }
                }
            }
        }
    }
}
