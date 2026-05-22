import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../colors" as ColorsModule

RowLayout {
    id: trayRoot

    property var colors: ColorsModule.Colors

    property int iconSize: 16
    property var pinnedApps: []
    property var blacklist: []
    property bool hidePassive: false

    spacing: 6

    Repeater {
        model: SystemTray.items.values

        delegate: Rectangle {
            // Filter here instead
            visible: {
                let item = modelData
                if (!item) return false
                if (trayRoot.blacklist.some(name =>
                    item.id.toLowerCase().includes(name.toLowerCase())))
                    return false
                if (trayRoot.hidePassive && item.status === SystemTrayStatus.Passive)
                    return false
                return true
            }
            height: visible ? trayRoot.iconSize + 10 : 0
            width: visible ? trayRoot.iconSize + 10 : 0

            Layout.preferredWidth: visible ? trayRoot.iconSize + 10 : 0
            Layout.preferredHeight: visible ? trayRoot.iconSize + 10 : 0

            radius: 6
            color: itemMouseArea.containsMouse
                ? colors.primary_container
                : "transparent"

            Image {
                id: trayIcon
                anchors.centerIn: parent

                width: trayRoot.iconSize
                height: trayRoot.iconSize

                source: modelData.icon || ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready || status === Image.Loading
            }

            // ---------- fallback ----------
            Text {
                anchors.centerIn: parent
                text: trayIcon.status === Image.Error ? "?" : ""
                color: colors.on_surface
                font.pixelSize: 10
                visible: trayIcon.status === Image.Error
            }

            // ---------- interactions ----------
            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate()
                    else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                        var pos = mapToGlobal(width/2, height)
                        contextMenu.open(modelData.menu, pos.x, pos.y)
                    }
                }
            }
        }
    }

    TrayContextMenu {
        id: contextMenu
    }
}
