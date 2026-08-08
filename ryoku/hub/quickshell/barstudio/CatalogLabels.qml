import QtQuick

QtObject {
    function item(id) {
        switch (id) {
        case "app-launcher": return qsTr("App Launcher")
        case "audio-input": return qsTr("Audio Input")
        case "audio-output": return qsTr("Audio Output")
        case "battery": return qsTr("Battery")
        case "bluetooth": return qsTr("Bluetooth")
        case "clipboard": return qsTr("Clipboard")
        case "clock": return qsTr("Clock")
        case "color-picker": return qsTr("Color Picker")
        case "container": return qsTr("Container")
        case "divider": return qsTr("Divider")
        case "dock": return qsTr("Dock")
        case "launcher": return qsTr("Launcher")
        case "layout-switcher": return qsTr("Layout Switcher")
        case "lock": return qsTr("Lock")
        case "logout": return qsTr("Log Out")
        case "media": return qsTr("Media")
        case "music": return qsTr("Music")
        case "network": return qsTr("Network")
        case "notifications": return qsTr("Notifications")
        case "power-profile": return qsTr("Power Profile")
        case "quick-actions": return qsTr("Quick Actions")
        case "quick-settings": return qsTr("Quick Settings")
        case "reboot": return qsTr("Reboot")
        case "recording": return qsTr("Recording")
        case "screenshot": return qsTr("Screenshot")
        case "shutdown": return qsTr("Shut Down")
        case "spacer": return qsTr("Spacer")
        case "sysmon": return qsTr("System Monitor")
        case "theme": return qsTr("Theme")
        case "tray": return qsTr("Tray")
        case "vpn": return qsTr("VPN")
        case "wallpaper": return qsTr("Wallpaper")
        case "weather": return qsTr("Weather")
        case "workspaces": return qsTr("Workspaces")
        default: return qsTr("Unknown")
        }
    }

    function anchor(id) {
        switch (id) {
        case "bottom": return qsTr("Bottom")
        case "bottom-left": return qsTr("Bottom left")
        case "bottom-right": return qsTr("Bottom right")
        case "left": return qsTr("Left")
        case "right": return qsTr("Right")
        case "top": return qsTr("Top")
        case "top-left": return qsTr("Top left")
        case "top-right": return qsTr("Top right")
        default: return qsTr("Unknown")
        }
    }

    function surface(id) {
        switch (id) {
        case "stash": return qsTr("Stash")
        case "system": return qsTr("System")
        default: return qsTr("Unknown")
        }
    }

    function pane(id) {
        switch (id) {
        case "calendar": return qsTr("Calendar")
        case "media": return qsTr("Media")
        case "notifications": return qsTr("Notifications")
        case "recording": return qsTr("Recording")
        case "stash": return qsTr("Stash")
        case "weather": return qsTr("Weather")
        default: return qsTr("Unknown")
        }
    }

    function edge(id) {
        switch (id) {
        case "bottom": return qsTr("Bottom")
        case "left": return qsTr("Left")
        case "right": return qsTr("Right")
        case "top": return qsTr("Top")
        default: return qsTr("Unknown")
        }
    }

    function zone(id) {
        switch (id) {
        case "bottom": return qsTr("Bottom")
        case "center": return qsTr("Center")
        case "end": return qsTr("End")
        case "start": return qsTr("Start")
        case "top": return qsTr("Top")
        default: return qsTr("Unknown")
        }
    }
}