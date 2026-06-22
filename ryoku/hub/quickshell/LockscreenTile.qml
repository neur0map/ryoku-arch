pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One lock-skin tile, in the Extras/Themes catalogue style: a looping preview of
// the actual qylock lockscreen as the hero, then a big monospace ordinal with an
// active mark, the theme tag, the skin name, a one-line summary, and a blurb,
// over a flat warm surface whose hairline warms to ember on hover. Clicking the
// tile selects the skin (writes the qylock theme preference); the Preview chip
// shows it live without changing the selection. Mirrors ThemeTile.
Rectangle {
    id: tile

    property var skin: ({})
    property int ordinal: 0
    property bool active: false
    property bool busy: false
    signal applied()
    signal previewed()

    implicitHeight: body.implicitHeight + 34
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
        anchors.margins: 16
        spacing: 0

        // --- preview hero: a looping frame of the actual lockscreen ---
        Rectangle {
            id: media
            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: 8
            color: Theme.keyBot
            border.width: 1
            border.color: (tile.active || hover.hovered) ? Theme.ember : Theme.line
            clip: true
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            AnimatedImage {
                id: gif
                anchors.fill: parent
                anchors.margins: 1
                source: (tile.skin.preview || "") !== "" ? "file://" + tile.skin.preview : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                playing: tile.visible
            }

            // shown when a skin ships no preview, or while it loads
            Icon {
                anchors.centerIn: parent
                visible: gif.status !== AnimatedImage.Ready
                name: "lock"
                size: 32
                tint: Theme.faint
            }

            // live-preview chip: shows the lock full screen without selecting it
            Rectangle {
                id: previewChip
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: pvRow.implicitWidth + 20
                height: 28
                radius: 14
                color: Qt.rgba(0, 0, 0, 0.55)
                border.width: 1
                border.color: pvArea.containsMouse ? Theme.ember : Qt.rgba(1, 1, 1, 0.18)
                opacity: (hover.hovered || pvArea.containsMouse) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                Row {
                    id: pvRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "play"; size: 11; weight: 2; tint: Theme.bright }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Preview"
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: pvArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.previewed()
                }
            }
        }

        Item { width: 1; height: 16 }

        // --- ordinal + active mark ---
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
            topPadding: 14
            text: (tile.skin.tags || []).join("  \u00b7  ")
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
            text: tile.skin.name || ""
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 18
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 4
            visible: (tile.skin.summary || "") !== ""
            text: tile.skin.summary || ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 10
            visible: (tile.skin.blurb || "") !== ""
            text: tile.skin.blurb || ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.32
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
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
