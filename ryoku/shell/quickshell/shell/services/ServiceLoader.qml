import QtQuick
import Quickshell

// Brings the shared service singletons online at startup. A QML singleton is
// constructed lazily on first access, so touching each entry here forces its
// construction (and, for ShellState, its per-monitor Variants) during load
// instead of on the first keybind, matching caelestia's eager ServiceLoader. The
// list is seeded at the shell.qml callsite and empty by default; grow it as
// surfaces migrate, and a later phase can split it into eager and Timer-deferred
// tiers (the iNiR pattern) once heavy providers land.
Scope {
    id: root

    // Service singletons to construct eagerly, in order.
    property var services: []

    Component.onCompleted: {
        // Reading each entry forces its singleton to construct now.
        for (let i = 0; i < services.length; i++)
            void services[i];
    }
}
