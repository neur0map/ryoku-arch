pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Singletons"

/**
 * 蓄 BATTERY surface: a carbon read-out for the laptop battery, in the Ryoku Hub
 * dossier language. The percentage is the hero over its state subline; a bold
 * Ryoku wave is the charge gauge; a 2x2 stat grid (rate / time / capacity /
 * health) reads off mono micro-labels and tabular figures beneath a hairline.
 * Charging warms the percentage, subline and wave to the flame tones. Exposes
 * `implicitHeight` from its content.
 */
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

        // ── Header: 力 BATTERY + state ─────────────────────────────────────
        Item {
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BATTERY"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
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

        // ── Hero: percentage + state subline ──────────────────────────────
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

        // ── Charge gauge: a bold Ryoku wave ───────────────────────────────
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

        // ── Stat grid: rate · time · capacity · health ────────────────────
        GridLayout {
            width: parent.width
            columns: 2
            columnSpacing: 0
            rowSpacing: 16 * root.s

            component Stat: Column {
                id: stat
                property string label: ""
                property string value: ""
                property bool warm: false
                Layout.fillWidth: true
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
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.4 * root.s
                }
            }

            Stat {
                label: "Rate"
                value: Math.abs(Battery.rateW) >= 0.05
                    ? (Battery.rateW > 0 ? "+" : "\u2212") + Math.abs(Battery.rateW).toFixed(1) + " W"
                    : "0 W"
                warm: Battery.charging
            }
            Stat {
                label: "Time"
                value: Battery.hasTime ? Battery.timeStr : (Battery.full ? "Full" : "\u2014")
            }
            Stat {
                label: "Capacity"
                value: Battery.capacityWh >= 1 ? Battery.capacityWh.toFixed(1) + " Wh" : "\u2014"
            }
            Stat {
                label: "Health"
                value: Battery.healthSupported ? Battery.health + "%" : "\u2014"
                warm: Battery.healthSupported
            }
        }

        // Breathing room under the grid.
        Item { width: 1; height: 4 * root.s }
    }
}
