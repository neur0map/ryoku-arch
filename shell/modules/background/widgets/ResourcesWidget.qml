pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.misc
import qs.services

// Self-contained desktop resources card (CPU / memory / disk). Style switches the
// presentation: "default" labelled bars, "compact" icon+percent row, "rings"
// circular gauges. Scales by re-rendering at the target size (sizeScale).
StyledRect {
    id: root

    property bool showBackground: true
    property real sizeScale: 1
    readonly property string style: GlobalConfig.background.widgets.resources.style

    readonly property real pad: Tokens.padding.large * sizeScale

    implicitWidth: content.implicitWidth + pad * 2
    implicitHeight: content.implicitHeight + pad * 2
    radius: Tokens.rounding.large * sizeScale
    color: showBackground ? Qt.alpha(Colours.palette.m3surfaceContainer, 0.78) : "transparent"
    border.width: showBackground ? 1 : 0
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Ref {
        service: SystemUsage
    }

    Loader {
        id: content
        anchors.centerIn: parent
        sourceComponent: {
            switch (root.style) {
            case "compact":
                return compactStyle;
            case "rings":
                return ringsStyle;
            default:
                return barsStyle;
            }
        }
    }

    // ── default: labelled rows with progress tracks ──────────────────────────
    Component {
        id: barsStyle

        Item {
            implicitWidth: 248 * root.sizeScale
            implicitHeight: col.implicitHeight

            ColumnLayout {
                id: col
                width: parent.width
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
    }

    // ── compact: icon + percent rows, no bars ────────────────────────────────
    Component {
        id: compactStyle

        ColumnLayout {
            spacing: Tokens.spacing.small * root.sizeScale

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
            spacing: Tokens.spacing.larger * root.sizeScale

            Ring {
                value: SystemUsage.cpuPerc
                colour: Colours.palette.m3primary
                label: qsTr("CPU")
            }
            Ring {
                value: SystemUsage.memPerc
                colour: Colours.palette.m3secondary
                label: qsTr("MEM")
            }
            Ring {
                value: SystemUsage.storagePerc
                colour: Colours.palette.m3tertiary
                label: qsTr("DSK")
            }
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

    component CompactStat: RowLayout {
        id: cstat

        required property string icon
        required property real value
        required property color colour

        spacing: Tokens.spacing.small * root.sizeScale

        MaterialIcon {
            text: cstat.icon
            color: cstat.colour
            font.pointSize: Tokens.font.size.larger * root.sizeScale
        }
        StyledText {
            text: Math.round(cstat.value * 100) + "%"
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.larger * root.sizeScale
            font.weight: Font.DemiBold
        }
    }

    component Ring: Item {
        id: ring

        required property real value
        required property color colour
        required property string label

        readonly property real ringSize: 60 * root.sizeScale

        implicitWidth: ringSize
        implicitHeight: ringSize + lbl.implicitHeight + Tokens.spacing.smaller * root.sizeScale

        Canvas {
            id: canvas
            width: ring.ringSize
            height: ring.ringSize
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            property real v: ring.value
            property color fg: ring.colour
            property color track: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

            onVChanged: requestPaint()
            onFgChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const lw = 5 * root.sizeScale;
                const r = width / 2 - lw;
                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.strokeStyle = canvas.track;
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.max(0.001, canvas.v) * 2 * Math.PI);
                ctx.strokeStyle = canvas.fg;
                ctx.stroke();
            }

            StyledText {
                anchors.centerIn: parent
                text: Math.round(ring.value * 100) + ""
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.normal * root.sizeScale
                font.weight: Font.DemiBold
            }
        }

        StyledText {
            id: lbl
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            color: ring.colour
            font.pointSize: Tokens.font.size.small * root.sizeScale
            font.letterSpacing: 1
        }
    }
}
