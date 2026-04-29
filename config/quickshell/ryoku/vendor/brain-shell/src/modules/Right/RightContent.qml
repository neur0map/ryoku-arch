import QtQuick
import Quickshell
import "../../components"
import "../../windows"
import "../../"

Item {
    id: root

    // Expand to fill the notch when notifications or network popup are open.
    implicitWidth: Popups.notificationsOpen
                   ? Theme.notificationsWidth
                   : Popups.networkOpen
                       ? Theme.networkPopupWidth
                       : Popups.notificationToastOpen
                           ? Theme.notificationToastWidth
                           :
                       contentRow.implicitWidth
    implicitHeight: contentRow.implicitHeight

    // ── Normal content — fades out when any right popup opens ─────────────────
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        opacity: (Popups.notificationsOpen || Popups.networkOpen) ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Network{}
        Audio{}
        Battery{}
        Clock{}
        SysTray{}
        Notifications{}
    }

    // ── Open indicator — fades in when any right popup opens ──────────────────
    Text {
        anchors.centerIn: parent
        text:           "▾"
        color:          Theme.active
        font.pixelSize: 14
        opacity:        (Popups.notificationsOpen || Popups.networkOpen) ? 1 : 0
        visible:        opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
