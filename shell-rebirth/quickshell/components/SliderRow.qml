pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../colors" as ColorsModule

Item {
    id: root

    readonly property int fontMedium: 14
    readonly property int fontLarge: 22
    readonly property int animSmall: 120
    readonly property int animFast: 90
    readonly property int moveFast: 100
    readonly property int rounding: 6

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 0
    property int snapMode: stepSize > 0 ? Slider.SnapAlways : Slider.NoSnap

    signal moved(real value)

    property string label: ""
    property bool showValue: true
    property string valuePrefix: ""
    property string valueSuffix: ""
    property int valuePrecision: 0

    property real trackHeightDiff: 30
    property real handleGap: 6
    property bool useAnim: true
    property int iconSize: fontLarge
    property string icon: ""

    property color accentColor: ColorsModule.Colors.primary
    property color trackColor: ColorsModule.Colors.surface_container_high
    property color labelColor: ColorsModule.Colors.on_surface
    property color valueColor: ColorsModule.Colors.on_surface_variant

    Layout.fillWidth: true
    implicitWidth: 200
    implicitHeight: label !== "" ? 60 : 40

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: label !== "" ? 20 : 0
            visible: label !== ""

            RowLayout {
                anchors.fill: parent
                spacing: 12

                Text {
                    visible: root.icon !== ""
                    text: root.icon
                    font.family: "Material Icons"
                    font.pixelSize: root.iconSize
                    color: root.accentColor
                }

                Text {
                    text: root.label
                    font.pixelSize: root.fontMedium
                    font.weight: Font.Medium
                    color: root.labelColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.showValue
                    text: {
                        let val = root.valuePrecision > 0
                            ? slider.value.toFixed(root.valuePrecision)
                            : Math.round(slider.value)
                        return root.valuePrefix + val + root.valueSuffix
                    }
                    font.pixelSize: root.fontMedium
                    font.weight: Font.DemiBold
                    font.family: "JetBrains Mono"
                    color: root.valueColor
                }
            }
        }

        Slider {
            id: slider

            Layout.fillWidth: true
            Layout.preferredHeight: 40

            from: root.from
            to: root.to
            value: root.value
            stepSize: root.stepSize
            snapMode: root.snapMode

            onMoved: root.moved(value)

            background: Item {
                anchors.fill: parent

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: slider.visualPosition * slider.width
                    height: slider.height - root.trackHeightDiff
                    radius: height / 2
                    color: root.accentColor

                    Behavior on width {
                        NumberAnimation {
                            duration: root.useAnim ? root.animSmall : 0
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                /* ===== Unfilled ===== */
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: (1 - slider.visualPosition) * slider.width
                    height: slider.height - root.trackHeightDiff
                    radius: height / 2
                    color: root.trackColor

                    Behavior on width {
                        NumberAnimation {
                            duration: root.useAnim ? root.animSmall : 0
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            handle: Rectangle {
                x: slider.visualPosition * (slider.width - width)
                anchors.verticalCenter: parent.verticalCenter

                width: slider.pressed ? 24 : 20
                height: width
                radius: width / 2
                color: root.accentColor

                Behavior on x {
                    NumberAnimation {
                        duration: root.moveFast
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on width {
                    NumberAnimation { duration: root.animFast }
                }
            }
        }
    }
}
