import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: main
    implicitWidth: Screen.width
    implicitHeight: Screen.height
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property color bgMain:       "#000000"
    readonly property color accent:       "#89b4fa"
    readonly property color activeTagBg:  "#89b4fa"
    readonly property color activeTagText:"#11111b"
    readonly property color borderCol:    "#1e1e2e"
    readonly property color textMain:     "#cdd6f4"
    readonly property string activeFont:  "JetBrains Mono"
    readonly property string wallPath:    Quickshell.env("RYOKU_VROOMIES_WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/visions/")
    readonly property string wallScript:  (Quickshell.env("RYOKU_VROOMIES_SHELL_DIR") || (Quickshell.env("HOME") + "/.config/quickshell/ryoku-vroomies-shell")) + "/components/wall/wall.sh"

    Item {
        id: root
        anchors.fill: parent
        focus: true

        Component.onCompleted: root.forceActiveFocus()

        Rectangle {
            id: mainPanel
            width: 1120; height: 700
            anchors.centerIn: parent
            color: bgMain
            radius: 12
            border.color: borderCol
            border.width: 1
            clip: true

            Item {
                id: header
                width: parent.width; height: 85

                Row {
                    anchors.left: parent.left; anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text { text: "󰸉"; font.pixelSize: 26; color: accent; font.family: "Symbols Nerd Font" }
                    Text { text: "Wallpapers"; font.pixelSize: 22; font.bold: true; color: textMain }
                }

                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    width: 95; height: 30; radius: 15; color: "#11111b"
                    Text {
                        anchors.centerIn: parent
                        text: folderModel.count + " images"
                        font.pixelSize: 14; color: "#a6adc8"
                    }
                }
            }

            GridView {
                id: grid
                width: parent.width - 40; height: parent.height - 110
                anchors.top: header.bottom; anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                model: folderModel
                cellWidth: width / 4; cellHeight: 185
                clip: true
                cacheBuffer: 1000

                FolderListModel {
                    id: folderModel
                    folder: "file://" + wallPath
                    showDirs: false
                    nameFilters: ["*.png","*.jpg","*.jpeg","*.webp"]
                }

                delegate: Item {
                    width: grid.cellWidth; height: grid.cellHeight

                    Rectangle {
                        width: parent.width - 12; height: parent.height - 12
                        anchors.centerIn: parent
                        radius: 8; color: "#0a0a0a"; clip: true

                        border.width: grid.currentIndex === index ? 2 : 0
                        border.color: accent

                        Image {
                            anchors.fill: parent
                            source: "file://" + filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(400, 250)
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            visible: grid.currentIndex === index
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.margins: 12
                            width: 68; height: 24; radius: 4
                            color: activeTagBg

                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                color: activeTagText
                                font.bold: true
                                font.pixelSize: 10
                                font.family: activeFont
                                font.letterSpacing: 1
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                grid.currentIndex = index
                                root.forceActiveFocus()
                            }
                            onDoubleClicked: applyWallpaper(filePath)
                        }
                    }
                }
            }
        }

        Keys.onPressed: (event) => {
            if      (event.key === Qt.Key_Right || event.key === Qt.Key_L) grid.moveCurrentIndexRight()
            else if (event.key === Qt.Key_Left  || event.key === Qt.Key_H) grid.moveCurrentIndexLeft()
            else if (event.key === Qt.Key_Down  || event.key === Qt.Key_J) grid.moveCurrentIndexDown()
            else if (event.key === Qt.Key_Up    || event.key === Qt.Key_K) grid.moveCurrentIndexUp()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                let path = folderModel.get(grid.currentIndex, "filePath")
                if (path) applyWallpaper(path)
            }
            else if (event.key === Qt.Key_Escape) main.visible = false
        }
    }

    function applyWallpaper(path) {
        console.log("PATH:", path)
        console.log("SCRIPT:", wallScript)
        Quickshell.execDetached(["bash", wallScript, path])
        main.visible = false
    }
}
