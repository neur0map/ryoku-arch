pragma ComponentBehavior: Bound
import QtQuick
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The layer's system monitor: a mono-tracked style switcher over a Loader that
// swaps between three readings of the same Sys vitals (instrument rows, gauges,
// tiles). The chosen style persists per entry in ryolayer.json via Config.patch.
// The widget owns Sys.active: sampling runs only while this plate is live.
Item {
    id: sys

    property var slot: null
    property bool active: false

    // Sampling is gated on a live plate; last writer wins if two ever coexist.
    onActiveChanged: Sys.active = active
    Component.onCompleted: Sys.active = active
    Component.onDestruction: Sys.active = false

    readonly property string style: {
        if (!slot || !slot.entry)
            return "rows";
        var e = (Config.rev, Config.entry(slot.entry.id, slot.screenName));
        return (e && e.style) || "rows";
    }

    Row {
        id: switcher
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: Tokens.s1

        Repeater {
            model: [{ k: "rows", l: "ROWS" }, { k: "dials", l: "DIAL" }, { k: "tiles", l: "TILE" }]
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: sys.style === modelData.k
                width: Math.max(48, ct.implicitWidth + Tokens.s3)
                height: Tokens.ctlH - 6
                radius: Tokens.radius
                color: on ? Tokens.bone : (ch.hovered ? Tokens.tint10 : "transparent")
                border { width: Tokens.border; color: ch.hovered && !on ? Tokens.lineStrong : Tokens.line }
                Text {
                    id: ct
                    anchors.centerIn: parent
                    text: chip.modelData.l
                    color: chip.on ? Tokens.inkOnBone : Tokens.inkDim
                    font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                }
                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: if (sys.slot && sys.slot.entry)
                        Config.patch(sys.slot.entry.id, sys.slot.screenName, { style: chip.modelData.k })
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    Loader {
        anchors { top: switcher.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Tokens.s3 }
        source: Qt.resolvedUrl(sys.style === "dials" ? "SysDials.qml"
                             : sys.style === "tiles" ? "SysTiles.qml"
                             : "SysRows.qml")
    }
}
