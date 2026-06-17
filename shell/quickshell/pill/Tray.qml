pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "Singletons"

/**
 * System tray. Draws StatusNotifier items as warm-tinted icons. Left-click
 * activates (preferring the resolved desktop entry), middle-click does the
 * secondary action, right-click opens the item's native menu in a floating
 * washi card, wheel scrolls the item. The menu gets its own overlay window so
 * it can grab keyboard focus for dismissal.
 */
Item {
    id: tray

    property real s: 1
    property var barWindow

    visible: SystemTray.items.values.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 24 * tray.s

    function showMenu(item, anchorItem) {
        if (!item.hasMenu)
            return;
        card.expandedIdx = -1;
        opener.menu = item.menu;
        var p = anchorItem.mapToItem(null, anchorItem.width / 2, 0);
        menu.anchorX = p.x;
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

                Layout.preferredWidth: 24 * tray.s
                Layout.preferredHeight: 24 * tray.s

                Rectangle {
                    anchors.fill: parent
                    radius: 6 * tray.s
                    color: Theme.frameBg
                    border.width: 1
                    border.color: Theme.frameBorder
                    opacity: area.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Image {
                    anchors.centerIn: parent
                    source: slot.modelData.icon
                    sourceSize.width: 32
                    sourceSize.height: 32
                    width: 16 * tray.s
                    height: 16 * tray.s
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
                        } else if (slot.modelData.onlyMenu) {
                            tray.showMenu(slot.modelData, slot);
                        } else {
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

    /**
     * One menu line: separator, or a row with optional checkbox/radio state,
     * icon, label and a submenu chevron that rotates when expanded. Used for
     * both top-level entries and indented submenu children.
     */
    component MenuRow: Item {
        id: mrow

        property var entryData
        property real indent: 0
        property bool expanded: false
        signal activated()

        height: entryData.isSeparator ? 9 * tray.s : 32 * tray.s

        Rectangle {
            visible: mrow.entryData.isSeparator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8 * tray.s + mrow.indent
            anchors.rightMargin: 8 * tray.s
            height: 1
            color: Theme.hair
        }

        Rectangle {
            visible: !mrow.entryData.isSeparator
            anchors.fill: parent
            anchors.leftMargin: mrow.indent
            radius: 8 * tray.s
            color: mrowArea.containsMouse && mrow.entryData.enabled
                ? Theme.frameBg : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6 * tray.s
                width: 2 * tray.s
                height: parent.height * 0.46
                radius: width / 2
                color: Theme.vermLit
                opacity: mrowArea.containsMouse && mrow.entryData.enabled ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            Rectangle {
                id: stateBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16 * tray.s
                readonly property bool isCheck: mrow.entryData.buttonType === QsMenuButtonType.CheckBox
                readonly property bool isRadio: mrow.entryData.buttonType === QsMenuButtonType.RadioButton
                readonly property bool present: isCheck || isRadio
                readonly property bool checked: mrow.entryData.checkState === Qt.Checked
                visible: present
                width: present ? 11 * tray.s : 0
                height: 11 * tray.s
                radius: isRadio ? width / 2 : 3 * tray.s
                color: "transparent"
                border.width: 1
                border.color: checked ? Theme.vermLit : Theme.border

                Rectangle {
                    anchors.centerIn: parent
                    visible: stateBox.checked
                    width: 5 * tray.s
                    height: 5 * tray.s
                    radius: stateBox.isRadio ? width / 2 : 1.5 * tray.s
                    color: Theme.vermLit
                }
            }

            Image {
                id: entryIcon
                anchors.left: stateBox.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: stateBox.present ? 8 * tray.s : 0
                width: mrow.entryData.icon ? 15 * tray.s : 0
                height: 15 * tray.s
                source: mrow.entryData.icon
                sourceSize.width: 30
                sourceSize.height: 30
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: mrow.entryData.icon
            }

            Text {
                anchors.left: entryIcon.right
                anchors.leftMargin: mrow.entryData.icon ? 9 * tray.s : 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: chevron.visible ? chevron.left : parent.right
                anchors.rightMargin: 14 * tray.s
                text: mrow.entryData.text
                color: !mrow.entryData.enabled ? Theme.dim
                    : (mrowArea.containsMouse ? Theme.cream : Theme.creamMenu)
                font.family: Theme.font
                font.pixelSize: 13 * tray.s
                font.weight: mrowArea.containsMouse ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            GlyphIcon {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 10 * tray.s
                anchors.verticalCenter: parent.verticalCenter
                visible: mrow.entryData.hasChildren === true
                width: 10 * tray.s
                height: 10 * tray.s
                name: "chevron-right"
                color: mrow.expanded ? Theme.vermLit : Theme.iconDim
                stroke: 2
                rotation: mrow.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: Motion.fast } }
            }

            MouseArea {
                id: mrowArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: mrow.entryData.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: mrow.activated()
            }
        }
    }

    PanelWindow {
        id: menu

        property bool open: false
        property real anchorX: 0

        onOpenChanged: {
            if (!open) {
                card.expandedIdx = -1;
                opener.menu = null;
            }
        }

        screen: tray.barWindow ? tray.barWindow.screen : null
        visible: open
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "pill-tray"

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

                property int expandedIdx: -1

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

                        delegate: Column {
                            id: entry

                            required property var modelData
                            required property int index
                            readonly property bool expanded: card.expandedIdx === index

                            width: col.width

                            MenuRow {
                                width: parent.width
                                entryData: entry.modelData
                                expanded: entry.expanded
                                onActivated: {
                                    if (entry.modelData.hasChildren) {
                                        card.expandedIdx = entry.expanded ? -1 : entry.index;
                                    } else {
                                        entry.modelData.triggered();
                                        menu.open = false;
                                    }
                                }
                            }

                            QsMenuOpener {
                                id: childOpener
                                menu: entry.expanded ? entry.modelData : null
                            }

                            Repeater {
                                model: childOpener.children ? childOpener.children.values : []

                                delegate: MenuRow {
                                    required property var modelData
                                    width: entry.width
                                    indent: 14 * tray.s
                                    entryData: modelData
                                    onActivated: {
                                        if (!modelData.hasChildren) {
                                            modelData.triggered();
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
}
