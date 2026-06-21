import QtQuick
import "Singletons"

// One bento tile: a bundle at a glance. The ember badge, the name and its source
// tags, a blurb, and an installed count, with a hover lift. The tile sizes to its
// content so the page can lay tiles out as a ragged bento mosaic. Clicking it
// opens the bundle detail where per-tool install and removal happens.
Rectangle {
    id: tile

    property var bundle: ({})
    property int installedCount: 0
    readonly property int totalCount: bundle.items ? bundle.items.length : 0
    readonly property bool anyInstalled: tile.installedCount > 0

    signal opened()

    implicitHeight: body.implicitHeight + 36
    radius: 18
    color: hover.hovered ? Theme.surface : Theme.surfaceLo
    border.width: 1
    border.color: hover.hovered ? Qt.rgba(0.95, 0.42, 0.18, 0.4) : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.quick } }
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    scale: hover.hovered ? 1.012 : 1
    Behavior on scale { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        spacing: 0

        Item {
            width: parent.width
            height: 40

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.ember }
                    GradientStop { position: 1.0; color: Theme.emberDeep }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "sparkles"
                    size: 20
                    weight: 1.6
                    tint: Theme.onAccent
                }
            }

            Icon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron"
                size: 16
                weight: 2
                rotation: -90
                tint: hover.hovered ? Theme.ember : Theme.faint
                Behavior on tint { ColorAnimation { duration: Theme.quick } }
            }
        }

        Text {
            width: parent.width
            topPadding: 14
            text: tile.bundle.name || ""
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 4
            text: tile.bundle.sources || ""
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
            topPadding: 12
            bottomPadding: 16
            text: tile.bundle.description || ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            lineHeight: 1.3
            wrapMode: Text.WordWrap
            maximumLineCount: 5
            elide: Text.ElideRight
        }

        Item {
            width: parent.width
            height: 16

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: tile.anyInstalled ? Theme.ok : Theme.faint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.installedCount + " / " + tile.totalCount + " installed"
                    color: tile.anyInstalled ? Theme.cream : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "View"
                color: hover.hovered ? Theme.ember : Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                opacity: hover.hovered ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.opened() }
}
