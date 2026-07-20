pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The input field for the mic widget: the default source, every capture
// device, and the streams currently recording from it. Classification mirrors
// the pill's Audio singleton (the ground truth for the installed Quickshell's
// PwNodeType names); volumes and mutes bind live through PwObjectTracker.
Singleton {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: (Pipewire.nodes && Pipewire.ready) ? Pipewire.nodes.values : []

    function typeOf(n) {
        return (n && typeof PwNodeType !== "undefined") ? PwNodeType.toString(n.type) : "";
    }

    // a real, switchable capture device (not a stream).
    function isInput(n) { return !!(n && !n.isSink && !n.isStream && n.audio); }
    // an application capturing from the graph (an input stream).
    function isRecorder(n) {
        return !!(n && n.isStream && n.audio && root.typeOf(n).indexOf("In") >= 0);
    }

    readonly property var inputs: root.nodes.filter(root.isInput)
    // the level meter runs its own cava capture on the default source, so it
    // shows up here as a recorder of itself; drop it by cava's node identity.
    readonly property var recorders: root.nodes.filter(function (n) {
        return root.isRecorder(n) && n.name !== "cava";
    })

    function setInput(n) { if (n) Pipewire.preferredDefaultAudioSource = n; }

    PwObjectTracker {
        objects: [root.source].filter(Boolean)
            .concat(root.inputs).concat(root.recorders)
    }
}
