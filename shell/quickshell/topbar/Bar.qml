import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Singletons"

Item {
    id: bar

    required property var screen
    property string screenName: ""
    property real s: 1
    property var barWindow

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 22
        border.width: 1
        border.color: Theme.border
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 1
            color: Theme.sheen
        }

        Item {
            id: leftZone
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12 * bar.s
            implicitWidth: leftRow.implicitWidth
            width: leftRow.implicitWidth

            RowLayout {
                id: leftRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * bar.s

                Item {
                    Layout.preferredWidth: 18 * bar.s
                    Layout.preferredHeight: 18 * bar.s

                    Image {
                        id: ryokuImg
                        anchors.fill: parent
                        source: Qt.resolvedUrl("assets/icons/ryoku.svg")
                        sourceSize.width: 96
                        sourceSize.height: 96
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: false
                    }

                    MultiEffect {
                        source: ryokuImg
                        anchors.fill: ryokuImg
                        colorization: 1.0
                        colorizationColor: Theme.vermLit
                    }
                }

                Workspaces {
                    screenName: bar.screenName
                    s: bar.s
                }
            }
        }

        Clock {
            id: clock
            anchors.centerIn: parent
            s: bar.s
            barWindow: bar.barWindow
        }

        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12 * bar.s
            spacing: 8 * bar.s

            Mpris {
                s: bar.s
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16 * bar.s
                Layout.alignment: Qt.AlignVCenter
                color: Theme.hair
            }

            RowLayout {
                spacing: 2 * bar.s

                Minimized {
                    s: bar.s
                }

                Tray {
                    s: bar.s
                    barWindow: bar.barWindow
                }

                SidebarButton {
                    s: bar.s
                    screenName: bar.screenName
                }

                Power {
                    s: bar.s
                    barWindow: bar.barWindow
                }
            }
        }
    }
}
