pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The cobalt download/remux window, raised over the stash grid. It mirrors
 * cobalt's own flow (https://github.com/imputnet/cobalt): a download tab with the
 * auto/audio/mute modes and a paste bar, and a remux tab that rebuilds a media
 * file's container losslessly. Both feed a shared processing queue. The work runs
 * through stash-cobalt.sh (a cobalt API client with a yt-dlp fallback) behind the
 * Stash singleton; the cobalt credit stays visible since the engine is theirs.
 */
Rectangle {
    id: root

    property real s: 1
    readonly property bool isRemux: Stash.dlTab === "remux"
    readonly property string mono: "JetBrainsMono Nerd Font"

    radius: Motion.rTile * s
    color: Qt.alpha(Theme.cardTop, 0.98)
    visible: Stash.dlOpen

    MouseArea { anchors.fill: parent; hoverEnabled: true }

    component Tab: Rectangle {
        id: tb
        property string key: ""
        property string label: ""
        readonly property bool sel: Stash.dlTab === tb.key
        width: tbT.implicitWidth + 18 * root.s
        height: 22 * root.s
        radius: height / 2
        color: tb.sel ? Theme.frameBg : (tbA.containsMouse ? Qt.alpha(Theme.frameBg, 0.5) : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Text {
            id: tbT
            anchors.centerIn: parent
            text: tb.label
            color: tb.sel ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8 * root.s
        }
        MouseArea {
            id: tbA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Stash.dlTab = tb.key
        }
    }

    // ── Header: cobalt mark + tabs ──────────────────────────────────────
    Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4 * root.s
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 6 * root.s
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.s; height: 14 * root.s
                    name: "remux"
                    color: Theme.flameGlow
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "cobalt"
                    color: Theme.cream
                    font.family: root.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s
                Tab { key: "download"; label: "Download" }
                Tab { key: "remux"; label: "Remux" }
            }
        }
    }

    // ── Download tab: modes + paste bar ─────────────────────────────────
    Item {
        id: dlPane
        anchors.top: head.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 14 * root.s
        height: visible ? 78 * root.s : 0
        visible: !root.isRemux

        component ModeBtn: Rectangle {
            id: mb
            property string mode: ""
            property string glyph: ""
            property string label: ""
            readonly property bool sel: Stash.dlMode === mb.mode
            width: mbRow.implicitWidth + 18 * root.s
            height: 30 * root.s
            radius: Motion.rSmall * root.s
            color: mb.sel ? Qt.alpha(Theme.flameGlow, 0.16) : (mbA.containsMouse ? Theme.frameBg : Theme.tileBg)
            border.width: 1
            border.color: mb.sel ? Qt.alpha(Theme.flameGlow, 0.6) : (mbA.containsMouse ? Theme.frameBorder : Theme.border)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            Row {
                id: mbRow
                anchors.centerIn: parent
                spacing: 5 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s; height: 13 * root.s
                    name: mb.glyph
                    color: mb.sel ? Theme.flameGlow : (mbA.containsMouse ? Theme.cream : Theme.iconDim)
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: mb.label
                    color: mb.sel ? Theme.flameCore : (mbA.containsMouse ? Theme.cream : Theme.subtle)
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: mbA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.dlMode = mb.mode
            }
        }

        Row {
            id: modeRow
            anchors.top: parent.top
            anchors.left: parent.left
            spacing: 6 * root.s
            ModeBtn { mode: "auto";  glyph: "sparkle";     label: "Auto" }
            ModeBtn { mode: "audio"; glyph: "music";       label: "Audio" }
            ModeBtn { mode: "mute";  glyph: "speaker-off"; label: "Mute" }
        }

        // Paste bar with an inline Paste button; Enter or the arrow submits.
        Rectangle {
            id: bar
            anchors.top: modeRow.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 34 * root.s
            radius: Motion.rSmall * root.s
            color: Theme.tileBg
            border.width: 1
            border.color: field.activeFocus ? Theme.frameBorder : Theme.border
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            GlyphIcon {
                id: linkIcon
                anchors.left: parent.left
                anchors.leftMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * root.s; height: 14 * root.s
                name: "link"
                color: Theme.iconDim
                stroke: 1.6
            }

            TextInput {
                id: field
                anchors.left: linkIcon.right
                anchors.leftMargin: 8 * root.s
                anchors.right: pasteChip.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: Stash.dlText
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                clip: true
                selectByMouse: true
                selectionColor: Qt.alpha(Theme.flameGlow, 0.4)
                onTextChanged: if (text !== Stash.dlText) Stash.dlText = text
                onAccepted: Stash.submitDownload()

                Connections {
                    target: Stash
                    function onDlTextChanged() {
                        if (field.text !== Stash.dlText)
                            field.text = Stash.dlText;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: "paste the link here"
                    color: Theme.faint
                    font: field.font
                }
            }

            Rectangle {
                id: pasteChip
                anchors.right: getChip.left
                anchors.rightMargin: 5 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: pasteRow.implicitWidth + 14 * root.s
                height: 24 * root.s
                radius: Motion.rSmall * root.s
                color: pasteArea.containsMouse ? Theme.frameBg : Qt.alpha(Theme.cardBot, 0.7)
                border.width: 1
                border.color: pasteArea.containsMouse ? Theme.frameBorder : Theme.border
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    id: pasteRow
                    anchors.centerIn: parent
                    spacing: 4 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11 * root.s; height: 11 * root.s
                        name: "clipboard"
                        color: pasteArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Paste"
                        color: pasteArea.containsMouse ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: pasteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.pasteDownload()
                }
            }

            Rectangle {
                id: getChip
                anchors.right: parent.right
                anchors.rightMargin: 5 * root.s
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool on: field.text.trim().length > 0
                width: 26 * root.s
                height: 24 * root.s
                radius: Motion.rSmall * root.s
                opacity: getChip.on ? 1 : 0.4
                color: getArea.containsMouse && getChip.on ? Theme.flameGlow : Qt.alpha(Theme.flameGlow, 0.18)
                border.width: 1
                border.color: Qt.alpha(Theme.flameGlow, 0.6)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                GlyphIcon {
                    anchors.centerIn: parent
                    width: 13 * root.s; height: 13 * root.s
                    name: "tray-down"
                    color: getArea.containsMouse && getChip.on ? Theme.cardBot : Theme.flameGlow
                    stroke: 1.8
                }
                MouseArea {
                    id: getArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: getChip.on
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.submitDownload()
                }
            }
        }
    }

    // ── Remux tab: info + droppable media list ──────────────────────────
    Item {
        id: rxPane
        anchors.top: head.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 14 * root.s
        height: visible ? 64 * root.s : 0
        visible: root.isRemux

        Text {
            id: rxInfo
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            text: "Remux fixes a file's container (missing timestamps, odd codecs) without re-encoding. Lossless and on-device."
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            lineHeight: 1.3
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: drop
            anchors.top: rxInfo.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24 * root.s
            radius: Motion.rSmall * root.s
            color: dropArea.containsDrag ? Qt.alpha(Theme.flameGlow, 0.12) : "transparent"
            border.width: 1
            border.color: dropArea.containsDrag ? Qt.alpha(Theme.flameGlow, 0.6) : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Text {
                anchors.centerIn: parent
                text: dropArea.containsDrag ? "Release to add" : "Drop a file in, or pick one below"
                color: dropArea.containsDrag ? Theme.flameGlow : Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
            }
            DropArea {
                id: dropArea
                anchors.fill: parent
                onDropped: (d) => { for (var i = 0; i < d.urls.length; i++) Stash.addUrl(d.urls[i]); d.accept(); }
            }
        }
    }

    // ── Shared list area: processing queue (download) or media (remux) ──
    Item {
        id: listArea
        anchors.top: root.isRemux ? rxPane.bottom : dlPane.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: credit.top
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 14 * root.s
        anchors.bottomMargin: 6 * root.s

        // Section label.
        Item {
            id: secHead
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.isRemux ? "media in the stash" : "processing queue"
                color: Theme.dim
                font.family: root.mono
                font.pixelSize: 9 * root.s
                font.weight: Font.DemiBold
            }

            // Clear finished queue entries.
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isRemux && Stash.queueModel.count > 0
                text: "clear"
                color: clearArea.containsMouse ? Theme.cream : Theme.faint
                font.family: root.mono
                font.pixelSize: 9 * root.s
                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.clearQueueDone()
                }
            }
        }

        // Processing queue (download tab).
        ListView {
            id: queue
            anchors.top: secHead.bottom
            anchors.topMargin: 4 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: !root.isRemux && Stash.queueModel.count > 0
            clip: true
            spacing: 4 * root.s
            model: Stash.queueModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: q
                required property var model
                width: ListView.view.width
                height: 34 * root.s
                radius: Motion.rSmall * root.s
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.border

                readonly property bool running: q.model.state === "running"
                readonly property bool done: q.model.state === "done"
                readonly property bool failed: q.model.state === "error"

                // Status glyph / spinner.
                Item {
                    id: st
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * root.s
                    height: 16 * root.s

                    Item {
                        anchors.fill: parent
                        visible: q.running
                        Rectangle {
                            width: 5 * root.s; height: 5 * root.s; radius: width / 2
                            color: Theme.flameGlow
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                        }
                        RotationAnimation on rotation {
                            running: q.running; from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        }
                    }
                    GlyphIcon {
                        anchors.centerIn: parent
                        visible: q.done || q.failed
                        width: 13 * root.s; height: 13 * root.s
                        name: q.done ? "check" : "close"
                        color: q.done ? Theme.flameGlow : Theme.vermLit
                        stroke: 1.9
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: q.model.state === "queued"
                        width: 6 * root.s; height: 6 * root.s; radius: width / 2
                        color: "transparent"
                        border.width: 1.4 * root.s
                        border.color: Theme.iconDim
                    }
                }

                Text {
                    id: qName
                    anchors.left: st.right
                    anchors.leftMargin: 9 * root.s
                    anchors.right: qState.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: q.model.name
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }

                Text {
                    id: qState
                    anchors.right: parent.right
                    anchors.rightMargin: 11 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: q.running ? (q.model.pct > 0 ? (q.model.pct + "%") : "working")
                        : q.done ? "done"
                        : q.failed ? (q.model.msg.length > 0 ? q.model.msg : "failed")
                        : "queued"
                    color: q.done ? Theme.flameGlow : q.failed ? Theme.vermLit : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Media list (remux tab): tap a stash media file to remux it.
        Flickable {
            id: mediaFlick
            anchors.top: secHead.bottom
            anchors.topMargin: 4 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.isRemux
            clip: true
            contentHeight: mediaCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: mediaCol
                width: parent.width
                spacing: 4 * root.s

                Repeater {
                    model: Stash.files
                    delegate: Rectangle {
                        id: mrow
                        required property string fileName
                        required property string filePath
                        readonly property string ext: {
                            var n = mrow.fileName.toLowerCase();
                            return n.substring(n.lastIndexOf(".") + 1);
                        }
                        readonly property bool isMedia: /^(mp4|mkv|webm|mov|avi|m4v|mp3|flac|wav|ogg|opus|m4a|aac|gif)$/.test(mrow.ext)
                        width: mediaCol.width
                        height: isMedia ? 32 * root.s : 0
                        visible: isMedia
                        radius: Motion.rSmall * root.s
                        color: mrowArea.containsMouse ? Theme.frameBg : Theme.tileBg
                        border.width: 1
                        border.color: mrowArea.containsMouse ? Theme.frameBorder : Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        GlyphIcon {
                            id: mGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14 * root.s; height: 14 * root.s
                            name: /^(png|jpe?g|webp|gif|bmp)$/.test(mrow.ext) ? "image"
                                : /^(mp3|flac|wav|ogg|opus|m4a|aac)$/.test(mrow.ext) ? "music" : "film"
                            color: mrowArea.containsMouse ? Theme.cream : Theme.iconDim
                            stroke: 1.6
                        }
                        Text {
                            anchors.left: mGlyph.right
                            anchors.leftMargin: 9 * root.s
                            anchors.right: mGo.left
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: mrow.fileName
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }
                        GlyphIcon {
                            id: mGo
                            anchors.right: parent.right
                            anchors.rightMargin: 11 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13 * root.s; height: 13 * root.s
                            name: "remux"
                            color: mrowArea.containsMouse ? Theme.flameGlow : Theme.iconDim
                            stroke: 1.7
                        }
                        MouseArea {
                            id: mrowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Stash.enqueueRemux(mrow.filePath); Stash.dlTab = "download"; }
                        }
                    }
                }
            }
        }

        // Empty states.
        Column {
            anchors.centerIn: parent
            spacing: 5 * root.s
            visible: root.isRemux ? !Stash.hasMedia : Stash.queueModel.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isRemux ? "no media in the stash" : "nothing here yet"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isRemux ? "drop a video or audio file above" : "paste a link to start a download"
                color: Theme.ghost
                font.family: Theme.font
                font.pixelSize: 9 * root.s
            }
        }
    }

    // ── Credit ──────────────────────────────────────────────────────────
    Text {
        id: credit
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8 * root.s
        text: "media engine by cobalt · processed on-device"
        color: Theme.ghost
        font.family: root.mono
        font.pixelSize: 8.5 * root.s
    }
}
