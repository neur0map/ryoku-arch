import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.ambxst.modules.services
import "./NotificationDelegate.qml"

ListView {
    id: root
    property bool popup: false

    spacing: 8

    model: root.popup ? Notifications.popupNotifications : Notifications.notifications

    delegate: NotificationDelegate {
        required property int index
        required property var modelData
        anchors.left: parent?.left
        anchors.right: parent?.right
        notificationObject: modelData
        expanded: true
        onlyNotification: true

        onDestroyRequested:
        {}
    }
}
