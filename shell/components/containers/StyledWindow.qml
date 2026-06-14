import Quickshell
import Quickshell.Wayland
import Ryoku.Config


PanelWindow {

    required property string name

    WlrLayershell.namespace: `ryoku-${name}`
    color: "transparent"

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name
}
