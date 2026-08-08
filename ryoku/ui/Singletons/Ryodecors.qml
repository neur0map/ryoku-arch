pragma Singleton
import QtQuick
import Quickshell

// Where the shipped decor art set lives on a user box: ~/Pictures/ryodecors,
// seeded by the installer and kept current by `ryoku doctor`, so it sits beside
// Wallpapers and livewalls where a user can see and swap it. Decor and Placard
// resolve their baked art through `dir`; a custom pick keeps its own absolute
// path, so it never routes through here.
Singleton {
    readonly property string dir: "file://" + (Quickshell.env("HOME") || "") + "/Pictures/ryodecors/"
}
