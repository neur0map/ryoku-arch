pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import "Singletons"

// Modal image picker: a thumbnail grid over a folder, so you choose by sight
// instead of by filename in the OS dialog. Folders open in place, an image tile
// picks and closes. Reusable wherever the Hub needs an image off disk.
Item {
    id: picker

    property bool active: false
    readonly property string home: Quickshell.env("HOME") || ""
    property url startFolder: "file://" + picker.home + "/Pictures"
    property url currentFolder: picker.startFolder

    signal picked(string path)
    signal canceled()

    function open() {
        picker.currentFolder = picker.startFolder;
        picker.active = true;
    }
    function goto(sub) {
        picker.currentFolder = "file://" + picker.home + (sub.length ? "/" + sub : "");
    }

    anchors.fill: parent
    visible: picker.active
    z: 100

    FolderListModel {
        id: fm
        folder: picker.currentFolder
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.bmp"]
        sortField: FolderListModel.Name
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: picker.canceled() }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 900)
        height: Math.min(parent.height - 60, 640)
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        MouseArea { anchors.fill: parent; onClicked: {} }

        // --- header: title, folder path, close ---------------------------
        Text {
            id: title
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 22
            anchors.topMargin: 18
            text: "Choose a backdrop"
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: title.left
            anchors.top: title.bottom
            anchors.topMargin: 4
            anchors.right: closeBtn.left
            anchors.rightMargin: 12
            elide: Text.ElideLeft
            text: ("" + picker.currentFolder).replace("file://", "").replace(picker.home, "~")
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
        }

        Rectangle {
            id: closeBtn
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 16
            anchors.topMargin: 16
            width: 30
            height: 30
            radius: Theme.radius
            color: closeHov.hovered ? Theme.surfaceLo : "transparent"
            Icon { anchors.centerIn: parent; name: "close"; size: 15; tint: closeHov.hovered ? Theme.bright : Theme.dim }
            HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: picker.canceled() }
        }

        // --- nav: quick locations + up -----------------------------------
        Row {
            id: nav
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 34
            spacing: 8

            component Chip: Rectangle {
                id: chip
                property string label: ""
                signal clicked()
                width: chipText.implicitWidth + 22
                height: 28
                radius: Theme.radius
                color: chipHov.hovered ? Theme.keyTop : Theme.surfaceLo
                border.width: 1
                border.color: chipHov.hovered ? Theme.subtle : Theme.line
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.label
                    color: chipHov.hovered ? Theme.bright : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: chip.clicked() }
            }

            Chip { label: "\u2191 Up"; onClicked: picker.currentFolder = fm.parentFolder }
            Chip { label: "Home"; onClicked: picker.goto("") }
            Chip { label: "Pictures"; onClicked: picker.goto("Pictures") }
            Chip { label: "Downloads"; onClicked: picker.goto("Downloads") }
        }

        // --- grid --------------------------------------------------------
        GridView {
            id: grid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: nav.bottom
            anchors.bottom: footer.top
            anchors.leftMargin: 18
            anchors.rightMargin: 12
            anchors.topMargin: 16
            anchors.bottomMargin: 8
            clip: true
            readonly property int cols: Math.max(3, Math.floor(width / 190))
            cellWidth: Math.floor(width / cols)
            cellHeight: Math.round(cellWidth * 0.72)
            cacheBuffer: 1200
            boundsBehavior: Flickable.StopAtBounds
            model: fm

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }

            delegate: Item {
                id: tile
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: Theme.radius
                    color: Theme.surfaceLo
                    border.width: tileHov.hovered ? 1.6 : 1
                    border.color: tileHov.hovered ? Theme.ember : Theme.line
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                    // folder tile: icon + name
                    Column {
                        visible: tile.fileIsDir
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "folder"; size: 30; tint: Theme.cream }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.parent.width - 20
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            text: tile.fileName
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    // image thumbnail
                    Image {
                        visible: !tile.fileIsDir
                        anchors.fill: parent
                        anchors.margins: 1
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(Math.ceil(parent.width * 1.4), Math.ceil(parent.height * 1.4))
                        source: tile.fileIsDir ? "" : tile.fileUrl
                    }

                    // filename ribbon on hover
                    Rectangle {
                        visible: !tile.fileIsDir && tileHov.hovered
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 20
                        color: Qt.rgba(0, 0, 0, 0.6)
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideMiddle
                            text: tile.fileName
                            color: Theme.bright
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }

                    HoverHandler { id: tileHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (tile.fileIsDir)
                                picker.currentFolder = tile.fileUrl;
                            else
                                picker.picked("" + tile.fileUrl);
                        }
                    }
                }
            }
        }

        // empty state
        Column {
            anchors.centerIn: grid
            spacing: 10
            visible: fm.status === FolderListModel.Ready && fm.count === 0
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "image"; size: 28; tint: Theme.faint }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No images or folders here"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        // --- footer: cancel ----------------------------------------------
        Rectangle {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 56
            color: "transparent"

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.lineSoft
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: cancelText.implicitWidth + 28
                height: 32
                radius: Theme.radius
                color: cancelHov.hovered ? Theme.surfaceLo : "transparent"
                border.width: 1
                border.color: Theme.line
                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: cancelHov.hovered ? Theme.bright : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                HoverHandler { id: cancelHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: picker.canceled() }
            }
        }
    }
}
