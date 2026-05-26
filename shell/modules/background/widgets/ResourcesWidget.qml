pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.misc
import qs.services

// Self-contained desktop resources card: CPU / memory / disk as labelled rows
// with a thin progress track each. Scales by re-rendering at the target size
// (sizeScale) rather than an Item transform, so it stays crisp.
StyledRect {
    id: root

    property bool showBackground: true
    property real sizeScale: 1

    readonly property real pad: Tokens.padding.large * sizeScale

    implicitWidth: 248 * sizeScale
    implicitHeight: col.implicitHeight + pad * 2
    radius: Tokens.rounding.large * sizeScale
    color: showBackground ? Qt.alpha(Colours.palette.m3surfaceContainer, 0.78) : "transparent"
    border.width: showBackground ? 1 : 0
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Ref {
        service: SystemUsage
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: root.pad
        spacing: Tokens.spacing.normal * root.sizeScale

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
        spacing: Tokens.spacing.smaller * root.sizeScale

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small * root.sizeScale

            MaterialIcon {
                text: stat.icon
                color: stat.colour
                font.pointSize: Tokens.font.size.normal * root.sizeScale
            }

            StyledText {
                Layout.fillWidth: true
                text: stat.label
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small * root.sizeScale
            }

            StyledText {
                text: Math.round(stat.value * 100) + "%"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small * root.sizeScale
                font.weight: Font.DemiBold
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 5 * root.sizeScale
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
