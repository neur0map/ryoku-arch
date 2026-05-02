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

    function toggleControlCenter() {
        var next = !Popups.settingsMenuOpen
        Popups.closeAll()
        Popups.requestSettingsMenuPage("home", "")
        Popups.settingsMenuOpen = next
    }

    // ── Normal content — fades out when any right popup opens ─────────────────
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        opacity: (Popups.notificationsOpen || Popups.networkOpen || Popups.settingsMenuOpen) ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Network{}
        Audio{}
        Battery{}
        Clock{}
        // Ryoku: SysTray + Notifications removed from bar (icons became
        // visually unfit; their popups are dormant per Spec 1 Reading X
        // anyway). Re-add when the popups activate in Spec 3+.
        // SysTray{}
        // Notifications{}
    }

    MouseArea {
        id: rightPillControlCenterMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleControlCenter()
    }

    // ── Open indicator — fades in when any right popup opens ──────────────────
    Text {
        anchors.centerIn: parent
        text:           "▾"
        color:          Theme.active
        font.pixelSize: 12
        opacity:        (Popups.notificationsOpen || Popups.networkOpen || Popups.settingsMenuOpen) ? 1 : 0
        visible:        opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
