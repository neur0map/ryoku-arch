pragma ComponentBehavior: Bound

import Quickshell.Hyprland

// Wraps a Hyprland global-shortcuts-v1 handler so every shell keybind shares the
// single "ryoku" appid: the compositor dispatches `global:ryoku:<name>` straight
// to the running instance with zero process spawn, where the old path paid a Go
// client plus a `qs ipc call` per press. Consumers set `name`/`description` and
// handle `onPressed`/`onReleased` (inherited from GlobalShortcut); `appid` is
// pinned here so no surface can drift it and split the namespace.
GlobalShortcut {
    appid: "ryoku"
}
