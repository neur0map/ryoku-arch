pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."
import "../Singletons"

/**
 * Power popout content for the frame: a vertical column of hand-drawn session
 * glyphs with Shutdown enlarged at the centre as the primary action. The
 * destructive holds (Logout, Restart, Shutdown) flank the centre and fire only
 * on press-and-hold, ramping a bottom-up heat fill; releasing early drains it,
 * so a stray click can never reboot the machine. The safe taps (Lock, Sleep)
 * sit at the ends.
 *
 * Root is a plain transparent Item: the blob body behind it (the Popout surface)
 * is what the user sees, so painting a background here would double it.
 */
Item {
    id: root

    anchors.fill: parent

    // Host passes its content scale; every sizing term reads root.s.
    property real s: 1

    // Emitted after an action runs so the host can dismiss the popout. The
    // popout also closes on hover-leave, so this is just a courtesy.
    signal closed()

    property string hovered: ""

    // Ordered top -> bottom with Shutdown at the centre (index 2): safe taps at
    // the ends, the destructive holds clustered around the central Shutdown.
    readonly property var actions: [
        { key: "lock",     glyph: "lock",     label: "Lock",     confirm: false, dispatch: "",              argv: ["ryoku-shell", "lock"] },
        { key: "logout",   glyph: "logout",   label: "Logout",   confirm: true,  dispatch: "hl.dsp.exit()", argv: [] },
        { key: "shutdown", glyph: "shutdown", label: "Shutdown", confirm: true,  dispatch: "",              argv: ["systemctl", "poweroff"] },
        { key: "reboot",   glyph: "reboot",   label: "Restart",  confirm: true,  dispatch: "",              argv: ["systemctl", "reboot"] },
        { key: "suspend",  glyph: "suspend",  label: "Sleep",    confirm: false, dispatch: "",              argv: ["systemctl", "suspend"] }
    ]

    readonly property int centerIndex: 2

    function run(a) {
        if (a.dispatch && a.dispatch.length)
            Hyprland.dispatch(a.dispatch);
        else
            Quickshell.execDetached(a.argv);
        root.closed();
    }
    Column {
        id: tiles
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 11 * root.s

        Repeater {
            model: root.actions

            delegate: Item {
                id: tile
                required property int index
                required property var modelData

                readonly property bool center: index === root.centerIndex
                readonly property real dim: (center ? 62 : 46) * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                width: dim
                height: dim

                readonly property real hold: heat.hold
                readonly property bool isHover: root.hovered === modelData.key
                readonly property bool holding: heat.holding
                readonly property bool lit: isHover || tile.holding
                readonly property color accent: modelData.confirm ? Theme.vermLit : Theme.cream

                Rectangle {
                    anchors.fill: parent
                    radius: Motion.rTile * root.s
                    color: tile.isHover ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: tile.center ? (tile.lit ? Theme.vermLit : Theme.frameBorder)
                                              : (tile.isHover ? Theme.frameBorder : Theme.border)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                /**
                 * Heat fill lives in a ClippingRectangle that carries the tile's
                 * corner radius. A plain Rectangle with its own radius gets it
                 * clamped to height/2 while the fill is still flat, so corners
                 * poke outside the tile outline on the first beat of every hold.
                 */
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: (Motion.rTile - 1) * root.s
                    color: "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: tile.height * tile.hold
                        visible: tile.holding
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.alpha(Theme.verm, 0.7) }
                            GradientStop { position: 1.0; color: Qt.alpha(Theme.vermLit, 0.15) }
                        }
                    }
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    width: (tile.center ? 28 : 22) * root.s
                    height: (tile.center ? 28 : 22) * root.s
                    name: tile.modelData.glyph
                    color: tile.holding ? Theme.flameCore
                                        : (tile.center ? (tile.lit ? Theme.vermLit : Theme.cream)
                                                       : (tile.lit ? tile.accent : Theme.iconDim))
                    stroke: 1.9
                }

                HeatHold {
                    id: heat
                    onConfirmed: root.run(tile.modelData)
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hovered = tile.modelData.key
                    onExited: {
                        if (root.hovered === tile.modelData.key)
                            root.hovered = "";
                        if (tile.modelData.confirm)
                            heat.cancel();
                    }
                    onPressed: if (tile.modelData.confirm) heat.press()
                    onReleased: if (tile.modelData.confirm) heat.release()
                    onClicked: {
                        if (!tile.modelData.confirm)
                            root.run(tile.modelData);
                    }
                }
            }
        }
    }
}
