pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 力 STASH surface: a drop-target grid over ~/Downloads/Stash with one-tap
 * LocalSend. Image files render thumbnails, everything else shows its
 * extension; hovering a tile reveals send (↑) and remove (✕) actions and the
 * tile body opens the file. Dragging files onto the surface copies them in.
 * The send action raises a device picker over the grid that runs a LAN
 * discovery and uploads the chosen file to the picked device. All model and
 * process state lives in the Stash singleton; only the morph fade and subtle
 * hover transitions animate, matching the native pill feel.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 14

    implicitHeight: 150 * s

    ameForm: open ? "dock" : "off"

    // ── Header ──────────────────────────────────────────────────────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22 * root.s

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

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Stash.count > 0
            text: Stash.count + " FILES"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.1 * root.s
            font.features: { "tnum": 1 }
        }
    }

    // ── File grid ───────────────────────────────────────────────────────
    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        visible: Stash.count > 0
        cellWidth: 92 * root.s
        cellHeight: 92 * root.s
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

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                id: card
                anchors.fill: parent
                anchors.margins: 5 * root.s
                radius: Motion.rTile * root.s
                clip: true
                color: tile.hovered ? Theme.frameBg : Theme.tileBg
                border.width: 1
                border.color: tile.hovered ? Theme.frameBorder : Theme.border

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                // Thumbnail for image files
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: tile.isImage
                    source: tile.isImage ? tile.fileUrl : ""
                    sourceSize.width: 192
                    sourceSize.height: 192
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    clip: true
                }

                // Extension fallback for non-image files
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -8 * root.s
                    visible: !tile.isImage
                    text: tile.ext
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 17 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: 1 * root.s
                }

                // Legibility scrim under the name on image tiles
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: nameText.height + 10 * root.s
                    visible: tile.isImage
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, 0.82) }
                    }
                }

                Text {
                    id: nameText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 5 * root.s
                    text: tile.fileName
                    color: Theme.subtle
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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.openFile(tile.filePath)
                }

                // Hover actions, top-right
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4 * root.s
                    spacing: 4 * root.s
                    opacity: tile.hovered ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                    }

                    Rectangle {
                        width: 20 * root.s
                        height: 20 * root.s
                        radius: width / 2
                        color: sendArea.containsMouse ? Theme.frameBorder : Qt.alpha(Theme.cardBot, 0.9)
                        border.width: 1
                        border.color: Theme.border

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            color: sendArea.containsMouse ? Theme.cream : Theme.iconDim
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.Bold
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
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
                        width: 20 * root.s
                        height: 20 * root.s
                        radius: width / 2
                        color: removeArea.containsMouse ? Theme.vermLit : Qt.alpha(Theme.cardBot, 0.9)
                        border.width: 1
                        border.color: Theme.border

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: removeArea.containsMouse ? Theme.cream : Theme.iconDim
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Bold
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Stash.removeFile(tile.filePath)
                        }
                    }
                }
            }
        }
    }

    // ── Empty state ─────────────────────────────────────────────────────
    Column {
        anchors.centerIn: grid
        visible: Stash.count === 0
        spacing: 6 * root.s

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Drop files to stash"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "~/Downloads/Stash"
            color: Theme.ghost
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Normal
        }
    }

    // ── Drag-and-drop intake ────────────────────────────────────────────
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            for (var i = 0; i < drop.urls.length; i++)
                Stash.addUrl(drop.urls[i]);
            drop.accept();
        }
    }

    // ── Device-picker overlay ───────────────────────────────────────────
    Rectangle {
        id: picker
        anchors.fill: parent
        radius: Motion.rTile * root.s
        color: Qt.alpha(Theme.cardTop, 0.97)
        visible: Stash.lsState !== "idle"
        z: 20

        // Absorb clicks/hover so the grid beneath stays inert
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Item {
            id: pickerHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 4 * root.s
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 6 * root.s
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Item {
                    id: spinner
                    width: 12 * root.s
                    height: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Stash.lsState === "scanning" || Stash.lsState === "sending"

                    Rectangle {
                        width: 4 * root.s
                        height: 4 * root.s
                        radius: width / 2
                        color: Theme.flameGlow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                    }

                    RotationAnimation on rotation {
                        running: spinner.visible
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Stash.lsState === "scanning" ? "Scanning…"
                        : Stash.lsState === "sending" ? "Sending…"
                        : Stash.deviceModel.count === 0 ? "No devices found"
                        : "Send to"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                id: closeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 22 * root.s
                height: 22 * root.s
                radius: Motion.rSmall * root.s
                color: closeArea.containsMouse ? Theme.frameBg : "transparent"
                border.width: closeArea.containsMouse ? 1 : 0
                border.color: Theme.frameBorder

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.cream : Theme.iconDim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Bold
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Stash.discoverProc.running = false;
                        Stash.lsState = "idle";
                        Stash.pendingFile = "";
                    }
                }
            }
        }

        ListView {
            id: deviceList
            anchors.top: pickerHeader.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            anchors.bottomMargin: 12 * root.s
            clip: true
            spacing: 4 * root.s
            model: Stash.deviceModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: drow

                required property var model

                width: ListView.view.width
                height: 40 * root.s
                radius: Motion.rSmall * root.s
                color: drowArea.containsMouse && Stash.lsState === "ready"
                    ? Theme.frameBg : Theme.tileBg
                border.width: 1
                border.color: drowArea.containsMouse && Stash.lsState === "ready"
                    ? Theme.frameBorder : Theme.border

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 11 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 11 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        width: parent.width
                        text: drow.model.alias
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }
                    Text {
                        width: parent.width
                        text: drow.model.ip
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        font.features: { "tnum": 1 }
                    }
                }

                MouseArea {
                    id: drowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Stash.lsState === "ready"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.sendTo(drow.model.ip)
                }
            }
        }
    }
}
