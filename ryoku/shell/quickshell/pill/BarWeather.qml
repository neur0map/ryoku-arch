pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// weather module: the condition symbol + the temperature, read from the shared
// Weather singleton (Open-Meteo, no key). the Weather model's glyph names map to
// Material Symbols here so the readout matches the status cluster's iconography.
// click opens the weather popout at the module. hidden until a reading lands, so
// the slot only exists with real data. root is an Item (not a Row) so the click
// MouseArea can fill it without fighting a positioner.
Item {
    id: wx

    property real s: 1
    property bool vertical: false

    signal requestPopout(string name, real center)

    readonly property var symFor: ({
        "sun": "clear_day", "cloud": "cloud", "fog": "foggy",
        "rain": "rainy", "snow": "weather_snowy", "storm": "thunderstorm"
    })

    visible: Weather.available
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function open() {
        const p = wx.mapToItem(null, wx.width / 2, wx.height / 2);
        wx.requestPopout("weather", wx.vertical ? p.y : p.x);
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4 * wx.s

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * wx.s
            height: 16 * wx.s
            MaterialIcon {
                anchors.centerIn: parent
                text: wx.symFor[Weather.glyph] || "cloud"
                fill: 1
                color: Theme.subtle
                font.pixelSize: 14 * wx.s
            }
        }
        Text {
            visible: !wx.vertical
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.temp
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10.5 * wx.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: wx.open()
    }
}
