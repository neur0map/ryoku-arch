import QtQuick
import "../modules"

// QUICK | CONFIGURE mode switch. Neutral hover; accent only on the selected tab.
Row {
    id: tabs
    property var root
    property string current: "quick"
    signal chose(string mode)

    spacing: 4

    Repeater {
        model: [ { key: "quick", label: "QUICK" }, { key: "configure", label: "CONFIGURE" } ]
        delegate: Rectangle {
            id: tab
            required property var modelData
            readonly property bool on: tabs.current === modelData.key
            readonly property color hf: Qt.rgba(tabs.root.ink.r, tabs.root.ink.g, tabs.root.ink.b, 0.06)
            readonly property color hb: Qt.rgba(tabs.root.ink.r, tabs.root.ink.g, tabs.root.ink.b, 0.28)
            width: Math.max(96, lbl.implicitWidth + 26)
            height: 30
            radius: tabs.root.tileRadius
            color: on ? Qt.rgba(tabs.root.seal.r, tabs.root.seal.g, tabs.root.seal.b, 0.14)
                      : (ma.containsMouse ? tab.hf : tabs.root.fillIdle)
            border.width: 1
            border.color: on ? Qt.rgba(tabs.root.seal.r, tabs.root.seal.g, tabs.root.seal.b, 0.52)
                             : (ma.containsMouse ? tab.hb : tabs.root.sep)
            Behavior on color { ColorAnimation { duration: 120 } }
            UiText {
                id: lbl
                anchors.centerIn: parent
                text: tab.modelData.label
                color: tab.on ? tabs.root.seal : tabs.root.ink
                font.family: tabs.root.mono
                font.pixelSize: 11
                font.letterSpacing: 1
                font.weight: tab.on ? Font.DemiBold : Font.Normal
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tabs.chose(tab.modelData.key)
            }
        }
    }
}
