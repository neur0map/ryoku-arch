pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One theme tile, in the Extras catalogue style: a big monospace ordinal, an
// active mark, the theme's tags, its name, the one-line summary of what it changes,
// a blurb, and a palette swatch strip, over a flat warm surface with a hairline
// that warms to ember on hover. No gradient. Clicking applies the theme.
Rectangle {
    id: tile

    property var theme: ({})
    property int ordinal: 0
    property bool active: false
    property bool busy: false
    signal applied()

    implicitHeight: body.implicitHeight + 38
    radius: 16
    color: hover.hovered ? Theme.surface : Theme.surfaceLo
    border.width: tile.active ? 2 : 1
    border.color: (tile.active || hover.hovered) ? Theme.ember : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.quick } }
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 0

        Item {
            width: parent.width
            height: number.implicitHeight

            Text {
                id: number
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: (tile.ordinal < 10 ? "0" : "") + tile.ordinal
                color: (tile.active || hover.hovered) ? Theme.ember : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 26
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                visible: tile.active || tile.busy

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.ember
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.busy ? "APPLYING" : "ACTIVE"
                    color: Theme.ember
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                }
            }
        }

        Text {
            width: parent.width
            topPadding: 16
            text: (tile.theme.tags || []).join("  \u00b7  ")
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 8
            text: tile.theme.name || ""
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 18
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 4
            visible: (tile.theme.summary || "") !== ""
            text: tile.theme.summary || ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 12
            text: tile.theme.blurb || ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.32
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            topPadding: 16
            spacing: 5
            Repeater {
                model: tile.theme.swatch || []
                delegate: Rectangle {
                    required property string modelData
                    width: (body.width - 25) / 6
                    height: 8
                    radius: 4
                    color: modelData
                }
            }
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        anchors.bottomMargin: 16
        name: "chevron"
        size: 15
        weight: 2
        rotation: -90
        tint: Theme.ember
        opacity: (hover.hovered && !tile.active) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (!tile.active) tile.applied() }
}
