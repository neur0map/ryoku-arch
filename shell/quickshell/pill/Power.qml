pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "Singletons"

/**
 * Power surface: a row of hand-drawn session glyphs split by a hairline into a
 * safe group (lock, logout, sleep; fire on tap) and a destructive group
 * (restart, shutdown; press-and-hold). Holding a destructive tile ramps a
 * bottom-up heat fill, releasing early drains it, so a stray click can never
 * reboot the machine. Only the hovered or held action shows its label.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 17
    mRight: 17
    mBottom: 14

    property string hovered: ""

    property int holdingIndex: -1
    property real holdProgress: 0

    readonly property real anchorX: tiles.x + tiles.width / 2
    readonly property real anchorY: tiles.y - 10 * root.s
    property real tileHeatX: 0
    property real tileHeatY: 0
    property string soulKey: ""
    property real hoverX: 0
    property real hoverY: 0
    readonly property real heatX: holdingIndex >= 0 ? tileHeatX : (soulKey.length ? hoverX : anchorX)
    readonly property real heatY: holdingIndex >= 0 ? tileHeatY : (soulKey.length ? hoverY : anchorY)

    ameForm: holdingIndex >= 0 ? "dock" : (soulKey.length ? "soul" : "off")
    amePoint: Qt.point(heatX, heatY)

    readonly property var actions: [
        { key: "lock",     glyph: "lock",     label: "Lock",     confirm: false, dispatch: "",             argv: ["ryoku-shell", "lock"] },
        { key: "logout",   glyph: "logout",   label: "Logout",   confirm: true,  dispatch: "hl.dsp.exit()", argv: [] },
        { key: "suspend",  glyph: "suspend",  label: "Sleep",    confirm: false, dispatch: "",             argv: ["systemctl", "suspend"] },
        { key: "reboot",   glyph: "reboot",   label: "Restart",  confirm: true,  dispatch: "",             argv: ["systemctl", "reboot"] },
        { key: "shutdown", glyph: "shutdown", label: "Shutdown", confirm: true,  dispatch: "",             argv: ["systemctl", "poweroff"] }
    ]

    readonly property int splitAfter: 2

    function run(a) {
        if (a.dispatch && a.dispatch.length)
            Hyprland.dispatch(a.dispatch);
        else
            Quickshell.execDetached(a.argv);
        root.requestClose();
    }

    onActiveChanged: if (!active) {
        hovered = "";
        soulKey = "";
        holdingIndex = -1;
        holdProgress = 0;
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 22 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "電"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "POWER"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }
    }

    Row {
        id: tiles
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: header.bottom
        anchors.topMargin: 14 * root.s
        spacing: 12 * root.s

        Repeater {
            model: root.actions

            delegate: Row {
                id: cell
                required property int index
                required property var modelData
                spacing: 12 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cell.index === root.splitAfter
                    width: 1
                    height: 26 * root.s
                    color: Theme.hair
                }

                Item {
                    id: tile
                    width: 50 * root.s
                    height: 50 * root.s

                    readonly property real hold: heat.hold
                    readonly property bool isHover: root.hovered === cell.modelData.key
                    readonly property bool holding: heat.holding
                    readonly property bool lit: isHover || tile.holding
                    readonly property color accent: cell.modelData.confirm ? Theme.vermLit : Theme.cream

                    onHoldChanged: {
                        if (cell.modelData.confirm && tile.hold > 0.001) {
                            root.holdingIndex = cell.index;
                            root.holdProgress = tile.hold;
                            const c = tile.mapToItem(root, tile.width / 2, tile.height / 2);
                            root.tileHeatX = c.x;
                            root.tileHeatY = c.y;
                        } else if (root.holdingIndex === cell.index) {
                            root.holdingIndex = -1;
                            root.holdProgress = 0;
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Motion.rTile * root.s
                        color: tile.isHover ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: tile.isHover ? Theme.frameBorder : Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    /**
                     * Heat fill lives in a ClippingRectangle that carries the
                     * tile's corner radius. A plain Rectangle with its own radius
                     * gets it clamped to height/2 while the fill is still flat,
                     * so corners poked outside the tile outline on the first beat
                     * of every hold.
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
                        width: 22 * root.s
                        height: 22 * root.s
                        name: cell.modelData.glyph
                        color: tile.holding ? Theme.flameCore : (tile.lit ? tile.accent : Theme.iconDim)
                        stroke: 1.9
                    }

                    HeatHold {
                        id: heat
                        onConfirmed: root.run(cell.modelData)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.hovered = cell.modelData.key;
                            root.soulKey = cell.modelData.key;
                            const c = tile.mapToItem(root, tile.width / 2, 0);
                            root.hoverX = c.x;
                            root.hoverY = c.y - 9 * root.s;
                        }
                        onExited: {
                            if (root.hovered === cell.modelData.key)
                                root.hovered = "";
                            if (cell.modelData.confirm)
                                heat.cancel();
                        }
                        onPressed: if (cell.modelData.confirm) heat.press()
                        onReleased: if (cell.modelData.confirm) heat.release()
                        onClicked: {
                            if (!cell.modelData.confirm)
                                root.run(cell.modelData);
                        }
                    }
                }
            }
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: tiles.bottom
        anchors.topMargin: 12 * root.s
        readonly property string focusKey: root.holdingIndex >= 0
            ? root.actions[root.holdingIndex].key : root.hovered
        readonly property var act: {
            for (var i = 0; i < root.actions.length; i++)
                if (root.actions[i].key === label.focusKey)
                    return root.actions[i];
            return null;
        }
        text: act ? (act.confirm ? act.label + " · hold" : act.label) : ""
        color: act && act.confirm ? Theme.vermLit : Theme.subtle
        font.family: Theme.font
        font.pixelSize: 11 * root.s
        font.weight: Font.Medium
        font.letterSpacing: 0.4 * root.s
        opacity: text.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
