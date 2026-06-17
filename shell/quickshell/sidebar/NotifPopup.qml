pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "Singletons"

Rectangle {
    id: toast
    required property var notif
    property real s: 1

    readonly property var acts: notif.actions.filter(function(a) { return a.text.length > 0; })

    radius: 15 * s
    border.width: 1
    border.color: notif.urgency === NotificationUrgency.Critical ? Theme.vermLit : Theme.border
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.panelTop }
        GradientStop { position: 1.0; color: Theme.panelBot }
    }
    implicitHeight: body.implicitHeight + 28 * s

    Timer {
        interval: Math.max(300, (Notifs.expireAt[toast.notif.id] || 0) - Date.now())
        running: toast.notif.urgency !== NotificationUrgency.Critical
        onTriggered: Notifs.removePopup(toast.notif)
    }

    Row {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14 * toast.s
        spacing: 12 * toast.s

        Rectangle {
            width: 40 * toast.s
            height: 40 * toast.s
            radius: 12 * toast.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.border

            Image {
                id: toastImg
                anchors.fill: parent
                anchors.margins: toast.notif.image ? 0 : 8 * toast.s
                source: toast.notif.image
                    ? toast.notif.image
                    : (toast.notif.appIcon ? Quickshell.iconPath(toast.notif.appIcon, "") : "")
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: source.toString().length > 0
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !toastImg.visible
                width: 11 * toast.s
                height: 11 * toast.s
                radius: 3 * toast.s
                rotation: 45
                color: Theme.verm
            }
        }

        Column {
            width: parent.width - 52 * toast.s
            spacing: 3 * toast.s

            Item {
                width: parent.width
                height: tTitle.implicitHeight

                Text {
                    id: tTitle
                    width: parent.width - 24 * toast.s
                    text: toast.notif.summary
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 14.5 * toast.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    text: "✕"
                    color: Theme.faint
                    font.pixelSize: 13 * toast.s

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6 * toast.s
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.removePopup(toast.notif)
                    }
                }
            }

            Text {
                width: parent.width
                visible: toast.notif.body.length > 0
                text: toast.notif.body
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 13 * toast.s
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Row {
                visible: toast.acts.length > 0
                spacing: 8 * toast.s
                topPadding: 7 * toast.s

                Repeater {
                    model: toast.acts

                    Rectangle {
                        id: actPill
                        required property var modelData
                        required property int index

                        radius: 999
                        color: Theme.tileBg
                        border.width: 1
                        border.color: actPill.index === 0 ? Theme.accent45 : Theme.border
                        implicitHeight: 26 * toast.s
                        implicitWidth: actText.implicitWidth + 26 * toast.s

                        Text {
                            id: actText
                            anchors.centerIn: parent
                            text: actPill.modelData.text
                            color: actPill.index === 0 ? Theme.vermLit : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 11 * toast.s
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actPill.modelData.invoke();
                                Notifs.removePopup(toast.notif);
                            }
                        }
                    }
                }
            }
        }
    }
}
