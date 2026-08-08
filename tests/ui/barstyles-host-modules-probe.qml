import QtQuick
import Quickshell
import pill.framebars.menus as Menus
import pill.popouts as Popouts

ShellRoot {
    id: root

    Component { id: audioPicker; Menus.AudioDevicePicker { width: 300 } }
    Component { id: notifications; Menus.MenuNotifications { width: 410 } }
    Component { id: chip; Popouts.PopoutChip {} }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            const picker = audioPicker.createObject(root);
            const history = notifications.createObject(root, {"s": 1, "open": false});
            const token = chip.createObject(root);
            if (!picker || !history || !token)
                throw new Error("host module component creation failed");
            picker.destroy();
            history.destroy();
            token.destroy();
            console.log("BARSTYLE-HOST-MODULES-PROBE-PASS");
            Qt.quit();
        }
    }
}
