pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// stash section of the 力 deck: a 4-col file board over ~/Downloads/Stash that
// doubles as a LocalSend hub. grid = what's stashed (image -> thumb, rest -> a
// type glyph), hover a tile to open/send/remove, drag files onto the section
// to copy them in. action bar sends the whole stash or a typed note, pulls a
// copied link in, shrinks or installs what's here. the compact Receive switch
// up top lets other devices push files straight in. send/recv/long jobs raise
// focused sheets over the grid; every state lives in the Stash singleton.
// headerless: the deck eyebrow ("Stash") sits above this Item.
Item {
    id: stash

    // scale + deck-activity gate.
    property real s: 1
    property bool active: true

    // true while a file drag hovers the board. the shell reads this to hold the
    // left sidebar open across the edge-strip -> board handoff during a drag.
    readonly property bool dragActive: dropArea.containsDrag

    // reserved (none here: stash flows raise their own overlays).
    signal requestClose()

    // fixed cell + grid height so implicitHeight never depends on the column
    // width handed down by the deck (width-driven height -> loop with the deck's
    // Math.max(left,right)). cell WIDTH stays dynamic (filled to `cols`) because
    // it reads the laid-out grid width, which never flows back into height.
    readonly property int cols: 4
    readonly property real cellH: 104 * s
    readonly property real gridH: cellH * 2
    readonly property real headH: 18 * s
    readonly property real actionsH: 50 * s

    implicitHeight: headH + 6 * s + 1 + 6 * s + gridH + 12 * s + actionsH

    // an overlay (send / recv / task sheet) owns the body below the header.
    readonly property bool sheetOpen: Stash.lsState !== "idle"
        || Stash.recvState !== "idle"
        || Stash.dlOpen
        || (Stash.task !== "" && Stash.taskState !== "idle")

    // dismiss whichever sub-sheet is open. driven by the header Back.
    function dismissSheet() {
        if (Stash.recvState !== "idle") Stash.stopReceive();
        else if (Stash.lsState !== "idle") Stash.cancelSend();
        else if (Stash.dlOpen) Stash.closeDownload();
        else if (Stash.task !== "") Stash.dismissTask();
    }

    // file-type bucket for the non-image tile glyph, by extension.
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

    // ── header micro-row: count · Receive chip ──────────────────────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: stash.headH

        // Back + file count. Back only while a sub-sheet is open; sits just
        // left of the count, breadcrumb-style.
        Item {
            id: backBtn
            visible: stash.sheetOpen
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: bChevron.width + 4 * stash.s + bLabel.implicitWidth
            height: stash.headH

            GlyphIcon {
                id: bChevron
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 11 * stash.s
                height: 11 * stash.s
                name: "chevron-left"
                color: bArea.containsMouse ? Theme.cream : Theme.subtle
                stroke: 1.9
            }
            Text {
                id: bLabel
                anchors.left: bChevron.right
                anchors.leftMargin: 4 * stash.s
                anchors.verticalCenter: parent.verticalCenter
                text: "BACK"
                color: bArea.containsMouse ? Theme.cream : Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 9.5 * stash.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6 * stash.s
                font.capitalization: Font.AllUppercase
            }
            MouseArea {
                id: bArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: stash.dismissSheet()
            }
        }

        Rectangle {
            id: backDiv
            visible: stash.sheetOpen
            anchors.left: backBtn.right
            anchors.leftMargin: 9 * stash.s
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 11 * stash.s
            color: Theme.hair
        }

        Text {
            id: countText
            anchors.left: stash.sheetOpen ? backDiv.right : parent.left
            anchors.leftMargin: stash.sheetOpen ? 9 * stash.s : 0
            anchors.verticalCenter: parent.verticalCenter
            text: Stash.count > 0
                ? Stash.count + (Stash.count === 1 ? " FILE" : " FILES")
                : "EMPTY"
            color: Stash.count > 0 ? Theme.dim : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 9.5 * stash.s
            font.weight: Font.DemiBold
            font.letterSpacing: 2 * stash.s
            font.capitalization: Font.AllUppercase
            font.features: { "tnum": 1 }
        }

        // receive switch: flip it on and other LocalSend devices push files
        // straight into the stash. lit while listening, dot breathes.
        Rectangle {
            id: recvChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool on: Stash.recvState !== "idle"
            width: recvRow.implicitWidth + 16 * stash.s
            height: 18 * stash.s
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
                spacing: 5 * stash.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5 * stash.s
                    height: 5 * stash.s
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
                    text: recvChip.on ? "LISTENING" : "RECEIVE"
                    color: recvChip.on ? Theme.flameGlow : (recvArea.containsMouse ? Theme.cream : Theme.subtle)
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * stash.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * stash.s
                    font.capitalization: Font.AllUppercase
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

    // hairline under the header, matching the dossier rules elsewhere.
    Rectangle {
        id: headerRule
        anchors.top: header.bottom
        anchors.topMargin: 6 * stash.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    // ── file grid ───────────────────────────────────────────────────────
    Rectangle {
        id: content
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * stash.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.bottomMargin: 12 * stash.s
        color: Qt.alpha(Theme.cardBot, 0.5)
        border.width: 1
        border.color: Theme.hair
        radius: Theme.radius
        clip: true

        // square spec grid behind the files (same texture as the hub Profile drop window).
        Canvas {
            anchors.fill: parent
            z: -2
            property string tint: "rgba(" + Math.round(Theme.cream.r * 255) + ", " + Math.round(Theme.cream.g * 255) + ", " + Math.round(Theme.cream.b * 255) + ", 0.05)"
            property real step: 30 * stash.s
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = tint;
                ctx.lineWidth = 1;
                for (let x = 0; x <= width; x += step) {
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                }
                for (let y = 0; y <= height; y += step) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }
            }
        }

        GridView {
            id: grid
            anchors.fill: parent
            clip: true
            visible: Stash.count > 0
            cellWidth: Math.floor(grid.width / stash.cols)
            cellHeight: stash.cellH
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
                    anchors.margins: 4 * stash.s
                    radius: Theme.radius
                    clip: true
                    color: (tile.hovered || tile.confirming) ? Theme.frameBg : Theme.tileBg
                    border.width: 1
                    border.color: tile.confirming ? Qt.alpha(Theme.vermLit, 0.7)
                        : (tile.hovered ? Theme.frameBorder : Theme.border)

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    transform: Translate {
                        y: tile.hovered && !tile.confirming ? -3 * stash.s : 0
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
                        anchors.verticalCenterOffset: -8 * stash.s
                        visible: !tile.isImage
                        opacity: tile.confirming ? 0.4 : 1
                        width: 28 * stash.s
                        height: 28 * stash.s
                        name: stash.catGlyph(tile.ext)
                        color: tile.hovered ? Theme.cream : Theme.iconDim
                        stroke: 1.5
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }

                    // type tag for non-image files, under the glyph.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 12 * stash.s
                        visible: !tile.isImage && !tile.confirming
                        text: tile.ext
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 8 * stash.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1 * stash.s
                    }

                    // scrim under the name on image tiles for legibility.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: nameText.height + 12 * stash.s
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
                        anchors.margins: 6 * stash.s
                        visible: !tile.confirming
                        text: tile.fileName
                        color: tile.isImage ? Theme.bright : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9 * stash.s
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

                    // hover actions, top-right: send + remove.
                    Row {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5 * stash.s
                        spacing: 5 * stash.s
                        opacity: tile.hovered && !tile.confirming ? 1 : 0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                        }

                        Rectangle {
                            width: 22 * stash.s
                            height: 22 * stash.s
                            radius: width / 2
                            color: sendArea.containsMouse ? Theme.frameBorder : Qt.alpha(Theme.cardBot, 0.92)
                            border.width: 1
                            border.color: Theme.border

                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 12 * stash.s
                                height: 12 * stash.s
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
                            width: 22 * stash.s
                            height: 22 * stash.s
                            radius: width / 2
                            color: removeArea.containsMouse ? Theme.vermLit : Qt.alpha(Theme.cardBot, 0.92)
                            border.width: 1
                            border.color: Theme.border

                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 12 * stash.s
                                height: 12 * stash.s
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

                    // inline remove confirm in place of a modal.
                    Column {
                        anchors.centerIn: parent
                        spacing: 8 * stash.s
                        visible: tile.confirming
                        opacity: tile.confirming ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Remove?"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 10 * stash.s
                            font.weight: Font.DemiBold
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8 * stash.s

                            Rectangle {
                                width: 26 * stash.s
                                height: 26 * stash.s
                                radius: width / 2
                                color: yesArea.containsMouse ? Theme.vermLit : Qt.alpha(Theme.vermLit, 0.18)
                                border.width: 1
                                border.color: Qt.alpha(Theme.vermLit, 0.7)
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 13 * stash.s; height: 13 * stash.s
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
                                width: 26 * stash.s
                                height: 26 * stash.s
                                radius: width / 2
                                color: noArea.containsMouse ? Theme.frameBg : "transparent"
                                border.width: 1
                                border.color: Theme.border
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 12 * stash.s; height: 12 * stash.s
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

        // ── empty / drop state ──────────────────────────────────────────
        Item {
            anchors.fill: parent
            z: -1

            BrandMark {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -14 * stash.s
                size: 72 * stash.s
                opacity: dropArea.containsDrag ? 0.32 : 0.14
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            Column {
                visible: Stash.count === 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10 * stash.s
                spacing: 4 * stash.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dropArea.containsDrag ? "Release to stash" : "Drop files here"
                    color: dropArea.containsDrag ? Theme.flameGlow : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * stash.s
                    font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "~/Downloads/Stash"
                    color: Theme.ghost
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * stash.s
                    font.letterSpacing: 1.2 * stash.s
                }
            }
        }
    }

    // brand ring while a drag hovers the section, over the whole body.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: "transparent"
        border.width: 1.5 * stash.s
        border.color: Qt.alpha(Theme.brand, 0.55)
        visible: dropArea.containsDrag
        z: 5
    }

    // ── drag-and-drop intake ────────────────────────────────────────────
    DropArea {
        id: dropArea
        anchors.fill: parent
        onDropped: (drop) => {
            for (var i = 0; i < drop.urls.length; i++)
                Stash.addUrl(drop.urls[i]);
            drop.accept();
        }
    }

    // ── action bar ──────────────────────────────────────────────────────
    StashActions {
        id: actions
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        s: stash.s
        hasFiles: Stash.count > 0
        hasMedia: Stash.hasMedia
        hasInstallable: Stash.hasInstallable
        onSendAll: Stash.openSendAll()
        onSendText: Stash.openSendText()
        onDownload: Stash.openDownload()
        onCompress: Stash.requestCompress()
        onInstall: Stash.requestInstall()
    }

    // ── sheets (send / recv / task) over the body ───────────────────────
    StashSendSheet {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * stash.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: stash.s
    }

    StashReceive {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * stash.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: stash.s
    }

    StashTaskOverlay {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * stash.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: stash.s
    }

    StashDownload {
        anchors.top: headerRule.bottom
        anchors.topMargin: 6 * stash.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        s: stash.s
    }
}
