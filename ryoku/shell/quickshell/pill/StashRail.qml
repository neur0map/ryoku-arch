pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The stash action rail: a vertical column of buttons down the left of the
 * stash surface. Send every file over LocalSend, install dropped AppImages and
 * tarballs into the app launcher, compress media through ffmpeg, and pull media
 * in with yt-dlp. The file actions dim when the stash is empty; download stays
 * live since it brings files in. Hovering a button slides its name out beside
 * it. The work itself lives in helper scripts behind the Stash singleton.
 */
Column {
    id: root

    property real s: 1
    property bool hasFiles: false

    signal sendAll()
    signal install()
    signal compress()
    signal download()

    spacing: 12 * s

    component RailButton: Item {
        id: btn

        property string glyph: ""
        property string label: ""
        property bool active: true

        signal triggered()

        width: 36 * root.s
        height: 36 * root.s
        opacity: active ? 1 : 0.3

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

        Rectangle {
            anchors.fill: parent
            radius: Motion.rSmall * root.s
            color: area.containsMouse && btn.active ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: area.containsMouse && btn.active ? Theme.frameBorder : Theme.border

            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            GlyphIcon {
                anchors.centerIn: parent
                width: 17 * root.s
                height: 17 * root.s
                name: btn.glyph
                color: area.containsMouse && btn.active ? Theme.cream : Theme.iconDim
                stroke: 1.7
            }
        }

        // Name tag that slides out beside the button on hover.
        Rectangle {
            anchors.left: parent.right
            anchors.leftMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: tagText.implicitWidth + 16 * root.s
            height: 22 * root.s
            radius: height / 2
            color: Theme.cardBot
            border.width: 1
            border.color: Theme.border
            opacity: area.containsMouse && btn.active ? 1 : 0
            visible: opacity > 0.01
            z: 5

            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            Text {
                id: tagText
                anchors.centerIn: parent
                text: btn.label
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.active
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    RailButton {
        glyph: "send"
        label: "Send all"
        active: root.hasFiles
        onTriggered: root.sendAll()
    }
    RailButton {
        glyph: "install"
        label: "Install apps"
        active: root.hasFiles
        onTriggered: root.install()
    }
    RailButton {
        glyph: "compress"
        label: "Compress"
        active: root.hasFiles
        onTriggered: root.compress()
    }
    RailButton {
        glyph: "download"
        label: "Download"
        onTriggered: root.download()
    }
}
