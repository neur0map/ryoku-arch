import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtQuick.Window
import Quickshell
import Quickshell.Io

Rectangle {
    id: window

    width: 1920
    height: 400
    color: "transparent"
    anchors.fill: parent
    focus: true
    visible: false

    readonly property string srcDir: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"

    readonly property string setwallCommand: Quickshell.env("HOME") + "/.local/bin/setwall '%1'"

    readonly property int itemWidth: 300
    readonly property int itemHeight: 420
    readonly property int borderWidth: 3
    readonly property int spacing: 0
    readonly property real skewFactor: -0.35

    Shortcut { sequence: "Escape"; onActivated: window.visible = false }

    FocusScope {
        focus: parent.visible
        anchors.fill: parent
        ListView {
            id: view
            anchors.fill: parent
            anchors.margins: 0

            spacing: window.spacing
            orientation: ListView.Horizontal

            clip: false
            cacheBuffer: 2000  // Keep this for preloading

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - (window.itemWidth / 2)
            preferredHighlightEnd: (width / 2) + (window.itemWidth / 2)

            highlightMoveDuration: 300

            focus: true

            property bool initialFocusSet: false
            onCountChanged: {
                if (!initialFocusSet && count > 0) {
                    var idx = parseInt(Quickshell.env("WALLPAPER_INDEX") || "0")
                    if (count > idx) {
                        currentIndex = idx
                        positionViewAtIndex(idx, ListView.Center)
                        initialFocusSet = true
                    }
                }
            }

            model: FolderListModel {
                id: folderModel
                folder: window.srcDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
                showDirs: false
                sortField: FolderListModel.Name
            }

            Keys.onReturnPressed: {
                if (currentItem) currentItem.pickWallpaper()
            }

            delegate: Item {
                id: delegateRoot
                width: window.itemWidth
                height: window.itemHeight
                anchors.verticalCenter: parent.verticalCenter

                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isVideo: fileName.toLowerCase().match(/\.(mp4|mkv|mov|webm)$/)
                readonly property int reqImgWidth: window.itemWidth + (window.itemHeight * Math.abs(window.skewFactor)) + 50

                z: isCurrent ? 10 : 1

                function pickWallpaper() {
                    let originalFile = window.srcDir + "/" + fileName

                    originalFile = originalFile.replace(/^file:\/\//, "")

                    const finalCmd = window.setwallCommand.arg(originalFile)
                    Quickshell.execDetached(["bash", "-c", finalCmd])
                    window.visible = false
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        view.currentIndex = index
                        delegateRoot.pickWallpaper()
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height

                    scale: delegateRoot.isCurrent ? 1.15 : 0.95
                    opacity: delegateRoot.isCurrent ? 1.0 : 0.6

                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 500 } }

                    transform: Matrix4x4 {
                        property real s: window.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: window.borderWidth

                        Rectangle { anchors.fill: parent; color: "black" }
                        clip: true

                        Image {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: -35

                            width: parent.width + (parent.height * Math.abs(window.skewFactor)) + 50
                            height: parent.height

                            fillMode: Image.PreserveAspectCrop
                            source: fileUrl
                            sourceSize: Qt.size(delegateRoot.reqImgWidth, window.itemHeight)
                            asynchronous: true

                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        Rectangle {
                            visible: delegateRoot.isVideo
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10

                            width: 32
                            height: 32
                            radius: 6
                            color: "#60000000"

                            transform: Matrix4x4 {
                                property real s: -window.skewFactor
                                matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            Canvas {
                                anchors.fill: parent
                                anchors.margins: 8
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.fillStyle = "#EEFFFFFF";
                                    ctx.beginPath();
                                    ctx.moveTo(4, 0);
                                    ctx.lineTo(14, 8);
                                    ctx.lineTo(4, 16);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }
                    }
                }
            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                    event.key === Qt.Key_Up || event.key === Qt.Key_Down ||
                    event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    view.forceActiveFocus()
                    event.accepted = false
                }
            }
        }
    }
}
