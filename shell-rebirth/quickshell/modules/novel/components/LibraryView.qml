import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../colors" as ColorsModule
import qs.services

Item {
    id: libraryView

    readonly property var c: ColorsModule.Colors
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal novelSelected(string novelId)

    Rectangle { anchors.fill: parent; color: c.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: Novel.libraryList.length === 0 && Novel.libraryLoaded

            Column {
                anchors.centerIn: parent; spacing: 14
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⊡"; font.pixelSize: 44; color: c.outline; opacity: 0.3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Your library is empty"
                    font.family: libraryView.fontDisplay; font.pixelSize: 15
                    color: c.on_surface; opacity: 0.45
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Open any novel and tap  + Library"
                    font.family: libraryView.fontBody; font.pixelSize: 11
                    color: c.on_surface_variant; opacity: 0.4; font.letterSpacing: 0.2
                }
            }
        }


        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: !Novel.libraryLoaded

            Rectangle {
                width: 28; height: 28; radius: 14; anchors.centerIn: parent
                color: "transparent"; border.color: c.primary; border.width: 2
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 800
                    loops: Animation.Infinite; running: parent.visible; easing.type: Easing.Linear
                }
            }
        }

        GridView {
            id: libGrid
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: Novel.libraryList.length > 0
            topMargin: 10; leftMargin: 8; rightMargin: 8; bottomMargin: 10
            cellWidth: Math.floor((width - leftMargin - rightMargin) / 4)
            cellHeight: cellWidth * 1.72
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: Novel.libraryList

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; color: c.primary; opacity: 0.45; radius: 2 }
            }

            delegate: Item {
                width: libGrid.cellWidth; height: libGrid.cellHeight

                Rectangle {
                    id: libCard
                    anchors { fill: parent; margins: 5 }
                    radius: 12; color: c.surface_container; clip: true

                    Image {
                        id: libCover
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: parent.height - libTitleBar.height - libProgressBar.height
                        source: modelData.coverUrl || ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            anchors.fill: parent; color: c.surface_container_high
                            visible: libCover.status !== Image.Ready
                            Text { anchors.centerIn: parent; text: "◫"; font.pixelSize: 32; color: c.outline; opacity: 0.25 }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 52
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: c.surface_container }
                            }
                        }
                    }

                    Rectangle {
                        id: libTitleBar
                        anchors { bottom: libProgressBar.top; left: parent.left; right: parent.right }
                        height: libTitleText.implicitHeight + 10; color: c.surface_container

                        Text {
                            id: libTitleText
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10; rightMargin: 10
                            }
                            text: modelData.title || ""
                            font.family: libraryView.fontBody; font.pixelSize: 11
                            font.letterSpacing: 0.2; color: c.on_surface
                            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.3
                        }
                    }

                    Rectangle {
                        id: libProgressBar
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 30; color: c.surface_container_high; radius: 12

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.radius; color: parent.color
                        }

                        Row {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▶"; font.pixelSize: 7
                                color: modelData.lastReadChapterNum ? c.primary : c.outline
                                opacity: modelData.lastReadChapterNum ? 1 : 0.4
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.lastReadChapterNum
                                    ? "Ch. " + modelData.lastReadChapterNum
                                    : "Not started"
                                font.family: libraryView.fontBody; font.pixelSize: 10
                                font.letterSpacing: 0.4
                                color: modelData.lastReadChapterNum ? c.on_surface : c.on_surface_variant
                                opacity: modelData.lastReadChapterNum ? 0.85 : 0.45
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 12; color: c.primary
                        opacity: libCardArea.pressed ? 0.16 : (libCardArea.containsMouse ? 0.07 : 0)
                        Behavior on opacity { NumberAnimation { duration: 130 } }
                    }

                    transform: Scale {
                        origin.x: libCard.width / 2; origin.y: libCard.height / 2
                        xScale: libCardArea.pressed ? 0.97 : 1.0
                        yScale: libCardArea.pressed ? 0.97 : 1.0
                        Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: libCardArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            Novel.fetchNovelDetail(modelData.id)
                            libraryView.novelSelected(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
