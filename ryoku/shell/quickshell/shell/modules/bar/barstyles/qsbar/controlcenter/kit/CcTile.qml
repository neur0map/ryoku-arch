import QtQuick
import "../../modules"

// A thin action row (Shibumi ActionTile 1:1): leading icon glyph, label, detail.
// Neutral at rest AND on hover; accent only when `active`. Colours from root.
Rectangle {
    id: tile
    property var root
    property string label: ""
    property string icon: ""
    property string sub: ""
    property color accent: root ? root.seal : "#888888"
    property bool active: false
    signal activated()

    readonly property color hoverFill: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06) : "#161616"
    readonly property color hoverBorder: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28) : "#444444"

    height: 40
    radius: root ? root.tileRadius : 6
    opacity: enabled ? 1.0 : 0.4
    color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.08)
                  : (ma.containsMouse ? hoverFill : (root ? root.fillIdle : "#111111"))
    border.width: 1
    border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.52)
                         : (ma.containsMouse ? hoverBorder : (root ? root.sep : "#333333"))
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        anchors.left: parent.left; anchors.leftMargin: 9
        anchors.right: parent.right; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        IconText {
            visible: tile.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: tile.icon
            color: tile.active ? tile.accent : (tile.root ? tile.root.ink : "#cccccc")
            opacity: 0.88
            font.pixelSize: 17
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            UiText {
                text: tile.label
                color: tile.active ? tile.accent : (tile.root ? tile.root.ink : "#cccccc")
                font.family: tile.root ? tile.root.mono : "monospace"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            UiText {
                visible: tile.sub !== ""
                text: tile.sub
                color: tile.root ? tile.root.ink : "#cccccc"
                opacity: 0.42
                font.family: tile.root ? tile.root.mono : "monospace"
                font.pixelSize: 10
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.activated()
    }
}
