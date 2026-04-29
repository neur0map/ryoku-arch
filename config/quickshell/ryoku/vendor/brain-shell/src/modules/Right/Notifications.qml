import QtQuick
import Quickshell.Services.SystemTray
import "../../components"
import "../../windows"
import "../../"
import "../../services/"

// Ryoku: wrap IconBtn in a notch-height Item so the bell vertically
// centers in the bar instead of top-aligning at row top.
Item {
    implicitWidth:  btn.implicitWidth
    implicitHeight: Theme.notchHeight

    IconBtn {
        id: btn
        anchors.centerIn: parent

        text: ShellState.dnd
              ? ""
              : NotificationService.count > 0 ? "" : ""

        onClicked: {
            var next = !Popups.notificationsOpen
            Popups.closeAll()
            Popups.notificationsOpen = next
        }
    }
}
