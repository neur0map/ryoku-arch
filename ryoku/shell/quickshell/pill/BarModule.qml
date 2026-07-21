import QtQuick
import "Singletons"

// the module container, one look per bar skin. rounded skins (noctalia,
// caelestia) wear the fully rounded pill with the caelestia StateLayer feel
// (hover overlay + press ripple). aegis is flat on the band with a hairline
// accent underline that brightens on hover. stele is a sharp engraved cell
// with L-bracket corners. nacre is flat and transparent too: the frosted
// capsule drawn behind each cluster is the surface, so a module only lifts a
// soft hover overlay. content centres; the module hugs it plus padding.
Item {
    id: mod

    property real s: 1
    property bool vertical: false
    property real padX: 12 * s
    property real padY: 10 * s
    default property alias content: slot.data
    property bool interactive: true
    property bool filled: true  // a control module; false = a bare mark (the logo)
    readonly property alias hovered: hoverArea.containsMouse

    readonly property string style: Config.barStyle
    readonly property bool rounded: style === "noctalia" || style === "caelestia"
    // the flat iNiR-family module treatments: inir = TUI bordered cell, aurora =
    // faint glass tint (the full-width panel carries the translucency), angel =
    // a raised brutalist key with a hard accent offset shadow (no blur) that
    // deepens as it lifts on hover -- the "escalonado" carried from iNiR.
    readonly property bool tui:    style === "inir"
    readonly property bool glass:  style === "aurora"
    readonly property bool brutal: style === "angel"
    readonly property real modRadius: rounded ? Math.min(width, height) / 2
        : (tui || brutal) ? Math.max(2, Theme.radius) : 0
    readonly property bool raised: brutal && filled
    property real shadowOff: (hoverArea.containsMouse && interactive ? 5 : 2.5) * s
    Behavior on shadowOff { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }

    signal tapped()
    signal wheeled(int steps)

    implicitWidth: vertical ? width : slot.implicitWidth + 2 * padX
    implicitHeight: vertical ? slot.implicitHeight + 2 * padY : height

    // angel: the escalonado hard offset shadow -- a pure-offset accent plate
    // behind the key, no blur, deepening as the key lifts on hover.
    Rectangle {
        visible: mod.raised
        x: mod.shadowOff
        y: mod.shadowOff
        width: base.width
        height: base.height
        radius: base.radius
        color: Qt.alpha(Theme.brand, 0.5)
    }
    Rectangle {
        id: base
        anchors.fill: parent
        radius: mod.modRadius
        color: !mod.filled ? "transparent"
            : mod.rounded ? Theme.tileBg
            : mod.tui ? "transparent"
            : mod.glass ? "transparent"
            : mod.brutal ? Theme.tileBg
            : mod.style === "stele" ? Qt.alpha(Theme.bright, 0.03)
            : "transparent"
        border.width: (mod.brutal && mod.filled) ? Math.max(1, mod.s) : 0
        border.color: mod.brutal ? Qt.alpha(Theme.brand, 0.55) : "transparent"
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: base.radius
            color: Theme.cream
            opacity: hoverArea.containsMouse && mod.interactive ? (mod.rounded ? 0.08 : 0.05) : 0
            Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: ripple
            visible: mod.rounded
            property real cx: base.width / 2
            property real cy: base.height / 2
            x: cx - width / 2
            y: cy - width / 2
            height: width
            radius: width / 2
            color: Theme.cream
            opacity: 0
            width: 0

            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "width"; from: 0; to: Math.max(base.width, base.height) * 2.6; duration: Motion.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsSlowCurve }
                SequentialAnimation {
                    NumberAnimation { target: ripple; property: "opacity"; to: 0.1; duration: 60 }
                    NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: Motion.effectsSlow; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // aegis: a hairline accent underline on the inner edge, lit on hover.
    Rectangle {
        visible: mod.filled && mod.interactive && mod.style === "aegis"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, mod.s)
        color: Theme.verm
        opacity: hoverArea.containsMouse && mod.interactive ? 0.85 : 0.26
        Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
    }

    // stele: engraved corner brackets, brightening on hover.
    CornerTicks {
        visible: mod.filled && mod.style === "stele"
        anchors.fill: parent
        s: mod.s
        len: 6 * mod.s
        tint: hoverArea.containsMouse && mod.interactive ? Theme.subtle : Theme.hair
    }

    Item {
        id: slot
        anchors.centerIn: parent
        implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        width: implicitWidth
        height: implicitHeight
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: mod.interactive
        cursorShape: Qt.PointingHandCursor
        onPressed: (e) => {
            ripple.cx = e.x;
            ripple.cy = e.y;
            rippleAnim.restart();
        }
        onClicked: mod.tapped()
        onWheel: (w) => mod.wheeled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
