pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * Tools section of the 力 deck: screen-capture helpers (Lens, Color, OCR, Mirror,
 * QR) as a flat tile strip with hairline dividers over a Ryoku wave signature.
 * Each tile runs a self-contained ~/.config/hypr/scripts helper and dismisses the
 * deck (via requestClose) so the action owns the whole screen. Keep-awake now
 * lives in the Utilities section, so the old Caffeine toggle is gone from here.
 */
Item {
    id: tools

    property real s: 1
    signal requestClose()

    implicitHeight: strip.height + 12 * s + waveSig.height

    readonly property string scripts: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/"

    readonly property var items: [
        { "key": "lens",   "glyph": "lens",       "label": "Lens",   "argv": [tools.scripts + "ryoku-cmd-google-lens"] },
        { "key": "color",  "glyph": "eyedropper", "label": "Color",  "argv": [tools.scripts + "ryoku-cmd-color-picker"] },
        { "key": "ocr",    "glyph": "ocr",        "label": "OCR",    "argv": [tools.scripts + "ryoku-cmd-ocr"] },
        { "key": "mirror", "glyph": "webcam",     "label": "Mirror", "argv": [tools.scripts + "ryoku-cmd-mirror"] },
        { "key": "qr",     "glyph": "qr",         "label": "QR",     "argv": [tools.scripts + "ryoku-cmd-qr-scan"] }
    ]

    property string hovered: ""
    property var pendingArgv: null

    // Tools grab the screen (slurp region, hyprpicker freeze); the deck holds
    // exclusive focus and would be frozen into the pick. Close, let the morph
    // settle, then launch.
    function launch(argv) {
        tools.pendingArgv = argv;
        tools.requestClose();
        launchTimer.restart();
    }
    Timer {
        id: launchTimer
        interval: 400
        onTriggered: {
            if (tools.pendingArgv) {
                Quickshell.execDetached(tools.pendingArgv);
                tools.pendingArgv = null;
            }
        }
    }

    Item {
        id: strip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60 * tools.s

        Row {
            id: tileRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16 * tools.s

            Repeater {
                model: tools.items

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index

                    readonly property bool lit: tools.hovered === tile.modelData.key

                    width: 40 * tools.s
                    height: 60 * tools.s

                    transform: Translate {
                        y: tile.lit ? -3 * tools.s : 0
                        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    }

                    Rectangle {
                        id: btn
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40 * tools.s
                        height: 40 * tools.s
                        radius: 3 * tools.s
                        color: tile.lit ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: tile.lit ? Theme.frameBorder : Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 15 * tools.s
                            height: 15 * tools.s
                            name: tile.modelData.glyph
                            color: tile.lit ? Theme.cream : Theme.iconDim
                            stroke: 1.6
                        }
                    }

                    Text {
                        anchors.top: btn.bottom
                        anchors.topMargin: 6 * tools.s
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        color: tile.lit ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9.5 * tools.s
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: tools.hovered = tile.modelData.key
                        onExited: if (tools.hovered === tile.modelData.key) tools.hovered = ""
                        onClicked: tools.launch(tile.modelData.argv)
                    }

                    // Hairline divider to the next tile.
                    Rectangle {
                        visible: tile.index < tools.items.length - 1
                        width: 1
                        height: 22 * tools.s
                        color: Theme.hair
                        x: tile.width + (tileRow.spacing - width) / 2
                        y: (btn.height - height) / 2
                    }
                }
            }
        }
    }

    // Ryoku wave signature under the strip.
    WaveMeter {
        id: waveSig
        anchors.top: strip.bottom
        anchors.topMargin: 12 * tools.s
        anchors.left: parent.left
        anchors.right: parent.right
        s: tools.s
        frac: 1
    }
}
