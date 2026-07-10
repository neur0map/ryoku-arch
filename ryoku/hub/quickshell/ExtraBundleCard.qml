import QtQuick
import QtQuick.Effects
import "Singletons"

// storefront tile for one bundle: a hero image up top with a warm scrim carrying
// the 力 mark + name and an install-progress badge, then tagline and source /
// tool-count chips on the warm surface below. on hover the hairline warms to
// ember, the image eases in, and the tile lifts, so the grid reads like an app
// store. click opens the rich detail. mirrors PluginStoreCard.
Rectangle {
    id: tile

    property var bundle: ({})
    property int installedCount: 0
    readonly property int totalCount: bundle.items ? bundle.items.length : 0
    readonly property bool anyInstalled: tile.installedCount > 0
    readonly property bool allInstalled: tile.totalCount > 0 && tile.installedCount >= tile.totalCount
    readonly property string preview: tile.bundle.preview || ((tile.bundle.screenshots && tile.bundle.screenshots.length > 0) ? tile.bundle.screenshots[0] : "")

    signal opened()

    implicitWidth: 320
    implicitHeight: 300
    radius: Theme.radius
    color: hover.hovered ? Theme.surface : Theme.surfaceLo
    border.width: 1
    border.color: hover.hovered ? Theme.ember : Theme.line
    clip: true
    scale: hover.hovered ? 1.012 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.quick } }
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

    // ── hero image, top ─────────────────────────────────────────────────────
    Item {
        id: shot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 168
        clip: true

        // placeholder behind the image so a slow/missing load still reads.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.keyTop }
                GradientStop { position: 1.0; color: Theme.surfaceLo }
            }
            Icon {
                anchors.centerIn: parent
                name: tile.bundle.icon || "package"
                size: 34
                weight: 1.5
                tint: Theme.faint
                visible: img.status !== Image.Ready
            }
        }

        Image {
            id: img
            anchors.fill: parent
            source: tile.preview
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 720
            scale: hover.hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Theme.ease } }
        }

        // bottom scrim keeps the name legible over any image.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 84
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
            }
        }

        // install-progress badge, top-right.
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: badge.implicitWidth + 18
            height: 22
            radius: Theme.radius
            color: tile.allInstalled ? Qt.rgba(Theme.ok.r, Theme.ok.g, Theme.ok.b, 0.92)
                 : tile.anyInstalled ? Qt.rgba(0, 0, 0, 0.55)
                 : Qt.rgba(0, 0, 0, 0.55)
            border.width: tile.allInstalled ? 0 : 1
            border.color: Theme.hair
            Row {
                id: badge
                anchors.centerIn: parent
                spacing: 5
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: tile.allInstalled ? "check" : "package"
                    size: 11
                    weight: 2
                    tint: tile.allInstalled ? "#0d1208" : Theme.subtle
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.allInstalled ? "Installed" : (tile.installedCount + " / " + tile.totalCount)
                    color: tile.allInstalled ? "#0d1208" : Theme.subtle
                    font.family: tile.allInstalled ? Theme.font : Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }

        // name + brand mark over the scrim.
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u529b"
                color: Theme.brand
                font.family: Theme.fontJp
                font.pixelSize: 15
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 26
                text: tile.bundle.name || tile.bundle.id || ""
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 19
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    // ── tagline + source / count chips, below ───────────────────────────────
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: shot.bottom
        anchors.margins: 16
        spacing: 11

        Text {
            width: parent.width
            text: tile.bundle.tagline || tile.bundle.description || ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
            lineHeight: 1.3
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Row {
            spacing: 6
            Rectangle {
                visible: (tile.bundle.sources || "") !== ""
                height: 20
                width: srcLabel.implicitWidth + 16
                radius: Theme.radius
                color: Theme.keyBot
                border.width: 1
                border.color: Theme.line
                Text {
                    id: srcLabel
                    anchors.centerIn: parent
                    text: tile.bundle.sources || ""
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }
            Rectangle {
                height: 20
                width: countLabel.implicitWidth + 16
                radius: Theme.radius
                color: Theme.keyBot
                border.width: 1
                border.color: Theme.line
                Text {
                    id: countLabel
                    anchors.centerIn: parent
                    text: tile.totalCount + " tools"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }
        }
    }

    layer.enabled: hover.hovered
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
        shadowBlur: 1.0
        shadowVerticalOffset: 8
        autoPaddingEnabled: true
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.opened() }
}
