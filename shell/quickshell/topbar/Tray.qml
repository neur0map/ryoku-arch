pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "Singletons"

Item {
    id: tray

    property real s: 1
    property var barWindow

    visible: SystemTray.items.values.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 28 * tray.s

    function showMenu(item, anchorItem) {
        if (!item.hasMenu)
            return;
        opener.menu = item.menu;
        var p = anchorItem.mapToItem(null, anchorItem.width / 2, 0);
        menu.anchorX = 12 * tray.s + p.x;
        menu.open = true;
    }

    QsMenuOpener {
        id: opener
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 2 * tray.s

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: slot

                required property var modelData

                Layout.preferredWidth: 28 * tray.s
                Layout.preferredHeight: 28 * tray.s

                Rectangle {
                    id: hover
                    anchors.fill: parent
                    radius: 7 * tray.s
                    color: Theme.sheen
                    opacity: area.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Image {
                    anchors.centerIn: parent
                    source: slot.modelData.icon
                    sourceSize.width: 36
                    sourceSize.height: 36
                    width: 18 * tray.s
                    height: 18 * tray.s
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            slot.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            tray.showMenu(slot.modelData, slot);
                        } else {
                            var entry = DesktopEntries.heuristicLookup(slot.modelData.id);
                            if (entry)
                                entry.execute();
                            else
                                slot.modelData.activate();
                        }
                    }
                    onWheel: (wheel) => {
                        slot.modelData.scroll(wheel.angleDelta.y, false);
                    }
                }
            }
        }
    }

    PanelWindow {
        id: menu

        property bool open: false
        property real anchorX: 0

        screen: tray.barWindow ? tray.barWindow.screen : null
        visible: open
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "topbar-tray"

        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.open = false
        }

        FocusScope {
            anchors.fill: parent
            focus: menu.open

            Keys.onEscapePressed: menu.open = false

            Rectangle {
                id: card

                x: Math.max(8 * tray.s, Math.min(menu.anchorX - width / 2, menu.width - width - 8 * tray.s))
                y: 50 * tray.s
                width: 220 * tray.s
                radius: 12 * tray.s
                clip: true

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.cardTop }
                    GradientStop { position: 1.0; color: Theme.cardBot }
                }
                border.width: 1
                border.color: Theme.border

                implicitHeight: col.implicitHeight + 12 * tray.s
                height: implicitHeight

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 10 * tray.s
                    anchors.rightMargin: 10 * tray.s
                    height: 1
                    color: Theme.sheen
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadow
                    shadowBlur: 0.9
                    shadowVerticalOffset: 4 * tray.s
                }

                MouseArea { anchors.fill: parent }

                Column {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6 * tray.s
                    spacing: 0

                    Repeater {
                        model: opener.children ? opener.children.values : []

                        delegate: Item {
                            id: entry
                            required property var modelData
                            width: col.width
                            height: modelData.isSeparator ? 9 * tray.s : 32 * tray.s

                            Rectangle {
                                visible: entry.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8 * tray.s
                                anchors.rightMargin: 8 * tray.s
                                height: 1
                                color: Theme.hair
                            }

                            Rectangle {
                                visible: !entry.modelData.isSeparator
                                anchors.fill: parent
                                radius: 8 * tray.s
                                color: rowArea.containsMouse && entry.modelData.enabled
                                    ? Theme.accent16 : "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 6 * tray.s
                                    width: 3 * tray.s
                                    height: parent.height * 0.46
                                    radius: width / 2
                                    color: Theme.vermLit
                                    opacity: rowArea.containsMouse && entry.modelData.enabled ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                Image {
                                    id: entryIcon
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 16 * tray.s
                                    width: entry.modelData.icon ? 15 * tray.s : 0
                                    height: 15 * tray.s
                                    source: entry.modelData.icon
                                    sourceSize.width: 30
                                    sourceSize.height: 30
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    visible: entry.modelData.icon
                                }

                                Text {
                                    anchors.left: entryIcon.right
                                    anchors.leftMargin: entry.modelData.icon ? 9 * tray.s : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14 * tray.s
                                    text: entry.modelData.text
                                    color: !entry.modelData.enabled ? Theme.dim
                                        : (rowArea.containsMouse ? Theme.cream : Qt.rgba(230 / 255, 214 / 255, 203 / 255, 0.82))
                                    font.family: Theme.font
                                    font.pixelSize: 13 * tray.s
                                    font.weight: rowArea.containsMouse ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: entry.modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        entry.modelData.triggered();
                                        menu.open = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
