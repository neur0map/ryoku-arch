pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The stash action bar along the bottom of the surface. Send the whole stash or
 * a typed note over LocalSend, pull a copied link in with yt-dlp, and shrink or
 * install what is already stashed. Actions that act on the files dim when the
 * stash is empty; Text and Download stay live since they bring content in. Tiles
 * lift and light on hover, matching the toolkit surface; a hairline separates the
 * outgoing actions from the ones that manage what is here.
 */
Row {
    id: root

    property real s: 1
    property bool hasFiles: false
    property bool hasMedia: false
    property bool hasInstallable: false

    signal sendAll()
    signal sendText()
    signal download()
    signal compress()
    signal install()

    spacing: 6 * s

    component ActionTile: Item {
        id: t

        property string glyph: ""
        property string label: ""
        property bool active: true

        signal triggered()

        readonly property bool lit: area.containsMouse && t.active

        width: 56 * root.s
        height: 50 * root.s
        opacity: active ? 1 : 0.3

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

        transform: Translate {
            y: t.lit ? -2 * root.s : 0
            Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }

        Rectangle {
            id: chip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40 * root.s
            height: 34 * root.s
            radius: Motion.rSmall * root.s
            color: t.lit ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: t.lit ? Theme.frameBorder : Theme.border

            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            GlyphIcon {
                anchors.centerIn: parent
                width: 17 * root.s
                height: 17 * root.s
                name: t.glyph
                color: t.lit ? Theme.cream : Theme.iconDim
                stroke: 1.7
            }
        }

        Text {
            anchors.top: chip.bottom
            anchors.topMargin: 5 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            text: t.label
            color: t.lit ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6 * root.s
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: t.active
            cursorShape: Qt.PointingHandCursor
            onClicked: t.triggered()
        }
    }

    ActionTile {
        glyph: "send"
        label: "Send all"
        active: root.hasFiles
        onTriggered: root.sendAll()
    }
    ActionTile {
        glyph: "text"
        label: "Text"
        onTriggered: root.sendText()
    }

    // Divider: outgoing on the left, manage-what-is-here on the right.
    Item {
        width: 11 * root.s
        height: 50 * root.s
        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8 * root.s
            width: 1
            height: 22 * root.s
            color: Theme.hair
        }
    }

    ActionTile {
        glyph: "download"
        label: "Download"
        onTriggered: root.download()
    }
    ActionTile {
        glyph: "compress"
        label: "Compress"
        active: root.hasMedia
        onTriggered: root.compress()
    }
    ActionTile {
        glyph: "install"
        label: "Install"
        active: root.hasInstallable
        onTriggered: root.install()
    }
}
