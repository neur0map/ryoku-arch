pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services

// Self-contained desktop resources card (CPU / memory / disk). Style switches the
// presentation: "default" gradient labelled bars, "compact" accent chips,
// "rings" circular gauges. Each metric owns an accent (CPU primary, memory
// secondary, disk tertiary) and eases on value change. Scales by re-rendering at
// the target size (sizeScale).
WidgetCard {
    id: root

    readonly property string style: GlobalConfig.background.widgets.resources.style

    Ref {
        service: SystemUsage
    }

    Loader {
        id: content

        sourceComponent: {
            switch (root.style) {
            case "compact":
                return compactStyle;
            case "bars":
                return barsStyle;
            default:
                return ringsStyle;
            }
        }
    }

    // ── default: labelled rows with gradient progress tracks ─────────────────
    Component {
        id: barsStyle

        ColumnLayout {
            implicitWidth: 252 * root.sizeScale
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
    }

    // ── compact: accent chip + percent rows ──────────────────────────────────
    Component {
        id: compactStyle

        ColumnLayout {
            spacing: Tokens.spacing.normal * root.sizeScale

            CompactStat {
                icon: "memory"
                value: SystemUsage.cpuPerc
                colour: Colours.palette.m3primary
            }
            CompactStat {
                icon: "memory_alt"
                value: SystemUsage.memPerc
                colour: Colours.palette.m3secondary
            }
            CompactStat {
                icon: "hard_disk"
                value: SystemUsage.storagePerc
                colour: Colours.palette.m3tertiary
            }
        }
    }

    // ── rings: circular gauges side by side ──────────────────────────────────
    Component {
        id: ringsStyle

        RowLayout {
            spacing: Tokens.spacing.large * root.sizeScale

            Ring {
                icon: "memory"
                value: SystemUsage.cpuPerc
                colour: Colours.palette.m3primary
                label: qsTr("CPU")
            }
            Ring {
                icon: "memory_alt"
                value: SystemUsage.memPerc
                colour: Colours.palette.m3secondary
                label: qsTr("MEM")
            }
            Ring {
                icon: "hard_disk"
                value: SystemUsage.storagePerc
                colour: Colours.palette.m3tertiary
                label: qsTr("DSK")
            }
        }
    }

    component IconChip: StyledRect {
        required property string icon
        required property color colour

        implicitWidth: Tokens.font.size.larger * 1.9 * root.sizeScale
        implicitHeight: implicitWidth
        radius: Tokens.rounding.small * root.sizeScale
        color: Qt.alpha(colour, 0.16)

        MaterialIcon {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.colour
            fill: 1
            font.pointSize: Tokens.font.size.normal * root.sizeScale
        }
    }

    component Stat: ColumnLayout {
        id: stat

        required property string icon
        required property string label
        required property real value
        required property color colour

        Layout.fillWidth: true
        spacing: Tokens.spacing.small * root.sizeScale

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal * root.sizeScale

            IconChip {
                icon: stat.icon
                colour: stat.colour
            }
            StyledText {
                Layout.fillWidth: true
                text: stat.label
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.normal * root.sizeScale
                font.weight: Font.Medium
            }
            StyledText {
                text: Math.round(stat.value * 100) + "%"
                color: stat.colour
                font.pointSize: Tokens.font.size.normal * root.sizeScale
                font.weight: Font.Bold
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 8 * root.sizeScale
            radius: Tokens.rounding.full
            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
            clip: true

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                implicitWidth: Math.max(parent.height, stat.value * parent.width)
                radius: Tokens.rounding.full
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: stat.colour
                    }
                    GradientStop {
                        position: 1
                        color: Qt.lighter(stat.colour, 1.3)
                    }
                }

                Behavior on implicitWidth {
                    Anim {
                        type: Anim.StandardLarge
                    }
                }
            }
        }
    }

    component CompactStat: RowLayout {
        id: cstat

        required property string icon
        required property real value
        required property color colour

        Layout.fillWidth: true
        spacing: Tokens.spacing.normal * root.sizeScale

        IconChip {
            icon: cstat.icon
            colour: cstat.colour
        }
        StyledText {
            Layout.fillWidth: true
            text: Math.round(cstat.value * 100) + "%"
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.larger * root.sizeScale
            font.weight: Font.Bold
        }
    }

    component Ring: ColumnLayout {
        id: ring

        required property string icon
        required property real value
        required property color colour
        required property string label

        readonly property real ringSize: 70 * root.sizeScale

        spacing: Tokens.spacing.small * root.sizeScale

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: ring.ringSize
            implicitHeight: ring.ringSize

            CircularProgress {
                anchors.fill: parent
                strokeWidth: 7 * root.sizeScale
                value: ring.value
                fgColour: ring.colour
                bgColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                Behavior on value {
                    Anim {
                        type: Anim.StandardLarge
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: Math.round(ring.value * 100)
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.large * root.sizeScale
                font.weight: Font.Bold
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: ring.label
            color: ring.colour
            font.pointSize: Tokens.font.size.small * root.sizeScale
            font.weight: Font.Medium
            font.letterSpacing: 1.5
        }
    }
}
