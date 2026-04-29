import QtQuick
import Quickshell.Services.SystemTray
import "../../components"
import "../../windows"
import "../../"
import "../../services/"

IconBtn {
    text: ShellState.dnd
          ? "󰂛"
          : NotificationService.count > 0 ? "󰂚" : "󰂜"

    onClicked: {
        var next = !Popups.notificationsOpen
        Popups.closeAll()
        Popups.notificationsOpen = next
    }
}