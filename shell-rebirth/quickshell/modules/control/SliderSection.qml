import QtQuick.Layouts
import qs.components
import qs.services as Services

ColumnLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 8
    spacing: 14

    SliderRow {
        label: "Volume"
        icon: "󰕾"
        showValue: true
        valueSuffix: "%"
        value: Services.Volume.volume*100
        onMoved: Services.Volume.setVolume(value / 100)
    }

    SliderRow {
        icon: "󰃞"
        label: "Brightness"
        value: Services.System.brightness
        onMoved: Services.System.setBrightness(value)
        showValue: true
        valueSuffix: "%"
    }
}