pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Ryoku.Config
import qs.components
import qs.services

// Desktop battery pill. The pill itself fills with the charge level (left→right),
// eased success → amber → error, with a charging bolt and a slow shimmer while
// plugged in. Reuses WidgetCard for the frosted glass; the fill lives in its
// full-bleed `backdrop` slot so it bleeds to the rounded edges.
WidgetCard {
    id: root

    radius: Tokens.rounding.full
    tintColour: root.levelColour

    readonly property real perc: UPower.displayDevice.percentage
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool low: root.perc <= 0.2 && !root.charging
    readonly property color levelColour: root.charging ? Colours.palette.m3success : root.low ? Colours.palette.m3error : root.perc <= 0.4 ? Colours.palette.m3tertiary : Colours.palette.m3primary

    property real animPerc: root.perc

    Behavior on animPerc {
        Anim {
            type: Anim.EmphasizedLarge
        }
    }

    backdrop: StyledRect {
        id: fill

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * root.animPerc
        visible: root.showBackground
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.alpha(root.levelColour, 0.3)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(root.levelColour, 0.5)
            }
        }

        // Charging shimmer: a slow breathe while plugged in.
        SequentialAnimation {
            running: root.charging && root.showBackground
            loops: Animation.Infinite
            alwaysRunToEnd: true
            onRunningChanged: if (!running) fill.opacity = 1

            NumberAnimation {
                target: fill
                property: "opacity"
                from: 1
                to: 0.62
                duration: 1100
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: fill
                property: "opacity"
                from: 0.62
                to: 1
                duration: 1100
                easing.type: Easing.InOutSine
            }
        }
    }

    RowLayout {
        spacing: Tokens.spacing.small * root.sizeScale

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: root.charging ? "bolt" : "battery_horiz_075"
            fill: 1
            color: root.levelColour
            font.pointSize: Tokens.font.size.extraLarge * root.sizeScale

            Behavior on color {
                CAnim {}
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Math.round(root.perc * 100) + "%"
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
            font.weight: Font.Bold
        }
    }
}
