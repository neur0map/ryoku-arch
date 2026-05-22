import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule
import "../../components"
import Qt5Compat.GraphicalEffects
import Quickshell.Wayland

PanelWindow {
    id: win

    color: "transparent"

    anchors.top: true
    anchors.right: true

    implicitWidth: Services.Notification.popups.length > 0 ? 328 : 0
    implicitHeight: 600
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    Popout {
        id: mainPopout
        alignment: 1
        radius: 14
        color: ColorsModule.Colors.surface_container

        anchors.top: parent.top
        anchors.right: parent.right

        visible: Services.Notification.popups.length > 0

        width: 300
        height: toastColumn.implicitHeight + radius * 2

        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 3
            radius: 16
            samples: 24
            color: ColorsModule.Colors.shadow
        }

        Column {
            id: toastColumn
            width: mainPopout.width - mainPopout.radius * 2
            spacing: 0

            Repeater {
                model: Services.Notification.popups

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: toastColumn.width
                    height: notifCol.implicitHeight

                    Column {
                        id: notifCol
                        width: parent.width
                        spacing: 0

                        // separator above (all except the first notification)
                        Rectangle {
                            visible: index > 0
                            width: parent.width
                            height: visible ? 1 : 0
                            color: ColorsModule.Colors.outline_variant
                            opacity: 0.4
                        }

                        // top spacing
                        Item {
                            width: parent.width
                            height: index > 0 ? 10 : 0
                        }

                        // timer progress track
                        Rectangle {
                            id: timerTrack
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: ColorsModule.Colors.outline_variant
                            clip: true

                            Rectangle {
                                id: timerBar
                                anchors.left: parent.left
                                height: parent.height
                                radius: parent.radius
                                color: ColorsModule.Colors.primary
                                width: timerTrack.width

                                Component.onCompleted: {
                                    const totalDuration = modelData.notification.expireTimeout > 0
                                        ? modelData.notification.expireTimeout
                                        : 5000
                                    const elapsed = Date.now() - modelData.time.getTime()
                                    const remaining = Math.max(0, totalDuration - elapsed)
                                    timerAnim.duration = remaining
                                    timerAnim.from = timerTrack.width * (remaining / totalDuration)
                                    timerAnim.start()
                                }

                                NumberAnimation {
                                    id: timerAnim
                                    target: timerBar
                                    property: "width"
                                    to: 0
                                    easing.type: Easing.Linear
                                }
                            }
                        }

                        // spacing between bar and content
                        Item { width: parent.width; height: 8 }

                        // notification row
                        RowLayout {
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 7
                                color: "transparent"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true

                                    source: {
                                        const icon = modelData.appIcon;
                                        if (icon) {
                                            if (icon.startsWith("/"))
                                                return "file://" + icon;
                                            if (icon.includes("://"))
                                                return icon;
                                            return "image://icon/" + icon;
                                        }
                                        return "image://icon/dialog-information";
                                    }

                                    onStatusChanged: {
                                        if (status === Image.Error)
                                            source = "image://icon/dialog-information";
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: modelData.summary
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: ColorsModule.Colors.on_surface
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: modelData.body.length > 0
                                    text: modelData.body
                                    font.pixelSize: 12
                                    color: ColorsModule.Colors.on_surface_variant
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // bottom spacing
                        Item { width: parent.width; height: 10 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (modelData.actions.length > 0) {
                                let defaultAction = modelData.actions.find(a => a.id === "default");
                                if (defaultAction)
                                    defaultAction.invoke();
                                else
                                    modelData.actions[0].invoke();
                            }
                            modelData.popup = false;
                        }
                    }
                }
            }
        }
    }
}
