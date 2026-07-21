pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Ryoku.Ui.Singletons

// One session action in the power panel's action row. Safe actions (lock, sleep)
// fire on a tap. Destructive ones (logout, restart, shutdown) fire only on a
// press-and-hold: the tile fills bottom-up with bone and inverts to a black-ink
// plate as it confirms, release early drains it. Inversion, not a red glow, is
// the beta-18 way to say "this is serious" -- one stray click never reboots the
// box. `s` is the content scale.
Item {
    id: root

    property real s: 1
    property string glyph: ""
    property string label: ""
    property bool confirm: false
    property var argv: []
    property string dispatch: ""

    signal ran()

    readonly property real tileW: 62 * root.s
    readonly property real tileH: 66 * root.s
    implicitWidth: tileW
    implicitHeight: tileH

    // hold-to-confirm: heat rides to 1 over the hold while pressed, drains back
    // when released early; reaching 1 fires. A tap fires a safe action outright.
    property bool holding: false
    property real heat: 0
    onHoldingChanged: heat = holding ? 1 : 0
    Behavior on heat { NumberAnimation { duration: root.holding ? 780 : 220; easing.type: Easing.OutCubic } }
    onHeatChanged: if (root.heat >= 0.999 && root.holding) root.fire()

    readonly property bool hovered: ma.containsMouse

    function fire() {
        root.holding = false;
        root.heat = 0;
        if (root.dispatch && root.dispatch.length)
            Hyprland.dispatch(root.dispatch);
        else if (root.argv && root.argv.length)
            Quickshell.execDetached(root.argv);
        root.ran();
    }

    Rectangle {
        id: tile
        anchors.fill: parent
        radius: Tokens.radius
        color: root.hovered ? Tokens.tint10 : "transparent"
        border.width: Tokens.border
        border.color: (root.hovered || root.heat > 0.01) ? Tokens.lineStrong : Tokens.line
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        clip: true

        // the confirm ramp: a bone plate rising from the base. At full height the
        // tile is inverted bone and the glyph reads black.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * root.heat
            color: Tokens.bone
            visible: root.heat > 0.001
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4 * root.s

        PowerIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            fill: root.heat > 0.5 ? 1 : (root.hovered ? 1 : 0)
            opsz: 24
            font.pixelSize: 23 * root.s
            // ink normally; flips to black once the bone plate is under it.
            color: root.heat > 0.5 ? Tokens.inkOnBone : (root.hovered ? Tokens.ink : Tokens.inkDim)
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Tokens.mono
            font.pixelSize: Tokens.fTiny * root.s
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Tokens.trackLabel
            color: root.heat > 0.5 ? Tokens.inkOnBone : (root.hovered ? Tokens.inkDim : Tokens.inkFaint)
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: if (root.confirm) root.holding = true
        onReleased: if (root.confirm) root.holding = false
        onCanceled: if (root.confirm) root.holding = false
        onExited: if (root.confirm) root.holding = false
        onClicked: if (!root.confirm) root.fire()
    }
}
