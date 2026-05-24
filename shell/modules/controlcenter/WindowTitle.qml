import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property ShellScreen screen
    required property Session session

    implicitHeight: 44
    color: Colours.palette.m3surfaceContainer

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.normal
        anchors.rightMargin: Tokens.padding.small
        spacing: Tokens.spacing.small

        IconTextButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "tune"
            text: qsTr("Hyprland")
            type: IconTextButton.Tonal
            horizontalPadding: Tokens.padding.small
            verticalPadding: Tokens.padding.smaller
            enabled: !closeAfterHyprmodLaunch.running

            onClicked: {
                Quickshell.execDetached(["ryoku-launch-hyprmod"]);
                closeAfterHyprmodLaunch.restart();
            }

            Timer {
                id: closeAfterHyprmodLaunch

                interval: 2200
                repeat: false

                onTriggered: {
                    QsWindow.window.destroy();
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.session.active
                color: Colours.palette.m3onSurfaceVariant
                font.capitalization: Font.Capitalize
                font.pointSize: Tokens.font.size.normal
                elide: Text.ElideRight
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: implicitHeight
            implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                onClicked: {
                    QsWindow.window.destroy();
                }

                radius: Tokens.rounding.full
            }

            MaterialIcon {
                id: closeIcon

                anchors.centerIn: parent
                text: "close"
            }
        }
    }
}
