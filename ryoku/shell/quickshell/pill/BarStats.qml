pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// CPU / RAM / temp readout for the Nacre bar. reads the SysStats singleton and
// keeps its poller awake while shown; each item is a glyph + value, tinted like
// the status glyphs and warn-tinted over threshold. click opens the resources
// popout. `vertical` stacks the items for a side bar.
Grid {
    id: stats

    property real s: 1
    property bool vertical: false

    signal requestPopout(string name, real center)

    readonly property real glyphPx: 14 * s

    columns: vertical ? 1 : 3
    columnSpacing: 11 * s
    rowSpacing: 7 * s
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    Component.onCompleted: SysStats.active = true
    Component.onDestruction: SysStats.active = false

    function open(item) {
        const p = item.mapToItem(null, item.width / 2, item.height / 2);
        stats.requestPopout("resources", stats.vertical ? p.y : p.x);
    }

    component StatItem: Item {
        id: it
        property string glyph: ""
        property string value: ""
        property bool warn: false
        implicitWidth: itRow.implicitWidth
        implicitHeight: itRow.implicitHeight

        Row {
            id: itRow
            anchors.centerIn: parent
            spacing: 3 * stats.s
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: it.glyph
                fill: 1
                color: it.warn ? Theme.vermLit : Theme.subtle
                font.pixelSize: stats.glyphPx
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: it.value
                color: it.warn ? Theme.vermLit : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9.5 * stats.s
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: stats.open(it)
        }
    }

    StatItem { glyph: "memory"; value: SysStats.cpu + "%"; warn: SysStats.cpu > 85 }
    StatItem { glyph: "developer_board"; value: SysStats.mem + "%"; warn: SysStats.mem > 90 }
    StatItem {
        visible: SysStats.tempAvailable
        glyph: "device_thermostat"
        value: SysStats.temp + "\u00b0"
        warn: SysStats.temp > 80
    }
}
