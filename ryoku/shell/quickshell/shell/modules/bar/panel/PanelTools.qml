pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"
import "../framebars/menus" as Menus

// Tools: the kept download / convert / install backends with a clean face.
// Paste a link to fetch it into the stash (cobalt drives a sequential queue);
// the list shows what landed; Convert compresses stashed media, Install runs a
// stashed package. No LocalSend, no file board -- those went with the old stash.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal pick(string mode)

    property string urlText: ""
    implicitHeight: col.implicitHeight + 24 * root.s

    function startDownload() {
        if (root.urlText.trim().length === 0)
            return;
        Stash.enqueueDownload(root.urlText, Stash.dlMode);
        root.urlText = "";
    }

    function fileGlyph(name) {
        const e = ("" + name).toLowerCase().split(".").pop();
        if (/^(png|jpe?g|webp|gif|bmp|tiff?|avif)$/.test(e)) return "image";
        if (/^(mp4|mkv|webm|mov|avi|m4v)$/.test(e)) return "movie";
        if (/^(mp3|flac|wav|ogg|opus|m4a|aac)$/.test(e)) return "music_note";
        if (/^(zip|tar|gz|xz|zst|bz2|7z|rar|tgz)$/.test(e)) return "folder_zip";
        if (/^(appimage|deb|rpm|flatpak|pkg)$/.test(e)) return "deployed_code";
        return "draft";
    }

    readonly property var modes: [
        { id: "auto", label: qsTr("Auto") },
        { id: "audio", label: qsTr("Audio") },
        { id: "mute", label: qsTr("Mute") }
    ]

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        anchors.topMargin: 16 * root.s
        anchors.bottomMargin: 8 * root.s
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: parent.width
            spacing: 10 * root.s

            Menus.QsSection { width: parent.width; label: qsTr("Download") }

            Rectangle {
                width: parent.width
                height: 26 * root.s
                radius: Theme.radiusWidget
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: urlInput.activeFocus ? Theme.primary : Theme.outline
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                SumiEdge {}

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12 * root.s
                    anchors.rightMargin: 12 * root.s
                    spacing: 9 * root.s

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 13 * root.s
                        text: "link"
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    TextInput {
                        id: urlInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 27 * root.s - parent.spacing
                        text: root.urlText
                        onTextChanged: root.urlText = text
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                        clip: true
                        selectByMouse: true
                        onAccepted: root.startDownload()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: urlInput.text.length === 0
                            text: qsTr("Paste a link to download")
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font: urlInput.font
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6 * root.s
                readonly property real segW: (width - 2 * spacing) / 3

                Repeater {
                    model: root.modes
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: Stash.dlMode === modelData.id
                        width: parent.segW
                        height: 22 * root.s
                        radius: Theme.radiusWidget
                        color: on ? Theme.primary : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.05)
                        border.width: 1
                        border.color: on ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.on ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                                : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: 9 * root.s
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Stash.dlMode = modelData.id
                        }
                    }
                }
            }

            ActionButton {
                width: parent.width
                label: qsTr("Download")
                icon: "download"
                primary: root.urlText.trim().length > 0
                enabled: root.urlText.trim().length > 0
                onTapped: root.startDownload()
            }

            // what cobalt can pull from, live from the instance (built-in list otherwise).
            Rectangle {
                width: parent.width
                visible: Stash.supportedSites.length > 0
                radius: Theme.radiusWidget
                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.04)
                border.width: Theme.borderWidth
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                implicitHeight: sitesCol.implicitHeight + 18 * root.s

                Column {
                    id: sitesCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 9 * root.s
                    spacing: 4 * root.s

                    Row {
                        spacing: 5 * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 10 * root.s
                            text: "public"
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("WORKS WITH %1 SITES").arg(Stash.supportedSites.length)
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: 6.5 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.5
                        }
                    }

                    Text {
                        width: parent.width
                        text: Stash.supportedSites.map(s => s === "twitter" ? "x" : s).join("  ·  ")
                        wrapMode: Text.WordWrap
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.mono
                        font.pixelSize: 8.5 * root.s
                        lineHeight: 1.3
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6 * root.s
                visible: Stash.queueModel.count > 0

                Repeater {
                    model: Stash.queueModel
                    delegate: Rectangle {
                        required property var model
                        width: parent.width
                        height: 24 * root.s
                        radius: Theme.radiusWidget
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.05)

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12 * root.s
                            anchors.rightMargin: 12 * root.s
                            spacing: 5 * root.s

                            Item {
                                width: parent.width
                                height: qName.implicitHeight

                                Text {
                                    id: qName
                                    anchors.left: parent.left
                                    anchors.right: qState.left
                                    anchors.rightMargin: 8 * root.s
                                    text: model.name && model.name.length > 0 ? model.name : model.arg
                                    elide: Text.ElideRight
                                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: 9 * root.s
                                }
                                Text {
                                    id: qState
                                    anchors.right: parent.right
                                    text: model.state === "running" ? model.pct + "%" : model.state
                                    color: model.state === "error" ? Theme.vermLit
                                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                                    font.family: Theme.mono
                                    font.pixelSize: 8 * root.s
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 2
                                radius: 1
                                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.1)
                                Rectangle {
                                    height: parent.height
                                    radius: 1
                                    width: parent.width * Math.max(0, Math.min(1, (model.pct || 0) / 100))
                                    color: Theme.primary
                                    Behavior on width { NumberAnimation { duration: Motion.fast } }
                                }
                            }
                        }
                    }
                }
            }

            Menus.QsSection { width: parent.width; label: qsTr("Recently downloaded") }

            Text {
                width: parent.width
                visible: Stash.count === 0
                text: qsTr("Nothing downloaded yet. Links you grab land here.")
                wrapMode: Text.WordWrap
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.fontPrimary
                font.pixelSize: 9 * root.s
            }

            Column {
                width: parent.width
                spacing: 6 * root.s

                Repeater {
                    model: Stash.recentFiles
                    delegate: Rectangle {
                        id: fileRow
                        required property var modelData
                        width: parent.width
                        height: 24 * root.s
                        radius: Theme.radiusWidget
                        color: rowArea.containsMouse
                            ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                            : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.04)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Stash.openFile(fileRow.modelData.path)
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: rmBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12 * root.s
                            anchors.rightMargin: 6 * root.s
                            spacing: 10 * root.s

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 13 * root.s
                                text: root.fileGlyph(fileRow.modelData.name)
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 * root.s - parent.spacing
                                text: fileRow.modelData.name
                                elide: Text.ElideMiddle
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                font.family: Theme.fontPrimary
                                font.pixelSize: 9 * root.s
                            }
                        }

                        MaterialIcon {
                            id: rmBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 10 * root.s
                            font.pixelSize: 13 * root.s
                            text: "close"
                            color: Theme.inkOn(Theme.effectiveSurface, rmArea.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant, 3.0)
                            MouseArea {
                                id: rmArea
                                anchors.fill: parent
                                anchors.margins: -8 * root.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stash.removeFile(fileRow.modelData.path)
                            }
                        }
                    }
                }
            }

            Menus.QsSection { width: parent.width; label: qsTr("Convert & install") }

            ActionButton {
                width: parent.width
                label: qsTr("Compress video…")
                icon: "compress"
                onTapped: root.pick("compress")
            }
            ActionButton {
                width: parent.width
                label: qsTr("Install app…")
                icon: "install_desktop"
                onTapped: root.pick("install")
            }

            Item { width: 1; height: 6 * root.s }
        }
    }

    // primary = bone plate + dark ink; otherwise a quiet outlined tile.
    component ActionButton: Item {
        id: btn
        property string label: ""
        property string icon: ""
        property bool primary: false
        signal tapped()

        implicitHeight: 24 * root.s
        opacity: btn.enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusWidget
            color: btn.primary ? Theme.primary
                : ba.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.04)
            border.width: btn.primary ? 0 : Theme.borderWidth
            border.color: Theme.outline
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            SumiEdge { visible: btn.primary }

            Row {
                anchors.centerIn: parent
                spacing: 8 * root.s

                MaterialIcon {
                    visible: btn.icon.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 13 * root.s
                    text: btn.icon
                    color: btn.primary ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: btn.label
                    color: btn.primary ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        scale: ba.pressed && btn.enabled ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast } }

        MouseArea {
            id: ba
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }
    }
}
