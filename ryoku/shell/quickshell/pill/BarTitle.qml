import QtQuick
import "Singletons"

// the focused-window title. on a focus change the outgoing title cross-fades
// out (a ghost layer) while the new one fades in, and the width eases to the
// new length instead of snapping, so the left island and its frame lobe resize
// smoothly. the live layer is bound straight to the source, so the title always
// shows; an empty title (no window, or the toggle off) collapses to nothing.
Item {
    id: root

    property real s: 1
    property string label: ""
    property real maxWidth: 240
    readonly property real lead: 6 * s

    property bool ready: false
    property string prevLabel: ""
    Component.onCompleted: { prevLabel = label; ready = true; }

    clip: true
    width: label.length > 0 ? Math.min(metrics.implicitWidth, maxWidth - lead) + lead : 0
    implicitWidth: width
    height: metrics.implicitHeight
    implicitHeight: height
    Behavior on width {
        enabled: root.ready
        NumberAnimation { duration: Motion.spatial; easing.type: Easing.OutCubic }
    }

    onLabelChanged: {
        if (!ready)
            return;
        ghost.text = prevLabel;
        prevLabel = label;
        ghost.opacity = 1;
        live.opacity = 0;
        fade.restart();
    }
    ParallelAnimation {
        id: fade
        NumberAnimation { target: ghost; property: "opacity"; to: 0; duration: Motion.effects; easing.type: Easing.OutCubic }
        NumberAnimation { target: live; property: "opacity"; to: 1; duration: Motion.effects; easing.type: Easing.OutCubic }
    }

    Text {
        id: metrics
        visible: false
        text: root.label
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
        font.weight: Font.Medium
    }

    // the old title, held and faded out on a change.
    Text {
        id: ghost
        x: root.lead
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.lead
        elide: Text.ElideRight
        color: Theme.dim
        font: metrics.font
        opacity: 0
    }
    // the current title.
    Text {
        id: live
        x: root.lead
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.lead
        elide: Text.ElideRight
        text: root.label
        color: Theme.dim
        font: metrics.font
        opacity: 1
    }
}
