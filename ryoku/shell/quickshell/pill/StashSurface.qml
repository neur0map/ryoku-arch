pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 力 STASH surface: a drop box over ~/Downloads/Stash that doubles as a LocalSend
 * hub. The grid shows what is stashed (image files render thumbnails, the rest a
 * type glyph); hovering a tile opens, sends, or removes it, and dragging files
 * onto the surface copies them in. The action bar sends the whole stash or a
 * typed note, pulls a copied link in, and shrinks or installs what is here, while
 * the header's Receive switch lets other devices push files straight into the
 * stash. Sending, receiving, and the long-running rail jobs raise focused sheets
 * over the grid; every state lives in the Stash singleton.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 18
    mRight: 18
    mBottom: 14

    ameForm: "off"

    // Fixed cell height and grid height so implicitHeight never depends on the
    // host-provided openW: the pill derives openW (its width) from this surface's
    // size, so reading it back here would form a binding loop. Cell WIDTH stays
    // dynamic (filled to `cols` columns) because that reads the laid-out grid
    // width, which never flows back into implicitHeight.
    readonly property int cols: 4
    readonly property real cellH: 104 * s
    readonly property real gridH: cellH * 2
    readonly property real headerH: 22 * s
    readonly property real actionsH: 50 * s

    implicitHeight: headerH + 12 * s + gridH + 12 * s + actionsH

    // An overlay (send / receive / task sheet) owns the body below the header.
    readonly property bool sheetOpen: Stash.lsState !== "idle"
        || Stash.recvState !== "idle"
        || Stash.dlOpen
        || (Stash.task !== "" && Stash.taskState !== "idle")

    // File-type category for the non-image tile glyph, by extension.
    function catGlyph(ext) {
        var e = ext.toLowerCase();
        if (/^(zip|tar|gz|tgz|bz2|xz|7z|rar|zst)$/.test(e)) return "archive";
        if (/^(mp4|mkv|webm|mov|avi|m4v)$/.test(e)) return "film";
        if (/^(mp3|flac|wav|ogg|opus|m4a|aac)$/.test(e)) return "music";
        if (/^(png|jpe?g|webp|gif|bmp|svg|tiff?|ico)$/.test(e)) return "image";
        if (/^(js|ts|jsx|tsx|py|sh|bash|c|h|cpp|hpp|rs|go|lua|json|ya?ml|toml|qml|css|html?|xml)$/.test(e)) return "code";
        if (/^(pdf|epub|md|txt|rtf|docx?|odt)$/.test(e)) return "text";
        return "file";
    }

    // ── Header ──────────────────────────────────────────────────────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerH

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "力"
                color: Theme.brand
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "STASH"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Stash.count > 0
                text: Stash.count + (Stash.count === 1 ? " file" : " files")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
                font.features: { "tnum": 1 }
            }

            // Receive switch: flip it and other LocalSend devices can push files
            // straight into the stash. Lit while listening, with a breathing dot.
            Rectangle {
                id: recvChip
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool on: Stash.recvState !== "idle"
                width: recvRow.implicitWidth + 18 * root.s
                height: 20 * root.s
                radius: height / 2
                color: recvChip.on ? Qt.alpha(Theme.flameGlow, 0.16)
                    : (recvArea.containsMouse ? Theme.frameBg : Theme.tileBg)
                border.width: 1
                border.color: recvChip.on ? Qt.alpha(Theme.flameGlow, 0.55)
                    : (recvArea.containsMouse ? Theme.frameBorder : Theme.border)

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Row {
                    id: recvRow
                    anchors.centerIn: parent
                    spacing: 5 * root.s

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6 * root.s
                        height: 6 * root.s
                        radius: width / 2
                        color: recvChip.on ? Theme.flameGlow : Theme.iconDim
                        SequentialAnimation on opacity {
                            running: recvChip.on
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.3; to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: recvChip.on ? "Listening" : "Receive"
                        color: recvChip.on ? Theme.flameGlow : (recvArea.containsMouse ? Theme.cream : Theme.subtle)
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.9 * root.s
                    }
                }

                MouseArea {
                    id: recvArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: recvChip.on ? Stash.stopReceive() : Stash.startReceive()
                }
            }
        }
    }

    Rectangle {
        id: headerRule
        anchors.top: header.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    // ── File grid ───────────────────────────────────────────────────────
    Item {
        id: content
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.gridH

        GridView {
            id: grid
            anchors.fill: parent
            clip: true
            visible: Stash.count > 0
            cellWidth: Math.floor(grid.width / root.cols)
            cellHeight: root.cellH
            model: Stash.files
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: tile

                required property string fileName
                required property string filePath
                required property url fileUrl

                readonly property bool isImage: /\.(png|jpe?g|webp|gif|bmp)$/i.test(tile.fileName)
                readonly property string ext: {
                    var dot = tile.fileName.lastIndexOf(".");
                    return dot > 0 && dot < tile.fileName.length - 1
                        ? tile.fileName.substring(dot + 1).toUpperCase()
                        : "FILE";
                }
                readonly property bool hovered: tileArea.containsMouse
                    || sendArea.containsMouse || removeArea.containsMouse
                property bool confirming: false

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.margins: 5 * root.s
                    radius: Motion.rTile * root.s
                    clip: true
                    color: (tile.hovered || tile.confirming) ? Theme.frameBg : Theme.tileBg
                    border.width: 1
                    border.color: tile.confirming ? Qt.alpha(Theme.vermLit, 0.7)
                        : (tile.hovered ? Theme.frameBorder : Theme.border)

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    transform: Translate {
                        y: tile.hovered && !tile.confirming ? -3 * root.s : 0
                        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: tile.isImage
                        source: tile.isImage ? tile.fileUrl : ""
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        clip: true
                        opacity: tile.confirming ? 0.4 : 1
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }

                    GlyphIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -8 * root.s
                        visible: !tile.isImage
                        opacity: tile.confirming ? 0.4 : 1
                        width: 30 * root.s
                        height: 30 * root.s
                        name: root.catGlyph(tile.ext)
                        color: tile.hovered ? Theme.cream : Theme.iconDim
                        stroke: 1.5
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }

                    // Type tag for non-image files, under the glyph.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 12 * root.s
                        visible: !tile.isImage && !tile.confirming
                        text: tile.ext
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 8 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1 * root.s
                    }

                    // Legibility scrim under the name on image tiles.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: nameText.height + 12 * root.s
                        visible: tile.isImage && !tile.confirming
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, 0.85) }
                        }
                    }

                    Text {
                        id: nameText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6 * root.s
                        visible: !tile.confirming
                        text: tile.fileName
                        color: tile.isImage ? Theme.bright : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !tile.confirming
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Stash.openFile(tile.filePath)
                    }

                    // Hover actions, top-right: send and remove.
                    Row {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5 * root.s
                        spacing: 5 * root.s
                        opacity: tile.hovered && !tile.confirming ? 1 : 0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                        }

                        Rectangle {
                            width: 22 * root.s
                            height: 22 * root.s
                            radius: width / 2
                            color: sendArea.containsMouse ? Theme.frameBorder : Qt.alpha(Theme.cardBot, 0.92)
                            border.width: 1
                            border.color: Theme.border

                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 12 * root.s
                                height: 12 * root.s
                                name: "send"
                                color: sendArea.containsMouse ? Theme.cream : Theme.iconDim
                                stroke: 1.6
                            }

                            MouseArea {
                                id: sendArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stash.openSendPicker(tile.filePath)
                            }
                        }

                        Rectangle {
                            width: 22 * root.s
                            height: 22 * root.s
                            radius: width / 2
                            color: removeArea.containsMouse ? Theme.vermLit : Qt.alpha(Theme.cardBot, 0.92)
                            border.width: 1
                            border.color: Theme.border

                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 12 * root.s
                                height: 12 * root.s
                                name: "trash"
                                color: removeArea.containsMouse ? Theme.cream : Theme.iconDim
                                stroke: 1.6
                            }

                            MouseArea {
                                id: removeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tile.confirming = true
                            }
                        }
                    }

                    // Inline remove confirmation, in place of a modal.
                    Column {
                        anchors.centerIn: parent
                        spacing: 8 * root.s
                        visible: tile.confirming
                        opacity: tile.confirming ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Remove?"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.DemiBold
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8 * root.s

                            Rectangle {
                                width: 26 * root.s
                                height: 26 * root.s
                                radius: width / 2
                                color: yesArea.containsMouse ? Theme.vermLit : Qt.alpha(Theme.vermLit, 0.18)
                                border.width: 1
                                border.color: Qt.alpha(Theme.vermLit, 0.7)
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 13 * root.s; height: 13 * root.s
                                    name: "check"
                                    color: yesArea.containsMouse ? Theme.cardBot : Theme.vermLit
                                    stroke: 2
                                }
                                MouseArea {
                                    id: yesArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { Stash.removeFile(tile.filePath); tile.confirming = false; }
                                }
                            }
                            Rectangle {
                                width: 26 * root.s
                                height: 26 * root.s
                                radius: width / 2
                                color: noArea.containsMouse ? Theme.frameBg : "transparent"
                                border.width: 1
                                border.color: Theme.border
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 12 * root.s; height: 12 * root.s
                                    name: "close"
                                    color: noArea.containsMouse ? Theme.cream : Theme.iconDim
                                    stroke: 1.8
                                }
                                MouseArea {
                                    id: noArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tile.confirming = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Empty / drop state ──────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: Stash.count === 0

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -14 * root.s
                text: "力"
                color: Theme.brand
                opacity: dropArea.containsDrag ? 0.32 : 0.14
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 76 * root.s
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10 * root.s
                spacing: 4 * root.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dropArea.containsDrag ? "Release to stash" : "Drop files here"
                    color: dropArea.containsDrag ? Theme.flameGlow : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "~/Downloads/Stash"
                    color: Theme.ghost
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                }
            }
        }
    }

    // Brand ring while a drag hovers the surface, over the whole body.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2 * root.s
        radius: Motion.rTile * root.s
        color: "transparent"
        border.width: 1.5 * root.s
        border.color: Qt.alpha(Theme.brand, 0.55)
        visible: dropArea.containsDrag
        z: 5
    }

    // ── Drag-and-drop intake ────────────────────────────────────────────
    DropArea {
        id: dropArea
        anchors.fill: parent
        onDropped: (drop) => {
            for (var i = 0; i < drop.urls.length; i++)
                Stash.addUrl(drop.urls[i]);
            drop.accept();
        }
    }

    // ── Action bar ──────────────────────────────────────────────────────
    StashActions {
        id: actions
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        s: root.s
        hasFiles: Stash.count > 0
        hasMedia: Stash.hasMedia
        hasInstallable: Stash.hasInstallable
        onSendAll: Stash.openSendAll()
        onSendText: Stash.openSendText()
        onDownload: Stash.openDownload()
        onCompress: Stash.requestCompress()
        onInstall: Stash.requestInstall()
    }

    // ── Sheets (send / receive / task) over the body ────────────────────
    StashSendSheet {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: root.s
    }

    StashReceive {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: root.s
    }

    StashTaskOverlay {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: root.s
    }

    StashDownload {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: root.s
    }
}
