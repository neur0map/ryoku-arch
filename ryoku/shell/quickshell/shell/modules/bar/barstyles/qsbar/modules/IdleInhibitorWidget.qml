import QtQuick

// True idle inhibitor (Waybar-style). Toggles root.idleInhibited, which drives
// the Quickshell.Wayland.IdleInhibitor attached to the bar window in BarSlot.qml.
// While ON, Hyprland suppresses idle (no lock/dpms) via the idle-inhibit
// protocol — the hypridle daemon keeps running, it just isn't told to idle.
Item {
    id: rootMod
    required property var root

    implicitWidth: 22
    implicitHeight: 28

    readonly property bool on: root.idleInhibited
    readonly property string tooltipText: on ? "Idle inhibited: ON" : "Idle inhibited: OFF"

    UiText {
        anchors.centerIn: parent
        // 󰛨 U+F06E8 = activated / 󰛩 U+F06E9 = deactivated
        text: rootMod.on ? String.fromCodePoint(0xF06E8) : String.fromCodePoint(0xF06E9)
        renderType: Text.QtRendering
        font.family: root.mono
        font.pixelSize: 14
        color: rootMod.on
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: { tip.hide(); root.idleInhibited = !root.idleInhibited }
    }
}
