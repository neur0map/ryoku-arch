import QtQuick
import "Singletons"

// bar module plate: the sharp-cornered slab every bar module sits on. a faint
// warm fill with a hairline edge; hover lifts the fill (the noctalia 10%-tint
// mechanic in Ryoku's brutalist skin) so a module reads as touchable before
// it's clicked. content is centred; the plate sizes to it plus padding.
Item {
    id: plate

    property real s: 1
    // plate height comes from the bar (a fraction of the band); width hugs content.
    property real padX: 10 * s
    default property alias content: slot.data
    property bool interactive: true
    // quiet = no resting fill; the plate only surfaces on hover (tray, title).
    property bool quiet: false
    readonly property alias hovered: hoverArea.containsMouse

    signal tapped()
    signal wheeled(int steps)

    implicitWidth: slot.implicitWidth + 2 * padX

    Rectangle {
        anchors.fill: parent
        color: hoverArea.containsMouse && plate.interactive
            ? Qt.alpha(Theme.bright, 0.10)
            : (plate.quiet ? "transparent" : Qt.alpha(Theme.bright, 0.045))
        border.width: 1
        border.color: hoverArea.containsMouse && plate.interactive
            ? Qt.alpha(Theme.bright, 0.22)
            : (plate.quiet ? "transparent" : Theme.hair)
        Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        Behavior on border.color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
    }

    // single-root content: the plate hugs its implicit size. (childrenRect is
    // unreliable under anchors; one root Row/Item per module is the contract.)
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
        enabled: plate.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: plate.tapped()
        onWheel: (w) => plate.wheeled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
