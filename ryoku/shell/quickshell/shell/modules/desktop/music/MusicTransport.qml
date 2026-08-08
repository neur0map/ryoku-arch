pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "../../../components"

// The three moves: reverse, play or pause, skip. Play/pause wears the sleeve's
// colour as the one filled tile, so the widget has a single focal control.
Row {
    id: transport

    property real s: 1
    property color accent: Theme.accent
    property color ink: Theme.ink
    // ink for the one filled tile. Not named onAccent: QML would read that as a
    // change handler for `accent` and drop the assignment.
    property color inkOnAccent: Theme.surface
    property bool playing: false
    property bool canPrevious: false
    property bool canNext: false
    property bool canToggle: false

    signal previous()
    signal toggle()
    signal next()

    spacing: 6 * transport.s

    component Move: Item {
        id: move
        property string glyph: ""
        property bool filled: false
        property bool live: true
        property bool pulsing: false
        signal activated()

        width: (move.filled ? 38 : 30) * transport.s
        height: move.width

        opacity: move.live ? 1 : 0.35

        // focal glow: the one filled tile sits on a soft accent seat that
        // breathes while the track plays, so the eye lands on play/pause first.
        Rectangle {
            visible: move.filled
            anchors.centerIn: parent
            width: parent.width + 12 * transport.s
            height: width
            radius: width / 2
            color: transport.accent
            opacity: 0.18
            SequentialAnimation on opacity {
                running: move.pulsing && move.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.08; duration: 1000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.26; duration: 1000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: move.filled ? transport.accent
                : (hover.hovered ? Qt.rgba(transport.ink.r, transport.ink.g, transport.ink.b, 0.10)
                                 : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: (move.filled ? 17 : 14) * transport.s
            height: width
            name: move.glyph
            color: move.filled ? transport.inkOnAccent : transport.ink
        }
        // press dip: the same physical acknowledgement the menu rows use.
        scale: tap.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: tap
            enabled: move.live
            onTapped: move.activated()
        }
    }

    Move {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "prev"
        live: transport.canPrevious
        onActivated: transport.previous()
    }
    Move {
        anchors.verticalCenter: parent.verticalCenter
        filled: true
        pulsing: transport.playing
        glyph: transport.playing ? "pause" : "play"
        live: transport.canToggle
        onActivated: transport.toggle()
    }
    Move {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "next"
        live: transport.canNext
        onActivated: transport.next()
    }
}
