import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// Click-to-confirm icon button for destructive session actions: a stray click
// never fires instantly. The first click arms the tile and a bone liquid fills
// it on its own, the glyph inverting to black; it confirms when the fill reaches
// the top, and a second click before then drains it back and cancels.
Rectangle {
    id: root

    property string icon: "circle"
    property string tip: ""
    // Top-edge controls open their bubble downward so it never leaves the panel.
    property bool tipBelow: false
    // Bubble edge to pin to: "center" (default), "left" or "right".
    property string tipAlign: "center"
    // Fill time (ms) from the arming click to the confirm.
    property int holdMs: 800
    signal activated()

    implicitWidth: 38
    implicitHeight: 38
    radius: Theme.radiusWidget
    color: tap.containsMouse
        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12)
        : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
        (tap.containsMouse || root.armed) ? 0.4 : 0.22)
    Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
    clip: true

    scale: tap.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    // Fill heat 0..1: once armed it rises to the top over holdMs and fires at 1;
    // disarming drains it back. Literal durations so reduce-motion can never
    // collapse the fill to an instant confirm.
    property bool armed: false
    property real heat: 0
    readonly property bool active: root.armed || root.heat > 0.001
    onArmedChanged: heat = armed ? 1 : 0
    Behavior on heat { NumberAnimation { duration: root.armed ? root.holdMs : 220; easing.type: Easing.OutCubic } }
    onHeatChanged: if (root.heat >= 0.999 && root.armed) root.fire()

    function fire() {
        root.armed = false;
        root.heat = 0;
        root.activated();
    }

    // Bone liquid rising from the base with a wavy top; repaints only while active.
    Canvas {
        id: liquid
        anchors.fill: parent
        property real phase: 0

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.heat <= 0.001)
                return;
            const w = width;
            const h = height;
            const level = h * (1 - root.heat);
            const amp = root.active ? 2.4 : 0;
            const k = 6.28318 / (w / 1.4);
            ctx.beginPath();
            ctx.moveTo(0, h);
            for (let x = 0; x <= w; x += 1.5)
                ctx.lineTo(x, level + amp * Math.sin(k * x + liquid.phase));
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Theme.inverseSurface;
            ctx.fill();
        }

        NumberAnimation on phase {
            running: root.active
            from: 0; to: 6.28318
            duration: 1100
            loops: Animation.Infinite
        }
        onPhaseChanged: requestPaint()
        Connections {
            target: root
            function onHeatChanged() { liquid.requestPaint(); }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        font.pixelSize: 18
        text: root.icon
        fill: root.heat > 0.5 ? 1 : 0
        // Flips to black once the bone plate has risen under it.
        color: root.heat > 0.5
            ? Theme.inverseOnSurface
            : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface, 3.0)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // First click arms and starts the fill; a second click before it tops
        // out cancels. Moving the pointer away never cancels: the fill is
        // autonomous once armed.
        onClicked: root.armed = !root.armed
    }

    QsTip {
        text: root.tip
        below: root.tipBelow
        align: root.tipAlign
        hovered: tap.containsMouse && !tap.pressed
    }
}
