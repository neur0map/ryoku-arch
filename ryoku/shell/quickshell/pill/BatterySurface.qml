pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// BATTERY surface = laptop battery, carbon dossier idiom. an eyebrow header,
// percentage as hero over its state subline, bold Ryoku wave as the gauge, then
// rate / time / capacity / health as figures split by hairlines, mono
// micro-labels and tabular figures. charging warms the percentage, subline and
// wave to flame tones. exposes implicitHeight from content.
PillSurface {
    id: root

    mTop: 16
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitHeight: content.implicitHeight

    ameForm: "off"

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // header: 力 BATTERY + state
        Item {
            width: parent.width
            height: 22 * root.s

            Eyebrow {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: "Battery"
                s: root.s
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.stateLabel
                color: Battery.charging ? Theme.flameGlow : Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }
        }

        // hero: percentage + state subline
        Column {
            width: parent.width
            topPadding: 18 * root.s
            spacing: 7 * root.s

            Text {
                id: pctText
                text: Battery.pct + "%"
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.cream)
                font.family: Theme.font
                font.pixelSize: 54 * root.s
                font.weight: Font.Bold
                font.letterSpacing: -1.5 * root.s
                font.features: { "tnum": 1 }
            }

            Text {
                readonly property string body: Battery.full
                    ? "Plugged in"
                    : (Battery.hasTime
                        ? Battery.timeStr + (Battery.charging ? " to full" : " remaining")
                        : "")
                visible: body.length > 0
                text: body
                color: Battery.charging ? Theme.flameCore : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
        }

        // charge gauge: a bold Ryoku wave
        Column {
            width: parent.width
            topPadding: 18 * root.s
            bottomPadding: 18 * root.s
            spacing: 9 * root.s

            Item {
                width: parent.width
                height: chargeLbl.implicitHeight

                Text {
                    id: chargeLbl
                    anchors.left: parent.left
                    text: "CHARGE"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2 * root.s
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: chargeLbl.baseline
                    text: Battery.pct + "%"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            WaveMeter {
                width: parent.width
                s: root.s * 1.8
                frac: Battery.frac
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 16 * root.s }

        // stat quadrants: rate / time over capacity / health, figures split by
        // hairlines (the dossier idiom), no boxes. mono micro-labels, tabular figures.
        Column {
            id: statGrid
            width: parent.width
            spacing: 0

            component Stat: Column {
                id: stat
                property string label: ""
                property string value: ""
                property bool warm: false
                spacing: 3 * root.s

                Text {
                    text: stat.value
                    color: stat.warm ? Theme.flameGlow : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 17 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: stat.label
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.4 * root.s
                }
            }

            component StatRow: Item {
                width: statGrid.width
                height: 46 * root.s
                default property alias content: cells.data
                Row { id: cells; anchors.fill: parent }
            }

            StatRow {
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Stat {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Rate"
                        value: Math.abs(Battery.rateW) >= 0.05
                            ? (Battery.rateW > 0 ? "+" : "\u2212") + Math.abs(Battery.rateW).toFixed(1) + " W"
                            : "0 W"
                        warm: Battery.charging
                    }
                }
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 28 * root.s
                        color: Theme.hair
                    }
                    Stat {
                        anchors.left: parent.left
                        anchors.leftMargin: 18 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Time"
                        value: Battery.hasTime ? Battery.timeStr : (Battery.full ? "Full" : "\u2014")
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hair }

            StatRow {
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Stat {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Capacity"
                        value: Battery.capacityWh >= 1 ? Battery.capacityWh.toFixed(1) + " Wh" : "\u2014"
                    }
                }
                Item {
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 28 * root.s
                        color: Theme.hair
                    }
                    Stat {
                        anchors.left: parent.left
                        anchors.leftMargin: 18 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Health"
                        value: Battery.healthSupported ? Battery.health + "%" : "\u2014"
                        warm: Battery.healthSupported
                    }
                }
            }
        }

        // breathing room under the grid.
        Item { width: 1; height: 4 * root.s }
    }
}
