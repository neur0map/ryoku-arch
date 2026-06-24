pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The LocalSend send sheet, raised over the stash grid. It runs a ~2s LAN scan
 * and lists the devices it finds; picking one raises an inline confirmation
 * naming exactly what goes where before anything is uploaded. The same sheet
 * handles all three send kinds: a single file, the whole stash, or a typed note
 * (which adds a paste-or-type field up top). All discovery and upload state lives
 * in the Stash singleton; this is purely its face.
 */
Rectangle {
    id: root

    property real s: 1

    readonly property bool active: Stash.lsState !== "idle"
    readonly property bool isText: Stash.sendKind === "text"
    readonly property bool scanning: Stash.lsState === "scanning"
    readonly property bool sending: Stash.lsState === "sending"
    readonly property bool ready: Stash.lsState === "ready"

    // A device is pickable once the scan is ready, and (for a note) only once
    // there is text to send, so an empty note can never go out.
    readonly property bool canPick: ready && (!isText || Stash.composeText.length > 0)

    // What this send will move, for the title and the confirmation.
    readonly property string subject: Stash.sendKind === "all"
        ? (Stash.count + (Stash.count === 1 ? " file" : " files"))
        : Stash.sendKind === "text" ? "a note"
        : (("" + Stash.pendingFile).split("/").pop() || "file")

    // The device the user tapped, awaiting confirmation.
    property string pickIp: ""
    property string pickAlias: ""

    radius: Motion.rTile * s
    color: Qt.alpha(Theme.cardTop, 0.98)
    visible: active

    onActiveChanged: if (!active) { root.pickIp = ""; root.pickAlias = ""; }

    // Absorb clicks/hover so the grid beneath stays inert.
    MouseArea { anchors.fill: parent; hoverEnabled: true }

    // ── Header ──────────────────────────────────────────────────────────
    Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 2 * root.s
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 6 * root.s
        height: 26 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            // Orbiting dot while a scan or upload runs.
            Item {
                id: spinner
                width: 13 * root.s
                height: 13 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: root.scanning || root.sending

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
                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                }
            }

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.scanning && !root.sending
                width: 14 * root.s
                height: 14 * root.s
                name: "send"
                color: Theme.flameGlow
                stroke: 1.7
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s

                Text {
                    text: root.sending ? "Sending" : root.scanning ? "Scanning" : "Send to"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.subject
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: head.width - 150 * root.s
                    textFormat: Text.PlainText
                }
            }
        }

        Rectangle {
            id: rescanBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.ready
            width: 22 * root.s
            height: 22 * root.s
            radius: Motion.rSmall * root.s
            color: rescanHeadArea.containsMouse ? Theme.frameBg : "transparent"
            border.width: rescanHeadArea.containsMouse ? 1 : 0
            border.color: Theme.frameBorder
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            GlyphIcon {
                anchors.centerIn: parent
                width: 12 * root.s; height: 12 * root.s
                name: "scan"
                color: rescanHeadArea.containsMouse ? Theme.cream : Theme.iconDim
                stroke: 1.7
            }
            MouseArea {
                id: rescanHeadArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.rescan()
            }
        }
    }

    // ── Compose field (text send only) ──────────────────────────────────
    Rectangle {
        id: composeBox
        anchors.top: head.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12 * root.s
        anchors.rightMargin: 12 * root.s
        visible: root.isText
        height: visible ? 64 * root.s : 0
        radius: Motion.rSmall * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: field.activeFocus ? Theme.frameBorder : Theme.border
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        Flickable {
            anchors.fill: parent
            anchors.margins: 8 * root.s
            contentHeight: field.implicitHeight
            clip: true

            TextEdit {
                id: field
                width: parent.width
                text: Stash.composeText
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                selectionColor: Qt.alpha(Theme.flameGlow, 0.4)
                onTextChanged: if (text !== Stash.composeText) Stash.composeText = text

                Connections {
                    target: Stash
                    function onComposeTextChanged() {
                        if (field.text !== Stash.composeText)
                            field.text = Stash.composeText;
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: field.text.length === 0
                    text: "Type or paste a note to send…"
                    color: Theme.faint
                    font: field.font
                    wrapMode: Text.Wrap
                }
            }
        }

        // Paste-from-clipboard affordance.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6 * root.s
            width: pasteRow.implicitWidth + 14 * root.s
            height: 18 * root.s
            radius: height / 2
            color: pasteArea.containsMouse ? Theme.frameBg : Qt.alpha(Theme.cardBot, 0.85)
            border.width: 1
            border.color: pasteArea.containsMouse ? Theme.frameBorder : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Row {
                id: pasteRow
                anchors.centerIn: parent
                spacing: 4 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10 * root.s; height: 10 * root.s
                    name: "clipboard"
                    color: pasteArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 1.6
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Paste"
                    color: pasteArea.containsMouse ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: pasteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.pasteCompose()
            }
        }
    }

    // ── Device list ─────────────────────────────────────────────────────
    ListView {
        id: deviceList
        anchors.top: composeBox.visible ? composeBox.bottom : head.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12 * root.s
        anchors.rightMargin: 12 * root.s
        anchors.bottomMargin: 12 * root.s
        clip: true
        spacing: 5 * root.s
        model: Stash.deviceModel
        boundsBehavior: Flickable.StopAtBounds
        visible: !root.sending

        delegate: Rectangle {
            id: drow
            required property var model

            width: ListView.view.width
            height: 38 * root.s
            radius: Motion.rSmall * root.s
            color: drowArea.containsMouse && root.canPick ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: drowArea.containsMouse && root.canPick ? Theme.frameBorder : Theme.border

            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            GlyphIcon {
                id: devGlyph
                anchors.left: parent.left
                anchors.leftMargin: 11 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s; height: 16 * root.s
                name: "hotspot"
                color: drowArea.containsMouse && root.canPick ? Theme.flameGlow : Theme.iconDim
                stroke: 1.6
            }

            Column {
                anchors.left: devGlyph.right
                anchors.leftMargin: 10 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 30 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s

                Text {
                    width: parent.width
                    text: drow.model.alias
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
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
                    font.pixelSize: 9 * root.s
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    font.features: { "tnum": 1 }
                }
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.rightMargin: 11 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 12 * root.s; height: 12 * root.s
                name: "chevron-right"
                color: Theme.iconDim
                stroke: 1.7
                opacity: drowArea.containsMouse && root.canPick ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            MouseArea {
                id: drowArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.canPick
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.pickIp = drow.model.ip; root.pickAlias = drow.model.alias; }
            }
        }
    }

    // Empty / scanning hint when the list has nothing yet.
    Column {
        anchors.centerIn: deviceList
        spacing: 6 * root.s
        visible: !root.sending && Stash.deviceModel.count === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.scanning ? "Looking for devices…" : "No devices found"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.scanning
            text: "Open LocalSend on the other device"
            color: Theme.ghost
            font.family: Theme.font
            font.pixelSize: 9 * root.s
        }

        Item { width: 1; height: 4 * root.s }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.scanning
            width: rescanRow.implicitWidth + 26 * root.s
            height: 28 * root.s
            radius: Motion.rSmall * root.s
            color: rescanArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: rescanArea.containsMouse ? Theme.frameBorder : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Row {
                id: rescanRow
                anchors.centerIn: parent
                spacing: 6 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s; height: 12 * root.s
                    name: "scan"
                    color: rescanArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Scan again"
                    color: rescanArea.containsMouse ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: rescanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.rescan()
            }
        }
    }

    // ── Confirmation bar (after a device is picked) ─────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Motion.rTile * root.s
        color: Qt.alpha(Theme.cardBot, 0.6)
        visible: root.pickIp !== "" && !root.sending
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: { root.pickIp = ""; root.pickAlias = ""; } }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 40 * root.s
            height: confirmCol.implicitHeight + 28 * root.s
            radius: Motion.rTile * root.s
            color: Theme.cardTop
            border.width: 1
            border.color: Theme.border
            MouseArea { anchors.fill: parent; hoverEnabled: true }

            Column {
                id: confirmCol
                anchors.centerIn: parent
                width: parent.width - 28 * root.s
                spacing: 14 * root.s

                Text {
                    width: parent.width
                    text: "Send " + root.subject + " to " + root.pickAlias + "?"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * root.s

                    Rectangle {
                        width: 84 * root.s
                        height: 30 * root.s
                        radius: Motion.rSmall * root.s
                        color: cancelArea.containsMouse ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: cancelArea.containsMouse ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.pickIp = ""; root.pickAlias = ""; }
                        }
                    }

                    Rectangle {
                        width: 100 * root.s
                        height: 30 * root.s
                        radius: Motion.rSmall * root.s
                        color: sendOkArea.containsMouse ? Theme.flameGlow : Qt.alpha(Theme.flameGlow, 0.18)
                        border.width: 1
                        border.color: Qt.alpha(Theme.flameGlow, 0.7)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6 * root.s
                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12 * root.s; height: 12 * root.s
                                name: "send"
                                color: sendOkArea.containsMouse ? Theme.cardBot : Theme.flameGlow
                                stroke: 1.7
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Send"
                                color: sendOkArea.containsMouse ? Theme.cardBot : Theme.flameCore
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            id: sendOkArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Stash.sendTo(root.pickIp); root.pickIp = ""; }
                        }
                    }
                }
            }
        }
    }
}
