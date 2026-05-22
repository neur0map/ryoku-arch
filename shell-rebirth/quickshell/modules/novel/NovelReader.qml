import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../colors" as ColorsModule
import qs.services
import qs.modules.novel.components

Item {
    id: root
    anchors {
        top: parent.top
        bottom: parent.bottom
        right: parent.right
    }
    implicitWidth: 600
    visible: false

    readonly property var c: ColorsModule.Colors
    readonly property string fontBody: "Noto Sans"

    property int tabIndex: 0

    property int browseStack:  0
    property int libraryStack: 0

    Rectangle { anchors.fill: parent; color: c.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 44
            color: c.surface_container_low; z: 10

            Rectangle {
                anchors { bottom: parent.bottom; right: parent.right; left: parent.left }
                height: 1; color: c.outline_variant; opacity: 0.4
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { label: "Browse",  icon: "⊞" },
                        { label: "Library", icon: "⊟" }
                    ]

                    delegate: Item {
                        width: root.width / 2; height: parent.height
                        readonly property bool active: root.tabIndex === index

                        Rectangle {
                            anchors.fill: parent
                            color: tabTap.containsMouse && !active
                                ? Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.05)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon; font.pixelSize: 13
                                color: active ? c.primary : c.on_surface_variant
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label; font.family: root.fontBody
                                font.pixelSize: 10; font.letterSpacing: 0.6
                                color: active ? c.primary : c.on_surface_variant
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        // Active indicator
                        Rectangle {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            width: active ? 28 : 0; height: 2; radius: 1; color: c.primary
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: tabTap; anchors.fill: parent; hoverEnabled: true
                            onClicked: root.tabIndex = index
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: root.tabIndex

            Item {
                BrowseView {
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onNovelSelected: function(novelId) {
                        root.browseStack = 1
                    }
                }

                DetailView {
                    id: browseDetail
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested:    { root.browseStack = 0 }
                    onChapterSelected:  { root.browseStack = 2 }
                }

                ReaderView {
                    id: browseReader
                    anchors.fill: parent
                    visible: root.browseStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.browseStack = 1
                        browseReader.reset()
                    }
                }
            }

            Item {
                LibraryView {
                    anchors.fill: parent
                    visible: root.libraryStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onNovelSelected: function(novelId) {
                        root.libraryStack = 1
                    }
                }

                DetailView {
                    id: libraryDetail
                    anchors.fill: parent
                    visible: root.libraryStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested:   { root.libraryStack = 0 }
                    onChapterSelected: { root.libraryStack = 2 }
                }

                ReaderView {
                    id: libraryReader
                    anchors.fill: parent
                    visible: root.libraryStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.libraryStack = 1
                        libraryReader.reset()
                    }
                }
            }
        }
    }
}
