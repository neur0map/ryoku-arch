import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property alias zyuTheme: zyuTheme
    property alias dashboardState: dashboardState
    property alias logoutState: logoutState
    property bool musicVisible: false
    property bool wifiVisible:  false
    property bool btVisible:    false

    readonly property string configPath: Quickshell.env("RYOKU_VROOMIES_SHELL_DIR") || (Quickshell.env("HOME") + "/.config/quickshell/ryoku-vroomies-shell")
    readonly property string compPath:   configPath + "/components"
    readonly property string wrapperPath: Quickshell.env("RYOKU_VROOMIES_WRAPPER") || (Quickshell.env("HOME") + "/.local/bin/ryoku-vroomies-shell")

    QtObject {
        id: zyuTheme
        property bool floating_feel: true
        property color bar_bg:    "#000000"
        property color bar_fg:    "#ffffff"
        property color accent:    "#ffffff"
        property color widget_bg: "#1a1a1a"
        property int bar_height: 50
        property int rounding:   15
        property font mainFont: Qt.font({family: "JetBrainsMono Nerd Font", pixelSize: 14, bold: true})
    }
    QtObject { id: dashboardState; property bool show: false }
    QtObject { id: logoutState;    property bool show: false }

    Process {
        id: colorProc
        command: ["bash", "-c", "cat " + configPath + "/Colors/colors.json"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var c = JSON.parse(data)
                    if (c.background)        zyuTheme.bar_bg    = c.background
                    if (c.on_surface)        zyuTheme.bar_fg    = c.on_surface
                    if (c.primary)           zyuTheme.accent    = c.primary
                    if (c.surface_container) zyuTheme.widget_bg = c.surface_container
                } catch(e) {}
            }
        }
        Component.onCompleted: running = true
    }

    IpcHandler {
        target: "vroomies"

        function launcher(): void {
            Quickshell.execDetached([root.wrapperPath, "launcher"])
        }

        function dashboard(): void {
            dashboardState.show = !dashboardState.show
        }

        function power(): void {
            dashboardState.show = true
        }
    }

    Loader { source: compPath + "/Bar/Sway.qml" }
    Loader { source: compPath + "/Dashboard/Sway.qml" }
    Loader { source: compPath + "/MusicPanel.qml" }
    Loader { source: compPath + "/WifiPanel.qml" }
    Loader { source: compPath + "/BluetoothPanel.qml" }
    Loader { source: compPath + "/Clock.qml" }
    Loader { source: compPath + "/linux.qml" }
}
