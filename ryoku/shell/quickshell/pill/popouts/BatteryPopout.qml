pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"

// battery popout content: a compact laptop-battery readout drawn straight from
// the Battery singleton. a BATTERY eyebrow, the percentage as a hero figure
// with its state riding the baseline, a thin charge bar, then the meaningful
// numbers (time, draw, capacity, health) as mono-labelled rows. a bare,
// transparent Item -- the Popout blob behind it IS the surface; this panel only
// reports its implicit size so the popout melts open to fit and shrinks when a
// row has nothing to say. pointer-driven, no keyboard focus.
Item {
    id: root

    property real s: 1
    // popout open flag (content contract): no live polling lives here -- the
    // Battery singleton feeds itself off UPower -- but we honour the contract.
    property bool open: false

    anchors.fill: parent

    implicitWidth: 260 * s
    implicitHeight: body.implicitHeight + 27 * s

    // is any detail row worth drawing? gates the divider + rows so a bone-dry
    // reading (on AC, full, no rate or health) never leaves a dangling hairline.
    readonly property bool hasDetails: Battery.hasTime || Battery.rateW !== 0
        || Battery.capacityWh > 0 || Battery.healthSupported

    // charge tint shared by the hero number and the bar fill: vermilion when
    // low, flame while charging, cream at rest.
    readonly property color chargeTint: Battery.low ? Theme.vermLit
        : (Battery.charging ? Theme.flameGlow : Theme.cream)

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    // one figure row: a mono eyebrow label on the left, a tabular value on the
    // right riding its baseline. collapses out of the Column when not visible.
    component InfoRow: Item {
        id: infoRow

        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        height: rowLabel.implicitHeight

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: infoRow.label
            color: Theme.subtle
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }
        Text {
            anchors.right: parent.right
            anchors.baseline: rowLabel.baseline
            text: infoRow.value
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 11 * root.s

        // header: state-tinted battery glyph + BATTERY eyebrow, Mixer idiom.
        Row {
            spacing: 8 * root.s

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.low ? "battery_alert"
                    : (Battery.charging ? "battery_charging_full" : "battery_full")
                fill: 1
                color: Battery.low ? Theme.vermLit
                    : (Battery.charging ? Theme.flameGlow : Theme.brand)
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

        // hero: percentage as the figure, the state label on its baseline.
        Item {
            width: parent.width
            height: pctText.implicitHeight

            Text {
                id: pctText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.pct + "%"
                color: root.chargeTint
                font.family: Theme.font
                font.pixelSize: 26 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: -0.5 * root.s
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: pctText.baseline
                text: Battery.stateLabel
                color: Battery.charging ? Theme.flameCore : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
        }

        // charge bar: a frameBg track with a chargeTint fill sized to the frac.
        Rectangle {
            width: parent.width
            height: 6 * root.s
            radius: height / 2
            color: Theme.frameBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(parent.width * Battery.frac)
                height: parent.height
                radius: parent.radius
                color: root.chargeTint

                Behavior on width { NumberAnimation { duration: Motion.effects; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Motion.effects } }
            }
        }

        Divider { visible: root.hasDetails }

        // figures: only the meaningful rows; each collapses when it has nothing.
        Column {
            width: parent.width
            spacing: 8 * root.s
            visible: root.hasDetails

            InfoRow {
                visible: Battery.hasTime
                label: Battery.charging ? "Until full" : "Remaining"
                value: Battery.timeStr
            }
            InfoRow {
                visible: Battery.rateW !== 0
                label: Battery.discharging ? "Draw" : "Charging"
                value: Math.abs(Battery.rateW).toFixed(1) + " W"
            }
            InfoRow {
                visible: Battery.capacityWh > 0
                label: "Capacity"
                value: Battery.capacityWh.toFixed(1) + " Wh"
            }
            InfoRow {
                visible: Battery.healthSupported
                label: "Health"
                value: Battery.health + "%"
            }
        }
    }
}
