import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "Singletons"

Item {
    id: btn

    property real s: 1
    property var barWindow

    readonly property var actions: [
        { label: "Lock", argv: ["ryoku-shell", "lock"] },
        { label: "Logout", dispatch: "hl.dsp.exit()" },
        { label: "Reboot", argv: ["systemctl", "reboot"] },
        { label: "Shutdown", argv: ["systemctl", "poweroff"] }
    ]

    implicitWidth: 28 * s
    implicitHeight: 28 * s

    function run(action) {
        if (action.dispatch)
            Hyprland.dispatch(action.dispatch);
        else
            Quickshell.execDetached(action.argv);
        menu.open = false;
    }

    Rectangle {
        id: hover
        anchors.fill: parent
        radius: 7 * btn.s
        color: Theme.sheen
        opacity: area.containsMouse || menu.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Image {
        id: glyph
        anchors.centerIn: parent
        width: 16 * btn.s
        height: 16 * btn.s
        source: Qt.resolvedUrl("assets/icons/power.svg")
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: glyph
        source: glyph
        colorization: 1.0
        colorizationColor: Theme.vermLit
        opacity: area.containsMouse || menu.open ? 1 : 0.82
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.open = !menu.open
    }

    PanelWindow {
        id: menu

        property bool open: false

        screen: btn.barWindow ? btn.barWindow.screen : null
        visible: open
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "topbar-power"

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

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 50 * btn.s
                anchors.rightMargin: 12 * btn.s
                width: 184 * btn.s
                radius: 12 * btn.s
                clip: true

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.cardTop }
                    GradientStop { position: 1.0; color: Theme.cardBot }
                }
                border.width: 1
                border.color: Theme.border

                implicitHeight: col.implicitHeight + 12 * btn.s
                height: implicitHeight

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 10 * btn.s
                    anchors.rightMargin: 10 * btn.s
                    height: 1
                    color: Theme.sheen
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadow
                    shadowBlur: 0.9
                    shadowVerticalOffset: 4 * btn.s
                }

                MouseArea { anchors.fill: parent }

                Column {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6 * btn.s
                    spacing: 0

                    Repeater {
                        model: btn.actions

                        delegate: Column {
                            required property int index
                            required property var modelData

                            width: col.width

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.hair
                                visible: index > 0
                            }

                            Rectangle {
                                id: pill
                                width: parent.width
                                height: 34 * btn.s
                                radius: 8 * btn.s
                                color: rowArea.containsMouse ? Theme.accent16 : "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 6 * btn.s
                                    width: 3 * btn.s
                                    height: parent.height * 0.46
                                    radius: width / 2
                                    color: Theme.vermLit
                                    opacity: rowArea.containsMouse ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 18 * btn.s
                                    text: modelData.label
                                    color: rowArea.containsMouse ? Theme.cream : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 13 * btn.s
                                    font.weight: rowArea.containsMouse ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: btn.run(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
