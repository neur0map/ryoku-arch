import QtQuick
import Quickshell
import Ryoku.Blobs
import "modules/bar/popouts" as PillPopouts
import "services" as PillSingletons

// Built-in half of the nacre popup probe: verifies the consolidated bar popout
// (shell/modules/bar/popouts/Popout.qml) and the Media singleton
// (shell/services/Media.qml) resolve and behave against the merged shell tree.
// The external nacre/obi barstyle products are exercised separately in
// nacre-popup-probe.barstyles.qml, because they still import the retired pill.*
// namespace (see the header of nacre-popup-probe.sh).
ShellRoot {
    id: root

    // The consolidated bar popout now declares `group` and `frameThickness` as
    // `required` (Popout.qml); supplying both instantiates it cleanly, which is
    // the assertion: the built-in popout type resolves and builds.
    BlobGroup { id: probeGroup }
    PillPopouts.Popout {
        group: probeGroup
        frameThickness: 16
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            if (typeof PillSingletons.Media.pick !== "function")
                throw new Error("MEDIA-PLAYER-PICKER-PROBE-FAIL");
            const blankPlayer = { isPlaying: false, trackTitle: "" };
            const pausedPlayer = { isPlaying: false, trackTitle: "Paused track" };
            if (PillSingletons.Media.pick([blankPlayer, pausedPlayer]) !== pausedPlayer)
                throw new Error("MEDIA-PAUSED-PLAYER-PROBE-FAIL");
            console.log("NACRE-POPUP-PROBE-PASS");
            Qt.quit();
        }
    }
}
