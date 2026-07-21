pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "Singletons"

// a cue for an active Hyprland special workspace (scratchpad): a small accent
// pill with a layers glyph + the scratchpad's name, shown only while a special
// workspace is up and collapsed to nothing otherwise. click toggles it away.
// tracks the activespecial event and seeds from hyprctl so it reads right on a
// fresh instance. `vertical` drops the label for a side bar.
Item {
    id: sw

    property real s: 1
    property bool vertical: false

    // raw special-workspace name for this session ("" = none active).
    property string special: ""
    readonly property bool active: special.length > 0
    readonly property string label: {
        var n = sw.special;
        if (n.indexOf("special:") === 0)
            n = n.slice(8);
        return n.length > 0 ? n : "scratch";
    }

    visible: active
    implicitWidth: active ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight

    // seed once from hyprctl; the activespecial event owns it after.
    Process {
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var ms = JSON.parse(text);
                    for (var i = 0; i < ms.length; i++) {
                        var s = ms[i].specialWorkspace;
                        if (s && s.name && s.name.length > 0) {
                            sw.special = s.name;
                            return;
                        }
                    }
                    sw.special = "";
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial" && event.name !== "activespecialv2")
                return;
            // activespecial>>name,monitor ; activespecialv2>>id,name,monitor
            var parts = String(event.data).split(",");
            sw.special = event.name === "activespecialv2" ? (parts[1] || "") : (parts[0] || "");
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5 * sw.s

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "layers"
            fill: 1
            color: Theme.brand
            font.pixelSize: 13 * sw.s
        }
        Text {
            visible: !sw.vertical
            anchors.verticalCenter: parent.verticalCenter
            text: sw.label
            color: Theme.brand
            font.family: Theme.font
            font.pixelSize: 10 * sw.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1 * sw.s
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch('hl.dsp.workspace.toggle_special({ name = "' + sw.label + '" })')
    }
}
