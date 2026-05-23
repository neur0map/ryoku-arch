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

    implicitHeight: 58
    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.normal
        spacing: Tokens.spacing.normal

        IconTextButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "tune"
            text: qsTr("Advanced settings")
            type: IconTextButton.Tonal
            horizontalPadding: Tokens.padding.normal
            verticalPadding: Tokens.padding.smaller

            onClicked: {
                Quickshell.execDetached(["hyprmod"]);
                QsWindow.window.destroy();
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
