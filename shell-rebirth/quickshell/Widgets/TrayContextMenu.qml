import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../colors" as ColorsModule

PanelWindow {
    id: root

    property var menuHandle: null
    property real menuX: 0
    property real menuY: 0
    property bool hasCurrent: false
    property int animLength: 400
    property var animCurve: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
    property var colors: ColorsModule.Colors

    function open(handle, x, y) {
        menuHandle = handle;
        let width = 240;
        let safeX = x - (width / 2);
        safeX = Math.max(8, Math.min(safeX, Screen.width - width - 8));
        menuX = safeX;
        menuY = y - 32;
        hasCurrent = true;
    }

    function close() {
        hasCurrent = false;
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: wrapper.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        enabled: wrapper.visible
        onClicked: root.close()
    }

    Item {
        id: wrapper

        readonly property real contentHeight: menuColumn.implicitHeight + 16

        x: root.menuX
        y: root.menuY
        width: 240
        visible: height > 0
        clip: true
        implicitHeight: root.hasCurrent ? contentHeight : 0

        Rectangle {
            id: menuBg

            anchors.fill: parent
            color: root.colors.surface_container  // was: colors.on_surface
            clip: true
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 14
            bottomRightRadius: 14

            QsMenuOpener {
                id: opener

                menu: root.menuHandle
            }

            Rectangle {
                id: highlight

                property real targetY: 0
                property bool active: false

                x: 8
                y: menuColumn.y + targetY
                width: parent.width - 16
                height: 36
                radius: 8
                color: root.colors.secondary  // was: colors.secondary
                opacity: active ? 0.15 : 0

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.8
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            Column {
                id: menuColumn

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 2

                Repeater {
                    model: opener.children

                    delegate: Item {
                        id: menuItem

                        property bool isSeparator: modelData.isSeparator
                        property bool hasChildren: modelData.hasChildren

                        width: menuColumn.width
                        height: isSeparator ? 12 : 36

                        Rectangle {
                            visible: isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 1
                            color: root.colors.outline_variant  // was: colors.border
                            opacity: 0.5
                        }

                        Rectangle {
                            visible: !isSeparator && highlight.active && highlight.targetY === menuItem.y
                            width: 3
                            height: 16
                            radius: 2
                            color: root.colors.primary  // was: colors.accent
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        RowLayout {
                            visible: !isSeparator
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20

                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: modelData.icon !== undefined && modelData.icon !== ""
                                    layer.enabled: true

                                    layer.effect: ColorOverlay {
                                        color: (highlight.active && highlight.targetY === menuItem.y)
                                            ? root.colors.primary           // was: colors.accent
                                            : root.colors.on_surface_variant // was: colors.muted
                                    }

                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !(modelData.icon !== undefined && modelData.icon !== "")
                                    text: ""
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 6
                                    color: (highlight.active && highlight.targetY === menuItem.y)
                                        ? root.colors.on_surface          // was: colors.on_surface
                                        : root.colors.on_surface_variant  // was: colors.muted
                                }

                            }

                            Text {
                                text: modelData.text || ""
                                color: (highlight.active && highlight.targetY === menuItem.y)
                                    ? root.colors.on_surface  // was: colors.fg
                                    : Qt.rgba(
                                        Qt.color(root.colors.on_surface).r,
                                        Qt.color(root.colors.on_surface).g,
                                        Qt.color(root.colors.on_surface).b,
                                        0.8
                                    )                        // was: Qt.rgba(colors.fg.r/g/b, 0.8)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 0.2
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                visible: (modelData.checkable && modelData.checked) || menuItem.hasChildren
                                text: menuItem.hasChildren ? "" : ""
                                font.family: "Symbols Nerd Font"
                                color: root.colors.primary  // was: colors.accent
                                font.pixelSize: 12
                            }

                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onEntered: {
                                if (!menuItem.isSeparator) {
                                    highlight.targetY = menuItem.y;
                                    highlight.active = true;
                                } else {
                                }
                            }
                            onClicked: {
                                if (!menuItem.isSeparator) {
                                    if (modelData.hasChildren) {
                                        root.menuHandle = modelData;
                                    } else {
                                        modelData.triggered();
                                        root.close();
                                    }
                                }
                            }
                        }

                    }

                }

            }

        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: root.animLength
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.animCurve
            }

        }

    }

    mask: Region {
        item: wrapper.visible ? wrapper : null
    }

}
