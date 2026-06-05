import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.ambxst.modules.theme
import qs.ambxst.modules.components

    StyledRect {
    variant: "bg"
    id: root

    visible: hasItems

    topLeftRadius: root.vertical ? root.startRadius : root.startRadius
    topRightRadius: root.vertical ? root.startRadius : root.endRadius
    bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
    bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

    required property var bar
    
    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property bool vertical: bar.orientation === "vertical"

    readonly property bool hasItems: rowRepeater.count > 0 || columnRepeater.count > 0

    height: vertical ? implicitHeight : parent.height
    Layout.preferredWidth: hasItems ? ((vertical ? columnLayout.implicitWidth : rowLayout.implicitWidth) + 16) : 0
    implicitWidth: hasItems ? ((vertical ? columnLayout.implicitWidth : rowLayout.implicitWidth) + 16) : 0
    implicitHeight: hasItems ? ((vertical ? columnLayout.implicitHeight : rowLayout.implicitHeight) + 16) : 0

    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: rowRepeater
            model: SystemTray.items

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
            }
        }
    }

    ColumnLayout {
        id: columnLayout
        visible: root.vertical
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            id: columnRepeater
            model: SystemTray.items

            SysTrayItem {
                required property SystemTrayItem modelData
                bar: root.bar
                item: modelData
            }
        }
    }
}
